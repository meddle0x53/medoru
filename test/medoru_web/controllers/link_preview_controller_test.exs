defmodule MedoruWeb.LinkPreviewControllerTest do
  use MedoruWeb.ConnCase

  import Medoru.AccountsFixtures

  alias Medoru.LinkPreviews

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  describe "GET /api/link-preview" do
    test "returns cached preview json", %{conn: conn} do
      url = "https://example.com/page"

      {:ok, preview} =
        LinkPreviews.create_preview(url, %{
          status: "fetched",
          title: "Example Page",
          description: "A page about examples",
          site_name: "example.com",
          image_url: "https://example.com/image.png"
        })

      conn = get(conn, ~p"/api/link-preview", url: url)

      assert json_response(conn, 200) == %{
               "id" => preview.id,
               "url" => url,
               "title" => "Example Page",
               "description" => "A page about examples",
               "site_name" => "example.com",
               "image_url" => "https://example.com/image.png",
               "favicon_url" => nil,
               "status" => "fetched",
               "error_message" => nil,
               "fetched_at" => nil
             }
    end

    test "returns pending status for new url", %{conn: conn} do
      url = "https://example.com/new-page"

      conn = get(conn, ~p"/api/link-preview", url: url)
      response = json_response(conn, 200)

      assert response["status"] == "pending"
      assert response["url"] == url
    end
  end
end
