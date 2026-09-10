defmodule Medoru.GrammarDefinitionsTest do
  use Medoru.DataCase

  alias Medoru.Content
  alias Medoru.Content.GrammarDefinition

  describe "grammar_definitions" do
    @valid_attrs %{
      title: "te-form",
      jlpt_level: 5,
      pattern_elements: [%{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]}],
      description: "The te-form is used to connect verbs.",
      examples: [%{"sentence" => "食べて", "reading" => "たべて", "meaning" => "eating"}]
    }

    @update_attrs %{
      title: "ta-form",
      description: "The ta-form is the past tense."
    }

    @invalid_attrs %{
      title: ""
    }

    test "list_grammar_definitions/1 returns paginated grammar definitions sorted by frequency" do
      # Create grammar definitions with different frequencies
      for i <- 1..5 do
        {:ok, _} =
          Content.create_grammar_definition(%{
            title: "Grammar #{i}",
            jlpt_level: rem(i, 5) + 1,
            frequency: 500 + i * 100,
            pattern_elements: [%{"type" => "literal", "text" => "test"}]
          })
      end

      result = Content.list_grammar_definitions(per_page: 10)
      frequencies = Enum.map(result.grammar_definitions, & &1.frequency)
      assert frequencies == Enum.sort(frequencies)

      result = Content.list_grammar_definitions(per_page: 3)
      assert length(result.grammar_definitions) == 3
      assert result.total_count == 5
      assert result.total_pages == 2
    end

    test "list_grammar_definitions/1 filters by jlpt_level" do
      {:ok, _} =
        Content.create_grammar_definition(%{
          title: "N5 Grammar",
          jlpt_level: 5,
          pattern_elements: [%{"type" => "literal", "text" => "test"}]
        })

      {:ok, _} =
        Content.create_grammar_definition(%{
          title: "N1 Grammar",
          jlpt_level: 1,
          pattern_elements: [%{"type" => "literal", "text" => "test"}]
        })

      result = Content.list_grammar_definitions(jlpt_level: 5)
      assert length(result.grammar_definitions) == 1
      assert hd(result.grammar_definitions).title == "N5 Grammar"
    end

    test "list_grammar_definitions/1 searches by title" do
      {:ok, _} =
        Content.create_grammar_definition(%{
          title: "te-form connection",
          jlpt_level: 5,
          pattern_elements: [%{"type" => "literal", "text" => "test"}]
        })

      {:ok, _} =
        Content.create_grammar_definition(%{
          title: "ta-form past",
          jlpt_level: 5,
          pattern_elements: [%{"type" => "literal", "text" => "test"}]
        })

      result = Content.list_grammar_definitions(search: "te-form")
      assert length(result.grammar_definitions) == 1
      assert hd(result.grammar_definitions).title == "te-form connection"
    end

    test "list_grammar_definitions/1 filters by entry_type" do
      {:ok, _} =
        Content.create_grammar_definition(%{
          title: "Pattern Grammar",
          jlpt_level: 5,
          pattern_elements: [%{"type" => "literal", "text" => "test"}]
        })

      {:ok, _} =
        Content.create_grammar_definition(%{
          title: "Text Grammar",
          jlpt_level: 5,
          entry_type: "text",
          explanation_sections: ["A section."]
        })

      result = Content.list_grammar_definitions(entry_type: "pattern")
      assert Enum.all?(result.grammar_definitions, &(&1.entry_type == "pattern"))
      assert Enum.any?(result.grammar_definitions, &(&1.title == "Pattern Grammar"))

      result = Content.list_grammar_definitions(entry_type: "text")
      assert length(result.grammar_definitions) == 1
      assert hd(result.grammar_definitions).title == "Text Grammar"
    end

    test "get_grammar_definition!/1 returns the grammar definition" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)
      assert Content.get_grammar_definition!(gd.id).title == "te-form"
    end

    test "get_grammar_definition_by_slug/1 returns the grammar definition" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)
      assert Content.get_grammar_definition_by_slug(gd.slug).title == "te-form"
    end

    test "get_grammar_definition_by_slug/1 returns nil for non-existent slug" do
      assert Content.get_grammar_definition_by_slug("nonexistent") == nil
    end

    test "get_grammar_definition_by_title/1 returns exact match" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)
      assert Content.get_grammar_definition_by_title("te-form").id == gd.id
    end

    test "get_grammar_definition_by_title/1 is case-insensitive" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)
      assert Content.get_grammar_definition_by_title("TE-FORM").id == gd.id
      assert Content.get_grammar_definition_by_title("Te-Form").id == gd.id
    end

    test "get_grammar_definition_by_title/1 falls back to partial match" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)
      assert Content.get_grammar_definition_by_title("te-for").id == gd.id
    end

    test "get_grammar_definition_by_title/1 returns most frequent when multiple match" do
      {:ok, less_frequent} =
        Content.create_grammar_definition(%{
          title: "Common Grammar",
          jlpt_level: 5,
          frequency: 500,
          pattern_elements: [%{"type" => "literal", "text" => "test"}]
        })

      {:ok, more_frequent} =
        Content.create_grammar_definition(%{
          title: "Common Grammar Pattern",
          jlpt_level: 5,
          frequency: 100,
          pattern_elements: [%{"type" => "literal", "text" => "test"}]
        })

      result = Content.get_grammar_definition_by_title("Common")
      assert result.id == more_frequent.id
      refute result.id == less_frequent.id
    end

    test "get_grammar_definition_by_title/1 returns nil for non-existent title" do
      assert Content.get_grammar_definition_by_title("nonexistent-grammar-xyz") == nil
    end

    test "create_grammar_definition/1 with valid data creates a grammar definition" do
      assert {:ok, %GrammarDefinition{} = gd} = Content.create_grammar_definition(@valid_attrs)
      assert gd.title == "te-form"
      assert gd.slug == "te-form"
      assert gd.jlpt_level == 5
      assert gd.frequency == 1000
      assert length(gd.pattern_elements) == 1
      assert length(gd.examples) == 1
    end

    test "create_grammar_definition/1 with custom frequency" do
      attrs = Map.put(@valid_attrs, :frequency, 250)
      assert {:ok, %GrammarDefinition{} = gd} = Content.create_grammar_definition(attrs)
      assert gd.frequency == 250
    end

    test "create_grammar_definition/1 auto-generates slug from title" do
      attrs = Map.put(@valid_attrs, :title, "My Test Grammar")
      assert {:ok, %GrammarDefinition{} = gd} = Content.create_grammar_definition(attrs)
      assert gd.slug == "my-test-grammar"
    end

    test "create_grammar_definition/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_grammar_definition(@invalid_attrs)
    end

    test "create_grammar_definition/1 enforces unique title" do
      assert {:ok, _} = Content.create_grammar_definition(@valid_attrs)
      assert {:error, %Ecto.Changeset{}} = Content.create_grammar_definition(@valid_attrs)
    end

    test "update_grammar_definition/2 with valid data updates the grammar definition" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)

      assert {:ok, %GrammarDefinition{} = gd} =
               Content.update_grammar_definition(gd, @update_attrs)

      assert gd.title == "ta-form"
      assert gd.description == "The ta-form is the past tense."
    end

    test "update_grammar_definition/2 with invalid data returns error changeset" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)
      assert {:error, %Ecto.Changeset{}} = Content.update_grammar_definition(gd, @invalid_attrs)
    end

    test "delete_grammar_definition/1 deletes the grammar definition" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)
      assert {:ok, %GrammarDefinition{}} = Content.delete_grammar_definition(gd)
      assert_raise Ecto.NoResultsError, fn -> Content.get_grammar_definition!(gd.id) end
    end

    test "change_grammar_definition/1 returns a changeset" do
      {:ok, gd} = Content.create_grammar_definition(@valid_attrs)
      assert %Ecto.Changeset{} = Content.change_grammar_definition(gd)
    end

    test "create_grammar_definition/1 defaults entry_type to pattern" do
      assert {:ok, %GrammarDefinition{} = gd} = Content.create_grammar_definition(@valid_attrs)
      assert gd.entry_type == "pattern"
    end

    test "create_grammar_definition/1 with text entry allows empty pattern_elements" do
      attrs = %{
        title: "Honorific overview",
        jlpt_level: 3,
        entry_type: "text",
        pattern_elements: [],
        explanation_sections: ["First part.", "Second part."]
      }

      assert {:ok, %GrammarDefinition{} = gd} = Content.create_grammar_definition(attrs)
      assert gd.entry_type == "text"
      assert gd.pattern_elements == []
      assert gd.explanation_sections == ["First part.", "Second part."]
    end

    test "create_grammar_definition/1 with text entry allows an optional display-only pattern" do
      attrs = %{
        title: "Text with pattern",
        jlpt_level: 3,
        entry_type: "text",
        pattern_elements: [%{"type" => "literal", "text" => "こと"}]
      }

      assert {:ok, %GrammarDefinition{} = gd} = Content.create_grammar_definition(attrs)
      assert gd.entry_type == "text"
      assert length(gd.pattern_elements) == 1
    end

    test "create_grammar_definition/1 with pattern entry requires pattern_elements" do
      attrs = %{title: "No pattern", jlpt_level: 5, pattern_elements: []}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Content.create_grammar_definition(attrs)

      assert %{pattern_elements: ["must have at least one pattern element"]} =
               errors_on(changeset)
    end

    test "create_grammar_definition/1 validates entry_type inclusion" do
      attrs = Map.put(@valid_attrs, :entry_type, "invalid")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Content.create_grammar_definition(attrs)

      assert %{entry_type: _} = errors_on(changeset)
    end

    test "create_grammar_definition/1 validates explanation_sections entries" do
      attrs = %{
        title: "Bad sections",
        jlpt_level: 5,
        entry_type: "text",
        explanation_sections: ["ok", 123]
      }

      assert {:error, %Ecto.Changeset{} = changeset} =
               Content.create_grammar_definition(attrs)

      assert %{explanation_sections: _} = errors_on(changeset)
    end

    test "update_grammar_definition/2 switching to pattern requires pattern_elements" do
      {:ok, gd} =
        Content.create_grammar_definition(%{
          title: "Text entry",
          jlpt_level: 5,
          entry_type: "text"
        })

      assert {:error, %Ecto.Changeset{} = changeset} =
               Content.update_grammar_definition(gd, %{entry_type: "pattern"})

      assert %{pattern_elements: ["must have at least one pattern element"]} =
               errors_on(changeset)
    end
  end

  describe "localized_description/2" do
    test "returns localized description based on locale" do
      gd = %GrammarDefinition{
        description: "English",
        description_bg: "Bulgarian",
        description_ja: "Japanese"
      }

      assert GrammarDefinition.localized_description(gd, "en") == "English"
      assert GrammarDefinition.localized_description(gd, "bg") == "Bulgarian"
      assert GrammarDefinition.localized_description(gd, "ja") == "Japanese"
    end

    test "falls back to English when localized version is nil" do
      gd = %GrammarDefinition{
        description: "English",
        description_bg: nil,
        description_ja: nil
      }

      assert GrammarDefinition.localized_description(gd, "bg") == "English"
      assert GrammarDefinition.localized_description(gd, "ja") == "English"
    end
  end

  describe "localized_example_meaning/2" do
    test "returns localized meaning based on locale" do
      example = %{
        "meaning" => "English",
        "meaning_bg" => "Bulgarian",
        "meaning_ja" => "Japanese"
      }

      assert GrammarDefinition.localized_example_meaning(example, "en") == "English"
      assert GrammarDefinition.localized_example_meaning(example, "bg") == "Bulgarian"
      assert GrammarDefinition.localized_example_meaning(example, "ja") == "Japanese"
    end

    test "falls back to English when localized version is nil" do
      example = %{
        "meaning" => "English",
        "meaning_bg" => nil,
        "meaning_ja" => nil
      }

      assert GrammarDefinition.localized_example_meaning(example, "bg") == "English"
      assert GrammarDefinition.localized_example_meaning(example, "ja") == "English"
    end
  end
end
