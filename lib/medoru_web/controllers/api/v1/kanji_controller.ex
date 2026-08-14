defmodule MedoruWeb.Api.V1.KanjiController do
  @moduledoc """
  Public API endpoints for kanji.
  """
  use MedoruWeb, :controller

  alias Medoru.Content

  @allowed_includes %{"bg_meanings" => true}

  @doc false
  def index(conn, params) do
    jlpt_level = parse_optional_int(params["jlpt_level"])
    limit = parse_optional_int(params["limit"])
    cursor = params["cursor"]
    include_fields = parse_include(params["include"])

    opts = [
      jlpt_level: jlpt_level,
      limit: limit,
      cursor: cursor
    ]

    case Content.list_kanji_for_api(opts) do
      {:ok, {items, next_cursor}} ->
        json(conn, %{
          items: Enum.map(items, &render_list_item(&1, include_fields)),
          next_cursor: next_cursor
        })

      {:error, :invalid_cursor} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: [%{detail: "Invalid cursor"}]})

      {:error, :cursor_mismatch} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: [%{detail: "Cursor does not match current filters"}]})
    end
  end

  @doc false
  def show(conn, %{"character" => character} = params) do
    include_fields = parse_include(params["include"])

    case Content.get_kanji_by_character_for_api(character) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: [%{detail: "Kanji not found"}]})

      kanji ->
        json(conn, render_detail(kanji, include_fields))
    end
  end

  defp parse_optional_int(nil), do: nil

  defp parse_optional_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_optional_int(value) when is_integer(value), do: value
  defp parse_optional_int(_), do: nil

  defp parse_include(nil), do: MapSet.new()

  defp parse_include(include) when is_binary(include) do
    include
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(MapSet.new(), fn value, acc ->
      if Map.has_key?(@allowed_includes, value) do
        MapSet.put(acc, value)
      else
        acc
      end
    end)
  end

  defp parse_include(_), do: MapSet.new()

  defp render_list_item(item, include_fields) do
    %{
      character: item.character,
      meanings: clean_string_list(item.meanings) || [],
      stroke_count: item.stroke_count,
      jlpt_level: item.jlpt_level,
      radicals: clean_string_list(item.radicals),
      frequency: item.frequency,
      school_level: item.school_level,
      bg_meanings: maybe_include_bg_meanings(item.translations, include_fields)
    }
  end

  defp render_detail(kanji, include_fields) do
    %{
      character: kanji.character,
      meanings: clean_string_list(kanji.meanings) || [],
      stroke_count: kanji.stroke_count,
      jlpt_level: kanji.jlpt_level,
      radicals: clean_string_list(kanji.radicals),
      frequency: kanji.frequency,
      school_level: kanji.school_level,
      bg_meanings: maybe_include_bg_meanings(kanji.translations, include_fields),
      stroke_data: kanji.stroke_data
    }
  end

  defp clean_string_list(nil), do: nil

  defp clean_string_list(values) do
    values
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      cleaned -> cleaned
    end
  end

  defp maybe_include_bg_meanings(translations, include_fields) do
    if MapSet.member?(include_fields, "bg_meanings") do
      extract_bg_meanings(translations)
    else
      nil
    end
  end

  defp extract_bg_meanings(nil), do: nil

  defp extract_bg_meanings(translations) do
    case translations["bg"] do
      %{"meanings" => meanings} when is_list(meanings) ->
        meanings
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&to_string/1)
        |> case do
          [] -> nil
          cleaned -> cleaned
        end

      _ ->
        nil
    end
  end
end
