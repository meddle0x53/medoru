defmodule MedoruWeb.Admin.KanjiLive.Form do
  @moduledoc """
  Admin form for creating and editing kanji.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.CoreComponents

  alias Medoru.AI.KanjiEnrichment
  alias Medoru.Content
  alias Medoru.Content.Kanji

  embed_templates "form/*"

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
     |> assign(:editing_reading, nil)
     |> assign(:new_reading, nil)
     |> assign(:edit_reading, nil)
     |> assign(:show_enrich_modal, false)
     |> assign(:enrich_mode, :main)
     |> assign(:enrich_loading, false)
     |> assign(:enrich_error, nil)
     |> assign(:enrich_prompt, "")
     |> assign(:suggested_readings, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    changeset = Content.change_kanji(%Kanji{})

    socket
    |> assign(:page_title, gettext("Add New Kanji"))
    |> assign(:kanji, %Kanji{})
    |> assign(:form, to_form(changeset))
    |> assign(:editing_reading, nil)
    |> assign(:new_reading, nil)
    |> assign(:edit_reading, nil)
    |> assign(:show_enrich_modal, false)
    |> assign(:enrich_mode, :main)
    |> assign(:enrich_loading, false)
    |> assign(:enrich_error, nil)
    |> assign(:enrich_prompt, KanjiEnrichment.main_prompt(""))
    |> assign(:suggested_readings, [])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    kanji = Content.get_kanji_with_readings!(id)
    changeset = Content.change_kanji(kanji)

    socket
    |> assign(:page_title, gettext("Edit Kanji - %{character}", character: kanji.character))
    |> assign(:kanji, kanji)
    |> assign(:form, to_form(changeset))
    |> assign(:editing_reading, nil)
    |> assign(:new_reading, nil)
    |> assign(:edit_reading, nil)
    |> assign(:show_enrich_modal, false)
    |> assign(:enrich_mode, :main)
    |> assign(:enrich_loading, false)
    |> assign(:enrich_error, nil)
    |> assign(:enrich_prompt, KanjiEnrichment.main_prompt(kanji.character))
    |> assign(:suggested_readings, [])
  end

  @impl true
  def handle_event("validate", %{"kanji" => kanji_params}, socket) do
    changeset =
      socket.assigns.kanji
      |> Content.change_kanji(kanji_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"kanji" => kanji_params}, socket) do
    save_kanji(socket, socket.assigns.live_action, kanji_params)
  end

  # AI enrichment events
  @impl true
  def handle_event("open_enrich_modal", %{"mode" => mode}, socket) do
    character = socket.assigns.form[:character].value || ""
    mode = String.to_existing_atom(mode)

    prompt =
      case mode do
        :main -> KanjiEnrichment.main_prompt(character)
        :readings -> KanjiEnrichment.readings_prompt(character)
        :stroke -> KanjiEnrichment.stroke_data_prompt(character)
      end

    {:noreply,
     socket
     |> assign(:show_enrich_modal, true)
     |> assign(:enrich_mode, mode)
     |> assign(:enrich_error, nil)
     |> assign(:enrich_prompt, prompt)}
  end

  @impl true
  def handle_event("close_enrich_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_enrich_modal, false)
     |> assign(:enrich_error, nil)}
  end

  @impl true
  def handle_event("update_enrich_prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :enrich_prompt, prompt)}
  end

  @impl true
  def handle_event("enrich_kanji", _params, socket) do
    character = socket.assigns.form[:character].value

    if is_nil(character) or String.trim(character) == "" do
      {:noreply,
       socket
       |> assign(:enrich_error, gettext("Please enter a kanji character first."))}
    else
      character = String.trim(character)
      mode = socket.assigns.enrich_mode
      custom_prompt = socket.assigns.enrich_prompt
      socket = assign(socket, :enrich_loading, true)

      case run_enrichment(mode, character, custom_prompt) do
        {:ok, enriched_data} ->
          socket = apply_enriched_data(socket, mode, enriched_data)

          {:noreply,
           socket
           |> assign(:show_enrich_modal, false)
           |> assign(:enrich_loading, false)
           |> assign(:enrich_error, nil)
           |> put_flash(
             :info,
             gettext("Kanji enriched successfully. Review the fields and save.")
           )}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:enrich_loading, false)
           |> assign(:enrich_error, reason)}
      end
    end
  end

  @impl true
  def handle_event("apply_suggested_readings", _params, socket) do
    kanji = socket.assigns.kanji
    readings = socket.assigns.suggested_readings

    if socket.assigns.live_action == :edit and kanji.id do
      Enum.each(readings, fn reading ->
        attrs =
          reading
          |> Map.put("kanji_id", kanji.id)
          |> Map.take(["kanji_id", "reading_type", "reading", "romaji", "usage_notes"])

        Content.create_kanji_reading(attrs)
      end)

      kanji = Content.get_kanji_with_readings!(kanji.id)

      {:noreply,
       socket
       |> assign(:kanji, kanji)
       |> assign(:suggested_readings, [])
       |> put_flash(:info, gettext("Readings added successfully."))}
    else
      {:noreply, put_flash(socket, :error, gettext("Save the kanji first to add readings."))}
    end
  end

  @impl true
  def handle_event("clear_suggested_readings", _params, socket) do
    {:noreply, assign(socket, :suggested_readings, [])}
  end

  # Reading management events
  @impl true
  def handle_event("show_new_reading", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_reading, %{
       "reading_type" => "on",
       "reading" => "",
       "romaji" => "",
       "usage_notes" => ""
     })
     |> assign(:editing_reading, nil)
     |> assign(:edit_reading, nil)}
  end

  @impl true
  def handle_event("cancel_new_reading", _params, socket) do
    {:noreply, assign(socket, :new_reading, nil)}
  end

  @impl true
  def handle_event("update_new_reading", %{} = params, socket) do
    reading_data =
      case Map.get(params, "reading") do
        nil -> %{}
        data -> data
      end

    # Merge new values into existing reading
    current = socket.assigns.new_reading || %{}
    updated = Map.merge(current, reading_data)

    {:noreply, assign(socket, :new_reading, updated)}
  end

  @impl true
  def handle_event("create_reading", %{} = params, socket) do
    kanji = socket.assigns.kanji

    reading_data =
      case Map.get(params, "reading") do
        nil -> %{}
        data -> data
      end

    attrs = %{
      "kanji_id" => kanji.id,
      "reading_type" => reading_data["reading_type"] || "on",
      "reading" => reading_data["reading"] || "",
      "romaji" => reading_data["romaji"] || "",
      "usage_notes" => reading_data["usage_notes"] || ""
    }

    case Content.create_kanji_reading(attrs) do
      {:ok, _reading} ->
        kanji = Content.get_kanji_with_readings!(kanji.id)

        {:noreply,
         socket
         |> assign(:kanji, kanji)
         |> assign(:new_reading, nil)
         |> put_flash(:info, gettext("Reading added successfully."))}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to add reading. Please check the fields."))}
    end
  end

  @impl true
  def handle_event("edit_reading", %{"id" => id}, socket) do
    reading = Enum.find(socket.assigns.kanji.kanji_readings, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:edit_reading, %{
       "id" => reading.id,
       "reading_type" => to_string(reading.reading_type),
       "reading" => reading.reading,
       "romaji" => reading.romaji,
       "usage_notes" => reading.usage_notes || ""
     })
     |> assign(:editing_reading, reading.id)
     |> assign(:new_reading, nil)}
  end

  @impl true
  def handle_event("cancel_edit_reading", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_reading, nil)
     |> assign(:edit_reading, nil)}
  end

  @impl true
  def handle_event("update_edit_reading", %{} = params, socket) do
    reading_data =
      case Map.get(params, "reading") do
        nil -> %{}
        data -> data
      end

    # Merge new values into existing reading
    current = socket.assigns.edit_reading || %{}
    updated = Map.merge(current, reading_data)

    {:noreply, assign(socket, :edit_reading, updated)}
  end

  @impl true
  def handle_event("update_reading", %{} = params, socket) do
    kanji = socket.assigns.kanji

    reading_data =
      case Map.get(params, "reading") do
        nil -> %{}
        data -> data
      end

    reading_id = reading_data["id"]
    reading = Enum.find(kanji.kanji_readings, &(&1.id == reading_id))

    attrs = %{
      "reading_type" => reading_data["reading_type"] || "on",
      "reading" => reading_data["reading"] || "",
      "romaji" => reading_data["romaji"] || "",
      "usage_notes" => reading_data["usage_notes"] || ""
    }

    case Content.update_kanji_reading(reading, attrs) do
      {:ok, _reading} ->
        kanji = Content.get_kanji_with_readings!(kanji.id)

        {:noreply,
         socket
         |> assign(:kanji, kanji)
         |> assign(:editing_reading, nil)
         |> assign(:edit_reading, nil)
         |> put_flash(:info, gettext("Reading updated successfully."))}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to update reading. Please check the fields."))}
    end
  end

  @impl true
  def handle_event("delete_reading", %{"id" => id}, socket) do
    kanji = socket.assigns.kanji
    reading = Enum.find(kanji.kanji_readings, &(&1.id == id))

    case Content.delete_kanji_reading(reading) do
      {:ok, _} ->
        kanji = Content.get_kanji_with_readings!(kanji.id)

        {:noreply,
         socket
         |> assign(:kanji, kanji)
         |> put_flash(:info, gettext("Reading deleted successfully."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete reading."))}
    end
  end

  @impl true
  def handle_event("reorder_readings", %{"reading_ids" => reading_ids}, socket) do
    kanji = socket.assigns.kanji

    case Content.reorder_kanji_readings(kanji.id, reading_ids) do
      {:ok, _} ->
        kanji = Content.get_kanji_with_readings!(kanji.id)

        {:noreply,
         socket
         |> assign(:kanji, kanji)
         |> put_flash(:info, gettext("Reading order updated."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to reorder readings."))}
    end
  end

  defp run_enrichment(:main, character, custom_prompt) do
    KanjiEnrichment.enrich(character, custom_prompt: custom_prompt)
  end

  defp run_enrichment(:readings, character, custom_prompt) do
    KanjiEnrichment.enrich_readings(character, custom_prompt: custom_prompt)
  end

  defp run_enrichment(:stroke, character, custom_prompt) do
    KanjiEnrichment.enrich_stroke_data(character, custom_prompt: custom_prompt)
  end

  defp apply_enriched_data(socket, :main, enriched_data) do
    current_params = form_params(socket.assigns.form)
    merged_params = merge_main_enriched_data(current_params, enriched_data)

    changeset =
      socket.assigns.kanji
      |> Content.change_kanji(merged_params)
      |> Map.put(:action, :validate)

    assign(socket, :form, to_form(changeset))
  end

  defp apply_enriched_data(socket, :readings, enriched_data) do
    readings = enriched_data["readings"] || []
    assign(socket, :suggested_readings, readings)
  end

  defp apply_enriched_data(socket, :stroke, enriched_data) do
    current_params = form_params(socket.assigns.form)

    merged_params =
      case enriched_data["stroke_data"] do
        data when is_map(data) ->
          Map.put(current_params, "stroke_data", Jason.encode!(data))

        _ ->
          current_params
      end

    changeset =
      socket.assigns.kanji
      |> Content.change_kanji(merged_params)
      |> Map.put(:action, :validate)

    assign(socket, :form, to_form(changeset))
  end

  defp merge_main_enriched_data(current_params, enriched_data) do
    current_params
    |> maybe_put("meanings", enriched_data["meanings"])
    |> maybe_put("stroke_count", enriched_data["stroke_count"])
    |> maybe_put("jlpt_level", enriched_data["jlpt_level"])
    |> maybe_put("school_level", enriched_data["school_level"])
    |> maybe_put("frequency", enriched_data["frequency"])
    |> maybe_put("radicals", format_radicals(enriched_data["radicals"]))
    |> maybe_put_translations(enriched_data["translations"])
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, ""), do: params
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
      |> maybe_put_map("meanings", data["meanings"])

    updated_parent = Map.put(parent_map, child, updated_child)
    Map.put(params, parent, updated_parent)
  end

  defp ensure_map(%{} = map), do: map
  defp ensure_map(_), do: %{}

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, _key, ""), do: map

  defp maybe_put_map(map, key, value) when is_list(value) do
    Map.put(map, key, Enum.join(value, ", "))
  end

  defp maybe_put_map(map, key, value), do: Map.put(map, key, to_string(value))

  defp format_radicals(nil), do: nil
  defp format_radicals(values) when is_list(values), do: Enum.join(values, ", ")
  defp format_radicals(value) when is_binary(value), do: value
  defp format_radicals(_), do: nil

  defp form_params(form) do
    form.source.params || %{}
  end

  defp save_kanji(socket, :new, kanji_params) do
    case Content.create_kanji(kanji_params) do
      {:ok, _kanji} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Kanji created successfully."))
         |> push_navigate(to: ~p"/admin/kanji")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_kanji(socket, :edit, kanji_params) do
    case Content.update_kanji(socket.assigns.kanji, kanji_params) do
      {:ok, _kanji} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Kanji updated successfully."))
         |> push_navigate(to: ~p"/admin/kanji")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Helper function to format meanings for display in the form
  # Handles both list (from database) and string (from form params) values
  def format_meanings(nil), do: ""
  def format_meanings(values) when is_list(values), do: Enum.join(values, ", ")
  def format_meanings(value) when is_binary(value), do: value
  def format_meanings(_), do: ""

  # Helper function to format stroke_data for the textarea.
  # The textarea expects a JSON string; an empty map is shown as an empty string.
  def format_stroke_data(nil), do: ""
  def format_stroke_data(data) when data == %{}, do: ""

  def format_stroke_data(data) when is_map(data) do
    Jason.encode!(data, pretty: true)
  end

  def format_stroke_data(value) when is_binary(value), do: value
  def format_stroke_data(_), do: ""

  # Helper function to format Ecto changeset errors for display
  # Ecto errors are tuples: {message, metadata}
  def format_error({message, _metadata}) when is_binary(message), do: message
  def format_error(message) when is_binary(message), do: message
  def format_error(_), do: gettext("Invalid value")
end
