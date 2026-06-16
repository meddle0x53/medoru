defmodule Medoru.Content.KanjiStrokePathFixTest do
  use Medoru.DataCase

  alias Medoru.Content.{Kanji, KanjiStrokePathFix}
  alias Medoru.Repo

  describe "needs_normalization?/1" do
    test "returns true for chained cubic bezier segments" do
      path = "M 0,0 c 1,1 2,2 3,3 4,4 5,5 6,6"
      assert KanjiStrokePathFix.needs_normalization?(path)
    end

    test "returns false for a single cubic bezier segment" do
      path = "M 0,0 c 1,1 2,2 3,3"
      refute KanjiStrokePathFix.needs_normalization?(path)
    end

    test "returns false for non-cubic paths" do
      refute KanjiStrokePathFix.needs_normalization?("M 0,0 L 10,10")
      refute KanjiStrokePathFix.needs_normalization?(nil)
    end
  end

  describe "normalize_path/1" do
    test "splits chained cubic bezier segments into explicit commands" do
      path = "M 17.88,20.29 c 1.91,0.51 5.41,0.64 7.31,0.51 17.69,-1.18 38.69,-3.05 58.21,-3.51"

      normalized = KanjiStrokePathFix.normalize_path(path)

      assert normalized ==
               "M 17.88,20.29 c 1.91,0.51 5.41,0.64 7.31,0.51 c 17.69,-1.18 38.69,-3.05 58.21,-3.51"
    end

    test "preserves a single cubic bezier segment" do
      path = "M 0,0 c 1,1 2,2 3,3"
      assert KanjiStrokePathFix.normalize_path(path) == "M 0,0 c 1,1 2,2 3,3"
    end

    test "handles mixed relative and absolute cubic commands" do
      path = "M 57.92,40.43 c 0.58,1.07 0.81,2.39 0.81,3.53 C 58.75,61.25 52.25,74 36.06,81.18"

      normalized = KanjiStrokePathFix.normalize_path(path)

      assert normalized ==
               "M 57.92,40.43 c 0.58,1.07 0.81,2.39 0.81,3.53 C 58.75,61.25 52.25,74 36.06,81.18"
    end
  end

  describe "apply_for/1" do
    test "normalizes chained cubic bezier strokes for a kanji" do
      id = Ecto.UUID.generate()

      Repo.insert!(%Kanji{
        id: id,
        character: "医",
        meanings: ["medicine"],
        stroke_count: 7,
        stroke_data: %{
          "strokes" => [
            %{
              "order" => 1,
              "type" => "horizontal",
              "direction" => "left-to-right",
              "path" =>
                "M 17.88,20.29 c 1.91,0.51 5.41,0.64 7.31,0.51 17.69,-1.18 38.69,-3.05 58.21,-3.51 3.18,-0.08 5.08,0.25 6.67,0.5"
            },
            %{
              "order" => 2,
              "type" => "diagonal",
              "direction" => "left-to-right",
              "path" => "M 0,0 L 10,10"
            }
          ]
        }
      })

      assert {:ok, :changed} = KanjiStrokePathFix.apply_for(id)

      kanji = Repo.get!(Kanji, id)
      [stroke1, stroke2] = kanji.stroke_data["strokes"]

      assert stroke1["path"] ==
               "M 17.88,20.29 c 1.91,0.51 5.41,0.64 7.31,0.51 c 17.69,-1.18 38.69,-3.05 58.21,-3.51 c 3.18,-0.08 5.08,0.25 6.67,0.5"

      assert stroke2["path"] == "M 0,0 L 10,10"
    end

    test "returns unchanged when no strokes need normalization" do
      id = Ecto.UUID.generate()

      Repo.insert!(%Kanji{
        id: id,
        character: "一",
        meanings: ["one"],
        stroke_count: 1,
        stroke_data: %{
          "strokes" => [
            %{
              "order" => 1,
              "type" => "horizontal",
              "direction" => "left-to-right",
              "path" => "M 10,10 L 90,10"
            }
          ]
        }
      })

      assert {:ok, :unchanged} = KanjiStrokePathFix.apply_for(id)
    end

    test "returns not found for missing id" do
      assert {:error, :not_found} = KanjiStrokePathFix.apply_for(Ecto.UUID.generate())
    end
  end

  describe "apply/0" do
    test "updates all kanji that need normalization" do
      id = Ecto.UUID.generate()

      Repo.insert!(%Kanji{
        id: id,
        character: "医",
        meanings: ["medicine"],
        stroke_count: 7,
        stroke_data: %{
          "strokes" => [
            %{
              "order" => 1,
              "type" => "horizontal",
              "direction" => "left-to-right",
              "path" =>
                "M 17.88,20.29 c 1.91,0.51 5.41,0.64 7.31,0.51 17.69,-1.18 38.69,-3.05 58.21,-3.51 3.18,-0.08 5.08,0.25 6.67,0.5"
            }
          ]
        }
      })

      assert {:ok, 1} = KanjiStrokePathFix.apply()

      kanji = Repo.get!(Kanji, id)
      [stroke] = kanji.stroke_data["strokes"]

      assert stroke["path"] ==
               "M 17.88,20.29 c 1.91,0.51 5.41,0.64 7.31,0.51 c 17.69,-1.18 38.69,-3.05 58.21,-3.51 c 3.18,-0.08 5.08,0.25 6.67,0.5"
    end
  end
end
