defmodule Medoru.DictionariesTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures

  alias Medoru.Chat
  alias Medoru.Dictionaries
  alias Medoru.Dictionaries.{ChatDictionary, DictionaryEntry}
  alias Medoru.Social

  defp user(attrs \\ %{}) do
    user_fixture_with_registration(attrs)
  end

  defp set_display_name(user, name) do
    {:ok, profile} = Medoru.Accounts.update_profile(user.profile, %{display_name: name})
    %{user | profile: profile}
  end

  defp conversation(user_a, user_b) do
    {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)
    conv
  end

  describe "dictionaries" do
    test "get_or_create_main_dictionary/1 creates the main dictionary once" do
      user = user()

      dict1 = Dictionaries.get_or_create_main_dictionary(user.id)
      dict2 = Dictionaries.get_or_create_main_dictionary(user.id)

      assert %ChatDictionary{conversation_id: nil, enabled: true} = dict1
      assert dict1.id == dict2.id
    end

    test "get_or_create_chat_dictionary/2 creates a per-chat dictionary" do
      user_a = user()
      user_b = user()
      conv = conversation(user_a, user_b)

      dict = Dictionaries.get_or_create_chat_dictionary(user_a.id, conv.id)

      assert %ChatDictionary{} = dict
      assert dict.conversation_id == conv.id
      assert dict.enabled
    end

    test "toggle_enabled/1 flips the enabled flag" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)

      assert {:ok, %ChatDictionary{enabled: false}} = Dictionaries.toggle_enabled(dict)

      assert {:ok, %ChatDictionary{enabled: true}} =
               Dictionaries.toggle_enabled(%{dict | enabled: false})
    end
  end

  describe "entries" do
    test "create_entry/2 and list_entries/1" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)

      assert {:ok, %DictionaryEntry{key: "hello"}} =
               Dictionaries.create_entry(dict, %{"key" => "hello", "value" => "こんにちは"})

      entries = Dictionaries.list_entries(dict.id)
      assert length(entries.entries) == 1
      assert hd(entries.entries).value == "こんにちは"
    end

    test "list_entries/2 filters by category" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)

      Dictionaries.create_entry(dict, %{"key" => "a", "value" => "1", "category" => "Greetings"})
      Dictionaries.create_entry(dict, %{"key" => "b", "value" => "2"})

      assert length(Dictionaries.list_entries(dict.id, category: "greetings").entries) == 1
      assert length(Dictionaries.list_entries(dict.id, category: "main").entries) == 1
    end

    test "list_entries/2 respects match modes" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)

      Dictionaries.create_entry(dict, %{
        "key" => "good morning",
        "value" => "おはよう",
        "match_mode" => "prefix"
      })

      Dictionaries.create_entry(dict, %{
        "key" => "good night",
        "value" => "おやすみ",
        "match_mode" => "substring"
      })

      assert length(Dictionaries.list_entries(dict.id, search: "good mo").entries) == 1
      assert length(Dictionaries.list_entries(dict.id, search: "night").entries) == 1
      assert length(Dictionaries.list_entries(dict.id, search: "good").entries) == 2
    end

    test "list_entries/2 paginates and reports totals" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)

      for i <- 1..5 do
        Dictionaries.create_entry(dict, %{"key" => "key#{i}", "value" => "v#{i}"})
      end

      page1 = Dictionaries.list_entries(dict.id, page: 1, per_page: 2)
      assert page1.total == 5
      assert page1.total_pages == 3
      assert page1.page == 1
      assert length(page1.entries) == 2

      last_page = Dictionaries.list_entries(dict.id, page: 3, per_page: 2)
      assert last_page.page == 3
      assert length(last_page.entries) == 1

      # out-of-range pages are clamped to the last page
      clamped = Dictionaries.list_entries(dict.id, page: 99, per_page: 2)
      assert clamped.page == 3
      assert length(clamped.entries) == 1
    end

    test "list_entries/2 sorts by key and recency" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)

      Dictionaries.create_entry(dict, %{"key" => "banana", "value" => "1"})
      Dictionaries.create_entry(dict, %{"key" => "Apple", "value" => "2"})
      Dictionaries.create_entry(dict, %{"key" => "cherry", "value" => "3"})

      asc = Dictionaries.list_entries(dict.id, sort: "key_asc")
      assert Enum.map(asc.entries, & &1.key) == ["Apple", "banana", "cherry"]

      desc = Dictionaries.list_entries(dict.id, sort: "key_desc")
      assert Enum.map(desc.entries, & &1.key) == ["cherry", "banana", "Apple"]

      newest_first = Dictionaries.list_entries(dict.id, sort: "newest")
      assert Enum.map(newest_first.entries, & &1.key) == ["cherry", "Apple", "banana"]

      oldest_first = Dictionaries.list_entries(dict.id, sort: "oldest")
      assert Enum.map(oldest_first.entries, & &1.key) == ["banana", "Apple", "cherry"]
    end

    test "list_entries/2 sorts by category with uncategorized first" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)

      Dictionaries.create_entry(dict, %{"key" => "zebra", "value" => "1", "category" => "Animals"})

      Dictionaries.create_entry(dict, %{"key" => "hello", "value" => "2"})
      Dictionaries.create_entry(dict, %{"key" => "ant", "value" => "3", "category" => "Animals"})

      result = Dictionaries.list_entries(dict.id, sort: "category")

      assert Enum.map(result.entries, &{&1.category, &1.key}) == [
               {nil, "hello"},
               {"Animals", "ant"},
               {"Animals", "zebra"}
             ]
    end

    test "list_autocomplete_entries/2 merges chat over main, chat wins on key collision" do
      user_a = user()
      user_b = user()
      conv = conversation(user_a, user_b)

      main = Dictionaries.get_or_create_main_dictionary(user_a.id)
      chat_dict = Dictionaries.get_or_create_chat_dictionary(user_a.id, conv.id)

      Dictionaries.create_entry(main, %{"key" => "hello", "value" => "main hello"})
      Dictionaries.create_entry(main, %{"key" => "only-main", "value" => "from main"})

      Dictionaries.create_entry(chat_dict, %{"key" => "HELLO", "value" => "chat hello"})
      Dictionaries.create_entry(chat_dict, %{"key" => "only-chat", "value" => "from chat"})

      entries = Dictionaries.list_autocomplete_entries(user_a.id, conv.id)
      assert Enum.map(entries, & &1.key) == ["HELLO", "only-chat", "only-main"]
      assert Enum.find(entries, &(&1.key == "HELLO")).value == "chat hello"

      # another chat without overrides still sees the main entries
      conv2 = conversation(user_a, user())
      entries2 = Dictionaries.list_autocomplete_entries(user_a.id, conv2.id)
      assert Enum.map(entries2, & &1.key) == ["hello", "only-main"]
    end

    test "update_entry/2 and delete_entry/1" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)
      {:ok, entry} = Dictionaries.create_entry(dict, %{"key" => "x", "value" => "y"})

      assert {:ok, %DictionaryEntry{value: "z"}} =
               Dictionaries.update_entry(entry, %{"value" => "z"})

      assert {:ok, _} = Dictionaries.delete_entry(entry)
      assert Dictionaries.list_entries(dict.id).entries == []
    end

    test "upsert_entry/4 updates existing entry by key" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)

      Dictionaries.create_entry(dict, %{"key" => "hi", "value" => "old"})
      {:ok, entry} = Dictionaries.upsert_entry(dict.id, "HI", "new", %{"category" => "Greetings"})

      assert entry.value == "new"
      assert entry.category == "Greetings"
      assert length(Dictionaries.list_entries(dict.id).entries) == 1
    end

    test "copy_entry_to_main/2 and copy_entry_to_chat/3" do
      user_a = user()
      user_b = user()
      conv = conversation(user_a, user_b)
      chat_dict = Dictionaries.get_or_create_chat_dictionary(user_a.id, conv.id)

      {:ok, entry} =
        Dictionaries.create_entry(chat_dict, %{"key" => "hello", "value" => "こんにちは"})

      assert {:ok, _} = Dictionaries.copy_entry_to_main(entry, user_a.id)
      main = Dictionaries.get_or_create_main_dictionary(user_a.id)
      assert length(Dictionaries.list_entries(main.id).entries) == 1

      assert {:ok, _} = Dictionaries.send_entry_to_chat(entry, conv.id, user_a.id)
      assert length(Dictionaries.list_entries(chat_dict.id).entries) == 1

      assert Dictionaries.list_entries(chat_dict.id).entries |> hd() |> Map.get(:key) == "hello"
    end
  end

  describe "categories" do
    test "list_categories/2 includes main for uncategorized entries" do
      user = user()
      dict = Dictionaries.get_or_create_main_dictionary(user.id)
      Dictionaries.create_entry(dict, %{"key" => "a", "value" => "1"})
      Dictionaries.create_entry(dict, %{"key" => "b", "value" => "2", "category" => "Playful"})

      categories = Dictionaries.list_categories(user.id, nil)
      assert "main" in categories
      assert "playful" in categories
    end
  end

  describe "user aliases" do
    test "build_user_aliases/2 orders by nickname then display name" do
      user_a = user() |> set_display_name("Alfa")
      user_b = user() |> set_display_name("Zebra")
      user_c = user() |> set_display_name("Apple")

      conv = conversation(user_a, user_b)
      {:ok, _} = Chat.add_participant_plain(conv.id, user_c.id)
      conv = Chat.get_conversation(user_a.id, conv.id)

      Social.upsert_relation(user_a.id, user_c.id, %{"nicknames" => ["Zazu"]})

      aliases = Dictionaries.build_user_aliases(user_a.id, conv)
      assert Enum.map(aliases, & &1.ref_index) == [1, 2]
      # Zazu comes before Zebra alphabetically
      assert Enum.at(aliases, 0).first_nickname == "Zazu"
      assert Enum.at(aliases, 1).first_nickname == "Zebra"
    end

    test "resolve_alias/3 for 1:1 chat" do
      user_a = user() |> set_display_name("Andy")
      user_b = user() |> set_display_name("Bob")
      conv = conversation(user_a, user_b)

      assert Dictionaries.resolve_alias(user_a.id, conv, 1) == "Bob"
      assert Dictionaries.resolve_alias(user_a.id, conv, 0) == "Andy"

      Social.upsert_relation(user_a.id, user_b.id, %{"nicknames" => ["Bobby"]})
      assert Dictionaries.resolve_alias(user_a.id, conv, 1) == "Bobby"
      assert Dictionaries.resolve_alias(user_a.id, conv, 1, 1) == "Bobby"
    end

    test "resolve_alias/3 for classroom chat excludes teacher from numbering" do
      teacher = user() |> set_display_name("Teacher")
      student_a = user() |> set_display_name("Student A")
      student_b = user() |> set_display_name("Student B")

      classroom =
        %{name: "Test Classroom", teacher_id: teacher.id}
        |> Medoru.Classrooms.create_classroom()
        |> elem(1)

      conv = Chat.get_classroom_conversation(classroom.id)
      {:ok, _} = Chat.add_participant_plain(conv.id, student_a.id)
      {:ok, _} = Chat.add_participant_plain(conv.id, student_b.id)
      conv = Chat.get_conversation(student_a.id, conv.id)

      assert Dictionaries.resolve_alias(student_a.id, conv, "t") == "Teacher"
      assert Dictionaries.resolve_alias(student_a.id, conv, 1) == "Student B"
    end
  end
end
