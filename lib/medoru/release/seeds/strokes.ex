defmodule Medoru.Release.Seeds.Strokes do
  @moduledoc """
  Seeds stroke data for kanji characters.
  """

  alias Medoru.Repo
  alias Medoru.Content.Kanji

  @stroke_data_file Path.join([:code.priv_dir(:medoru), "repo", "seeds", "strokes_n5.json"])

  @doc """
  Seeds stroke data for N5 kanji.
  """
  def seed do
    stroke_data = load_stroke_data()

    if stroke_data == %{} do
      IO.puts("No stroke data found, skipping...")
      :ok
    else
      stroke_data
      |> Enum.each(fn {character, data} ->
        case Repo.get_by(Kanji, character: character) do
          nil ->
            IO.puts("  Kanji '#{character}' not found, skipping stroke data")

          kanji ->
            if kanji.stroke_data == %{} or is_nil(kanji.stroke_data) do
              kanji
              |> Ecto.Changeset.change(stroke_data: data)
              |> Repo.update!()

              IO.puts(
                "  ✓ Added stroke data for '#{character}' (#{length(data["strokes"])} strokes)"
              )
            else
              IO.puts("  • '#{character}' already has stroke data, skipping")
            end
        end
      end)

      IO.puts("Stroke data seeding complete!")
    end
  end

  defp load_stroke_data do
    case File.read(@stroke_data_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"strokes" => strokes}} -> strokes
          _ -> %{}
        end

      {:error, _} ->
        %{}
    end
  end
end
