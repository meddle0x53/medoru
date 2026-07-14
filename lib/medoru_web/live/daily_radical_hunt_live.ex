defmodule MedoruWeb.DailyRadicalHuntLive do
  @moduledoc """
  Daily Component Hunt challenge.

  A 120-second game where the user types kanji that contain a chosen component.
  Earns 30 XP per found kanji plus a flat 50 XP participation bonus.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content.KanjiComponents

  @impl true
  def render(assigns) do
    ~H"""
    {index(assigns)}
    """
  end

  alias Medoru.Learning

  @timeout_seconds 120
  @xp_per_kanji 30
  @base_xp 50

  embed_templates "daily_radical_hunt_live/*.html"

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if Learning.daily_challenge_completed?(user.id, "daily_radical_hunt") do
      {:ok,
       socket
       |> assign(:page_title, gettext("Daily Component Hunt"))
       |> assign(:already_completed, true)
       |> assign(:streak, get_streak(user.id))}
    else
      hunt = Learning.generate_daily_component_hunt(user.id)
      valid_characters = MapSet.new(hunt.valid_kanji, & &1.character)

      {:ok,
       socket
       |> assign(:page_title, gettext("Daily Component Hunt"))
       |> assign(:already_completed, false)
       |> assign(:component, hunt.component)
       |> assign(:component_meaning, KanjiComponents.meaning(hunt.component))
       |> assign(:seed_kanji, hunt.seed_kanji)
       |> assign(:valid_characters, valid_characters)
       |> assign(:valid_kanji_count, length(hunt.valid_kanji))
       |> assign(:timeout_seconds, @timeout_seconds)
       |> assign(:status, :ready)
       |> assign(:time_remaining, @timeout_seconds)
       |> assign(:timer_ref, nil)
       |> assign(:input_value, "")
       |> assign(:found_kanji, [])
       |> assign(:last_result, nil)
       |> assign(:xp_awarded, nil)
       |> assign(:is_mobile, nil)
       |> assign(:streak, get_streak(user.id))}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.status != :playing do
      {:noreply, socket}
    else
      time_remaining = socket.assigns.time_remaining - 1

      if time_remaining <= 0 do
        {:noreply, end_game(socket)}
      else
        timer_ref = Process.send_after(self(), :tick, 1000)

        {:noreply,
         socket
         |> assign(:time_remaining, time_remaining)
         |> assign(:timer_ref, timer_ref)}
      end
    end
  end

  @impl true
  def handle_event("device_info", %{"is_mobile" => is_mobile}, socket) do
    {:noreply, assign(socket, :is_mobile, is_mobile)}
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    timer_ref = Process.send_after(self(), :tick, 1000)

    {:noreply,
     socket
     |> assign(:status, :playing)
     |> assign(:timer_ref, timer_ref)
     |> assign(:time_remaining, @timeout_seconds)
     |> assign(:found_kanji, [])
     |> assign(:last_result, nil)
     |> assign(:input_value, "")
     |> push_event("request_fullscreen", %{})}
  end

  @impl true
  def handle_event("start_game_fullscreen", _params, socket) do
    timer_ref = Process.send_after(self(), :tick, 1000)

    {:noreply,
     socket
     |> assign(:status, :playing)
     |> assign(:timer_ref, timer_ref)
     |> assign(:time_remaining, @timeout_seconds)
     |> assign(:found_kanji, [])
     |> assign(:last_result, nil)
     |> assign(:input_value, "")
     |> push_event("force_fullscreen", %{})}
  end

  @impl true
  def handle_event("submit_kanji", params, socket) do
    input = String.trim(params["kanji"] || "")

    cond do
      input == "" ->
        {:noreply, socket}

      String.length(input) != 1 ->
        {:noreply,
         socket
         |> assign(:last_result, :incorrect)
         |> assign(:input_value, "")}

      input in socket.assigns.found_kanji ->
        {:noreply,
         socket
         |> assign(:last_result, :already_found)
         |> assign(:input_value, "")}

      input in socket.assigns.valid_characters ->
        found_kanji = [input | socket.assigns.found_kanji]

        {:noreply,
         socket
         |> assign(:found_kanji, found_kanji)
         |> assign(:last_result, :correct)
         |> assign(:input_value, "")}

      true ->
        {:noreply,
         socket
         |> assign(:last_result, :incorrect)
         |> assign(:input_value, "")}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:timer_ref], do: Process.cancel_timer(socket.assigns.timer_ref)
    :ok
  end

  defp end_game(socket) do
    if socket.assigns[:timer_ref], do: Process.cancel_timer(socket.assigns.timer_ref)

    user = socket.assigns.current_scope.current_user
    found_kanji = socket.assigns.found_kanji
    component = socket.assigns.component
    seed_kanji = socket.assigns.seed_kanji
    xp = length(found_kanji) * @xp_per_kanji + @base_xp

    metadata = %{
      "kanji_found" => found_kanji,
      "component" => component,
      "seed_kanji_id" => seed_kanji && seed_kanji.id
    }

    _ =
      Learning.complete_daily_challenge(user.id, "daily_radical_hunt", xp,
        score: length(found_kanji),
        metadata: metadata
      )

    socket
    |> assign(:status, :game_over)
    |> assign(:timer_ref, nil)
    |> assign(:time_remaining, 0)
    |> assign(:found_kanji, found_kanji)
    |> assign(:last_result, nil)
    |> assign(:input_value, "")
    |> assign(:xp_awarded, xp)
    |> push_event("exit_fullscreen", %{})
  end

  defp get_streak(user_id) do
    case Learning.get_daily_streak(user_id) do
      nil -> %{current_streak: 0}
      streak -> streak
    end
  end

  defp format_time(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(m), 2, "0")}:#{String.pad_leading(Integer.to_string(s), 2, "0")}"
  end

  defp current_xp(found_count) do
    found_count * @xp_per_kanji + @base_xp
  end
end
