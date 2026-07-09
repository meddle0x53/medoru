defmodule Medoru.SlugTest do
  use ExUnit.Case, async: true

  alias Medoru.Slug

  describe "generate/2" do
    test "converts ASCII text to a hyphenated slug" do
      assert Slug.generate("Hello World") == "hello-world"
    end

    test "trims leading and trailing separators" do
      assert Slug.generate("  Hello World  ") == "hello-world"
    end

    test "collapses multiple non-alphanumeric characters into a single hyphen" do
      assert Slug.generate("Hello---World!!") == "hello-world"
    end

    test "uses a fallback prefix for non-ASCII text" do
      assert Slug.generate("こんにちは", "lesson") =~ ~r/^lesson-[a-f0-9]+$/
    end

    test "truncates slugs to a maximum length" do
      long_title = String.duplicate("a", 200)
      assert byte_size(Slug.generate(long_title)) <= 100
    end
  end

  describe "ensure_unique/2" do
    test "returns the base slug when there are no conflicts" do
      assert Slug.ensure_unique("hello-world", []) == "hello-world"
    end

    test "appends a numeric suffix when the base slug is taken" do
      assert Slug.ensure_unique("hello-world", ["hello-world"]) == "hello-world-1"
    end

    test "finds the next available suffix" do
      assert Slug.ensure_unique("hello-world", ["hello-world", "hello-world-1", "hello-world-3"]) ==
               "hello-world-2"
    end
  end

  describe "matching_existing/2" do
    test "filters slugs matching the base slug" do
      assert Slug.matching_existing(["foo", "foo-1", "bar"], "foo") == ["foo", "foo-1"]
    end

    test "does not match partial prefixes" do
      assert Slug.matching_existing(["foobar", "foo-1"], "foo") == ["foo-1"]
    end

    test "does not match non-sequential suffixes" do
      assert Slug.matching_existing(["foo-a", "foo-1-2"], "foo") == []
    end
  end
end
