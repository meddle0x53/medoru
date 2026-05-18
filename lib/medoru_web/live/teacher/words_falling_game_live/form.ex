defmodule MedoruWeb.Teacher.WordsFallingGameLive.Form do
  @moduledoc """
  LiveView for creating and editing words falling games.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Games
  alias Medoru.Learning.WordSets

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

  defp game_mode_options do
    [
      {gettext("Word Meaning"), "0"},
      {gettext("Word Reading"), "1"}
    ]
  end

  defp keyboard_type_options do
    [
      {gettext("Hiragana flick keyboard"), "hiragana"},
      {gettext("Latin QWERTY keyboard"), "latin"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    word_sets = WordSets.list_user_word_sets(user.id, per_page: 1000)

    {:ok,
     socket
     |> assign(:page_title, gettext("Create Words Cascade Game"))
     |> assign(:name, "")
     |> assign(:initial_speed, "1")
     |> assign(:speed_increase_threshold, "50")
     |> assign(:lives, "3")
     |> assign(:extra_life_threshold, "100")
     |> assign(:skill_level, "1")
     |> assign(:game_mode, "0")
     |> assign(:keyboard_type, "latin")
     |> assign(:selected_words, [])
     |> assign(:word_points, %{})
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:search_loading, false)
     |> assign(:word_sets, word_sets)
     |> assign(:selected_word_set_id, "")
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
      wfg = game.words_falling_game

      selected_words =
        (wfg.selected_words || [])
        |> Enum.map(fn word_id ->
          case Content.get_word(word_id) do
            nil -> nil
            word -> %{id: word.id, text: word.text, reading: word.reading, meaning: word.meaning}
          end
        end)
        |> Enum.reject(&is_nil/1)

      word_points = wfg.word_points || %{}

      {:noreply,
       socket
       |> assign(:page_title, gettext("Edit Words Cascade Game"))
       |> assign(:classroom, classroom)
       |> assign(:game, game)
       |> assign(:mode, :edit)
       |> assign(:name, game.name)
       |> assign(:initial_speed, Integer.to_string(wfg.initial_speed))
       |> assign(:speed_increase_threshold, Integer.to_string(wfg.speed_increase_threshold))
       |> assign(:lives, Integer.to_string(wfg.lives))
       |> assign(:extra_life_threshold, Integer.to_string(wfg.extra_life_threshold))
       |> assign(:skill_level, Integer.to_string(game.skill_level))
       |> assign(:game_mode, Integer.to_string(wfg.game_mode))
       |> assign(:keyboard_type, wfg.keyboard_type)
       |> assign(:selected_words, selected_words)
       |> assign(:word_points, word_points)
       |> assign(:background_image, wfg.background_image)
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
       |> assign(:skill_level, "1")
       |> assign(:game_mode, "0")
       |> assign(:keyboard_type, "latin")
       |> assign(:selected_words, [])
       |> assign(:word_points, %{})
       |> assign(:form_errors, %{})}
    end
  end

  @impl true
  def handle_event("search_words", %{"query" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply,
       socket
       |> assign(:search_query, "")
       |> assign(:search_results, [])
       |> assign(:search_loading, false)}
    else
      results = Content.search_words(query, limit: 10)
      existing_ids = Enum.map(socket.assigns.selected_words, & &1.id)
      filtered = Enum.reject(results, fn word -> word.id in existing_ids end)

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, filtered)
       |> assign(:search_loading, false)}
    end
  end

  @impl true
  def handle_event("add_word", %{"word_id" => word_id}, socket) do
    selected = socket.assigns.selected_words

    if Enum.any?(selected, &(&1.id == word_id)) do
      {:noreply, socket}
    else
      case Content.get_word(word_id) do
        nil ->
          {:noreply, socket}

        word ->
          new_word = %{
            id: word.id,
            text: word.text,
            reading: word.reading,
            meaning: word.meaning
          }

          word_points = Map.put(socket.assigns.word_points, to_string(word.id), 1)

          socket =
            if socket.assigns.form_errors[:selected_words] do
              assign(
                socket,
                :form_errors,
                Map.delete(socket.assigns.form_errors, :selected_words)
              )
            else
              socket
            end

          {:noreply,
           socket
           |> assign(:selected_words, selected ++ [new_word])
           |> assign(:word_points, word_points)
           |> assign(:search_query, "")
           |> assign(:search_results, [])}
      end
    end
  end

  @impl true
  def handle_event("remove_word", %{"word_id" => word_id}, socket) do
    selected = Enum.reject(socket.assigns.selected_words, &(&1.id == word_id))
    word_points = Map.delete(socket.assigns.word_points, to_string(word_id))

    socket =
      if socket.assigns.form_errors[:selected_words] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :selected_words))
      else
        socket
      end

    {:noreply, assign(socket, selected_words: selected, word_points: word_points)}
  end

  @impl true
  def handle_event("add_from_word_set", %{"word_set_id" => word_set_id}, socket) do
    if word_set_id == "" do
      {:noreply, socket}
    else
      {_word_set, words_result} =
        WordSets.get_word_set_with_words_paginated(word_set_id, per_page: 1000)

      existing_ids = Enum.map(socket.assigns.selected_words, & &1.id)
      new_words = Enum.reject(words_result.words, &(&1.id in existing_ids))

      selected =
        socket.assigns.selected_words ++
          Enum.map(new_words, fn word ->
            %{id: word.id, text: word.text, reading: word.reading, meaning: word.meaning}
          end)

      word_points =
        Enum.reduce(new_words, socket.assigns.word_points, fn word, acc ->
          Map.put_new(acc, to_string(word.id), 1)
        end)

      socket =
        if socket.assigns.form_errors[:selected_words] do
          assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :selected_words))
        else
          socket
        end

      {:noreply,
       socket
       |> assign(:selected_words, selected)
       |> assign(:word_points, word_points)
       |> assign(:selected_word_set_id, "")
       |> put_flash(
         :info,
         gettext("Added %{count} words from word set.", count: length(new_words))
       )}
    end
  end

  @impl true
  def handle_event("update_word_points", %{} = params, socket) do
    word_id = params["word_id"]
    points = params["points"]

    word_points =
      case Integer.parse(points) do
        {n, _} when n > 0 -> Map.put(socket.assigns.word_points, word_id, n)
        _ -> socket.assigns.word_points
      end

    {:noreply, assign(socket, :word_points, word_points)}
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
        "skill_level" -> assign(socket, :skill_level, value)
        "game_mode" -> assign(socket, :game_mode, value)
        "keyboard_type" -> assign(socket, :keyboard_type, value)
        _ -> socket
      end

    error_field =
      case field do
        "name" -> :name
        "initial_speed" -> :initial_speed
        "speed_increase_threshold" -> :speed_increase_threshold
        "lives" -> :lives
        "extra_life_threshold" -> :extra_life_threshold
        "skill_level" -> :skill_level
        "game_mode" -> :game_mode
        "keyboard_type" -> :keyboard_type
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
    selected_word_ids = Enum.map(socket.assigns.selected_words, & &1.id)

    name = String.trim(params["name"] || socket.assigns.name || "")
    initial_speed = params["initial_speed"] || socket.assigns.initial_speed || "1"

    speed_increase_threshold =
      params["speed_increase_threshold"] || socket.assigns.speed_increase_threshold || "50"

    lives = params["lives"] || socket.assigns.lives || "3"

    extra_life_threshold =
      params["extra_life_threshold"] || socket.assigns.extra_life_threshold || "100"

    skill_level = params["skill_level"] || socket.assigns.skill_level || "1"
    game_mode = params["game_mode"] || socket.assigns.game_mode || "0"
    keyboard_type = params["keyboard_type"] || socket.assigns.keyboard_type || "latin"

    socket =
      socket
      |> assign(:name, name)
      |> assign(:initial_speed, initial_speed)
      |> assign(:speed_increase_threshold, speed_increase_threshold)
      |> assign(:lives, lives)
      |> assign(:extra_life_threshold, extra_life_threshold)
      |> assign(:skill_level, skill_level)
      |> assign(:game_mode, game_mode)
      |> assign(:keyboard_type, keyboard_type)

    background_image = handle_background_image_upload(socket)

    wfg_attrs = %{
      "initial_speed" => initial_speed,
      "speed_increase_threshold" => speed_increase_threshold,
      "lives" => lives,
      "extra_life_threshold" => extra_life_threshold,
      "game_mode" => game_mode,
      "keyboard_type" => keyboard_type,
      "word_points" => socket.assigns.word_points
    }

    wfg_attrs =
      if background_image do
        Map.put(wfg_attrs, "background_image", background_image)
      else
        wfg_attrs
      end

    attrs = %{
      "name" => name,
      "skill_level" => skill_level,
      "words_falling_game" => wfg_attrs
    }

    errors = validate_form(name, selected_word_ids)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :form_errors, errors)}
    else
      result =
        case socket.assigns.mode do
          :new ->
            Games.create_words_falling_game(classroom_id, teacher_id, attrs, selected_word_ids)

          :edit ->
            Games.update_words_falling_game(
              socket.assigns.game,
              teacher_id,
              attrs,
              selected_word_ids
            )
        end

      case result do
        {:ok, _game} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             if(socket.assigns.mode == :new,
               do: gettext("Words Cascade game created successfully."),
               else: gettext("Words Cascade game updated successfully.")
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

  defp validate_form(name, selected_word_ids) do
    errors = %{}

    errors =
      if String.trim(name) == "" do
        Map.put(errors, :name, gettext("Name is required"))
      else
        errors
      end

    errors =
      if length(selected_word_ids) < 5 do
        Map.put(errors, :selected_words, gettext("Select at least 5 words"))
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
      [] -> nil
      [image_path | _] -> image_path
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
