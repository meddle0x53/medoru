defmodule Medoru.AI.ChatAssistant do
  @moduledoc """
  AI writing assistant for chat conversations.

  Translates and reshapes the user's input into a natural message in the target
  language by calling the OpenAI API. The assistant is triggered from chat with
  `/ai <prompt>` when the chat dictionary is enabled.

  The assistant receives:
  - The user's prompt (the idea or text they want to send).
  - Up to 20 recent messages for conversation context, labeled with sender names.
  - Relation context (description, relationship type, address style, nicknames)
    for the intended recipient(s):
      * 1:1 chats: always the other participant.
      * group/classroom chats: the user(s) referenced via slash aliases (`/1`,
        `/2`, `/t`, etc.). If no alias is used, the target is the whole group.

  The response language is chosen from the user's `learning_language`:
  - `english` -> response in English.
  - `bulgarian` -> response in Bulgarian.
  - anything else (including `japanese`) -> response in Japanese.

  The explanation is always returned in the current Gettext locale.
  """

  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Chat
  alias Medoru.Dictionaries
  alias Medoru.Social

  @openai_chat_url "https://api.openai.com/v1/chat/completions"

  @alias_pattern ~r/(?:^|\s)\/(\d+|t)(?:@(\d+))?(?=\s|$|[.,!?;])/

  @doc """
  Generates an AI-translated/reshaped message for a chat prompt.

  ## Options

    * `:context` - A list of recent messages. Each item may contain:
        * `"sender_id"` - the message sender's user id.
        * `"role"` - `"user"` for the current user, `"other"` for anyone else.
        * `"name"` - optional display name to use in the prompt.
        * `"text"` - the message text.
      If omitted, server-side conversation history is fetched for classroom chats.
    * `:model` - OpenAI model to use. Defaults to the configured model or "gpt-4o-mini".
    * `:req_opts` - Extra options passed to `Req.post` (useful for testing).

  ## Returns

    * `{:ok, %{response: String.t(), explanation: String.t()}}`
    * `{:error, String.t()}`
  """
  def generate_response(user, conversation, prompt, opts \\ []) do
    api_key = api_key()

    if is_nil(api_key) or api_key == "" do
      {:error, gettext("OpenAI API key is not configured.")}
    else
      model = Keyword.get(opts, :model, default_model())
      req_opts = Keyword.get(opts, :req_opts, [])
      context = build_context(user, conversation, opts)
      targets = extract_targets(user, conversation, prompt)

      system_prompt = build_system_prompt(user, conversation, context, targets)
      user_prompt = String.trim(prompt)

      call_openai(system_prompt, user_prompt, model, api_key, req_opts)
    end
  end

  @doc """
  Returns the JSON schema the assistant is expected to produce.
  """
  def response_schema do
    %{
      "response" => "string",
      "explanation" => "string"
    }
  end

  defp build_context(_user, conversation, opts) do
    case Keyword.get(opts, :context) do
      context when is_list(context) and context != [] ->
        context

      _ ->
        if conversation.classroom_id do
          conversation.id
          |> Chat.list_messages(limit: 20)
          |> Enum.map(fn message ->
            %{
              "sender_id" => message.sender_id,
              "text" => message.content || ""
            }
          end)
        else
          []
        end
    end
  end

  defp extract_targets(user, conversation, prompt) do
    cond do
      one_on_one?(conversation) ->
        other = Enum.find(conversation.participants, &(&1.user_id != user.id))
        if other, do: [target_info(user, other)], else: []

      true ->
        aliases = extract_mentioned_aliases(prompt, user, conversation)
        if aliases != [], do: aliases, else: []
    end
  end

  defp one_on_one?(conversation) do
    !conversation.is_group && is_nil(conversation.classroom_id)
  end

  defp target_info(user, participant) do
    relation = Social.get_relation(user.id, participant.user_id)

    %{
      ref: nil,
      nickname_index: nil,
      resolved_name: name_for_participant(participant, relation),
      gender: participant_gender(participant),
      relationship_type: relation && relation.relationship_type,
      address_style: relation && relation.address_style,
      description: relation && relation.description,
      nicknames: (relation && relation.nicknames) || []
    }
  end

  defp extract_mentioned_aliases(prompt, user, conversation) do
    aliases = Dictionaries.build_user_aliases(user.id, conversation)

    @alias_pattern
    |> Regex.scan(prompt)
    |> Enum.map(fn match ->
      [_full, ref | rest] = match
      nickname_index = List.first(rest)

      resolved =
        case ref do
          "t" ->
            Dictionaries.resolve_alias(
              user.id,
              conversation,
              "t",
              parse_nickname_index(nickname_index)
            )

          "0" ->
            Dictionaries.resolve_alias(user.id, conversation, 0, nil)

          _ ->
            Dictionaries.resolve_alias(
              user.id,
              conversation,
              String.to_integer(ref),
              parse_nickname_index(nickname_index)
            )
        end

      target_user_id = find_user_id_for_ref(aliases, ref, conversation)
      relation = if target_user_id, do: Social.get_relation(user.id, target_user_id)
      target_participant = Enum.find(conversation.participants, &(&1.user_id == target_user_id))

      %{
        ref: ref,
        nickname_index: nickname_index,
        resolved_name: resolved,
        gender: participant_gender(target_participant),
        relationship_type: relation && relation.relationship_type,
        address_style: relation && relation.address_style,
        description: relation && relation.description,
        nicknames: (relation && relation.nicknames) || []
      }
    end)
    |> Enum.uniq_by(&{&1.ref, &1.nickname_index})
  end

  defp parse_nickname_index(nil), do: nil
  defp parse_nickname_index(""), do: nil
  defp parse_nickname_index(index), do: String.to_integer(index)

  defp find_user_id_for_ref(_aliases, "0", _conversation), do: nil

  defp find_user_id_for_ref(_aliases, "t", conversation) do
    if conversation.classroom_id do
      conversation.classroom.teacher_id
    end
  end

  defp find_user_id_for_ref(aliases, ref, _conversation) do
    case Integer.parse(ref) do
      {index, _} ->
        alias_map = Enum.find(aliases, &(&1.ref_index == index))
        alias_map && alias_map.user_id

      :error ->
        nil
    end
  end

  defp build_system_prompt(user, conversation, context, targets) do
    response_language = response_language(user.learning_language)
    explanation_language = explanation_language()
    sender_gender = current_user_gender(user)

    context_section = format_context_section(user, conversation, context)

    target_section = format_target_section(conversation, targets)

    target_instruction =
      cond do
        one_on_one?(conversation) ->
          "The message should be addressed to the other participant in this 1:1 chat."

        targets == [] ->
          "The message should be addressed to the whole group/classroom."

        length(targets) == 1 ->
          "The message should be addressed only to the single user referenced in the prompt. Do not address the whole group or classroom."

        true ->
          "The message should be addressed only to the users referenced in the prompt. Do not address the whole group or classroom."
      end

    """
    You are a helpful assistant for a Japanese language learning chat application called Medoru.

    The user will provide a message or idea they want to send in the chat. Your job is to:
    1. Translate and reshape their input into a natural, context-aware message in #{response_language}.
    2. Provide an explanation and translation of that message in #{explanation_language}.

    The generated message should sound like something the user would send, not a reply to the user's prompt. Use the conversation context and the target user context below to choose the right tone, formality, and phrasing.

    Response language: #{response_language}
    Explanation language: #{explanation_language}#{if sender_gender, do: "\nSender gender: #{sender_gender}", else: ""}

    #{target_instruction}

    #{context_section}

    #{target_section}

    Return ONLY valid JSON with exactly these fields:
    - "response": the translated/reshaped message in #{response_language}
    - "explanation": explanation, translation, and any useful notes in #{explanation_language}
    """
    |> String.trim()
  end

  defp format_context_section(_user, _conversation, []) do
    "No recent conversation context is available."
  end

  defp format_context_section(user, conversation, context) do
    participants_by_id = Map.new(conversation.participants, &{to_string(&1.user_id), &1})

    relations_by_id =
      for participant <- conversation.participants,
          participant.user_id != user.id,
          into: %{} do
        {participant.user_id, Social.get_relation(user.id, participant.user_id)}
      end

    other_participants = Enum.reject(conversation.participants, &(&1.user_id == user.id))

    messages =
      Enum.map(context, fn item ->
        text = item["text"] || ""

        name =
          context_sender_name(
            user,
            item,
            participants_by_id,
            relations_by_id,
            other_participants
          )

        "#{name}: #{text}"
      end)
      |> Enum.join("\n")

    """
    Recent conversation context:
    #{messages}
    """
  end

  defp context_sender_name(user, item, participants_by_id, relations_by_id, other_participants) do
    cond do
      item["name"] ->
        item["name"]

      sender_id = item["sender_id"] ->
        if sender_id == user.id do
          gettext("Me")
        else
          participant = participants_by_id[to_string(sender_id)]
          name_for_participant(participant, relations_by_id[sender_id])
        end

      item["role"] == "user" ->
        gettext("Me")

      item["role"] == "other" && length(other_participants) == 1 ->
        [participant] = other_participants
        name_for_participant(participant, relations_by_id[participant.user_id])

      true ->
        gettext("Other")
    end
  end

  defp format_target_section(conversation, []) do
    if one_on_one?(conversation) do
      "Target user context is not available."
    else
      "Target: the whole group/classroom."
    end
  end

  defp format_target_section(_conversation, targets) do
    entries =
      Enum.map(targets, fn target ->
        ref_label =
          if target.ref do
            "Reference: /#{target.ref}#{if target.nickname_index, do: "@#{target.nickname_index}", else: ""}"
          else
            nil
          end

        parts =
          [
            ref_label,
            "Resolved name: #{target.resolved_name || gettext("unknown")}",
            if(target.gender, do: "Gender: #{target.gender}", else: nil),
            if(target.relationship_type,
              do: "Relationship: #{target.relationship_type}",
              else: nil
            ),
            if(target.address_style, do: "Address style: #{target.address_style}", else: nil),
            if(target.description, do: "Description: #{target.description}", else: nil),
            if(target.nicknames != [],
              do: "Nicknames: #{Enum.join(target.nicknames, ", ")}",
              else: nil
            )
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.join("\n")

        "- #{parts}"
      end)
      |> Enum.join("\n\n")

    """
    Target user context (use this to match tone and formality):
    #{entries}
    """
  end

  defp name_for_participant(nil, _relation), do: gettext("Unknown")

  defp name_for_participant(participant, relation) do
    relation_nickname = relation && List.first(relation.nicknames)

    cond do
      is_binary(relation_nickname) && relation_nickname != "" ->
        relation_nickname

      user = participant.user ->
        display_name_for_user(user)

      true ->
        gettext("Unknown")
    end
  end

  defp display_name_for_user(%{profile: %{display_name: name}})
       when is_binary(name) and name != "",
       do: name

  defp display_name_for_user(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name_for_user(_), do: gettext("Anonymous")

  defp gender_label(0), do: gettext("Male")
  defp gender_label(1), do: gettext("Female")
  defp gender_label(2), do: gettext("Other")
  defp gender_label(_), do: nil

  defp participant_gender(participant) do
    user =
      if participant do
        participant |> Medoru.Repo.preload([user: :profile], force: true) |> Map.get(:user)
      end

    profile = user && user.profile
    gender_label(profile && profile.gender)
  end

  defp current_user_gender(user) do
    profile =
      if user do
        user |> Medoru.Repo.preload(:profile, force: true) |> Map.get(:profile)
      else
        nil
      end

    gender_label(profile && profile.gender)
  end

  defp response_language("english"), do: "English"
  defp response_language("bulgarian"), do: "Bulgarian"
  defp response_language(_), do: "Japanese"

  defp explanation_language do
    locale = Gettext.get_locale(MedoruWeb.Gettext) || "en"

    case locale do
      "bg" -> "Bulgarian"
      "ja" -> "Japanese"
      _ -> "English"
    end
  end

  defp call_openai(system_prompt, user_prompt, model, api_key, req_opts) do
    body = %{
      model: model,
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ],
      response_format: %{type: "json_object"},
      temperature: 0.7
    }

    opts =
      [
        headers: [{"authorization", "Bearer #{api_key}"}],
        json: body,
        receive_timeout: 60_000
      ] ++ req_opts

    case Req.post(@openai_chat_url, opts) do
      {:ok, %{status: 200, body: response_body}} ->
        parse_response(response_body)

      {:ok, %{status: status, body: response_body}} when is_map(response_body) ->
        error_message =
          get_in(response_body, ["error", "message"]) || "OpenAI API returned status #{status}"

        {:error, error_message}

      {:ok, %{status: status}} ->
        {:error, "OpenAI API returned status #{status}"}

      {:error, exception} ->
        {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  defp parse_response(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    case Jason.decode(content) do
      {:ok, %{} = data} ->
        response = Map.get(data, "response", "")
        explanation = Map.get(data, "explanation", "")

        if is_binary(response) and is_binary(explanation) do
          {:ok, %{response: response, explanation: explanation}}
        else
          {:error, "OpenAI returned invalid response fields"}
        end

      {:ok, _} ->
        {:error, "OpenAI returned non-object JSON"}

      {:error, decode_error} ->
        {:error, "Failed to parse OpenAI response: #{Exception.message(decode_error)}"}
    end
  end

  defp parse_response(_) do
    {:error, "Unexpected response format from OpenAI API"}
  end

  defp default_model do
    Application.get_env(:medoru, :openai_model, "gpt-4o-mini")
  end

  defp api_key do
    Application.get_env(:medoru, :openai_api_key)
  end
end
