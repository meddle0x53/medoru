defmodule MedoruWeb.LearnedKanjiLive.PracticeForm do
  @moduledoc """
  LiveView for selecting kanji to practice.
  Shows all learned kanji with checkboxes. User can select up to 20.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Accounts
  alias Medoru.Learning

  @max_selection 20

  embed_templates "practice_form.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, locale: locale, selected_ids: [], max_selection: @max_selection, snap_correct: true)}
  end

  @impl true
  def handle_params(%{"id" => user_id}, _url, socket) do
    user = Accounts.get_user!(user_id)
    kanji = Learning.list_learned_kanji(user_id)

    {:noreply,
     socket
     |> assign(:user, user)
     |> assign(:kanji, kanji)
     |> assign(:page_title, gettext("Practice Kanji"))}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected = socket.assigns.selected_ids
    id = String.replace_prefix(id, "select-kanji-", "")

    new_selected =
      if id in selected do
        List.delete(selected, id)
      else
        if length(selected) < @max_selection do
          [id | selected]
        else
          selected
        end
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  @impl true
  def handle_event("toggle_snap", _params, socket) do
    {:noreply, assign(socket, :snap_correct, !socket.assigns.snap_correct)}
  end

  @impl true
  def handle_event("start_practice", _params, socket) do
    selected = socket.assigns.selected_ids

    if selected == [] do
      {:noreply, put_flash(socket, :error, gettext("Please select at least one kanji."))}
    else
      ids_param = Enum.join(selected, ",")
      snap = if socket.assigns.snap_correct, do: "true", else: "false"
      {:noreply, push_navigate(socket, to: ~p"/users/#{socket.assigns.user.id}/kanji/practice/challenge?ids=#{ids_param}&snap=#{snap}")}
    end
  end
end
