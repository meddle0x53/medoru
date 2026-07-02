defmodule MedoruWeb.Admin.WordLive.Form do
  @moduledoc """
  Admin form for creating and editing words.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.CoreComponents

  alias Medoru.AI.WordEnrichment
  alias Medoru.AI.WordRelations
  alias Medoru.Content
  alias Medoru.Content.Word
  alias Medoru.Content.WordRelation

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
     |> assign(:enrich_loading, false)
     |> assign(:enrich_error, nil)
     |> assign(:enrich_prompt, "")
     |> assign(:show_enrich_modal, false)
     |> assign(:tts_loading, false)
     |> assign(:tts_error, nil)
     |> assign(:tts_text, "")
     |> assign(:tts_vibe_prompt, WordEnrichment.tts_vibe_prompt())
     |> assign(:tts_temp_path, nil)
     |> assign(:show_tts_modal, false)
     |> assign(:image_loading, false)
     |> assign(:image_error, nil)
     |> assign(:image_prompt, "")
     |> assign(:image_temp_path, nil)
     |> assign(:show_image_modal, false)
     |> assign(:relations_loading, false)
     |> assign(:relations_error, nil)
     |> assign(:relations_prompt, "")
     |> assign(:show_relations_modal, false)
     |> assign(:pending_relations, [])
     |> assign(:selected_kanji_ids, MapSet.new())
     |> allow_upload(:image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 500_000
     )
     |> allow_upload(:pronunciation,
       accept: ~w(.mp3 .wav .webm),
       max_entries: 1,
       max_file_size: 2_000_000
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
    |> assign(:selected_kanji_ids, MapSet.new())
    |> assign(:enrich_prompt, WordEnrichment.predefined_prompt(""))
    |> assign(:relations_prompt, "")
    |> assign(:pending_relations, [])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    word = Content.get_word_with_kanji_and_relations!(id)
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
    |> assign(:selected_kanji_ids, MapSet.new())
    |> assign(:enrich_prompt, WordEnrichment.predefined_prompt(word.text))
    |> assign(:relations_prompt, WordRelations.predefined_prompt(word.text, word.reading, word.meaning, word.word_type))
    |> load_pending_relations(word)
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
  def handle_event("open_enrich_modal", _params, socket) do
    word_text = socket.assigns.form[:text].value || ""

    {:noreply,
     socket
     |> assign(:show_enrich_modal, true)
     |> assign(:enrich_error, nil)
     |> assign(:enrich_prompt, WordEnrichment.predefined_prompt(word_text))}
  end

  @impl true
  def handle_event("close_enrich_modal", _params, socket) do
    {:noreply, assign(socket, :show_enrich_modal, false)}
  end

  @impl true
  def handle_event("update_enrich_prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :enrich_prompt, prompt)}
  end

  @impl true
  def handle_event("enrich_word", _params, socket) do
    word_text = socket.assigns.form[:text].value

    if is_nil(word_text) or String.trim(word_text) == "" do
      {:noreply,
       socket
       |> assign(:enrich_error, gettext("Please enter a word text first."))}
    else
      socket = assign(socket, :enrich_loading, true)

      word_text = String.trim(word_text)
      custom_prompt = socket.assigns.enrich_prompt

      case WordEnrichment.enrich(word_text, custom_prompt: custom_prompt) do
        {:ok, enriched_data} ->
          current_params = form_params(socket.assigns.form)
          merged_params = merge_enriched_data(current_params, enriched_data)

          changeset =
            socket.assigns.word
            |> Content.change_word(merged_params)
            |> Map.put(:action, :validate)

          {:noreply,
           socket
           |> assign(:form, to_form(changeset))
           |> assign(:show_enrich_modal, false)
           |> assign(:enrich_loading, false)
           |> assign(:enrich_error, nil)
           |> put_flash(:info, gettext("Word enriched successfully. Review the fields and save."))}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:enrich_loading, false)
           |> assign(:enrich_error, reason)}
      end
    end
  end

  @impl true
  def handle_event("open_tts_modal", _params, socket) do
    word_text = socket.assigns.form[:text].value || ""
    reading = socket.assigns.form[:reading].value || ""
    tts_text = if reading != "", do: reading, else: word_text

    {:noreply,
     socket
     |> assign(:show_tts_modal, true)
     |> assign(:tts_error, nil)
     |> assign(:tts_text, tts_text)
     |> assign(:tts_vibe_prompt, WordEnrichment.tts_vibe_prompt())
     |> assign(:tts_temp_path, nil)}
  end

  @impl true
  def handle_event("close_tts_modal", _params, socket) do
    socket = cleanup_tts_temp_file(socket)
    {:noreply, assign(socket, :show_tts_modal, false)}
  end

  @impl true
  def handle_event("update_tts_text", %{"tts_text" => text}, socket) do
    {:noreply, assign(socket, :tts_text, text)}
  end

  @impl true
  def handle_event("update_tts_vibe_prompt", %{"vibe_prompt" => prompt}, socket) do
    {:noreply, assign(socket, :tts_vibe_prompt, prompt)}
  end

  @impl true
  def handle_event("generate_pronunciation", _params, socket) do
    tts_text = socket.assigns.tts_text

    if is_nil(tts_text) or String.trim(tts_text) == "" do
      {:noreply,
       socket
       |> assign(:tts_error, gettext("Please enter text to speak first."))}
    else
      socket =
        socket
        |> assign(:tts_loading, true)
        |> assign(:tts_error, nil)

      tts_text = String.trim(tts_text)
      vibe_prompt = socket.assigns.tts_vibe_prompt
      lv_pid = self()

      Task.start(fn ->
        result = WordEnrichment.generate_pronunciation(tts_text, instructions: vibe_prompt)
        send(lv_pid, {:tts_generation_result, result})
      end)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("approve_tts", _params, socket) do
    temp_path = socket.assigns.tts_temp_path

    if is_nil(temp_path) do
      {:noreply, put_flash(socket, :error, gettext("No pronunciation to approve."))}
    else
      permanent_path = move_tts_to_permanent(temp_path)

      socket =
        if socket.assigns.live_action == :edit do
          case Content.update_word(socket.assigns.word, %{pronunciation_path: permanent_path}) do
            {:ok, word} ->
              changeset = Content.change_word(word)

              socket
              |> assign(:word, word)
              |> assign(:form, to_form(changeset))
              |> assign(:show_tts_modal, false)
              |> assign(:tts_temp_path, nil)
              |> put_flash(:info, gettext("Pronunciation saved successfully."))

            {:error, _changeset} ->
              put_flash(socket, :error, gettext("Failed to save pronunciation."))
          end
        else
          # New mode: add pronunciation_path to form params
          current_params = form_params(socket.assigns.form)
          merged_params = Map.put(current_params, "pronunciation_path", permanent_path)

          changeset =
            socket.assigns.word
            |> Content.change_word(merged_params)
            |> Map.put(:action, :validate)

          socket
          |> assign(:form, to_form(changeset))
          |> assign(:show_tts_modal, false)
          |> assign(:tts_temp_path, nil)
          |> put_flash(:info, gettext("Pronunciation added. Save the word to persist it."))
        end

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reject_tts", _params, socket) do
    socket = cleanup_tts_temp_file(socket)

    {:noreply,
     socket
     |> assign(:tts_temp_path, nil)
     |> assign(:show_tts_modal, false)
     |> put_flash(:info, gettext("Pronunciation rejected and deleted."))}
  end

  @impl true
  def handle_event("open_image_modal", _params, socket) do
    word_text = socket.assigns.form[:text].value || ""
    meaning = socket.assigns.form[:meaning].value || ""

    {:noreply,
     socket
     |> assign(:show_image_modal, true)
     |> assign(:image_error, nil)
     |> assign(:image_prompt, WordEnrichment.image_prompt(word_text, meaning))
     |> assign(:image_temp_path, nil)}
  end

  @impl true
  def handle_event("close_image_modal", _params, socket) do
    socket = cleanup_image_temp_file(socket)
    {:noreply, assign(socket, :show_image_modal, false)}
  end

  @impl true
  def handle_event("update_image_prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :image_prompt, prompt)}
  end

  @impl true
  def handle_event("generate_image", params, socket) do
    # Prefer the prompt submitted with the form (current textarea value),
    # falling back to the assign in case the change event has not been processed yet.
    image_prompt =
      case params do
        %{"prompt" => prompt} when is_binary(prompt) -> prompt
        _ -> socket.assigns.image_prompt
      end

    if is_nil(image_prompt) or String.trim(image_prompt) == "" do
      {:noreply,
       socket
       |> assign(:image_error, gettext("Please enter an image prompt first."))}
    else
      socket =
        socket
        |> assign(:image_loading, true)
        |> assign(:image_error, nil)
        |> assign(:image_prompt, image_prompt)

      image_prompt = String.trim(image_prompt)
      lv_pid = self()

      Task.start(fn ->
        result = WordEnrichment.generate_image(nil, nil, prompt: image_prompt)
        send(lv_pid, {:image_generation_result, result})
      end)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("approve_image", _params, socket) do
    temp_path = socket.assigns.image_temp_path

    if is_nil(temp_path) do
      {:noreply, put_flash(socket, :error, gettext("No image to approve."))}
    else
      permanent_path = move_image_to_permanent(temp_path)

      socket =
        if socket.assigns.live_action == :edit do
          case Content.update_word(socket.assigns.word, %{image_path: permanent_path}) do
            {:ok, word} ->
              changeset = Content.change_word(word)

              socket
              |> assign(:word, word)
              |> assign(:form, to_form(changeset))
              |> assign(:show_image_modal, false)
              |> assign(:image_temp_path, nil)
              |> put_flash(:info, gettext("Image saved successfully."))

            {:error, _changeset} ->
              put_flash(socket, :error, gettext("Failed to save image."))
          end
        else
          current_params = form_params(socket.assigns.form)
          merged_params = Map.put(current_params, "image_path", permanent_path)

          changeset =
            socket.assigns.word
            |> Content.change_word(merged_params)
            |> Map.put(:action, :validate)

          socket
          |> assign(:form, to_form(changeset))
          |> assign(:show_image_modal, false)
          |> assign(:image_temp_path, nil)
          |> put_flash(:info, gettext("Image added. Save the word to persist it."))
        end

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reject_image", _params, socket) do
    socket = cleanup_image_temp_file(socket)

    {:noreply,
     socket
     |> assign(:image_temp_path, nil)
     |> assign(:show_image_modal, false)
     |> put_flash(:info, gettext("Image rejected and deleted."))}
  end

  @impl true
  def handle_event("open_relations_modal", _params, socket) do
    word = socket.assigns.word

    if socket.assigns.live_action == :edit do
      {:noreply,
       socket
       |> assign(:show_relations_modal, true)
       |> assign(:relations_error, nil)
       |> assign(:relations_prompt, WordRelations.predefined_prompt(word.text, word.reading, word.meaning, word.word_type))
       |> load_pending_relations(word)}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Save the word first before finding relations."))}
    end
  end

  @impl true
  def handle_event("close_relations_modal", _params, socket) do
    {:noreply, assign(socket, :show_relations_modal, false)}
  end

  @impl true
  def handle_event("update_relations_prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :relations_prompt, prompt)}
  end

  @impl true
  def handle_event("generate_relations", _params, socket) do
    word = socket.assigns.word

    if socket.assigns.live_action != :edit do
      {:noreply,
       socket
       |> assign(:relations_loading, false)
       |> assign(:relations_error, gettext("Save the word first before finding relations."))}
    else
      socket = assign(socket, :relations_loading, true)
      custom_prompt = socket.assigns.relations_prompt

      case WordRelations.generate(word.text, word.reading, word.meaning, word.word_type,
             custom_prompt: custom_prompt
           ) do
        {:ok, suggestions} ->
          created_count = create_pending_relations(word, suggestions)
          word = Content.get_word_with_kanji_and_relations!(word.id)

          {:noreply,
           socket
           |> assign(:relations_loading, false)
           |> assign(:relations_error, nil)
           |> assign(:word, word)
           |> load_pending_relations(word)
           |> put_flash(
             :info,
             gettext("Found %{count} relation suggestions.", count: created_count)
           )}

        {:error, reason} ->
{:noreply,
           socket
           |> assign(:relations_loading, false)
           |> assign(:relations_error, reason)}
      end
    end
  end

  @impl true
  def handle_event("approve_relation", %{"relation_id" => relation_id}, socket) do
    relation = Content.get_word_relation!(relation_id)

    case Content.approve_word_relation(relation) do
      {:ok, _approved} ->
        word = Content.get_word_with_kanji_and_relations!(socket.assigns.word.id)

        {:noreply,
         socket
         |> assign(:word, word)
         |> load_pending_relations(word)
         |> put_flash(:info, gettext("Relation approved."))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to approve relation."))}
    end
  end

  @impl true
  def handle_event("reject_relation", %{"relation_id" => relation_id}, socket) do
    relation = Content.get_word_relation!(relation_id)

    case Content.reject_word_relation(relation) do
      {:ok, _} ->
        word = Content.get_word_with_kanji_and_relations!(socket.assigns.word.id)

        {:noreply,
         socket
         |> assign(:word, word)
         |> load_pending_relations(word)
         |> put_flash(:info, gettext("Relation rejected."))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to reject relation."))}
    end
  end

  @impl true
  def handle_event("save", %{"word" => word_params}, socket) do
    save_word(socket, socket.assigns.live_action, word_params)
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("cancel-pronunciation-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pronunciation, ref)}
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
        word = Content.get_word_with_kanji_and_relations!(socket.assigns.word.id)

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
      word = Content.get_word_with_kanji_and_relations!(word.id)

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

  @impl true
  def handle_event("toggle_kanji_selection", %{"word_kanji_id" => word_kanji_id}, socket) do
    selected = socket.assigns.selected_kanji_ids

    selected =
      if MapSet.member?(selected, word_kanji_id) do
        MapSet.delete(selected, word_kanji_id)
      else
        MapSet.put(selected, word_kanji_id)
      end

    {:noreply, assign(socket, :selected_kanji_ids, selected)}
  end

  @impl true
  def handle_event("remove_selected_kanjis", _params, socket) do
    if socket.assigns.live_action == :edit do
      selected = socket.assigns.selected_kanji_ids

      if MapSet.size(selected) == 0 do
        {:noreply, put_flash(socket, :error, gettext("No kanji selected"))}
      else
        word = socket.assigns.word

        {:ok, count} = Content.delete_word_kanjis(word.id, MapSet.to_list(selected))

        word = Content.get_word_with_kanji_and_relations!(word.id)

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
            1 -> gettext("1 kanji removed")
            n -> gettext("%{count} kanji removed", count: n)
          end

        {:noreply,
         socket
         |> assign(:word, word)
         |> assign(:word_kanjis_with_readings, word_kanjis_with_readings)
         |> assign(:selected_kanji_ids, MapSet.new())
         |> put_flash(:info, message)}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("Save the word first before removing kanji"))}
    end
  end

  @impl true
  def handle_info({:tts_generation_result, {:ok, audio_data}}, socket) do
    temp_path = save_tts_temp_file(audio_data)

    {:noreply,
     socket
     |> assign(:tts_temp_path, temp_path)
     |> assign(:tts_loading, false)
     |> assign(:tts_error, nil)}
  end

  @impl true
  def handle_info({:tts_generation_result, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:tts_loading, false)
     |> assign(:tts_error, reason)}
  end

  @impl true
  def handle_info({:image_generation_result, {:ok, image_data}}, socket) do
    temp_path = save_image_temp_file(image_data)

    {:noreply,
     socket
     |> assign(:image_temp_path, temp_path)
     |> assign(:image_loading, false)
     |> assign(:image_error, nil)}
  end

  @impl true
  def handle_info({:image_generation_result, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:image_loading, false)
     |> assign(:image_error, reason)}
  end

  defp save_word(socket, :new, word_params) do
    word_params = handle_image_upload(socket, word_params)
    word_params = handle_pronunciation_upload(socket, word_params)

    case Content.create_word(word_params) do
      {:ok, _word} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word created successfully."))
         |> push_navigate(to: ~p"/admin/words")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_word(socket, :edit, word_params) do
    word_params = handle_image_upload(socket, word_params)
    word_params = handle_pronunciation_upload(socket, word_params)

    case Content.update_word(socket.assigns.word, word_params) do
      {:ok, word} ->
        word = Content.get_word_with_kanji_and_relations!(word.id)
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

  # Handle pronunciation upload and return updated params with pronunciation_path
  defp handle_pronunciation_upload(socket, word_params) do
    uploads_dir = Application.get_env(:medoru, :uploads_dir)

    case consume_uploaded_entries(socket, :pronunciation, fn %{path: path}, entry ->
           ext = Path.extname(entry.client_name) |> String.downcase()
           filename = "#{Ecto.UUID.generate()}#{ext}"
           dest_dir = Path.join(uploads_dir, "word_pronunciations")
           File.mkdir_p!(dest_dir)
           dest_path = Path.join(dest_dir, filename)
           File.cp!(path, dest_path)
           {:ok, "/uploads/word_pronunciations/#{filename}"}
         end) do
      [] ->
        word_params

      [pronunciation_path | _] ->
        Map.put(word_params, "pronunciation_path", pronunciation_path)
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

  # Extract current form params from the changeset
  defp form_params(form) do
    form.source.params || %{}
  end

  # Merge AI-enriched data into existing form params
  defp merge_enriched_data(current_params, enriched_data) do
    current_params
    |> maybe_put("meaning", enriched_data["meaning"])
    |> maybe_put("reading", enriched_data["reading"])
    |> maybe_put("difficulty", enriched_data["difficulty"])
    |> maybe_put("word_type", enriched_data["word_type"])
    |> maybe_put("usage_frequency", enriched_data["usage_frequency"])
    |> maybe_put("example_sentence", enriched_data["example_sentence"])
    |> maybe_put("example_reading", enriched_data["example_reading"])
    |> maybe_put("example_meaning", enriched_data["example_meaning"])
    |> maybe_put_translations(enriched_data["translations"])
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, to_string(value))

  defp maybe_put_translations(params, nil), do: params

  defp maybe_put_translations(params, translations) when is_map(translations) do
    params
    |> maybe_put_nested_translation("translations", "bg", translations["bg"])
    |> maybe_put_nested_translation("translations", "ja", translations["ja"])
  end

  defp maybe_put_nested_translation(params, _parent, _child, nil), do: params

  defp maybe_put_nested_translation(params, parent, child, data) when is_map(data) do
    parent_map = Map.get(params, parent, %{}) |> ensure_map()
    child_map = Map.get(parent_map, child, %{}) |> ensure_map()

    updated_child =
      child_map
      |> maybe_put_map("meaning", data["meaning"])
      |> maybe_put_map("example", data["example"])

    updated_parent = Map.put(parent_map, child, updated_child)
    Map.put(params, parent, updated_parent)
  end

  defp ensure_map(%{} = map), do: map
  defp ensure_map(_), do: %{}

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, key, value), do: Map.put(map, key, to_string(value))

  # TTS temp file helpers

  defp uploads_dir do
    Application.get_env(:medoru, :uploads_dir)
  end

  defp save_tts_temp_file(audio_data) do
    uploads_dir = uploads_dir()
    filename = "#{Ecto.UUID.generate()}.mp3"
    dest_dir = Path.join(uploads_dir, "word_pronunciations/temp")
    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)
    File.write!(dest_path, audio_data)
    "/uploads/word_pronunciations/temp/#{filename}"
  end

  defp move_tts_to_permanent(temp_web_path) do
    uploads_dir = uploads_dir()
    filename = Path.basename(temp_web_path)
    temp_full_path = Path.join(uploads_dir, String.trim_leading(temp_web_path, "/uploads/"))

    dest_dir = Path.join(uploads_dir, "word_pronunciations")
    File.mkdir_p!(dest_dir)
    dest_full_path = Path.join(dest_dir, filename)

    File.rename!(temp_full_path, dest_full_path)
    "/uploads/word_pronunciations/#{filename}"
  end

  defp cleanup_tts_temp_file(socket) do
    temp_path = socket.assigns.tts_temp_path

    if temp_path do
      uploads_dir = uploads_dir()
      full_path = Path.join(uploads_dir, String.trim_leading(temp_path, "/uploads/"))
      File.rm(full_path)
    end

    socket
  end

  # Image temp file helpers

  defp save_image_temp_file(image_data) do
    uploads_dir = uploads_dir()
    filename = "#{Ecto.UUID.generate()}.png"
    dest_dir = Path.join(uploads_dir, "word_images/temp")
    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)
    File.write!(dest_path, image_data)
    "/uploads/word_images/temp/#{filename}"
  end

  defp move_image_to_permanent(temp_web_path) do
    uploads_dir = uploads_dir()
    filename = Path.basename(temp_web_path)
    temp_full_path = Path.join(uploads_dir, String.trim_leading(temp_web_path, "/uploads/"))

    dest_dir = Path.join(uploads_dir, "word_images")
    File.mkdir_p!(dest_dir)
    dest_full_path = Path.join(dest_dir, filename)

    File.rename!(temp_full_path, dest_full_path)
    "/uploads/word_images/#{filename}"
  end

  defp cleanup_image_temp_file(socket) do
    temp_path = socket.assigns.image_temp_path

    if temp_path do
      uploads_dir = uploads_dir()
      full_path = Path.join(uploads_dir, String.trim_leading(temp_path, "/uploads/"))
      File.rm(full_path)
    end

    socket
  end

  # Word Relations helpers

  defp load_pending_relations(socket, %Word{id: nil}), do: assign(socket, :pending_relations, [])

  defp load_pending_relations(socket, %Word{} = word) do
    pending = Content.list_pending_word_relations_for_word(word.id)
    assign(socket, :pending_relations, pending)
  end

  defp create_pending_relations(%Word{} = word, suggestions) do
    types = [
      {"synonyms", :synonym},
      {"antonyms", :antonym},
      {"expressions", :expression}
    ]

    existing =
      (Content.list_pending_word_relations_for_word(word.id) ++
         Content.list_word_relations_for_word_structs(word.id))
      |> Enum.map(&relation_signature/1)
      |> MapSet.new()

    types
    |> Enum.flat_map(fn {key, type} ->
      suggestions
      |> Map.get(key, [])
      |> Enum.map(fn item -> {type, item} end)
    end)
    |> Enum.reduce(0, fn {type, item}, acc ->
      text = item["text"]
      related_word = Content.find_word_for_relation(text)

      # Synonyms and antonyms must match an existing word. Expressions may be
      # text-only when no matching word exists.
      attrs =
        cond do
          type in [:synonym, :antonym] and is_nil(related_word) ->
            nil

          type == :expression and is_nil(related_word) ->
            %{
              word_id: word.id,
              relation_type: type,
              related_word_id: nil,
              expression_text: text,
              status: :pending
            }

          true ->
            %{
              word_id: word.id,
              relation_type: type,
              related_word_id: related_word.id,
              expression_text: nil,
              status: :pending
            }
        end

      if is_nil(attrs) do
        acc
      else
        signature = relation_signature(attrs)

        if MapSet.member?(existing, signature) do
          acc
        else
          case Content.create_word_relation(attrs) do
            {:ok, _} -> acc + 1
            {:error, _} -> acc
          end
        end
      end
    end)
  end

  defp relation_signature(%{word_id: word_id, relation_type: type, related_word_id: rw_id, expression_text: text}) do
    {word_id, type, rw_id, text}
  end

  defp relation_signature(%WordRelation{} = relation) do
    {relation.word_id, relation.relation_type, relation.related_word_id,
     relation.expression_text}
  end

  # Helper function to format Ecto changeset errors for display
  def format_error({message, _metadata}) when is_binary(message), do: message
  def format_error(message) when is_binary(message), do: message
  def format_error(_), do: gettext("Invalid value")

  # Helper function to format upload errors
  defp error_to_string(:too_large), do: gettext("File is too large (max 500KB)")
  defp error_to_string(:too_many_files), do: gettext("You can only upload 1 file")
  defp error_to_string(:not_accepted), do: gettext("Invalid file type")
  defp error_to_string(_), do: gettext("Upload failed")
end
