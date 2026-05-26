defmodule MedoruWeb.Push do
  @moduledoc """
  Web Push notification sender without external dependencies.

  Implements VAPID authentication (RFC 8292) and payload encryption
  (RFC 8291 / Message Encryption for Web Push) using only Erlang's
  `:crypto` / `:public_key` and `Req`.

  This replaces `web_push_encryption` which pulls in `jose` — a
  dependency that requires Erlang/OTP 25+ for the `dynamic()` type.
  """

  @max_payload_length 4078
  @one_buffer <<1>>
  @auth_info "Content-Encoding: auth" <> <<0>>
  @supported_encodings ~w(aesgcm)

  @doc """
  Sends a web push notification with a payload.

  ## Arguments

    * `message` – binary payload (usually JSON).
    * `subscription` – `%{endpoint: url, keys: %{p256dh: key, auth: key}}`.
    * `ttl` – time to live in seconds (default `0`).

  ## Return value

  Returns whatever `Req.post/2` returns:
  `{:ok, %Req.Response{}} | {:error, Exception.t()}`.
  """
  def send_web_push(message, subscription, ttl \\ 0)

  def send_web_push(_message, _subscription, ttl)
      when not is_integer(ttl) or ttl < 0 do
    raise ArgumentError, "send_web_push expects a non-negative integer ttl"
  end

  def send_web_push(message, %{endpoint: endpoint} = subscription, ttl) do
    payload = encrypt(message, subscription)

    vapid_headers = get_vapid_headers(make_audience(endpoint), "aesgcm")

    headers =
      Map.merge(vapid_headers, %{
        "TTL" => to_string(ttl),
        "Content-Encoding" => "aesgcm",
        "Encryption" => "salt=#{ub64(payload.salt)}"
      })

    headers =
      Map.put(
        headers,
        "Crypto-Key",
        "dh=#{ub64(payload.server_public_key)};" <> headers["Crypto-Key"]
      )

    Req.post(endpoint,
      body: payload.ciphertext,
      headers: headers,
      connect_options: [transport_opts: [versions: [:"tlsv1.2"]]]
    )
  end

  def send_web_push(_message, _subscription, _ttl) do
    raise ArgumentError,
          "send_web_push expects a subscription with an :endpoint parameter"
  end

  # --------------------------------------------------------------------------
  # VAPID (RFC 8292)
  # --------------------------------------------------------------------------

  defp get_vapid_headers(audience, content_encoding, expiration \\ 12 * 3600) do
    unless content_encoding in @supported_encodings do
      raise ArgumentError, "Unsupported content encoding: #{content_encoding}"
    end

    expiration_timestamp = DateTime.to_unix(DateTime.utc_now()) + expiration

    vapid = Application.fetch_env!(:medoru, :vapid_details)

    _public_key = Base.url_decode64!(vapid[:public_key], padding: false)
    private_key = Base.url_decode64!(vapid[:private_key], padding: false)

    header = ~s({"alg":"ES256","typ":"JWT"})

    payload =
      Jason.encode!(%{
        aud: audience,
        exp: expiration_timestamp,
        sub: vapid[:subject]
      })

    signing_input =
      Base.url_encode64(header, padding: false) <>
        "." <> Base.url_encode64(payload, padding: false)

    signature = sign_ecdsa(signing_input, private_key)

    jwt = signing_input <> "." <> Base.url_encode64(signature, padding: false)

    headers(content_encoding, jwt, vapid[:public_key])
  end

  defp headers("aesgcm", jwt, pub) do
    %{
      "Authorization" => "WebPush " <> jwt,
      "Crypto-Key" => "p256ecdsa=" <> pub
    }
  end

  # Sign with ECDSA P-256 + SHA-256 and return the raw r || s signature
  # (64 bytes), which is what JWT ES256 requires.
  defp sign_ecdsa(message, private_key) do
    # :crypto.sign/4 returns a DER-encoded ECDSA-Sig-Value.
    der_signature = :crypto.sign(:ecdsa, :sha256, message, [private_key, :prime256v1])

    # Decode DER to extract r and s integers.
    {:"ECDSA-Sig-Value", r, s} =
      :public_key.der_decode(:"ECDSA-Sig-Value", der_signature)

    # Encode as fixed-width 32-byte big-endian integers.
    r_bytes = :binary.encode_unsigned(r)
    s_bytes = :binary.encode_unsigned(s)

    r_padded = pad_left(r_bytes, 32)
    s_padded = pad_left(s_bytes, 32)

    r_padded <> s_padded
  end

  defp pad_left(binary, length) when byte_size(binary) >= length, do: binary

  defp pad_left(binary, length) do
    :binary.copy(<<0>>, length - byte_size(binary)) <> binary
  end

  # --------------------------------------------------------------------------
  # Payload Encryption (RFC 8291)
  # --------------------------------------------------------------------------

  @doc false
  def encrypt(message, subscription, padding_length \\ 0)

  def encrypt(message, _subscription, padding_length)
       when byte_size(message) + padding_length > @max_payload_length do
    raise ArgumentError,
          "Payload is too large. The current length is #{byte_size(message)} bytes plus " <>
            "#{padding_length} bytes of padding but the max length is #{@max_payload_length} bytes"
  end

  def encrypt(message, subscription, padding_length) do
    padding = make_padding(padding_length)
    plaintext = padding <> message

    validate_subscription(subscription)

    client_public_key = Base.url_decode64!(subscription.keys.p256dh, padding: false)
    client_auth_token = Base.url_decode64!(subscription.keys.auth, padding: false)

    validate_length!(client_auth_token, 16, "Subscription's Auth token is not 16 bytes.")
    validate_length!(client_public_key, 65, "Subscription's client key (p256dh) is invalid.")

    salt = :crypto.strong_rand_bytes(16)

    {server_public_key, server_private_key} = :crypto.generate_key(:ecdh, :prime256v1)

    shared_secret =
      :crypto.compute_key(:ecdh, client_public_key, server_private_key, :prime256v1)

    prk = hkdf(client_auth_token, shared_secret, @auth_info, 32)

    context = create_context(client_public_key, server_public_key)

    content_encryption_key_info = create_info("aesgcm", context)
    content_encryption_key = hkdf(salt, prk, content_encryption_key_info, 16)

    nonce_info = create_info("nonce", context)
    nonce = hkdf(salt, prk, nonce_info, 12)

    ciphertext = encrypt_payload(plaintext, content_encryption_key, nonce)

    %{ciphertext: ciphertext, salt: salt, server_public_key: server_public_key}
  end

  # HKDF-Extract + HKDF-Expand (single block, length ≤ 32).
  defp hkdf(salt, ikm, info, length) do
    prk =
      :crypto.mac_init(:hmac, :sha256, salt)
      |> :crypto.mac_update(ikm)
      |> :crypto.mac_final()

    :crypto.mac_init(:hmac, :sha256, prk)
    |> :crypto.mac_update(info)
    |> :crypto.mac_update(@one_buffer)
    |> :crypto.mac_final()
    |> :binary.part(0, length)
  end

  defp create_context(client_public_key, _server_public_key)
       when byte_size(client_public_key) != 65,
       do: raise(ArgumentError, "invalid client public key length")

  defp create_context(_client_public_key, server_public_key)
       when byte_size(server_public_key) != 65,
       do: raise(ArgumentError, "invalid server public key length")

  defp create_context(client_public_key, server_public_key) do
    <<0, byte_size(client_public_key)::unsigned-big-integer-size(16)>> <>
      client_public_key <>
      <<byte_size(server_public_key)::unsigned-big-integer-size(16)>> <> server_public_key
  end

  defp create_info(_type, context) when byte_size(context) != 135,
    do: raise(ArgumentError, "Context argument has invalid size")

  defp create_info(type, context) do
    "Content-Encoding: " <> type <> <<0>> <> "P-256" <> context
  end

  defp encrypt_payload(plaintext, content_encryption_key, nonce) do
    {cipher_text, cipher_tag} =
      :crypto.crypto_one_time_aead(
        :aes_128_gcm,
        content_encryption_key,
        nonce,
        plaintext,
        "",
        true
      )

    cipher_text <> cipher_tag
  end

  defp validate_subscription(%{keys: %{p256dh: p256dh, auth: auth}})
       when not is_nil(p256dh) and not is_nil(auth),
       do: :ok

  defp validate_subscription(_subscription) do
    raise ArgumentError, "Subscription is missing some encryption details."
  end

  defp validate_length!(bytes, expected_size, _message)
       when byte_size(bytes) == expected_size,
       do: :ok

  defp validate_length!(_bytes, _expected_size, message) do
    raise ArgumentError, message
  end

  defp make_padding(padding_length) do
    binary_length = <<padding_length::unsigned-big-integer-size(16)>>
    binary_length <> :binary.copy(<<0>>, padding_length)
  end

  defp make_audience(endpoint) do
    parsed = URI.parse(endpoint)
    parsed.scheme <> "://" <> parsed.host
  end

  defp ub64(value) do
    Base.url_encode64(value, padding: false)
  end
end
