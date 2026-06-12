defmodule MedoruWeb.WordPreviewControllerTest do
  use MedoruWeb.ConnCase, async: false

  import Medoru.ContentFixtures
  import Medoru.AccountsFixtures

  describe "GET /api/word-preview/:text" do
    test "returns word preview data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      word = word_fixture(%{text: "青い", reading: "あおい"})

      conn = get(conn, ~p"/api/word-preview/青い")

      response = json_response(conn, 200)
      assert response["id"] == word.id
      assert response["text"] == word.text
      assert response["path"] == "/words/#{word.id}"
    end

    test "returns 404 when word not found", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn = get(conn, ~p"/api/word-preview/nonexistent-word-12345")
      assert response(conn, 404) == ""
    end

    test "returns blocked response for mature words when viewer is restricted", %{
      conn: conn
    } do
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 17, safety: false})
      conn = log_in_user(conn, user)
      word_fixture(%{text: "成人", reading: "せいじん", mature: true})

      conn = get(conn, ~p"/api/word-preview/成人")

      response = json_response(conn, 200)
      assert response["blocked"] == true
      assert response["message"] == "unsafe content detected"
      refute Map.has_key?(response, "id")
    end

    test "returns word data for mature words when viewer is an adult with safety disabled",
         %{conn: conn} do
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 18, safety: false})
      conn = log_in_user(conn, user)
      word = word_fixture(%{text: "成人", reading: "せいじん", mature: true})

      conn = get(conn, ~p"/api/word-preview/成人")

      response = json_response(conn, 200)
      assert response["id"] == word.id
      refute Map.has_key?(response, "blocked")
    end
  end
end
