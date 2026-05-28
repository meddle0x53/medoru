defmodule Medoru.EncryptionTest do
  use Medoru.DataCase, async: true

  alias Medoru.Encryption
  alias Medoru.Encryption.UserPublicKey
  alias Medoru.Accounts

  defp user_fixture(attrs \\ %{}) do
    unique_suffix = "_#{System.unique_integer([:positive])}"

    attrs =
      attrs
      |> Map.drop([:email, :provider_uid, "email", "provider_uid"])
      |> Enum.into(%{
        email: "user#{unique_suffix}@example.com",
        provider: "google",
        provider_uid: "uid#{unique_suffix}",
        name: "Test User"
      })

    {:ok, user} = Accounts.create_user(attrs)
    user
  end

  describe "public keys" do
    test "store_public_key/3 stores a new RSA public key" do
      user = user_fixture()
      spki = <<1, 2, 3, 4, 5>>

      assert {:ok, %UserPublicKey{}} = Encryption.store_public_key(user.id, spki)

      key = Encryption.get_public_key(user.id)
      assert key != nil
      assert key.public_key_spki == spki
      assert key.algorithm == "RSA-OAEP-2048"
      assert key.is_active == true
    end

    test "store_public_key/3 keeps multiple keys active" do
      user = user_fixture()
      old_spki = <<1, 2, 3>>
      new_spki = <<4, 5, 6>>

      {:ok, _} = Encryption.store_public_key(user.id, old_spki)
      {:ok, _} = Encryption.store_public_key(user.id, new_spki)

      # Both keys remain in the database
      keys = Encryption.list_public_keys(user.id)
      assert length(keys) == 2

      # In multi-key mode, BOTH keys stay active
      active_keys = Enum.filter(keys, & &1.is_active)
      assert length(active_keys) == 2
    end

    test "get_public_key/1 returns nil when no key exists" do
      user = user_fixture()
      assert Encryption.get_public_key(user.id) == nil
    end

    test "get_public_key/1 ignores legacy ECDH keys" do
      user = user_fixture()

      # Insert a legacy ECDH key directly
      {:ok, _} =
        %UserPublicKey{}
        |> Ecto.Changeset.change(%{
          user_id: user.id,
          key_version: "v1",
          public_key_spki: <<1, 2, 3>>,
          algorithm: "ECDH-P-256-LEGACY",
          is_active: true
        })
        |> Medoru.Repo.insert()

      assert Encryption.get_public_key(user.id) == nil
    end

    test "get_public_keys/1 returns all keys for multiple users" do
      user_a = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()

      Encryption.store_public_key(user_a.id, <<1>>)
      Encryption.store_public_key(user_b.id, <<2>>)
      # user_c has no key

      keys = Encryption.get_public_keys([user_a.id, user_b.id, user_c.id])
      assert map_size(keys) == 2
      assert hd(keys[user_a.id]).public_key_spki == <<1>>
      assert hd(keys[user_b.id]).public_key_spki == <<2>>
      assert not Map.has_key?(keys, user_c.id)
    end

    test "get_public_keys/1 returns all active keys per user" do
      user = user_fixture()

      # Insert two active keys directly
      {:ok, _old_key} =
        %UserPublicKey{}
        |> Ecto.Changeset.change(%{
          user_id: user.id,
          key_version: "v1",
          public_key_spki: <<1>>,
          algorithm: "RSA-OAEP-2048",
          is_active: true
        })
        |> Medoru.Repo.insert()

      {:ok, _new_key} =
        %UserPublicKey{}
        |> Ecto.Changeset.change(%{
          user_id: user.id,
          key_version: "v2",
          public_key_spki: <<2>>,
          algorithm: "RSA-OAEP-2048",
          is_active: true
        })
        |> Medoru.Repo.insert()

      keys = Encryption.get_public_keys([user.id])
      # Should return all keys per user (multi-device support)
      assert map_size(keys) == 1
      user_keys = keys[user.id]
      assert length(user_keys) == 2
      assert Enum.any?(user_keys, &(&1.public_key_spki == <<1>>))
      assert Enum.any?(user_keys, &(&1.public_key_spki == <<2>>))
    end

    test "list_public_keys/1 returns all keys for audit" do
      user = user_fixture()

      Encryption.store_public_key(user.id, <<1>>)
      Encryption.store_public_key(user.id, <<2>>)

      # Both keys remain active in multi-key mode
      keys = Encryption.list_public_keys(user.id)
      assert length(keys) == 2

      active_keys = Enum.filter(keys, & &1.is_active)
      assert length(active_keys) == 2
    end

    test "get_public_keys_for_user/1 returns all active keys for a user" do
      user = user_fixture()

      Encryption.store_public_key(user.id, <<1>>)
      Encryption.store_public_key(user.id, <<2>>)

      keys = Encryption.get_public_keys_for_user(user.id)
      assert length(keys) == 2
      assert Enum.any?(keys, &(&1.public_key_spki == <<1>>))
      assert Enum.any?(keys, &(&1.public_key_spki == <<2>>))
    end
  end
end
