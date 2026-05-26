defmodule MedoruWeb.PushTest do
  use ExUnit.Case

  alias MedoruWeb.Push

  describe "encrypt/2" do
    test "encrypts a payload for a valid subscription" do
      subscription = %{
        endpoint: "https://fcm.googleapis.com/fcm/send/test-123",
        keys: %{
          p256dh: "BLxuja-129dN_6pVsAeAABXiRkPtOogAmAuM2pomg7RquL_sflksWO4rDUnngBF6xG26ZEiTMFkBc-p7h68MwOs",
          auth: "Ryo7uSXQmMpf43JfB-bxRA"
        }
      }

      payload = Push.encrypt("hello world", subscription)

      assert is_binary(payload.ciphertext)
      assert byte_size(payload.ciphertext) > 0
      assert byte_size(payload.salt) == 16
      assert byte_size(payload.server_public_key) == 65
    end

    test "raises on missing subscription keys" do
      assert_raise ArgumentError, ~r/missing some encryption details/, fn ->
        Push.encrypt("test", %{endpoint: "https://example.com", keys: %{}})
      end
    end

    test "raises on invalid p256dh key length" do
      subscription = %{
        endpoint: "https://example.com",
        keys: %{
          p256dh: Base.url_encode64("short", padding: false),
          auth: "Ryo7uSXQmMpf43JfB-bxRA"
        }
      }

      assert_raise ArgumentError, ~r/invalid/, fn ->
        Push.encrypt("test", subscription)
      end
    end

    test "raises on payload too large" do
      subscription = %{
        endpoint: "https://example.com",
        keys: %{
          p256dh: "BLxuja-129dN_6pVsAeAABXiRkPtOogAmAuM2pomg7RquL_sflksWO4rDUnngBF6xG26ZEiTMFkBc-p7h68MwOs",
          auth: "Ryo7uSXQmMpf43JfB-bxRA"
        }
      }

      assert_raise ArgumentError, ~r/Payload is too large/, fn ->
        Push.encrypt(:binary.copy("x", 5000), subscription)
      end
    end
  end

  describe "send_web_push/3 validations" do
    test "raises on negative ttl" do
      assert_raise ArgumentError, ~r/non-negative integer ttl/, fn ->
        Push.send_web_push("test", %{endpoint: "https://example.com"}, -1)
      end
    end

    test "raises on missing endpoint" do
      assert_raise ArgumentError, ~r/endpoint/, fn ->
        Push.send_web_push("test", %{keys: %{}}, 0)
      end
    end
  end
end
