defmodule MedoruWeb.Teacher.KanjiFallingGameLive.Form do
  @moduledoc """
  LiveView for creating and editing kanji falling games.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Games

  embed_templates "form*.html"

  defp skill_level_options do
    [
      {gettext("Beginner"), "1"},
      {gettext("Elementary"), "2"},
      {gettext("Intermediate"), "3"},
      {gettext("Advanced"), "4"},
      {gettext("Expert"), "5"}
    ]
  end

  defp speed_options do
    [
      {"1 - Very Slow (1.8s/row)", "1"},
      {"2 - Slow (1.6s/row)", "2"},
      {"3 - Slow-Medium (1.3s/row)", "3"},
      {"4 - Medium (1s/row)", "4"},
      {"5 - Medium-Fast (0.8s/row)", "5"},
      {"6 - Fast (0.7s/row)", "6"},
      {"7 - Fast (0.5s/row)", "7"},
      {"8 - Very Fast (0.4s/row)", "8"},
      {"9 - Very Fast (0.3s/row)", "9"},
      {"10 - Extreme (0.1s/row)", "10"}
    ]
  end

  defp reading_type_options do
    [
      {gettext("Any reading (on'yomi or kun'yomi)"), "any"},
      {gettext("On'yomi only"), "onyomi"},
      {gettext("Kun'yomi only"), "kunyomi"}
    ]
  end

  defp keyboard_type_options do
    [
      {gettext("Hiragana grid keyboard"), "hiragana"},
      {gettext("Latin QWERTY keyboard"), "latin"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Create Kanji Cascade Game"))
     |> assign(:name, "")
     |> assign(:initial_speed, "1")
     |> assign(:speed_increase_threshold, "50")
     |> assign(:lives, "3")
     |> assign(:extra_life_threshold, "100")
     |> assign(:points_per_kanji, "1")
     |> assign(:skill_level, "1")
     |> assign(:reading_type, "any")
     |> assign(:keyboard_type, "hiragana")
     |> assign(:selected_kanji, [])
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:search_loading, false)
     |> assign(:form_errors, %{})
     |> allow_upload(:background_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 2_000_000
     )}
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
      kfg = game.kanji_falling_game

      selected_kanji =
        (kfg.selected_kanji || [])
        |> Enum.map(fn char ->
          case Content.get_kanji_by_character(char) do
            nil -> %{id: nil, character: char, readings: []}
            kanji -> %{id: kanji.id, character: char, readings: kanji.kanji_readings}
          end
        end)

      {:noreply,
       socket
       |> assign(:page_title, gettext("Edit Kanji Cascade Game"))
       |> assign(:classroom, classroom)
       |> assign(:game, game)
       |> assign(:mode, :edit)
       |> assign(:name, game.name)
       |> assign(:initial_speed, Integer.to_string(kfg.initial_speed))
       |> assign(:speed_increase_threshold, Integer.to_string(kfg.speed_increase_threshold))
       |> assign(:lives, Integer.to_string(kfg.lives))
       |> assign(:extra_life_threshold, Integer.to_string(kfg.extra_life_threshold))
       |> assign(:points_per_kanji, Integer.to_string(kfg.points_per_kanji))
       |> assign(:skill_level, Integer.to_string(game.skill_level))
       |> assign(:reading_type, kfg.reading_type)
       |> assign(:keyboard_type, kfg.keyboard_type)
       |> assign(:selected_kanji, selected_kanji)
       |> assign(:background_image, kfg.background_image)
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
       |> put_flash(
         :error,
         gettext("You don't have permission to create games in this classroom.")
       )
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
       |> assign(:points_per_kanji, "1")
       |> assign(:skill_level, "1")
       |> assign(:reading_type, "any")
       |> assign(:keyboard_type, "hiragana")
       |> assign(:selected_kanji, [])
       |> assign(:form_errors, %{})}
    end
  end

  @impl true
  def handle_event("search_kanji", %{"query" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply,
       socket
       |> assign(:search_query, "")
       |> assign(:search_results, [])
       |> assign(:search_loading, false)}
    else
      results = Content.search_kanji(query, limit: 10)
      existing_chars = Enum.map(socket.assigns.selected_kanji, & &1.character)
      filtered = Enum.reject(results, fn kanji -> kanji.character in existing_chars end)

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, filtered)
       |> assign(:search_loading, false)}
    end
  end

  @impl true
  def handle_event("add_kanji", %{"character" => character}, socket) do
    selected = socket.assigns.selected_kanji

    if Enum.any?(selected, &(&1.character == character)) do
      {:noreply, socket}
    else
      case Content.get_kanji_by_character(character) do
        nil ->
          {:noreply, socket}

        kanji ->
          new_kanji = %{
            id: kanji.id,
            character: kanji.character,
            readings: kanji.kanji_readings
          }

          socket =
            if socket.assigns.form_errors[:selected_kanji] do
              assign(
                socket,
                :form_errors,
                Map.delete(socket.assigns.form_errors, :selected_kanji)
              )
            else
              socket
            end

          {:noreply,
           socket
           |> assign(:selected_kanji, selected ++ [new_kanji])
           |> assign(:search_query, "")
           |> assign(:search_results, [])}
      end
    end
  end

  @impl true
  def handle_event("remove_kanji", %{"character" => character}, socket) do
    selected =
      Enum.reject(socket.assigns.selected_kanji, &(&1.character == character))

    socket =
      if socket.assigns.form_errors[:selected_kanji] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :selected_kanji))
      else
        socket
      end

    {:noreply, assign(socket, :selected_kanji, selected)}
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
        "points_per_kanji" -> assign(socket, :points_per_kanji, value)
        "reading_type" -> assign(socket, :reading_type, value)
        "keyboard_type" -> assign(socket, :keyboard_type, value)
        "skill_level" -> assign(socket, :skill_level, value)
        _ -> socket
      end

    error_field =
      case field do
        "name" -> :name
        "initial_speed" -> :initial_speed
        "speed_increase_threshold" -> :speed_increase_threshold
        "lives" -> :lives
        "extra_life_threshold" -> :extra_life_threshold
        "points_per_kanji" -> :points_per_kanji
        "reading_type" -> :reading_type
        "keyboard_type" -> :keyboard_type
        "skill_level" -> :skill_level
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
  def handle_event("save", params, socket) do
    classroom_id = socket.assigns.classroom.id
    teacher_id = socket.assigns.current_scope.current_user.id
    selected_kanji = Enum.map(socket.assigns.selected_kanji, & &1.character)

    name = String.trim(params["name"] || socket.assigns.name || "")
    initial_speed = params["initial_speed"] || socket.assigns.initial_speed || "1"

    speed_increase_threshold =
      params["speed_increase_threshold"] || socket.assigns.speed_increase_threshold || "50"

    lives = params["lives"] || socket.assigns.lives || "3"

    extra_life_threshold =
      params["extra_life_threshold"] || socket.assigns.extra_life_threshold || "100"

    points_per_kanji = params["points_per_kanji"] || socket.assigns.points_per_kanji || "1"
    skill_level = params["skill_level"] || socket.assigns.skill_level || "1"
    reading_type = params["reading_type"] || socket.assigns.reading_type || "any"
    keyboard_type = params["keyboard_type"] || socket.assigns.keyboard_type || "hiragana"

    socket =
      socket
      |> assign(:name, name)
      |> assign(:initial_speed, initial_speed)
      |> assign(:speed_increase_threshold, speed_increase_threshold)
      |> assign(:lives, lives)
      |> assign(:extra_life_threshold, extra_life_threshold)
      |> assign(:points_per_kanji, points_per_kanji)
      |> assign(:skill_level, skill_level)
      |> assign(:reading_type, reading_type)
      |> assign(:keyboard_type, keyboard_type)

    background_image = handle_background_image_upload(socket)

    kfg_attrs = %{
      "initial_speed" => initial_speed,
      "speed_increase_threshold" => speed_increase_threshold,
      "lives" => lives,
      "extra_life_threshold" => extra_life_threshold,
      "points_per_kanji" => points_per_kanji,
      "reading_type" => reading_type,
      "keyboard_type" => keyboard_type
    }

    kfg_attrs =
      if background_image do
        Map.put(kfg_attrs, "background_image", background_image)
      else
        kfg_attrs
      end

    attrs = %{
      "name" => name,
      "skill_level" => skill_level,
      "kanji_falling_game" => kfg_attrs
    }

    errors = validate_form(name, selected_kanji)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :form_errors, errors)}
    else
      result =
        case socket.assigns.mode do
          :new ->
            Games.create_kanji_falling_game(classroom_id, teacher_id, attrs, selected_kanji)

          :edit ->
            Games.update_kanji_falling_game(
              socket.assigns.game,
              teacher_id,
              attrs,
              selected_kanji
            )
        end

      case result do
        {:ok, _game} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             if(socket.assigns.mode == :new,
               do: gettext("Kanji Cascade game created successfully."),
               else: gettext("Kanji Cascade game updated successfully.")
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

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :background_image, ref)}
  end

  defp validate_form(name, selected_kanji) do
    errors = %{}

    errors =
      if String.trim(name) == "" do
        Map.put(errors, :name, gettext("Name is required"))
      else
        errors
      end

    errors =
      if length(selected_kanji) < 5 do
        Map.put(errors, :selected_kanji, gettext("Select at least 5 kanji"))
      else
        errors
      end

    errors
  end

  defp handle_background_image_upload(socket) do
    uploads_dir = Application.get_env(:medoru, :uploads_dir)

    case consume_uploaded_entries(socket, :background_image, fn %{path: path}, entry ->
           ext = Path.extname(entry.client_name) |> String.downcase()
           filename = "#{Ecto.UUID.generate()}#{ext}"
           dest_dir = Path.join(uploads_dir, "game_backgrounds")
           File.mkdir_p!(dest_dir)
           dest_path = Path.join(dest_dir, filename)
           File.cp!(path, dest_path)
           {:ok, "/uploads/game_backgrounds/#{filename}"}
         end) do
      [] ->
        nil

      [image_path | _] ->
        image_path
    end
  end

  defp error_to_string(:too_large), do: gettext("File is too large (max 2MB)")
  defp error_to_string(:too_many_files), do: gettext("You can only upload 1 file")
  defp error_to_string(:not_accepted), do: gettext("Invalid file type")
  defp error_to_string(_), do: gettext("Upload failed")

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Map.new()
  end
end
