defmodule MedoruWeb.WordPreviewController do
  use MedoruWeb, :controller

  alias Medoru.Content

  def show(conn, %{"text" => text}) do
    case Content.get_word_by_text_or_meaning_or_conjugation(text) do
      nil ->
        send_resp(conn, 404, "")

      word ->
        json(conn, %{
          id: word.id,
          text: word.text,
          reading: word.reading,
          word_type: word.word_type,
          image_path: word.image_path,
          pronunciation_path: word.pronunciation_path,
          path: ~p"/words/#{word.id}"
        })
    end
  end
end
