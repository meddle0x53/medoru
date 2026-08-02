defmodule MedoruWeb.WordBookCardTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Medoru.Content.Word

  test "renders both faces with configured content" do
    word = %Word{
      id: Ecto.UUID.generate(),
      text: "食べる",
      reading: "たべる",
      meaning: "to eat",
      difficulty: 5,
      usage_frequency: 42,
      image_path: "/images/words/eat.png",
      pronunciation_path: "/audio/eat.mp3",
      example_sentence: "私はりんごを食べる。 / 彼はパンを食べる。",
      example_meaning: "I eat an apple. / He eats bread.",
      translations: %{
        "bg" => %{"meaning" => "ям", "example" => "Аз ям ябълка. / Той яде хляб."}
      }
    }

    front = %{
      "show_image" => true,
      "show_sound" => true,
      "show_reading" => true,
      "show_level" => true,
      "show_frequency" => true,
      "meanings" => ["en", "bg"],
      "examples" => ["en", "bg"],
      "example_count" => 2
    }

    html =
      render_component(&MedoruWeb.WordBookCard.card/1,
        id: "smoke-card",
        word: word,
        front_config: front,
        back_config: %{},
        card_shape: "rectangle",
        front_background: "sakura",
        back_background: "word_image",
        download: true
      )

    assert html =~ ~s(id="smoke-card-front")
    assert html =~ ~s(id="smoke-card-back")
    assert html =~ ~s(data-share-front="smoke-card-front")
    assert html =~ ~s(data-share-back="smoke-card-back")
    assert html =~ ~s(data-filename="medoru-smoke-card")
    assert html =~ "medoru.net"
    assert html =~ "食べる"
    assert html =~ "たべる (taberu)"
    assert html =~ "to eat"
    assert html =~ "ям"
    assert html =~ "私はりんごを食べる。"
    assert html =~ "彼はパンを食べる。"
    assert html =~ "Той яде хляб."
    assert html =~ "N5"
    assert html =~ "Common word"
    assert html =~ "background-image"
    assert html =~ "/images/word_book/backgrounds/sakura.svg"
    # "word_image" resolves to the word's own image as the back background
    assert html =~ "url(&#39;/images/words/eat.png&#39;)"
    assert html =~ "/audio/eat.mp3"
    assert html =~ "event.stopPropagation()"
  end

  test "reading-only face does not leak example sentences" do
    word = %Word{
      id: Ecto.UUID.generate(),
      text: "食べる",
      reading: "たべる",
      meaning: "to eat",
      example_sentence: "私はりんごを食べる。",
      example_meaning: "I eat an apple."
    }

    html =
      render_component(&MedoruWeb.WordBookCard.card/1,
        id: "reading-only-card",
        word: word,
        front_config: %{"show_reading" => true},
        back_config: %{"show_reading" => true, "example_count" => 1},
        card_shape: "rectangle"
      )

    assert html =~ "たべる (taberu)"
    refute html =~ "私はりんごを食べる。"
  end
end
