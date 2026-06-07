defmodule MedoruWeb.GameApiController do
  @moduledoc """
  API controller for Kill Medoru! game events.
  """
  use MedoruWeb, :controller

  alias Medoru.Accounts
  alias Medoru.Accounts.UserStats
  alias Medoru.Learning
  alias Medoru.Repo

  def user_data(conn, _params) do
    user = conn.assigns.current_scope.current_user

    kanji_list =
      user.id
      |> Learning.list_learned_kanji(limit: 50)
      |> Enum.map(fn k ->
        readings = List.first(k.meanings || [], "")
        %{character: k.character, readings: [readings]}
      end)

    word_list =
      user.id
      |> Learning.list_learned_words(limit: 30)
      |> Enum.map(fn w ->
        %{word: w.text, reading: w.reading}
      end)

    user_level =
      case Repo.get_by(UserStats, user_id: user.id) do
        %UserStats{level: level} -> level
        _ -> 1
      end

    json(conn, %{
      user_id: user.id,
      name: user.name || user.email,
      level: user_level,
      kanji_list: kanji_list,
      word_list: word_list
    })
  end

  def run_result(conn, params) do
    user = conn.assigns.current_scope.current_user

    # Log the run result for now. In the future this will save to DB.
    require Logger
    Logger.info("Game run result for user #{user.id}: #{inspect(params)}")

    # Grant a small XP reward for winning
    if params["winner"] == "player" do
      Accounts.add_xp(user, 50, source_type: "game_battle", description: "Won a battle in Kill Medoru!")
    end

    json(conn, %{status: "ok"})
  end
end
