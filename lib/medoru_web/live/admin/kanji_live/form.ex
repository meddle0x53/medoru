defmodule MedoruWeb.Admin.KanjiLive.Form do
  @moduledoc """
  Admin form for creating and editing kanji.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.CoreComponents

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
     |> assign(:edit_reading, nil)}
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

  # Helper function to format Ecto changeset errors for display
  # Ecto errors are tuples: {message, metadata}
  def format_error({message, _metadata}) when is_binary(message), do: message
  def format_error(message) when is_binary(message), do: message
  def format_error(_), do: gettext("Invalid value")
end
