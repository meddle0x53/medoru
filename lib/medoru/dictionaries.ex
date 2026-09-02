defmodule Medoru.Dictionaries do
  @moduledoc """
  Context for chat dictionaries and dictionary entries.

  Each user has:
    * one main dictionary (`conversation_id` is nil)
    * one dictionary per chat they participate in

  Dictionaries are private to the owning user.
  """

  require Logger

  import Ecto.Query, warn: false
  alias Medoru.Repo

  alias Medoru.Dictionaries.{ChatDictionary, DictionaryEntry}
  alias Medoru.Social

  @default_category "main"

  # ============================================================================
  # Dictionaries
  # ============================================================================

  @doc """
  Gets or creates the main dictionary for a user.
  """
  def get_or_create_main_dictionary(user_id) do
    get_or_create_chat_dictionary(user_id, nil)
  end

  @doc """
  Gets or creates a dictionary for a user in a specific chat.
  Pass `conversation_id: nil` for the main dictionary.
  """
  def get_or_create_chat_dictionary(user_id, conversation_id \\ nil) do
    query =
      ChatDictionary
      |> where([d], d.user_id == ^user_id)
      |> then(fn q ->
        if conversation_id do
          where(q, [d], d.conversation_id == ^conversation_id)
        else
          where(q, [d], is_nil(d.conversation_id))
        end
      end)

    case Repo.one(query) do
      nil ->
        %ChatDictionary{}
        |> ChatDictionary.changeset(%{
          user_id: user_id,
          conversation_id: conversation_id,
          enabled: true
        })
        |> Repo.insert!()

      dictionary ->
        dictionary
    end
  end

  @doc """
  Gets a dictionary by id, ensuring it belongs to the user.
  """
  def get_dictionary!(user_id, dictionary_id) do
    ChatDictionary
    |> where([d], d.id == ^dictionary_id and d.user_id == ^user_id)
    |> Repo.one!()
  end

  @doc """
  Toggles the enabled flag on a dictionary.
  """
  def toggle_enabled(%ChatDictionary{} = dictionary) do
    dictionary
    |> ChatDictionary.changeset(%{enabled: not dictionary.enabled})
    |> Repo.update()
  end

  # ============================================================================
  # Entries
  # ============================================================================

  @sort_orders ["key_asc", "key_desc", "newest", "oldest", "category"]
  @default_per_page 50

  @doc """
  Lists entries for a dictionary with filtering, sorting and pagination.

  Options:
    * `:search` - case-insensitive filter on the key (respects each entry's match_mode)
    * `:category` - filter by lower-cased category (use "main" for uncategorized)
    * `:sort` - one of #{inspect(@sort_orders)} (default `"key_asc"`)
    * `:page` - 1-based page number (default 1)
    * `:per_page` - entries per page (default #{@default_per_page})

  Returns `%{entries: [...], total: n, page: p, per_page: n, total_pages: n}`.
  An out-of-range page is clamped to the last non-empty page.
  """
  def list_entries(dictionary_id, opts \\ []) do
    search = opts[:search]
    category = opts[:category]
    sort = if opts[:sort] in @sort_orders, do: opts[:sort], else: "key_asc"
    per_page = max(opts[:per_page] || @default_per_page, 1)

    base =
      DictionaryEntry
      |> where([e], e.dictionary_id == ^dictionary_id)
      |> maybe_query_search(search)
      |> maybe_query_category(category)

    total = Repo.aggregate(base, :count)

    total_pages =
      case total do
        0 -> 1
        _ -> ceil(total / per_page)
      end

    page = opts[:page] || 1
    page = page |> max(1) |> min(total_pages)

    entries =
      base
      |> sort_query(sort)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{entries: entries, total: total, page: page, per_page: per_page, total_pages: total_pages}
  end

  def sort_orders, do: @sort_orders

  @doc """
  Returns the effective entry list for `/d` autocomplete in a chat: the chat
  dictionary merged over the user's main dictionary. On key collision
  (case-insensitive) the chat entry wins.

  Used only for the client-side autocomplete payload; the drawer lists each
  dictionary separately.
  """
  def list_autocomplete_entries(user_id, conversation_id) do
    main = get_or_create_main_dictionary(user_id)
    chat = get_or_create_chat_dictionary(user_id, conversation_id)

    main.id
    |> entries_by_key()
    |> Map.merge(entries_by_key(chat.id))
    |> Map.values()
    |> Enum.sort_by(&String.downcase(&1.key))
  end

  defp entries_by_key(dictionary_id) do
    DictionaryEntry
    |> where([e], e.dictionary_id == ^dictionary_id)
    |> Repo.all()
    |> Map.new(fn e -> {String.downcase(e.key), e} end)
  end

  defp maybe_query_search(query, nil), do: query
  defp maybe_query_search(query, ""), do: query

  defp maybe_query_search(query, search) do
    search = search |> String.trim() |> escape_like() |> String.downcase()

    if search == "" do
      query
    else
      where(
        query,
        [e],
        # respect each entry's match mode: substring entries match anywhere,
        # prefix entries (default) match from the start
        (e.match_mode == "substring" and ilike(e.key, ^"%#{search}%")) or
          (coalesce(e.match_mode, "prefix") != "substring" and ilike(e.key, ^"#{search}%"))
      )
    end
  end

  # LIKE wildcards in user input must be escaped
  defp escape_like(text) do
    String.replace(text, ["\\", "%", "_"], fn ch -> "\\#{ch}" end)
  end

  defp maybe_query_category(query, nil), do: query
  defp maybe_query_category(query, ""), do: query

  defp maybe_query_category(query, category) do
    category = String.downcase(category)

    if category == @default_category do
      where(query, [e], is_nil(e.category) or ilike(e.category, ^"#{escape_like(category)}"))
    else
      where(query, [e], ilike(e.category, ^"#{escape_like(category)}"))
    end
  end

  defp sort_query(query, "key_asc"), do: order_by(query, [e], asc: fragment("lower(?)", e.key))
  defp sort_query(query, "key_desc"), do: order_by(query, [e], desc: fragment("lower(?)", e.key))

  defp sort_query(query, "newest"),
    do: order_by(query, [e], desc: e.inserted_at, desc: e.id)

  defp sort_query(query, "oldest"), do: order_by(query, [e], asc: e.inserted_at, asc: e.id)

  defp sort_query(query, "category") do
    order_by(query, [e],
      asc: fragment("lower(coalesce(?, ''))", e.category),
      asc: fragment("lower(?)", e.key)
    )
  end

  @doc """
  Creates a new dictionary entry.
  """
  def create_entry(%ChatDictionary{} = dictionary, attrs) do
    %DictionaryEntry{}
    |> DictionaryEntry.changeset(Map.put(attrs, "dictionary_id", dictionary.id))
    |> Repo.insert()
  end

  @doc """
  Updates a dictionary entry.
  """
  def update_entry(%DictionaryEntry{} = entry, attrs) do
    entry
    |> DictionaryEntry.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a dictionary entry.
  """
  def delete_entry(%DictionaryEntry{} = entry) do
    Repo.delete(entry)
  end

  @doc """
  Finds an entry by id, scoped to a user-owned dictionary.
  """
  def get_entry!(user_id, entry_id) do
    DictionaryEntry
    |> join(:inner, [e], d in ChatDictionary, on: d.id == e.dictionary_id)
    |> where([e, d], e.id == ^entry_id and d.user_id == ^user_id)
    |> Repo.one!()
  end

  @doc """
  Inserts or updates an entry by key within a dictionary.
  """
  def upsert_entry(dictionary_id, key, value, attrs \\ %{}) do
    normalized_key = String.trim(key)

    existing =
      DictionaryEntry
      |> where([e], e.dictionary_id == ^dictionary_id)
      |> where([e], fragment("lower(?)", e.key) == ^String.downcase(normalized_key))
      |> Repo.one()

    attrs =
      attrs
      |> Map.put("key", normalized_key)
      |> Map.put("value", String.trim(value))
      |> Map.put("dictionary_id", dictionary_id)

    case existing do
      nil ->
        %DictionaryEntry{}
        |> DictionaryEntry.changeset(attrs)
        |> Repo.insert()

      entry ->
        entry
        |> DictionaryEntry.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Copies an entry into the user's main dictionary.
  """
  def copy_entry_to_main(%DictionaryEntry{} = entry, user_id) do
    main = get_or_create_main_dictionary(user_id)

    upsert_entry(main.id, entry.key, entry.value, %{
      "category" => entry.category,
      "match_mode" => entry.match_mode
    })
  end

  @doc """
  Copies an entry into a chat dictionary.
  """
  def copy_entry_to_chat(%DictionaryEntry{} = entry, conversation_id, user_id) do
    dictionary = get_or_create_chat_dictionary(user_id, conversation_id)

    upsert_entry(dictionary.id, entry.key, entry.value, %{
      "category" => entry.category,
      "match_mode" => entry.match_mode
    })
  end

  @doc """
  Sends/copies an entry from the main dictionary into a chat dictionary.
  """
  def send_entry_to_chat(%DictionaryEntry{} = entry, conversation_id, user_id) do
    copy_entry_to_chat(entry, conversation_id, user_id)
  end

  # ============================================================================
  # Categories
  # ============================================================================

  @doc """
  Returns the list of categories for a user's dictionary.
  Always includes "main" if any uncategorized entries exist.
  """
  def list_categories(user_id, conversation_id) do
    dictionary = get_or_create_chat_dictionary(user_id, conversation_id)

    entries =
      DictionaryEntry
      |> where([e], e.dictionary_id == ^dictionary.id)
      |> select([e], e.category)
      |> Repo.all()

    categories =
      entries
      |> Enum.map(fn c -> if is_nil(c), do: @default_category, else: String.downcase(c) end)
      |> Enum.uniq()
      |> Enum.sort()

    if Enum.any?(entries, &is_nil/1) and @default_category not in categories do
      [@default_category | categories]
    else
      categories
    end
  end

  # ============================================================================
  # User aliases for slash shortcuts
  # ============================================================================

  @doc """
  Builds the list of aliases for other participants in a conversation.

  Returns a list of maps suitable for JSON serialization to the client:
    %{
      ref_index: 1,
      user_id: "...",
      display_name: "...",
      first_nickname: "...",
      nicknames: ["..."],
      relationship_type: "...",
      address_style: "...",
      description: "..."
    }

  The current user is excluded. For 1:1 chats this still returns the single
  other participant under `/1`. For group/classroom chats, participants are
  sorted by first nickname (if any) then display name.
  """
  def build_user_aliases(user_id, %{participants: participants} = _conversation) do
    participants
    |> Enum.reject(&(&1.user_id == user_id))
    |> Enum.map(fn participant ->
      relation = Social.get_relation(user_id, participant.user_id)
      display = display_name_for_user(participant.user)
      first = if relation && relation.nicknames != [], do: hd(relation.nicknames), else: display

      %{
        ref_index: nil,
        user_id: participant.user_id,
        display_name: display,
        first_nickname: first,
        nicknames: if(relation, do: relation.nicknames, else: []),
        relationship_type: if(relation, do: relation.relationship_type),
        address_style: if(relation, do: relation.address_style),
        description: if(relation, do: relation.description)
      }
    end)
    |> Enum.sort_by(fn a ->
      {String.downcase(a.first_nickname), String.downcase(a.display_name)}
    end)
    |> Enum.with_index(1)
    |> Enum.map(fn {alias_map, index} -> Map.put(alias_map, :ref_index, index) end)
  end

  @doc """
  Resolves a slash alias reference to the text that should be inserted.

  Supports:
    * ref 0 -> current user display name
    * ref "t" -> classroom teacher (uses nickname if relation exists)
    * ref 1..n -> other participants in alias order
    * nickname_index (1-based) overrides the default name with a stored nickname
  """
  def resolve_alias(user_id, conversation, ref, nickname_index \\ nil)

  def resolve_alias(user_id, _conversation, 0, nil) do
    current_user =
      Medoru.Accounts.User
      |> Medoru.Repo.get!(user_id)
      |> Medoru.Repo.preload(:profile)

    display_name_for_user(current_user)
  end

  def resolve_alias(user_id, conversation, ref, nickname_index)
      when is_integer(ref) and ref > 0 do
    alias_map = find_alias(user_id, conversation, ref)

    if alias_map do
      participant = Enum.find(conversation.participants, &(&1.user_id == alias_map.user_id))
      name_for_participant(user_id, participant, nickname_index)
    else
      nil
    end
  end

  def resolve_alias(user_id, %{classroom_id: classroom_id} = conversation, "t", nickname_index)
      when not is_nil(classroom_id) do
    teacher_id = conversation.classroom.teacher_id
    teacher = Enum.find(conversation.participants, &(&1.user_id == teacher_id))

    if teacher do
      name_for_participant(user_id, teacher, nickname_index)
    else
      nil
    end
  end

  def resolve_alias(_user_id, _conversation, _ref, _nickname_index) do
    nil
  end

  defp find_alias(user_id, %{classroom_id: nil} = conversation, ref) do
    build_user_aliases(user_id, conversation)
    |> Enum.find(&(&1.ref_index == ref))
  end

  defp find_alias(user_id, conversation, ref) do
    # In classroom chats, numbered aliases exclude the teacher.
    teacher_id = conversation.classroom.teacher_id

    aliases =
      build_user_aliases(user_id, conversation)
      |> Enum.reject(&(&1.user_id == teacher_id))
      |> Enum.with_index(1)
      |> Enum.map(fn {a, i} -> Map.put(a, :ref_index, i) end)

    Enum.find(aliases, &(&1.ref_index == ref))
  end

  defp name_for_participant(user_id, participant, nickname_index) do
    relation = Social.get_relation(user_id, participant.user_id)

    chosen_nickname =
      if relation && nickname_index && nickname_index > 0 do
        Enum.at(relation.nicknames, nickname_index - 1)
      else
        nil
      end

    default_nickname =
      if relation && relation.nicknames != [] do
        hd(relation.nicknames)
      else
        nil
      end

    cond do
      chosen_nickname -> chosen_nickname
      nickname_index -> display_name_for_user(participant.user)
      default_nickname -> default_nickname
      true -> display_name_for_user(participant.user)
    end
  end

  defp display_name_for_user(%{profile: %{display_name: name}})
       when is_binary(name) and name != "",
       do: name

  defp display_name_for_user(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name_for_user(_), do: "Anonymous"
end
