defmodule Medoru.Tests.MeaningSegmentsTest do
  use Medoru.DataCase, async: true

  alias Medoru.Tests.MeaningSegments

  describe "split/1" do
    test "single segment" do
      assert MeaningSegments.split("to eat") == ["to eat"]
    end

    test "multiple segments are trimmed" do
      assert MeaningSegments.split("to eat/to consume") == ["to eat", "to consume"]
      assert MeaningSegments.split(" a / b / c ") == ["a", "b", "c"]
    end

    test "empty parts are dropped" do
      assert MeaningSegments.split("to eat//to consume") == ["to eat", "to consume"]
      assert MeaningSegments.split("") == []
      assert MeaningSegments.split("//") == []
    end
  end

  describe "random_count/0" do
    test "returns a value between 1 and 3" do
      assert MeaningSegments.random_count() in [1, 2, 3]
    end
  end

  describe "pick_random/1" do
    test "returns segments and sorted distinct indices within range" do
      meaning = "to eat/to consume/to chew"

      for _ <- 1..20 do
        {segments, indices} = MeaningSegments.pick_random(meaning)
        all = MeaningSegments.split(meaning)

        assert length(indices) in 1..3
        assert indices == Enum.uniq(indices)
        assert indices == Enum.sort(indices)
        assert Enum.all?(indices, &(&1 >= 0 and &1 < length(all)))
        assert segments == Enum.map(indices, &Enum.at(all, &1))
        assert segments == Enum.map(segments, &String.trim/1)
      end
    end
  end

  describe "pick_indices/2" do
    test "returns segments at given indices" do
      assert MeaningSegments.pick_indices("to eat/to consume", [0, 1]) ==
               ["to eat", "to consume"]
    end

    test "skips out-of-range indices" do
      assert MeaningSegments.pick_indices("to eat/to consume", [0, 5, 1]) ==
               ["to eat", "to consume"]

      assert MeaningSegments.pick_indices("to eat", [5]) == []
    end
  end

  describe "join/1" do
    test "joins segments with ' / '" do
      assert MeaningSegments.join(["a", "b"]) == "a / b"
      assert MeaningSegments.join(["a"]) == "a"
    end
  end
end
