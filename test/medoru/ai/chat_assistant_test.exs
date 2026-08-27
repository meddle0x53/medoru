defmodule Medoru.AI.ChatAssistantTest do
  use Medoru.DataCase, async: false

  alias Medoru.AI.ChatAssistant
  alias Medoru.Chat
  alias Medoru.Social

  import Medoru.AccountsFixtures

  setup do
    original_key = Application.get_env(:medoru, :openai_api_key)
    Application.put_env(:medoru, :openai_api_key, "test-key")

    on_exit(fn ->
      Application.put_env(:medoru, :openai_api_key, original_key)
    end)

    :ok
  end

  describe "generate_response/4" do
    setup do
      user =
        user_fixture_with_registration(%{name: "Current User", learning_language: "japanese"})

      other = user_fixture_with_registration(%{name: "Other User"})
      {:ok, conversation} = Chat.find_or_create_conversation(user.id, other.id)

      Social.upsert_relation(user.id, other.id, %{
        "relationship_type" => "close-friend",
        "address_style" => "casual",
        "description" => "Old friend from school",
        "nicknames" => ["Mari", "Mar"]
      })

      user = user |> Repo.preload(:profile)
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{gender: 0})

      other = other |> Repo.preload(:profile)
      {:ok, _} = Medoru.Accounts.update_profile(other.profile, %{gender: 1})

      %{user: user, other: other, conversation: conversation}
    end

    test "returns reshaped message and explanation on successful API call", %{
      user: user,
      conversation: conversation
    } do
      Req.Test.stub(ChatAssistant, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "gpt-4o-mini"
        assert decoded["response_format"]["type"] == "json_object"
        assert decoded["temperature"] == 0.7

        [system_msg, user_msg] = decoded["messages"]
        assert system_msg["role"] == "system"
        assert user_msg["role"] == "user"
        assert user_msg["content"] == "say hi casually"

        system = system_msg["content"]
        assert system =~ "Response language: Japanese"
        assert system =~ "Translate and reshape"
        assert system =~ "The message should be addressed to the other participant"
        assert system =~ "Target user context"
        assert system =~ "Sender gender: Male"
        assert system =~ "Gender: Female"
        assert system =~ "close-friend"
        assert system =~ "casual"
        assert system =~ "Old friend from school"
        assert system =~ "Mari"
        assert system =~ "Mar"

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "response" => "やあ、元気？",
                    "explanation" => "A casual 'Hey, how are you?' in Japanese."
                  })
              }
            }
          ]
        })
      end)

      assert {:ok,
              %{response: "やあ、元気？", explanation: "A casual 'Hey, how are you?' in Japanese."}} =
               ChatAssistant.generate_response(user, conversation, "say hi casually",
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "uses provided context and response language", %{
      user: user,
      conversation: conversation
    } do
      user = %{user | learning_language: "english"}

      Req.Test.stub(ChatAssistant, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        system = decoded["messages"] |> hd() |> Map.get("content")

        assert system =~ "Response language: English"
        # The other participant's first nickname is used in the context line.
        assert system =~ "Mari: Hello"
        assert system =~ "Recent conversation context"
        assert system =~ "Target user context"

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "response" => "Hi there!",
                    "explanation" => "A friendly English greeting."
                  })
              }
            }
          ]
        })
      end)

      assert {:ok, %{response: "Hi there!", explanation: "A friendly English greeting."}} =
               ChatAssistant.generate_response(user, conversation, "say hi",
                 context: [%{"role" => "other", "text" => "Hello"}],
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "uses sender_id to label context messages", %{
      user: user,
      other: other,
      conversation: conversation
    } do
      Req.Test.stub(ChatAssistant, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        system = decoded["messages"] |> hd() |> Map.get("content")

        assert system =~ "Me: How are you?"
        assert system =~ "Mari: I'm fine"

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "response" => "Reply",
                    "explanation" => "Explanation"
                  })
              }
            }
          ]
        })
      end)

      assert {:ok, _} =
               ChatAssistant.generate_response(user, conversation, "reply",
                 context: [
                   %{"sender_id" => user.id, "text" => "How are you?"},
                   %{"sender_id" => other.id, "text" => "I'm fine"}
                 ],
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "target defaults to the whole group when no alias is used in a group chat", %{
      user: user,
      other: other
    } do
      {:ok, conversation} =
        Chat.create_group_conversation(
          user.id,
          "Test Group",
          [other.id],
          %{
            user.id => Base.encode64("dummy_key_user"),
            other.id => Base.encode64("dummy_key_other")
          }
        )

      Req.Test.stub(ChatAssistant, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        system = decoded["messages"] |> hd() |> Map.get("content")

        assert system =~ "Target: the whole group/classroom."
        refute system =~ "Target user context"

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "response" => "Hi everyone!",
                    "explanation" => "A friendly group greeting."
                  })
              }
            }
          ]
        })
      end)

      assert {:ok, %{response: "Hi everyone!"}} =
               ChatAssistant.generate_response(user, conversation, "greet everyone",
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "uses slash alias target in a group chat", %{user: user, other: other} do
      Social.upsert_relation(user.id, other.id, %{
        "relationship_type" => "friend",
        "address_style" => "informal",
        "description" => "Study buddy",
        "nicknames" => ["Mari", "Mar"]
      })

      {:ok, conversation} =
        Chat.create_group_conversation(
          user.id,
          "Test Group",
          [other.id],
          %{
            user.id => Base.encode64("dummy_key_user"),
            other.id => Base.encode64("dummy_key_other")
          }
        )

      Req.Test.stub(ChatAssistant, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        system = decoded["messages"] |> hd() |> Map.get("content")

        assert system =~ "Reference: /1@2"
        assert system =~ "Resolved name: Mar"
        assert system =~ "Relationship: friend"
        assert system =~ "Address style: informal"
        assert system =~ "Study buddy"

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "response" => "やあ、Mar！",
                    "explanation" => "A casual greeting using the nickname."
                  })
              }
            }
          ]
        })
      end)

      assert {:ok, %{response: "やあ、Mar！"}} =
               ChatAssistant.generate_response(user, conversation, "greet /1@2",
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "returns error when API key is not configured", %{
      user: user,
      conversation: conversation
    } do
      original_key = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, nil)

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original_key)
      end)

      assert {:error, "OpenAI API key is not configured" <> _} =
               ChatAssistant.generate_response(user, conversation, "hello")
    end

    test "returns error on API failure", %{user: user, conversation: conversation} do
      Req.Test.stub(ChatAssistant, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, "Request failed: " <> _} =
               ChatAssistant.generate_response(user, conversation, "hello",
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "returns error on non-200 status", %{user: user, conversation: conversation} do
      Req.Test.stub(ChatAssistant, fn conn ->
        response = %{"error" => %{"message" => "Invalid model"}}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(response))
      end)

      assert {:error, "Invalid model"} =
               ChatAssistant.generate_response(user, conversation, "hello",
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "returns error on malformed JSON response", %{user: user, conversation: conversation} do
      Req.Test.stub(ChatAssistant, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" => "not valid json"
              }
            }
          ]
        })
      end)

      assert {:error, "Failed to parse OpenAI response" <> _} =
               ChatAssistant.generate_response(user, conversation, "hello",
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "returns error on invalid response fields", %{user: user, conversation: conversation} do
      Req.Test.stub(ChatAssistant, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "response" => "ok",
                    "explanation" => ["not a string"]
                  })
              }
            }
          ]
        })
      end)

      assert {:error, "OpenAI returned invalid response fields"} =
               ChatAssistant.generate_response(user, conversation, "hello",
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end

    test "does not crash on blank prompt", %{user: user, conversation: conversation} do
      # The LiveView handler short-circuits empty prompts; the context function
      # will still call the API, so we just verify it does not crash on a blank prompt.
      Req.Test.stub(ChatAssistant, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "response" => "Empty?",
                    "explanation" => "Prompt was empty."
                  })
              }
            }
          ]
        })
      end)

      assert {:ok, %{response: "Empty?"}} =
               ChatAssistant.generate_response(user, conversation, "   ",
                 req_opts: [plug: {Req.Test, ChatAssistant}]
               )
    end
  end
end
