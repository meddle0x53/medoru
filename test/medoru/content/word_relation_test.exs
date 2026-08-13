defmodule Medoru.Content.WordRelationTest do
  use Medoru.DataCase

  import Medoru.ContentFixtures

  alias Medoru.Content
  alias Medoru.Content.WordRelation
  alias Medoru.Repo

  describe "WordRelation changeset" do
    test "validates required fields" do
      changeset = WordRelation.changeset(%WordRelation{}, %{})
      assert "can't be blank" in errors_on(changeset).word_id
      assert "can't be blank" in errors_on(changeset).relation_type
    end

    test "requires related_word_id for synonyms and antonyms" do
      word = word_fixture()

      attrs = %{
        word_id: word.id,
        relation_type: :synonym,
        expression_text: "some text"
      }

      changeset = WordRelation.changeset(%WordRelation{}, attrs)
      assert "is required for synonyms and antonyms" in errors_on(changeset).related_word_id
    end

    test "requires expression_text for unlinked expressions" do
      word = word_fixture()

      attrs = %{
        word_id: word.id,
        relation_type: :expression,
        related_word_id: nil
      }

      changeset = WordRelation.changeset(%WordRelation{}, attrs)

      assert "is required when expression is not linked to a word" in errors_on(changeset).expression_text
    end

    test "accepts a linked expression" do
      word = word_fixture()
      related = word_fixture()

      attrs = %{
        word_id: word.id,
        relation_type: :expression,
        related_word_id: related.id
      }

      assert %Ecto.Changeset{valid?: true} = WordRelation.changeset(%WordRelation{}, attrs)
    end

    test "rejects self-link for synonyms" do
      word = word_fixture()

      attrs = %{
        word_id: word.id,
        relation_type: :synonym,
        related_word_id: word.id
      }

      changeset = WordRelation.changeset(%WordRelation{}, attrs)
      assert "cannot be the same word" in errors_on(changeset).related_word_id
    end

    test "rejects self-link for antonyms" do
      word = word_fixture()

      attrs = %{
        word_id: word.id,
        relation_type: :antonym,
        related_word_id: word.id
      }

      changeset = WordRelation.changeset(%WordRelation{}, attrs)
      assert "cannot be the same word" in errors_on(changeset).related_word_id
    end

    test "rejects self-link for linked expressions" do
      word = word_fixture()

      attrs = %{
        word_id: word.id,
        relation_type: :expression,
        related_word_id: word.id
      }

      changeset = WordRelation.changeset(%WordRelation{}, attrs)
      assert "cannot be the same word" in errors_on(changeset).related_word_id
    end
  end

  describe "word relation CRUD" do
    test "create_word_relation/1 creates a relation" do
      word = word_fixture()
      related = word_fixture()

      attrs = %{
        word_id: word.id,
        relation_type: :synonym,
        related_word_id: related.id,
        status: :approved
      }

      assert {:ok, relation} = Content.create_word_relation(attrs)
      assert relation.word_id == word.id
      assert relation.related_word_id == related.id
      assert relation.relation_type == :synonym
      assert relation.status == :approved
    end

    test "list_word_relations_for_word/1 returns approved relations grouped by type" do
      word = word_fixture()
      related = word_fixture()

      {:ok, _} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :approved
        })

      relations = Content.list_word_relations_for_word(word.id)
      related_text = related.text
      assert [%{linked: true, text: ^related_text}] = relations.synonym
      assert Map.get(relations, :antonym, []) == []
    end

    test "list_word_relations_for_word/1 skips pending and rejected relations" do
      word = word_fixture()
      related = word_fixture()

      {:ok, _} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :pending
        })

      assert Content.list_word_relations_for_word(word.id) == %{}
    end

    test "approve_word_relation/1 approves and creates inverse synonym" do
      word = word_fixture()
      related = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :pending
        })

      assert {:ok, approved} = Content.approve_word_relation(relation)
      assert approved.status == :approved

      # Inverse relation exists
      inverse =
        Content.list_word_relations_for_word(related.id)
        |> Map.get(:synonym, [])
        |> List.first()

      assert inverse
      assert inverse.id == word.id
    end

    test "approve_word_relation/1 approves and creates inverse antonym" do
      word = word_fixture()
      related = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :antonym,
          related_word_id: related.id,
          status: :pending
        })

      assert {:ok, _} = Content.approve_word_relation(relation)

      inverse =
        Content.list_word_relations_for_word(related.id)
        |> Map.get(:antonym, [])
        |> List.first()

      assert inverse
      assert inverse.id == word.id
    end

    test "approve_word_relation/1 does not create inverse for expressions" do
      word = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :expression,
          expression_text: "テスト表現",
          status: :pending
        })

      assert {:ok, _} = Content.approve_word_relation(relation)

      assert Content.list_word_relations_for_word(word.id).expression == [
               %{text: "テスト表現", linked: false}
             ]
    end

    test "approve_word_relation/1 is idempotent for inverse creation" do
      word = word_fixture()
      related = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :pending
        })

      assert {:ok, _} = Content.approve_word_relation(relation)
      assert {:ok, _} = Content.approve_word_relation(relation)

      assert length(Content.list_word_relations_for_word(related.id).synonym) == 1
    end

    test "reject_word_relation/1 deletes the relation" do
      word = word_fixture()
      related = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :pending
        })

      assert {:ok, _} = Content.reject_word_relation(relation)
      assert Content.list_pending_word_relations_for_word(word.id) == []
    end

    test "delete_word_relation/1 deletes the relation" do
      word = word_fixture()
      related = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :approved
        })

      assert {:ok, _} = Content.delete_word_relation(relation)
      assert Content.list_word_relations_for_word(word.id) == %{}
    end

    test "delete_word_relation/1 also deletes the inverse synonym relation" do
      word = word_fixture()
      related = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :pending
        })

      assert {:ok, approved} = Content.approve_word_relation(relation)
      assert Content.list_word_relations_for_word(related.id).synonym != []

      assert {:ok, _} = Content.delete_word_relation(approved)
      assert Content.list_word_relations_for_word(word.id) == %{}
      assert Content.list_word_relations_for_word(related.id) == %{}
    end

    test "delete_word_relation/1 also deletes the inverse antonym relation" do
      word = word_fixture()
      related = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :antonym,
          related_word_id: related.id,
          status: :pending
        })

      assert {:ok, approved} = Content.approve_word_relation(relation)
      assert {:ok, _} = Content.delete_word_relation(approved)
      assert Content.list_word_relations_for_word(related.id) == %{}
    end

    test "delete_word_relation/1 does not try to delete inverse for expressions" do
      word = word_fixture()

      {:ok, relation} =
        Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :expression,
          expression_text: "テスト表現",
          status: :approved
        })

      assert {:ok, _} = Content.delete_word_relation(relation)
      assert Content.list_word_relations_for_word(word.id) == %{}
    end

    test "delete_word_relation/1 can delete an existing self-link" do
      word = word_fixture()

      relation =
        Repo.insert!(%WordRelation{
          word_id: word.id,
          related_word_id: word.id,
          relation_type: :synonym,
          status: :approved
        })

      assert {:ok, _} = Content.delete_word_relation(relation)
      assert Content.list_word_relations_for_word(word.id) == %{}
    end

    test "find_word_for_relation/1 finds a word by text" do
      word = word_fixture(text: "日本")
      assert found = Content.find_word_for_relation("日本")
      assert found.id == word.id
      assert found.text == "日本"
      assert is_map(found)
    end

    test "find_word_for_relation/1 returns nil for unknown text" do
      assert Content.find_word_for_relation("存在しない") == nil
    end
  end
end
