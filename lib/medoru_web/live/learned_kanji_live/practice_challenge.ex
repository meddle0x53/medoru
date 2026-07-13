defmodule MedoruWeb.LearnedKanjiLive.PracticeChallenge do
  @moduledoc """
  LiveView for practicing selected learned kanji.
  No per-kanji XP — flat 50 XP reward at completion.
  Updates known_score after each kanji.
  """
  use MedoruWeb, :live_view

  alias Medoru.Learning
  alias Medoru.Content
  alias Medoru.Repo
  alias Medoru.Learning.UserProgress
  alias Medoru.Accounts

  import Ecto.Query

  embed_templates "practice_challenge.html"

  @xp_reward 50
  @max_wrong_strokes 3

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, locale: locale)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    user = socket.assigns.current_scope.current_user
    kanji_ids = parse_kanji_ids(params["ids"] || "")
    snap_correct = parse_boolean(params["snap"], true)

    # Validate: all kanji must be in user's learned pool
    learned_ids = Learning.list_learned_kanji_ids(user.id)
    valid_ids = Enum.filter(kanji_ids, &(&1 in learned_ids))

    if valid_ids == [] do
      {:noreply,
       socket
       |> put_flash(:error, gettext("Please select at least one learned kanji."))
       |> push_navigate(to: ~p"/users/#{user.id}/kanji/practice")}
    else
      kanji_list =
        valid_ids
        |> Enum.map(&Content.get_kanji_with_readings!/1)
        |> Enum.shuffle()

      count = length(kanji_list)

      {:noreply,
       socket
       |> assign(:page_title, gettext("Kanji Practice"))
       |> assign(:finished, false)
       |> assign(:kanji_count, count)
       |> assign(:kanji_list, kanji_list)
       |> assign(:current_index, 1)
       |> assign(:current_kanji, List.first(kanji_list))
       |> assign(:current_wrong_strokes, 0)
       |> assign(:results, [])
       |> assign(:correct_count, 0)
       |> assign(:total_xp, 0)
       |> assign(:max_wrong_strokes, @max_wrong_strokes)
       |> assign(:snap_correct, snap_correct)}
    end
  end

  @impl true
  def handle_event("kanji_complete", params, socket) do
    wrong_strokes = parse_wrong_strokes(params)
    proceed_to_next_kanji(socket, true, wrong_strokes)
  end

  @impl true
  def handle_event("submit_writing", params, socket) do
    completed = parse_boolean(params["completed"], false)
    wrong_strokes = parse_wrong_strokes(params)
    proceed_to_next_kanji(socket, completed, wrong_strokes)
  end

  @impl true
  def handle_event("wrong_stroke", params, socket) do
    count = params["count"] || 0
    {:noreply, assign(socket, :current_wrong_strokes, count)}
  end

  defp proceed_to_next_kanji(socket, completed, wrong_strokes) do
    current_kanji = socket.assigns.current_kanji
    current_index = socket.assigns.current_index
    user = socket.assigns.current_scope.current_user

    # Update known_score for this kanji based on performance
    update_known_score(user.id, current_kanji.id, completed)

    results = [{current_kanji.id, completed, wrong_strokes} | socket.assigns.results]

    correct_count =
      if completed and wrong_strokes <= @max_wrong_strokes do
        socket.assigns.correct_count + 1
      else
        socket.assigns.correct_count
      end

    if current_index >= socket.assigns.kanji_count do
      # Finished — award flat XP directly (not via daily challenge system)
      _ =
        Accounts.add_xp(user.id, @xp_reward,
          source_type: "kanji_practice",
          description: "Completed kanji practice session"
        )

      {:noreply,
       socket
       |> assign(:finished, true)
       |> assign(:results, results)
       |> assign(:correct_count, correct_count)
       |> assign(:total_xp, @xp_reward)}
    else
      next_kanji = Enum.at(socket.assigns.kanji_list, current_index)

      {:noreply,
       socket
       |> assign(:current_index, current_index + 1)
       |> assign(:current_kanji, next_kanji)
       |> assign(:current_wrong_strokes, 0)
       |> assign(:results, results)
       |> assign(:correct_count, correct_count)}
    end
  end

  defp update_known_score(user_id, kanji_id, completed) do
    progress =
      UserProgress
      |> where([up], up.user_id == ^user_id and up.kanji_id == ^kanji_id)
      |> Repo.one()

    if progress do
      new_score =
        if completed do
          progress.known_score + 1
        else
          max(progress.known_score - 1, 1)
        end

      progress
      |> Ecto.Changeset.change(known_score: new_score)
      |> Repo.update()
    end
  end

  defp parse_kanji_ids(""), do: []

  defp parse_kanji_ids(ids_string) when is_binary(ids_string) do
    ids_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_wrong_strokes(%{"wrong_strokes" => wrong_strokes}) when is_integer(wrong_strokes),
    do: wrong_strokes

  defp parse_wrong_strokes(%{"wrong_strokes" => wrong_strokes}) when is_binary(wrong_strokes) do
    case Integer.parse(wrong_strokes) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_wrong_strokes(_), do: 0

  defp parse_boolean(true, _default), do: true
  defp parse_boolean("true", _default), do: true
  defp parse_boolean(false, _default), do: false
  defp parse_boolean("false", _default), do: false
  defp parse_boolean(nil, default), do: default
  defp parse_boolean(_, default), do: default

  defp first_reading(%{kanji_readings: %Ecto.Association.NotLoaded{}}, _type), do: "—"

  defp first_reading(kanji, type) do
    case Enum.find(kanji.kanji_readings || [], fn r -> r.reading_type == type end) do
      nil -> "—"
      reading -> reading.reading
    end
  end
end
