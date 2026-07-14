defmodule MedoruWeb.Teacher.RadicalHuntGameLive.Form do
  @moduledoc """
  LiveView for creating and editing radical hunt games.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content.KanjiComponents
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

  defp timeout_options do
    [
      {"30 seconds", "30"},
      {"60 seconds (1 min)", "60"},
      {"90 seconds", "90"},
      {"120 seconds (2 min)", "120"},
      {"180 seconds (3 min)", "180"},
      {"240 seconds (4 min)", "240"},
      {"300 seconds (5 min)", "300"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    components = KanjiComponents.by_frequency()

    {:ok,
     socket
     |> assign(:page_title, gettext("Create Component Hunt Game"))
     |> assign(:name, "")
     |> assign(:skill_level, "1")
     |> assign(:timeout_seconds, "120")
     |> assign(:selected_component, nil)
     |> assign(:components, components)
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
      rhg = game.radical_hunt_game

      {:noreply,
       socket
       |> assign(:page_title, gettext("Edit Component Hunt Game"))
       |> assign(:classroom, classroom)
       |> assign(:game, game)
       |> assign(:mode, :edit)
       |> assign(:name, game.name)
       |> assign(:skill_level, Integer.to_string(game.skill_level))
       |> assign(:timeout_seconds, Integer.to_string(rhg.timeout_seconds))
       |> assign(:selected_component, rhg.component)
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
        "skill_level" -> assign(socket, :skill_level, value)
        "timeout_seconds" -> assign(socket, :timeout_seconds, value)
        _ -> socket
      end

    error_field =
      case field do
        "name" -> :name
        "skill_level" -> :skill_level
        "timeout_seconds" -> :timeout_seconds
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
  def handle_event("select_component", %{"character" => character}, socket) do
    socket =
      if socket.assigns.form_errors[:selected_component] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :selected_component))
      else
        socket
      end

    {:noreply, assign(socket, :selected_component, character)}
  end

  @impl true
  def handle_event("save", params, socket) do
    classroom_id = socket.assigns.classroom.id
    teacher_id = socket.assigns.current_scope.current_user.id
    selected_component = socket.assigns.selected_component

    name = String.trim(params["name"] || socket.assigns.name || "")
    skill_level = params["skill_level"] || socket.assigns.skill_level || "1"
    timeout_seconds = params["timeout_seconds"] || socket.assigns.timeout_seconds || "120"

    socket =
      socket
      |> assign(:name, name)
      |> assign(:skill_level, skill_level)
      |> assign(:timeout_seconds, timeout_seconds)

    rhg_attrs = %{
      "timeout_seconds" => timeout_seconds
    }

    attrs = %{
      "name" => name,
      "skill_level" => skill_level,
      "radical_hunt_game" => rhg_attrs
    }

    errors = validate_form(name, selected_component)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :form_errors, errors)}
    else
      result =
        case socket.assigns.mode do
          :new ->
            Games.create_radical_hunt_game(classroom_id, teacher_id, attrs, selected_component)

          :edit ->
            Games.update_radical_hunt_game(
              socket.assigns.game,
              teacher_id,
              attrs,
              selected_component
            )
        end

      case result do
        {:ok, _game} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             if(socket.assigns.mode == :new,
               do: gettext("Component Hunt game created successfully."),
               else: gettext("Component Hunt game updated successfully.")
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

  defp validate_form(name, selected_component) do
    errors = %{}

    errors =
      if String.trim(name) == "" do
        Map.put(errors, :name, gettext("Name is required"))
      else
        errors
      end

    errors =
      if is_nil(selected_component) do
        Map.put(errors, :selected_component, gettext("Select a component"))
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
