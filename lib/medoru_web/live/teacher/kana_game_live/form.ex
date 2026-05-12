defmodule MedoruWeb.Teacher.KanaGameLive.Form do
  @moduledoc """
  LiveView for creating and editing kana memory card games.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content.Kana
  alias Medoru.Games

  embed_templates "*.html"

  defp board_sizes do
    [
      {"4x4 (16 cards, 8 kana)", "4x4"},
      {"6x6 (36 cards, 18 kana)", "6x6"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Create Kana Game"))
     |> assign(:name, "")
     |> assign(:board_size, "4x4")
     |> assign(:max_attempts, "10")
     |> assign(:require_reading, false)
     |> assign(:selected_kana, [])
     |> assign(:form_errors, %{})}
  end

  @impl true
  def handle_params(%{"classroom_id" => classroom_id, "id" => id}, _url, socket) do
    # Edit mode
    user = socket.assigns.current_scope.current_user
    game = Games.get_game!(id)
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != user.id or game.classroom_id != classroom_id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to edit this game."))
       |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=games")}
    else
      kmcg = game.kana_memory_card_game

      {:noreply,
       socket
       |> assign(:page_title, gettext("Edit Kana Game"))
       |> assign(:classroom, classroom)
       |> assign(:game, game)
       |> assign(:mode, :edit)
       |> assign(:name, game.name)
       |> assign(:board_size, kmcg.board_size)
       |> assign(:max_attempts, Integer.to_string(kmcg.max_attempts))
       |> assign(:require_reading, kmcg.require_reading)
       |> assign(:selected_kana, kmcg.selected_kana || [])
       |> assign(:form_errors, %{})}
    end
  end

  @impl true
  def handle_params(%{"classroom_id" => classroom_id}, _url, socket) do
    # New mode
    user = socket.assigns.current_scope.current_user
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != user.id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to create games in this classroom."))
       |> push_navigate(to: ~p"/teacher/classrooms")}
    else
      {:noreply,
       socket
       |> assign(:classroom, classroom)
       |> assign(:game, nil)
       |> assign(:mode, :new)
       |> assign(:name, "")
       |> assign(:board_size, "4x4")
       |> assign(:max_attempts, "10")
       |> assign(:require_reading, false)
       |> assign(:selected_kana, [])
       |> assign(:form_errors, %{})}
    end
  end

  @impl true
  def handle_event("update_field", %{} = params, socket) do
    # phx-value-field isn't always sent with phx-change, so fall back to _target
    field = params["field"] || List.first(params["_target"] || []) || ""
    value = params[field] || params["value"] || ""

    socket =
      case field do
        "name" -> assign(socket, :name, value)
        "board_size" -> assign(socket, :board_size, value)
        "max_attempts" -> assign(socket, :max_attempts, value)
        _ -> socket
      end

    error_field =
      case field do
        "name" -> :name
        "board_size" -> :board_size
        "max_attempts" -> :max_attempts
        _ -> nil
      end

    socket =
      if error_field && socket.assigns.form_errors[error_field] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, error_field))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_require_reading", _params, socket) do
    {:noreply, assign(socket, :require_reading, not socket.assigns.require_reading)}
  end

  @impl true
  def handle_event("toggle_kana", %{"character" => character}, socket) do
    selected = socket.assigns.selected_kana

    new_selected =
      if character in selected do
        List.delete(selected, character)
      else
        selected ++ [character]
      end

    socket =
      if socket.assigns.form_errors[:selected_kana] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :selected_kana))
      else
        socket
      end

    {:noreply, assign(socket, :selected_kana, new_selected)}
  end

  @impl true
  def handle_event("toggle_row", %{"row" => row}, socket) do
    row_kana =
      case row do
        "hiragana" ->
          Kana.list_hiragana()

        "katakana" ->
          Kana.list_katakana()

        "dakuten" ->
          Kana.by_group(Kana.list_all(), :ga) ++
            Kana.by_group(Kana.list_all(), :za) ++
            Kana.by_group(Kana.list_all(), :da) ++
            Kana.by_group(Kana.list_all(), :ba)

        "handakuten" ->
          Kana.by_group(Kana.list_all(), :pa)

        "small" ->
          Kana.by_group(Kana.list_all(), :small)

        prefixed ->
          # prefixed rows like "hiragana_a" or "katakana_ka"
          case String.split(prefixed, "_", parts: 2) do
            [script, group] ->
              kana_list =
                case script do
                  "hiragana" -> Kana.list_hiragana()
                  "katakana" -> Kana.list_katakana()
                  _ -> Kana.list_all()
                end

              Kana.by_group(kana_list, String.to_atom(group))

            _ ->
              Kana.by_group(Kana.list_all(), String.to_atom(prefixed))
          end
      end

    row_chars = Enum.map(row_kana, & &1.character)
    selected = socket.assigns.selected_kana

    all_selected? = Enum.all?(row_chars, &(&1 in selected))

    new_selected =
      if all_selected? do
        Enum.reject(selected, &(&1 in row_chars))
      else
        (selected ++ row_chars) |> Enum.uniq()
      end

    socket =
      if socket.assigns.form_errors[:selected_kana] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :selected_kana))
      else
        socket
      end

    {:noreply, assign(socket, :selected_kana, new_selected)}
  end

  @impl true
  def handle_event("save", params, socket) do
    classroom_id = socket.assigns.classroom.id
    teacher_id = socket.assigns.current_scope.current_user.id
    selected_kana = socket.assigns.selected_kana

    # Use params as fallback in case phx-change didn't fire before submit
    name = String.trim(params["name"] || socket.assigns.name || "")
    board_size = params["board_size"] || socket.assigns.board_size || "4x4"
    max_attempts = params["max_attempts"] || socket.assigns.max_attempts || "10"
    require_reading = socket.assigns.require_reading

    # Sync values back to socket so the form shows submitted values on validation failure
    socket =
      socket
      |> assign(:name, name)
      |> assign(:board_size, board_size)
      |> assign(:max_attempts, max_attempts)

    attrs = %{
      "name" => name,
      "memory_card_game" => %{
        "board_size" => board_size,
        "max_attempts" => max_attempts,
        "require_reading" => require_reading
      }
    }

    errors = validate_form(attrs, selected_kana)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :form_errors, errors)}
    else
      result =
        case socket.assigns.mode do
          :new ->
            Games.create_kana_memory_card_game(classroom_id, teacher_id, attrs, selected_kana)

          :edit ->
            Games.update_kana_memory_card_game(
              socket.assigns.game,
              teacher_id,
              attrs,
              selected_kana
            )
        end

      case result do
        {:ok, _game} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             if(socket.assigns.mode == :new,
               do: gettext("Kana game created successfully."),
               else: gettext("Kana game updated successfully.")
             )
           )
           |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=games")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> assign(:form_errors, format_changeset_errors(changeset))
           |> put_flash(:error, gettext("Please fix the errors below."))}

        {:error, %{selected_kana: [_msg]}} ->
          {:noreply,
           socket
           |> assign(:form_errors, %{selected_kana: gettext("Not enough kana selected.")})
           |> put_flash(:error, gettext("Please select enough kana to fill the board."))}

        {:error, :not_authorized} ->
          {:noreply,
           socket
           |> put_flash(:error, gettext("You are not authorized to manage this game."))
           |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=games")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to save game."))}
      end
    end
  end

  defp validate_form(attrs, selected_kana) do
    errors = %{}

    errors =
      if String.trim(attrs["name"] || "") == "" do
        Map.put(errors, :name, gettext("Name is required"))
      else
        errors
      end

    errors =
      if String.trim(get_in(attrs, ["memory_card_game", "max_attempts"]) || "") == "" do
        Map.put(errors, :max_attempts, gettext("Max attempts is required"))
      else
        errors
      end

    board_size = get_in(attrs, ["memory_card_game", "board_size"]) || "4x4"
    kana_needed = Games.KanaMemoryCardGame.kana_needed(board_size)

    errors =
      if length(selected_kana) < kana_needed do
        Map.put(
          errors,
          :selected_kana,
          gettext("Select at least %{count} kana", count: kana_needed)
        )
      else
        errors
      end

    errors
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Map.new()
  end

  def kana_needed_count(board_size) do
    Games.KanaMemoryCardGame.kana_needed(board_size)
  end
end
