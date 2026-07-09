defmodule MedoruWeb.WordPreviewController do
  use MedoruWeb, :controller

  import MedoruWeb.NavigationHelpers

  alias Medoru.Content
  alias Medoru.Content.MatureContent

  def show(conn, %{"text" => text}) do
    case Content.get_word_by_text_or_meaning_or_conjugation(text) do
      nil ->
        send_resp(conn, 404, "")

      word ->
        current_user = conn.assigns[:current_scope] && conn.assigns.current_scope.current_user

        if MatureContent.mature_word_visible_to_user?(word, current_user) do
          locale = conn.assigns[:locale] || "en"

          json(conn, %{
            id: word.id,
            text: word.text,
            reading: word.reading,
            meaning: Content.get_localized_meaning(word, locale),
            word_type: word.word_type,
            image_path: word.image_path,
            pronunciation_path: word.pronunciation_path,
            path: word_path(word)
          })
        else
          json(conn, %{blocked: true, message: gettext("unsafe content detected")})
        end
    end
  end
end
