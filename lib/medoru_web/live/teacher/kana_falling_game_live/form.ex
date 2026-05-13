defmodule MedoruWeb.Teacher.KanaFallingGameLive.Form do
  @moduledoc """
  LiveView for creating and editing kana falling games.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content.Kana
  alias Medoru.Games

  embed_templates "form*.html"

  defp speed_options do
    [
      {"1 - Very Slow (2s/row)", "1"},
      {"2 - Slow (1.8s/row)", "2"},
      {"3 - Slow-Medium (1.6s/row)", "3"},
      {"4 - Medium (1.4s/row)", "4"},
      {"5 - Medium-Fast (1s/row)", "5"},
      {"6 - Fast (0.9s/row)", "6"},
      {"7 - Fast (0.8s/row)", "7"},
      {"8 - Very Fast (0.6s/row)", "8"},
      {"9 - Very Fast (0.5s/row)", "9"},
      {"10 - Extreme (0.3s/row)", "10"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Create Kana Falling Game"))
     |> assign(:name, "")
     |> assign(:initial_speed, "1")
     |> assign(:speed_increase_threshold, "50")
     |> assign(:lives, "3")
     |> assign(:extra_life_threshold, "100")
     |> assign(:points_per_kana, "1")
     |> assign(:selected_kana, [])
     |> assign(:form_errors, %{})}
  end

  @impl true
  def handle_params(%{"classroom_id" => classroom_id, "id" => id}, _url, socket) do
    user = socket.assigns.current_scope.current_user
    game = Games.get_game!(id)
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != user.id or game.classroom_id != classroom_id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to edit this game."))
       |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=games")}
    else
      kfg = game.kana_falling_game

      {:noreply,
       socket
       |> assign(:page_title, gettext("Edit Kana Falling Game"))
       |> assign(:classroom, classroom)
       |> assign(:game, game)
       |> assign(:mode, :edit)
       |> assign(:name, game.name)
       |> assign(:initial_speed, Integer.to_string(kfg.initial_speed))
       |> assign(:speed_increase_threshold, Integer.to_string(kfg.speed_increase_threshold))
       |> assign(:lives, Integer.to_string(kfg.lives))
       |> assign(:extra_life_threshold, Integer.to_string(kfg.extra_life_threshold))
       |> assign(:points_per_kana, Integer.to_string(kfg.points_per_kana))
       |> assign(:selected_kana, kfg.selected_kana || [])
       |> assign(:form_errors, %{})}
    end
  end

  @impl true
  def handle_params(%{"classroom_id" => classroom_id}, _url, socket) do
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
       |> assign(:initial_speed, "1")
       |> assign(:speed_increase_threshold, "50")
       |> assign(:lives, "3")
       |> assign(:extra_life_threshold, "100")
       |> assign(:points_per_kana, "1")
       |> assign(:selected_kana, [])
       |> assign(:form_errors, %{})}
    end
  end

  @impl true
  def handle_event("update_field", %{} = params, socket) do
    field = params["field"] || List.first(params["_target"] || []) || ""
    value = params[field] || params["value"] || ""

    socket =
      case field do
        "name" -> assign(socket, :name, value)
        "initial_speed" -> assign(socket, :initial_speed, value)
        "speed_increase_threshold" -> assign(socket, :speed_increase_threshold, value)
        "lives" -> assign(socket, :lives, value)
        "extra_life_threshold" -> assign(socket, :extra_life_threshold, value)
        "points_per_kana" -> assign(socket, :points_per_kana, value)
        _ -> socket
      end

    error_field =
      case field do
        "name" -> :name
        "initial_speed" -> :initial_speed
        "speed_increase_threshold" -> :speed_increase_threshold
        "lives" -> :lives
        "extra_life_threshold" -> :extra_life_threshold
        "points_per_kana" -> :points_per_kana
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

    name = String.trim(params["name"] || socket.assigns.name || "")
    initial_speed = params["initial_speed"] || socket.assigns.initial_speed || "1"
    speed_increase_threshold = params["speed_increase_threshold"] || socket.assigns.speed_increase_threshold || "50"
    lives = params["lives"] || socket.assigns.lives || "3"
    extra_life_threshold = params["extra_life_threshold"] || socket.assigns.extra_life_threshold || "100"
    points_per_kana = params["points_per_kana"] || socket.assigns.points_per_kana || "1"

    socket =
      socket
      |> assign(:name, name)
      |> assign(:initial_speed, initial_speed)
      |> assign(:speed_increase_threshold, speed_increase_threshold)
      |> assign(:lives, lives)
      |> assign(:extra_life_threshold, extra_life_threshold)
      |> assign(:points_per_kana, points_per_kana)

    attrs = %{
      "name" => name,
      "kana_falling_game" => %{
        "initial_speed" => initial_speed,
        "speed_increase_threshold" => speed_increase_threshold,
        "lives" => lives,
        "extra_life_threshold" => extra_life_threshold,
        "points_per_kana" => points_per_kana
      }
    }

    errors = validate_form(name, selected_kana)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :form_errors, errors)}
    else
      result =
        case socket.assigns.mode do
          :new ->
            Games.create_kana_falling_game(classroom_id, teacher_id, attrs, selected_kana)

          :edit ->
            Games.update_kana_falling_game(
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
               do: gettext("Kana falling game created successfully."),
               else: gettext("Kana falling game updated successfully.")
             )
           )
           |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=games")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> assign(:form_errors, format_changeset_errors(changeset))
           |> put_flash(:error, gettext("Please fix the errors below."))}

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

  defp validate_form(name, selected_kana) do
    errors = %{}

    errors =
      if String.trim(name) == "" do
        Map.put(errors, :name, gettext("Name is required"))
      else
        errors
      end

    errors =
      if length(selected_kana) == 0 do
        Map.put(errors, :selected_kana, gettext("Select at least one kana"))
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
end
