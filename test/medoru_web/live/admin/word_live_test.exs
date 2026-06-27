defmodule MedoruWeb.Admin.WordLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.AI.WordEnrichment

  setup %{conn: conn} do
    user = user_fixture(%{type: "admin"})
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "New word form" do
    test "renders form with enrich and tts buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/words/new")

      assert html =~ "Add New Word"
      assert html =~ "Enrich with AI"
      assert html =~ "Generate with AI"
    end

    test "opens enrichment modal on button click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/words/new")

      html =
        view
        |> element("button[phx-click='open_enrich_modal']")
        |> render_click()

      assert html =~ "AI Word Enrichment"
      assert html =~ "Prompt (editable)"
    end

    test "shows error when enriching without word text", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/words/new")

      view
      |> element("button[phx-click='open_enrich_modal']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='enrich_word']")
        |> render_click()

      assert html =~ "Please enter a word text first"
    end

    test "enriches word and populates form fields", %{conn: conn} do
      # Set up mock API key and stub the OpenAI call
      original_key = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      Req.Test.stub(WordEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "meaning" => "Japan",
                    "reading" => "にほん",
                    "difficulty" => 5,
                    "word_type" => "noun",
                    "usage_frequency" => 100,
                    "example_sentence" => "日本に行きたいです。",
                    "example_reading" => "にほんにいきたいです。",
                    "example_meaning" => "I want to go to Japan.",
                    "translations" => %{
                      "bg" => %{"meaning" => "Япония", "example" => "Искам да отида в Япония."},
                      "ja" => %{"meaning" => "日本", "example" => "日本に行きたいです。"}
                    }
                  })
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original_key)
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/words/new")

      # Enter word text
      view
      |> form("#word-form", %{"word" => %{"text" => "日本"}})
      |> render_change()

      # Open modal
      view
      |> element("button[phx-click='open_enrich_modal']")
      |> render_click()

      # Click enrich
      html =
        view
        |> element("button[phx-click='enrich_word']")
        |> render_click()

      assert html =~ "にほん"
      assert html =~ "Japan"
      assert html =~ "I want to go to Japan"
    end

    test "displays error when API call fails", %{conn: conn} do
      original_key = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      Req.Test.stub(WordEnrichment, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original_key)
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/words/new")

      # Enter word text
      view
      |> form("#word-form", %{"word" => %{"text" => "日本"}})
      |> render_change()

      # Open modal
      view
      |> element("button[phx-click='open_enrich_modal']")
      |> render_click()

      # Click enrich
      view
      |> element("button[phx-click='enrich_word']")
      |> render_click()

      # Modal should still be open with error
      assert render(view) =~ "AI Word Enrichment"
      assert render(view) =~ "alert-error"
    end

    test "opens tts modal and pre-fills with reading", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/words/new")

      # Enter word text and reading
      view
      |> form("#word-form", %{"word" => %{"text" => "日本", "reading" => "にほん"}})
      |> render_change()

      html =
        view
        |> element("button[phx-click='open_tts_modal']")
        |> render_click()

      assert html =~ "Generate Pronunciation"
      assert html =~ "にほん"
    end

    test "opens image modal and pre-fills with word and meaning", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/words/new")

      view
      |> form("#word-form", %{"word" => %{"text" => "日本", "meaning" => "Japan"}})
      |> render_change()

      html =
        view
        |> element("button[phx-click='open_image_modal']")
        |> render_click()

      assert html =~ "Generate Word Image"
      assert html =~ "日本"
      assert html =~ "Japan"
      assert html =~ "anime-style illustration"
    end

    test "shows error when generating image without prompt", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/words/new")

      view
      |> element("button[phx-click='open_image_modal']")
      |> render_click()

      view
      |> element("textarea")
      |> render_change(%{"prompt" => ""})

      html =
        view
        |> element("button[phx-click='generate_image']")
        |> render_click()

      assert html =~ "Please enter an image prompt first"
    end

    test "shows error when generating pronunciation without text", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/words/new")

      view
      |> element("button[phx-click='open_tts_modal']")
      |> render_click()

      # Clear the text
      view
      |> element("input[name='tts_text']")
      |> render_change(%{"tts_text" => ""})

      html =
        view
        |> element("button[phx-click='generate_pronunciation']")
        |> render_click()

      assert html =~ "Please enter text to speak first"
    end
  end

  describe "Edit word form" do
    test "renders form with enrich button for existing word", %{conn: conn} do
      word = word_fixture(%{text: "本", meaning: "book", reading: "ほん"})

      {:ok, _view, html} = live(conn, ~p"/admin/words/#{word.id}/edit")

      assert html =~ "Edit Word"
      assert html =~ "Enrich with AI"
      assert html =~ "本"
    end

    test "pre-fills prompt with existing word text", %{conn: conn} do
      word = word_fixture(%{text: "本", meaning: "book", reading: "ほん"})

      {:ok, view, _html} = live(conn, ~p"/admin/words/#{word.id}/edit")

      html =
        view
        |> element("button[phx-click='open_enrich_modal']")
        |> render_click()

      assert html =~ "本"
      assert html =~ "AI Word Enrichment"
    end

    test "allows editing prompt before enrichment", %{conn: conn} do
      word = word_fixture(%{text: "本", meaning: "book", reading: "ほん"})

      {:ok, view, _html} = live(conn, ~p"/admin/words/#{word.id}/edit")

      view
      |> element("button[phx-click='open_enrich_modal']")
      |> render_click()

      html =
        view
        |> element("textarea")
        |> render_change(%{"prompt" => "Custom prompt for 本"})

      # The prompt should be updated
      assert html =~ "Custom prompt for 本"
    end

    test "opens tts modal pre-filled with word reading", %{conn: conn} do
      word = word_fixture(%{text: "本", meaning: "book", reading: "ほん"})

      {:ok, view, _html} = live(conn, ~p"/admin/words/#{word.id}/edit")

      html =
        view
        |> element("button[phx-click='open_tts_modal']")
        |> render_click()

      assert html =~ "Generate Pronunciation"
      assert html =~ "ほん"
    end

    test "renders kanji checkboxes and remove selected button", %{conn: conn} do
      word = word_with_kanji_fixture()
      [kanji1, kanji2] = Enum.map(word.word_kanjis, & &1.kanji)

      {:ok, _view, html} = live(conn, ~p"/admin/words/#{word.id}/edit")

      assert html =~ kanji1.character
      assert html =~ kanji2.character
      assert html =~ "Remove selected"
      assert html =~ "extract_kanji"
    end

    test "removes a single selected kanji association", %{conn: conn} do
      word = word_with_kanji_fixture()
      [word_kanji1, word_kanji2] = Enum.sort_by(word.word_kanjis, & &1.position)
      kanji1 = word_kanji1.kanji
      kanji2 = word_kanji2.kanji

      {:ok, view, _html} = live(conn, ~p"/admin/words/#{word.id}/edit")

      # Select the first kanji
      view
      |> element(
        "input[phx-click='toggle_kanji_selection'][phx-value-word_kanji_id='#{word_kanji1.id}']"
      )
      |> render_click()

      # Click remove selected
      view
      |> element("button[phx-click='remove_selected_kanjis']")
      |> render_click()

      flash_html = render(view)
      assert flash_html =~ "1 kanji removed"

      associations_html =
        view
        |> element("#kanji-associations")
        |> render()

      assert associations_html =~ kanji2.character
      refute associations_html =~ kanji1.character
    end

    test "removes multiple selected kanji associations", %{conn: conn} do
      word = word_with_kanji_fixture()
      [word_kanji1, word_kanji2] = Enum.sort_by(word.word_kanjis, & &1.position)
      kanji1 = word_kanji1.kanji
      kanji2 = word_kanji2.kanji

      {:ok, view, _html} = live(conn, ~p"/admin/words/#{word.id}/edit")

      # Select both kanji
      view
      |> element(
        "input[phx-click='toggle_kanji_selection'][phx-value-word_kanji_id='#{word_kanji1.id}']"
      )
      |> render_click()

      view
      |> element(
        "input[phx-click='toggle_kanji_selection'][phx-value-word_kanji_id='#{word_kanji2.id}']"
      )
      |> render_click()

      # Click remove selected
      view
      |> element("button[phx-click='remove_selected_kanjis']")
      |> render_click()

      flash_html = render(view)
      assert flash_html =~ "2 kanji removed"

      associations_html =
        view
        |> element("#kanji-associations")
        |> render()

      refute associations_html =~ kanji1.character
      refute associations_html =~ kanji2.character
      assert associations_html =~ "No kanji associated with this word yet"
    end
  end
end
