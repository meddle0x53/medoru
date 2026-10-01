defmodule MedoruWeb.CardGameLogic do
  @moduledoc """
  Pure memory card game logic shared by the daily card challenge and the
  word set memory card game. All functions operate on an in-memory session
  map and word structs/maps; no DB access.
  """

  @doc """
  Creates a new game session for the given word ids (one per pair). Each word
  id is dealt twice and the deck is shuffled.
  """
  def new_session(word_ids, max_attempts) do
    card_positions =
      word_ids
      |> Enum.flat_map(&[&1, &1])
      |> Enum.shuffle()

    %{
      status: :in_progress,
      attempts_used: 0,
      max_attempts: max_attempts,
      cards_state: %{
        "card_positions" => card_positions,
        "collected_indices" => [],
        "flipped_indices" => []
      }
    }
  end

  def flip_card(session, position) do
    cards_state = session.cards_state
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []
    flipped = cards_state["flipped_indices"] || []

    cond do
      session.status != :in_progress ->
        {:error, :game_over}

      position in collected ->
        {:error, :already_collected}

      position in flipped ->
        {:error, :already_flipped}

      length(flipped) >= 2 ->
        {:error, :too_many_flipped}

      position < 0 or position >= length(card_positions) ->
        {:error, :invalid_position}

      true ->
        new_flipped = flipped ++ [position]

        if length(new_flipped) == 2 do
          handle_two_flipped(session, new_flipped, card_positions, collected)
        else
          new_state = %{
            "card_positions" => card_positions,
            "collected_indices" => collected,
            "flipped_indices" => new_flipped
          }

          {:ok, Map.put(session, :cards_state, new_state)}
        end
    end
  end

  defp handle_two_flipped(session, [pos1, pos2], card_positions, collected) do
    word1 = Enum.at(card_positions, pos1)
    word2 = Enum.at(card_positions, pos2)

    if word1 == word2 do
      # Match found - ask for meaning input (keep flipped)
      new_state = %{
        "card_positions" => card_positions,
        "collected_indices" => collected,
        "flipped_indices" => [pos1, pos2]
      }

      updated = Map.put(session, :cards_state, new_state)
      {:needs_input, updated, word1}
    else
      new_attempts = session.attempts_used + 1

      new_state = %{
        "card_positions" => card_positions,
        "collected_indices" => collected,
        "flipped_indices" => [pos1, pos2]
      }

      updated =
        session
        |> Map.put(:cards_state, new_state)
        |> Map.put(:attempts_used, new_attempts)

      if new_attempts >= session.max_attempts do
        {:ok, Map.put(updated, :status, :completed), :no_match}
      else
        {:ok, updated, :no_match}
      end
    end
  end

  def collect_flipped_cards(session) do
    cards_state = session.cards_state
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []
    flipped = cards_state["flipped_indices"] || []

    new_collected = collected ++ flipped

    new_state = %{
      "card_positions" => card_positions,
      "collected_indices" => new_collected,
      "flipped_indices" => []
    }

    updated = Map.put(session, :cards_state, new_state)

    if all_collected?(updated) do
      Map.put(updated, :status, :completed)
    else
      updated
    end
  end

  def consume_attempt_and_close_flipped(session) do
    cards_state = session.cards_state
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []

    new_attempts = session.attempts_used + 1

    new_state = %{
      "card_positions" => card_positions,
      "collected_indices" => collected,
      "flipped_indices" => []
    }

    updated =
      session
      |> Map.put(:cards_state, new_state)
      |> Map.put(:attempts_used, new_attempts)

    if new_attempts >= session.max_attempts do
      Map.put(updated, :status, :completed)
    else
      updated
    end
  end

  def close_flipped(session) do
    Map.put(session, :cards_state, Map.put(session.cards_state, "flipped_indices", []))
  end

  def validate_meaning(answer, _word, _locale) when answer == "", do: false

  def validate_meaning(answer, word, locale) do
    answer_lower = String.downcase(answer)

    # Build list of valid meanings: English + locale translation
    localized_meaning = get_localized_meaning(word, locale)

    meanings =
      [word.meaning, localized_meaning]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&split_meanings/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))

    Enum.any?(meanings, fn meaning ->
      String.contains?(meaning, answer_lower) or
        String.contains?(answer_lower, meaning)
    end)
  end

  def get_localized_meaning(%{translations: translations}, locale)
      when is_map(translations) and translations != %{} do
    case get_in(translations, [locale, "meaning"]) do
      nil -> get_in(translations, ["en", "meaning"])
      meaning -> meaning
    end
  end

  def get_localized_meaning(_word, _locale), do: nil

  def split_meanings(nil), do: []

  def split_meanings(text) do
    text
    |> String.split(~r/[,;、]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def validate_japanese_answer(answer, _word) when answer == "", do: false

  def validate_japanese_answer(answer, word) do
    answer = String.trim(answer)

    valid_answers =
      [word.text, word.reading]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&split_readings/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Enum.any?(valid_answers, fn valid ->
      String.downcase(valid) == String.downcase(answer)
    end)
  end

  def split_readings(nil), do: []

  def split_readings(text) do
    text
    |> String.split(~r{[/／]})
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def card_states(session) do
    cards_state = session.cards_state || %{}
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []
    flipped = cards_state["flipped_indices"] || []

    Enum.map(0..(length(card_positions) - 1), fn index ->
      cond do
        index in collected -> :collected
        index in flipped -> :flipped
        true -> :hidden
      end
    end)
  end

  def word_at_position(session, words, position) do
    cards_state = session.cards_state || %{}
    card_positions = cards_state["card_positions"] || []
    word_id = Enum.at(card_positions, position)

    Enum.find(words, %{text: "?", reading: "", meaning: "?"}, fn w ->
      w.id == word_id
    end)
  end

  def attempts_remaining(session) do
    session.max_attempts - session.attempts_used
  end

  def game_over?(session) do
    session.status == :completed or attempts_remaining(session) <= 0
  end

  def all_collected?(session) do
    cards_state = session.cards_state || %{}
    collected = cards_state["collected_indices"] || []
    card_positions = cards_state["card_positions"] || []
    length(collected) == length(card_positions)
  end
end
