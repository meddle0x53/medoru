defmodule MedoruWeb.Moderator.WordLive.Form do
  @moduledoc """
  Admin form for creating and editing words.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.CoreComponents

  alias Medoru.Content
  alias Medoru.Content.Word

  embed_templates "form/*"

  @word_types [
    {gettext("Noun"), "noun"},
    {gettext("Verb"), "verb"},
    {gettext("Adjective"), "adjective"},
    {gettext("Adverb"), "adverb"},
    {gettext("Particle"), "particle"},
    {gettext("Pronoun"), "pronoun"},
    {gettext("Counter"), "counter"},
    {gettext("Expression"), "expression"},
    {gettext("Other"), "other"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    {form_template(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:word_types, @word_types)
     |> allow_upload(:image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 500_000
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    changeset = Content.change_word(%Word{})

    socket
    |> assign(:page_title, gettext("Add New Word"))
    |> assign(:word, %Word{})
    |> assign(:form, to_form(changeset))
    |> assign(:word_kanjis_with_readings, [])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    word = Content.get_word_with_kanji!(id)
    changeset = Content.change_word(word)

    # Load kanji readings for each kanji in the word
    word_kanjis_with_readings =
      word.word_kanjis
      |> Enum.sort_by(& &1.position)
      |> Enum.map(fn wk ->
        kanji = wk.kanji
        readings = Content.list_readings_for_kanji(kanji.id)
        {wk, readings}
      end)

    socket
    |> assign(:page_title, gettext("Edit Word - %{text}", text: word.text))
    |> assign(:word, word)
    |> assign(:form, to_form(changeset))
    |> assign(:word_kanjis_with_readings, word_kanjis_with_readings)
  end

  @impl true
  def handle_event("validate", %{"word" => word_params}, socket) do
    changeset =
      socket.assigns.word
      |> Content.change_word(word_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"word" => word_params}, socket) do
    save_word(socket, socket.assigns.live_action, word_params)
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  @impl true
  def handle_event(
        "update_word_kanji_reading",
        %{"word_kanji_id" => word_kanji_id, "reading_id" => reading_id},
        socket
      ) do
    word_kanji = Content.get_word_kanji!(word_kanji_id)

    # Handle "nil" as actually nil (no reading selected)
    reading_id = if reading_id == "nil" or reading_id == "", do: nil, else: reading_id

    attrs = %{kanji_reading_id: reading_id}

    case Content.update_word_kanji(word_kanji, attrs) do
      {:ok, _updated_word_kanji} ->
        # Reload word with updated word_kanjis
        word = Content.get_word_with_kanji!(socket.assigns.word.id)

        # Reload kanji readings
        word_kanjis_with_readings =
          word.word_kanjis
          |> Enum.sort_by(& &1.position)
          |> Enum.map(fn wk ->
            kanji = wk.kanji
            readings = Content.list_readings_for_kanji(kanji.id)
            {wk, readings}
          end)

        {:noreply,
         socket
         |> assign(:word, word)
         |> assign(:word_kanjis_with_readings, word_kanjis_with_readings)
         |> put_flash(:info, gettext("Reading updated successfully"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update reading"))}
    end
  end

  @impl true
  def handle_event("extract_kanji", _params, socket) do
    word = socket.assigns.word

    # Only works in edit mode (word must exist)
    if socket.assigns.live_action == :edit do
      {:ok, new_word_kanjis} = Content.extract_and_link_kanji_for_word(word)
      count = length(new_word_kanjis)

      # Reload word with updated word_kanjis
      word = Content.get_word_with_kanji!(word.id)

      # Reload kanji readings for display
      word_kanjis_with_readings =
        word.word_kanjis
        |> Enum.sort_by(& &1.position)
        |> Enum.map(fn wk ->
          kanji = wk.kanji
          readings = Content.list_readings_for_kanji(kanji.id)
          {wk, readings}
        end)

      message =
        case count do
          0 -> gettext("No new kanji found in word text")
          1 -> gettext("1 new kanji extracted and linked")
          n -> gettext("%{count} new kanji extracted and linked", count: n)
        end

      {:noreply,
       socket
       |> assign(:word, word)
       |> assign(:word_kanjis_with_readings, word_kanjis_with_readings)
       |> put_flash(:info, message)}
    else
      {:noreply,
       put_flash(socket, :error, gettext("Save the word first before extracting kanji"))}
    end
  end

  defp save_word(socket, :new, word_params) do
    word_params = handle_image_upload(socket, word_params)

    case Content.create_word(word_params) do
      {:ok, _word} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word created successfully."))
         |> push_navigate(to: ~p"/moderator/words")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_word(socket, :edit, word_params) do
    word_params = handle_image_upload(socket, word_params)

    case Content.update_word(socket.assigns.word, word_params) do
      {:ok, word} ->
        changeset = Content.change_word(word)

        {:noreply,
         socket
         |> assign(:word, word)
         |> assign(:form, to_form(changeset))
         |> put_flash(:info, gettext("Word updated successfully."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Handle image upload and return updated params with image_path
  defp handle_image_upload(socket, word_params) do
    # Get uploads directory from config (respects UPLOADS_DIR env var)
    uploads_dir = Application.get_env(:medoru, :uploads_dir)

    case consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
           # Generate unique filename
           ext = Path.extname(entry.client_name) |> String.downcase()
           filename = "#{Ecto.UUID.generate()}#{ext}"

           # Destination path in configured uploads directory
           dest_dir = Path.join(uploads_dir, "word_images")
           File.mkdir_p!(dest_dir)
           dest_path = Path.join(dest_dir, filename)

           # Copy file
           File.cp!(path, dest_path)

           # Return relative path for database
           {:ok, "/uploads/word_images/#{filename}"}
         end) do
      [] ->
        # No new upload, keep existing image_path if editing
        word_params

      [image_path | _] ->
        # New image uploaded
        Map.put(word_params, "image_path", image_path)
    end
  end

  # Helper function to format Ecto changeset errors for display
  def format_error({message, _metadata}) when is_binary(message), do: message
  def format_error(message) when is_binary(message), do: message
  def format_error(_), do: gettext("Invalid value")

  # Helper function to format upload errors
  defp error_to_string(:too_large), do: gettext("File is too large (max 500KB)")
  defp error_to_string(:too_many_files), do: gettext("You can only upload 1 file")
  defp error_to_string(:not_accepted), do: gettext("Invalid file type (use JPG, PNG, or WebP)")
  defp error_to_string(_), do: gettext("Upload failed")
end
