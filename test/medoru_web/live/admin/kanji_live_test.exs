defmodule MedoruWeb.Admin.KanjiLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.AI.KanjiEnrichment

  setup %{conn: conn} do
    user = user_fixture(%{type: "admin"})
    conn = log_in_user(conn, user)

    original_key = Application.get_env(:medoru, :openai_api_key)
    original_req_opts = Application.get_env(:req, :default_options, [])

    Application.put_env(:medoru, :openai_api_key, "test-key")
    Application.put_env(:req, :default_options, plug: {Req.Test, KanjiEnrichment})

    on_exit(fn ->
      Application.put_env(:medoru, :openai_api_key, original_key)

      if original_req_opts == [] do
        Application.delete_env(:req, :default_options)
      else
        Application.put_env(:req, :default_options, original_req_opts)
      end
    end)

    %{conn: conn, user: user}
  end

  describe "New kanji form" do
    test "renders form with AI enrichment buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/kanji/new")

      assert html =~ "Add New Kanji"
      assert html =~ "Enrich with AI"
      assert html =~ "Enrich Stroke Data"
    end

    test "shows error when enriching without a kanji character", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/kanji/new")

      view
      |> element("button[phx-click='open_enrich_modal'][phx-value-mode='main']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='enrich_kanji']")
        |> render_click()

      assert html =~ "Please enter a kanji character first"
    end

    test "enriches main kanji fields and populates the form", %{conn: conn} do
      Req.Test.stub(KanjiEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "meanings" => "sun, day, Japan",
                    "stroke_count" => "4",
                    "jlpt_level" => "5",
                    "school_level" => "1",
                    "frequency" => "100",
                    "radicals" => "日",
                    "translations" => %{
                      "bg" => %{"meanings" => "слънце, ден"},
                      "ja" => %{"meanings" => "太陽、日、日本"}
                    }
                  })
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/kanji/new")

      view
      |> form("#kanji-form", %{"kanji" => %{"character" => "日"}})
      |> render_change()

      view
      |> element("button[phx-click='open_enrich_modal'][phx-value-mode='main']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='enrich_kanji']")
        |> render_click()

      assert html =~ "sun, day, Japan"
      assert html =~ "value=\"4\""
      assert html =~ "value=\"100\""
      assert html =~ "日"
      assert html =~ "слънце, ден"
      assert html =~ "太陽, 日, 日本"
    end

    test "enriches stroke data from local KanjiVG", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/kanji/new")

      view
      |> form("#kanji-form", %{"kanji" => %{"character" => "一"}})
      |> render_change()

      view
      |> element("button[phx-click='open_enrich_modal'][phx-value-mode='stroke']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='enrich_kanji']")
        |> render_click()

      assert html =~ "bounds"
      assert html =~ "strokes"
      assert html =~ "Kanji enriched successfully"
    end

    test "displays an error when the AI request fails", %{conn: conn} do
      Req.Test.stub(KanjiEnrichment, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/kanji/new")

      view
      |> form("#kanji-form", %{"kanji" => %{"character" => "日"}})
      |> render_change()

      view
      |> element("button[phx-click='open_enrich_modal'][phx-value-mode='main']")
      |> render_click()

      view
      |> element("button[phx-click='enrich_kanji']")
      |> render_click()

      assert render(view) =~ "Enrich Kanji with AI"
      assert render(view) =~ "alert-error"
    end
  end

  describe "Edit kanji form" do
    test "shows the manual add reading form when Add Reading is clicked", %{conn: conn} do
      kanji = kanji_fixture(%{character: "日"})

      {:ok, view, _html} = live(conn, ~p"/admin/kanji/#{kanji.id}/edit")

      refute render(view) =~ "Add New Reading"

      html =
        view
        |> element("button[phx-click='show_new_reading']")
        |> render_click()

      assert html =~ "Add New Reading"
      assert html =~ "name=\"reading[reading]\""
    end

    test "enriches readings and lets the admin approve them", %{conn: conn} do
      kanji = kanji_fixture(%{character: "日"})

      Req.Test.stub(KanjiEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "readings" => [
                      %{
                        "reading_type" => "on",
                        "reading" => "ニチ",
                        "romaji" => "nichi",
                        "usage_notes" => "formal"
                      },
                      %{
                        "reading_type" => "kun",
                        "reading" => "ひ",
                        "romaji" => "hi"
                      }
                    ]
                  })
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/kanji/#{kanji.id}/edit")

      view
      |> element("button[phx-click='open_enrich_modal'][phx-value-mode='readings']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='enrich_kanji']")
        |> render_click()

      assert html =~ "Suggested Readings"
      assert html =~ "ニチ"
      assert html =~ "ひ"

      html =
        view
        |> element("button", "Add All Suggested")
        |> render_click()

      assert html =~ "ニチ"
      assert html =~ "ひ"
      assert html =~ "2 total"
    end
  end
end
