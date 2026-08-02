defmodule Medoru.Learning.WordBooksTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Accounts
  alias Medoru.Learning.{WordBook, WordBookWord, WordBooks, WordSets}

  describe "list_user_word_books/2" do
    setup do
      user = user_fixture()

      book1 = word_book_fixture(%{user_id: user.id, title: "Japanese Verbs"})
      book2 = word_book_fixture(%{user_id: user.id, title: "Numbers"})

      book3 =
        word_book_fixture(%{
          user_id: user.id,
          title: "Grammar",
          description: "particles and counters"
        })

      %{user: user, books: [book1, book2, book3]}
    end

    test "returns all of the user's word books", %{user: user, books: books} do
      %{word_books: result, total_count: total_count} = WordBooks.list_user_word_books(user.id)

      assert total_count == 3
      assert Enum.map(result, & &1.id) |> Enum.sort() == Enum.map(books, & &1.id) |> Enum.sort()
    end

    test "does not return other users' word books", %{user: user} do
      other_user = user_fixture(%{email: "other@example.com"})
      word_book_fixture(%{user_id: other_user.id, title: "Other Book"})

      %{word_books: result, total_count: total_count} = WordBooks.list_user_word_books(user.id)

      assert total_count == 3
      refute Enum.any?(result, &(&1.title == "Other Book"))
    end

    test "searches by title", %{user: user} do
      %{word_books: result} = WordBooks.list_user_word_books(user.id, search: "Verbs")

      assert length(result) == 1
      assert hd(result).title == "Japanese Verbs"
    end

    test "searches by description", %{user: user} do
      %{word_books: result} = WordBooks.list_user_word_books(user.id, search: "particles")

      assert length(result) == 1
      assert hd(result).title == "Grammar"
    end

    test "sorts by title", %{user: user} do
      %{word_books: result} =
        WordBooks.list_user_word_books(user.id, sort_by: :title, sort_order: :asc)

      assert Enum.map(result, & &1.title) == ["Grammar", "Japanese Verbs", "Numbers"]
    end

    test "paginates results", %{user: user} do
      %{word_books: page1, total_pages: total_pages} =
        WordBooks.list_user_word_books(user.id, page: 1, per_page: 2)

      assert length(page1) == 2
      assert total_pages == 2

      %{word_books: page2} = WordBooks.list_user_word_books(user.id, page: 2, per_page: 2)
      assert length(page2) == 1
    end
  end

  describe "get_word_book!/1" do
    test "returns the book with preloaded words" do
      user = user_fixture()
      word = word_fixture()
      book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      fetched = WordBooks.get_word_book!(book.id)

      assert fetched.id == book.id
      assert [%WordBookWord{word: loaded_word}] = fetched.word_book_words
      assert loaded_word.id == word.id
    end

    test "raises when the book does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        WordBooks.get_word_book!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_user_word_book/2" do
    test "returns the book for its owner" do
      user = user_fixture()
      book = word_book_fixture(%{user_id: user.id})

      assert %WordBook{id: id} = WordBooks.get_user_word_book(user.id, book.id)
      assert id == book.id
    end

    test "returns nil for another user" do
      user = user_fixture()
      other_user = user_fixture(%{email: "other@example.com"})
      book = word_book_fixture(%{user_id: user.id})

      assert WordBooks.get_user_word_book(other_user.id, book.id) == nil
    end
  end

  describe "get_word_book_with_words_paginated/2" do
    test "returns words ordered by position with pagination info" do
      user = user_fixture()
      words = for _ <- 1..3, do: word_fixture()
      book = word_book_with_words_fixture(%{user_id: user.id}, words)

      {fetched_book, page} = WordBooks.get_word_book_with_words_paginated(book.id, per_page: 2)

      assert fetched_book.id == book.id
      assert page.total_count == 3
      assert page.total_pages == 2
      assert Enum.map(page.words, & &1.id) == Enum.map(Enum.take(words, 2), & &1.id)
    end
  end

  describe "CRUD" do
    test "create_word_book/1 with valid data" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        title: "My Book",
        description: "Some cards",
        theme: "forest",
        card_shape: "square",
        cards_per_page: 9,
        front_background: "grid",
        back_background: "dots",
        cover_image: "fuji",
        front_config: %{"show_reading" => true, "meanings" => ["en"]},
        back_config: %{"example_count" => 2}
      }

      assert {:ok, %WordBook{} = book} = WordBooks.create_word_book(attrs)
      assert book.title == "My Book"
      assert book.card_shape == "square"
      assert book.cards_per_page == 9
      assert book.word_count == 0
    end

    test "create_word_book/1 requires a title" do
      user = user_fixture()

      assert {:error, changeset} = WordBooks.create_word_book(%{user_id: user.id})
      assert %{title: _} = errors_on(changeset)
    end

    test "update_word_book/2 with valid data" do
      user = user_fixture()
      book = word_book_fixture(%{user_id: user.id})

      assert {:ok, updated} = WordBooks.update_word_book(book, %{title: "New Title"})
      assert updated.title == "New Title"
    end

    test "update_word_book/2 with invalid data" do
      user = user_fixture()
      book = word_book_fixture(%{user_id: user.id})

      assert {:error, changeset} = WordBooks.update_word_book(book, %{title: nil})
      assert %{title: _} = errors_on(changeset)
    end

    test "delete_word_book/1 removes the book and its words" do
      user = user_fixture()
      word = word_fixture()
      book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      assert {:ok, _} = WordBooks.delete_word_book(book)

      assert_raise Ecto.NoResultsError, fn -> WordBooks.get_word_book!(book.id) end
      assert Repo.aggregate(WordBookWord, :count, :id) == 0
    end

    test "change_word_book/2 returns a changeset" do
      user = user_fixture()
      book = word_book_fixture(%{user_id: user.id})

      assert %Ecto.Changeset{} = WordBooks.change_word_book(book, %{title: "Changed"})
    end
  end

  describe "changeset validation" do
    setup do
      %{user: user_fixture()}
    end

    test "rejects unknown side config keys", %{user: user} do
      attrs = %{
        user_id: user.id,
        title: "Book",
        front_config: %{"show_kanji" => true}
      }

      assert {:error, changeset} = WordBooks.create_word_book(attrs)
      assert %{front_config: [msg]} = errors_on(changeset)
      assert msg =~ "unknown key"
    end

    test "rejects invalid locales in meanings", %{user: user} do
      attrs = %{
        user_id: user.id,
        title: "Book",
        back_config: %{"meanings" => ["en", "de"]}
      }

      assert {:error, changeset} = WordBooks.create_word_book(attrs)
      assert %{back_config: [msg]} = errors_on(changeset)
      assert msg =~ "locales"
    end

    test "rejects invalid example_count", %{user: user} do
      attrs = %{
        user_id: user.id,
        title: "Book",
        back_config: %{"example_count" => 5}
      }

      assert {:error, changeset} = WordBooks.create_word_book(attrs)
      assert %{back_config: [msg]} = errors_on(changeset)
      assert msg =~ "example_count"
    end

    test "accepts a fully valid side config", %{user: user} do
      config = %{
        "show_image" => true,
        "show_sound" => false,
        "show_reading" => true,
        "show_level" => false,
        "show_frequency" => true,
        "meanings" => ["en", "bg", "ja"],
        "examples" => ["en"],
        "example_count" => "all"
      }

      attrs = %{user_id: user.id, title: "Book", front_config: config, back_config: config}

      assert {:ok, %WordBook{}} = WordBooks.create_word_book(attrs)
    end

    test "validates card_shape and cards_per_page inclusion", %{user: user} do
      attrs = %{user_id: user.id, title: "Book", card_shape: "circle", cards_per_page: 5}

      assert {:error, changeset} = WordBooks.create_word_book(attrs)
      errors = errors_on(changeset)
      assert %{card_shape: _, cards_per_page: _} = errors
    end

    test "validates theme against allowed themes, allowing nil and empty", %{user: user} do
      assert {:error, changeset} =
               WordBooks.create_word_book(%{user_id: user.id, title: "Book", theme: "neon"})

      assert %{theme: _} = errors_on(changeset)

      theme = hd(Medoru.Classrooms.Classroom.allowed_themes())

      assert {:ok, _} =
               WordBooks.create_word_book(%{user_id: user.id, title: "Book", theme: theme})

      assert {:ok, _} = WordBooks.create_word_book(%{user_id: user.id, title: "Book", theme: ""})
      assert {:ok, _} = WordBooks.create_word_book(%{user_id: user.id, title: "Book", theme: nil})
    end

    test "validates word_count bounds", %{user: user} do
      assert {:error, changeset} =
               WordBooks.create_word_book(%{user_id: user.id, title: "Book", word_count: 101})

      assert %{word_count: _} = errors_on(changeset)
    end
  end

  describe "add_word_to_book/2" do
    test "adds a word, sets position, and updates word_count" do
      user = user_fixture()
      book = word_book_fixture(%{user_id: user.id})
      word1 = word_fixture()
      word2 = word_fixture()

      assert {:ok, book} = WordBooks.add_word_to_book(book, word1.id)
      assert book.word_count == 1

      assert {:ok, book} = WordBooks.add_word_to_book(book, word2.id)
      assert book.word_count == 2

      positions =
        Repo.all(
          from wbw in WordBookWord,
            where: wbw.word_book_id == ^book.id,
            order_by: [asc: wbw.position],
            select: {wbw.word_id, wbw.position}
        )

      assert positions == [{word1.id, 1}, {word2.id, 2}]
    end

    test "returns error when max words reached" do
      user = user_fixture()
      book = word_book_fixture(%{user_id: user.id})
      {:ok, book} = WordBooks.update_word_book(book, %{word_count: WordBook.max_words()})

      word = word_fixture()

      assert {:error, :max_words_reached} = WordBooks.add_word_to_book(book, word.id)
    end

    test "rejects duplicate words" do
      user = user_fixture()
      word = word_fixture()
      book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      assert {:error, changeset} =
               %WordBookWord{}
               |> WordBookWord.changeset(%{
                 word_book_id: book.id,
                 word_id: word.id,
                 position: 5
               })
               |> Repo.insert()

      assert %{word_book_id: _} = errors_on(changeset)
    end
  end

  describe "remove_word_from_book/2" do
    test "removes the word, updates count, and reorders remaining words" do
      user = user_fixture()
      [word1, word2, word3] = for _ <- 1..3, do: word_fixture()
      book = word_book_with_words_fixture(%{user_id: user.id}, [word1, word2, word3])

      assert {:ok, updated} = WordBooks.remove_word_from_book(book, word1.id)
      assert updated.word_count == 2

      positions =
        Repo.all(
          from wbw in WordBookWord,
            where: wbw.word_book_id == ^book.id,
            order_by: [asc: wbw.position],
            select: {wbw.word_id, wbw.position}
        )

      assert positions == [{word2.id, 0}, {word3.id, 1}]
    end

    test "is a no-op for words not in the book" do
      user = user_fixture()
      word = word_fixture()
      other_word = word_fixture()
      book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      assert {:ok, unchanged} = WordBooks.remove_word_from_book(book, other_word.id)
      assert unchanged.word_count == 1
    end
  end

  describe "reorder_words/2" do
    test "reorders words by the given id list" do
      user = user_fixture()
      [word1, word2, word3] = for _ <- 1..3, do: word_fixture()
      book = word_book_with_words_fixture(%{user_id: user.id}, [word1, word2, word3])

      assert {:ok, _} = WordBooks.reorder_words(book, [word3.id, word1.id, word2.id])

      positions =
        Repo.all(
          from wbw in WordBookWord,
            where: wbw.word_book_id == ^book.id,
            order_by: [asc: wbw.position],
            select: {wbw.word_id, wbw.position}
        )

      assert positions == [{word3.id, 0}, {word1.id, 1}, {word2.id, 2}]
    end
  end

  describe "list_book_ids_for_word/2" do
    test "returns ids of the user's books containing the word" do
      user = user_fixture()
      word = word_fixture()

      book1 = word_book_with_words_fixture(%{user_id: user.id}, [word])
      _book2 = word_book_fixture(%{user_id: user.id})

      assert WordBooks.list_book_ids_for_word(user.id, word.id) == [book1.id]
    end

    test "does not return other users' books" do
      user = user_fixture()
      other_user = user_fixture(%{email: "other@example.com"})
      word = word_fixture()

      word_book_with_words_fixture(%{user_id: other_user.id}, [word])

      assert WordBooks.list_book_ids_for_word(user.id, word.id) == []
    end
  end

  describe "create_word_book_from_word_set/2" do
    test "copies title, description, and words in position order" do
      user = user_fixture()
      word_set = word_set_fixture(%{user_id: user.id, name: "Set Title", description: "Set Desc"})
      [word1, word2] = for _ <- 1..2, do: word_fixture()

      {:ok, word_set} = WordSets.add_word_to_set(word_set, word1.id)
      {:ok, _word_set} = WordSets.add_word_to_set(word_set, word2.id)

      assert {:ok, book} = WordBooks.create_word_book_from_word_set(user.id, word_set.id)

      assert book.title == "Set Title"
      assert book.description == "Set Desc"
      assert book.user_id == user.id
      assert book.word_count == 2

      words =
        Repo.all(
          from wbw in WordBookWord,
            where: wbw.word_book_id == ^book.id,
            order_by: [asc: wbw.position],
            select: wbw.word_id
        )

      assert words == [word1.id, word2.id]
    end

    test "returns error for an empty word set" do
      user = user_fixture()
      word_set = word_set_fixture(%{user_id: user.id})

      assert {:error, :no_words} = WordBooks.create_word_book_from_word_set(user.id, word_set.id)
    end
  end

  describe "split_examples/1" do
    test "returns an empty list for nil and blank strings" do
      assert WordBooks.split_examples(nil) == []
      assert WordBooks.split_examples("") == []
      assert WordBooks.split_examples("  /  ") == []
    end

    test "returns a single example" do
      assert WordBooks.split_examples("one example") == ["one example"]
    end

    test "splits on slashes and trims parts" do
      assert WordBooks.split_examples("a / b / c") == ["a", "b", "c"]
    end
  end

  describe "default_side_config/1" do
    test "defaults to English for users without a profile" do
      user = user_fixture()

      %{front: front, back: back} = WordBooks.default_side_config(user)

      assert front["show_reading"] == true
      assert front["meanings"] == ["en"]
      assert front["examples"] == ["en"]
      assert back["show_reading"] == true
      assert back["meanings"] == ["en"]
      assert back["example_count"] == 1
    end

    test "uses the profile's meaning locale flags" do
      user = user_fixture_with_registration()

      {:ok, _profile} =
        Accounts.update_profile(user.profile, %{
          show_english_meanings: true,
          show_bulgarian_meanings: true
        })

      user = Accounts.get_user_with_profile(user.id)

      %{front: front, back: back} = WordBooks.default_side_config(user)

      assert front["meanings"] == ["en", "bg"]
      assert front["examples"] == ["en", "bg"]
      assert back["meanings"] == ["en", "bg"]
    end

    test "handles an unloaded profile association" do
      user = user_fixture_with_registration()
      {:ok, _} = Accounts.update_profile(user.profile, %{show_japanese_meanings: true})

      # Fresh user fetch without profile preload
      user = Accounts.get_user!(user.id)

      %{front: front} = WordBooks.default_side_config(user)
      assert front["meanings"] == ["ja"]
    end
  end

  describe "background_options/0 and cover_options/0" do
    test "returns {key, label, path} tuples" do
      backgrounds = WordBooks.background_options()
      assert length(backgrounds) == 10
      assert {"plain", "Plain", "/images/word_book/backgrounds/plain.svg"} in backgrounds
      assert {"seigaiha", "Seigaiha", "/images/word_book/backgrounds/seigaiha.svg"} in backgrounds

      covers = WordBooks.cover_options()
      assert length(covers) == 10
      assert {"fuji", "Fuji", "/images/word_book/covers/fuji.svg"} in covers

      for {key, label, path} <- backgrounds ++ covers do
        assert is_binary(key) and is_binary(label) and is_binary(path)
      end
    end

    test "cover_background_options/0 prefixes keys and background_path/1 resolves both kinds" do
      cover_backgrounds = WordBooks.cover_background_options()
      assert length(cover_backgrounds) == 10
      assert {"cover:fuji", "Fuji", "/images/word_book/covers/fuji.svg"} in cover_backgrounds

      assert WordBooks.background_path("seigaiha") == "/images/word_book/backgrounds/seigaiha.svg"
      assert WordBooks.background_path("cover:fuji") == "/images/word_book/covers/fuji.svg"
      assert WordBooks.background_path("cover:sakura") == "/images/word_book/covers/sakura.svg"
      assert WordBooks.background_path("sakura") == "/images/word_book/backgrounds/sakura.svg"
      assert WordBooks.background_path(nil) == nil
      assert WordBooks.background_path("") == nil
      assert WordBooks.background_path("nope") == nil
    end
  end
end
