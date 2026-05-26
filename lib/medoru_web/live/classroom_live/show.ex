defmodule MedoruWeb.ClassroomLive.Show do
  @moduledoc """
  LiveView for students to view a classroom they're a member of.
  Shows classroom info, rankings, and available lessons/tests.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.Components.Helpers, only: [display_name: 3]

  alias Medoru.Chat
  alias Medoru.Classrooms
  alias Medoru.Games
  alias Medoru.Learning.WordSets

  @chat_message_limit 20

  @skill_level_colors %{
    1 => "bg-success/10 text-success border-success/20",
    2 => "bg-info/10 text-info border-info/20",
    3 => "bg-purple-500/20 text-purple-500 border-purple-500/40",
    4 => "bg-error/10 text-error border-error/20",
    5 => "bg-warning/10 text-warning border-warning/20"
  }

  @skill_level_card_bgs %{
    1 => "bg-success/5 border-success/20 hover:border-success/40",
    2 => "bg-info/5 border-info/20 hover:border-info/40",
    3 => "bg-purple-500/5 border-purple-500/20 hover:border-purple-500/40",
    4 => "bg-error/5 border-error/20 hover:border-error/40",
    5 => "bg-warning/5 border-warning/20 hover:border-warning/40"
  }

  @skill_level_labels %{
    1 => gettext("Beginner"),
    2 => gettext("Elementary"),
    3 => gettext("Intermediate"),
    4 => gettext("Advanced"),
    5 => gettext("Expert")
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    classroom = Classrooms.get_classroom!(id)

    cond do
      classroom.teacher_id == user.id ->
        members = Classrooms.list_classroom_members(id)
        published_tests = Classrooms.list_classroom_tests(id, status: :active)
        user_attempts = Classrooms.list_user_test_attempts(id, user.id)
        published_games = Games.list_classroom_games(id, status: :published)
        conversation = Chat.get_classroom_conversation(id)

        socket =
          socket
          |> assign(:page_title, classroom.name)
          |> assign(:classroom, classroom)
          |> assign(:membership, nil)
          |> assign(:members, members)
          |> assign(:published_tests, published_tests)
          |> assign(:user_attempts, user_attempts)
          |> assign(:published_games, published_games)
          |> assign(:lessons_filter, :all)
          |> assign(:lessons_page, 1)
          |> assign(:lessons_per_page, 10)
          |> assign(:active_tab, "overview")
          |> assign(:copy_lesson_modal_open, false)
          |> assign(:copy_lesson_id, nil)
          |> assign(:copy_lesson_title, nil)
          |> assign(:conversation, conversation)
          |> assign(:chat_messages, [])
          |> assign(:chat_has_more, false)
          |> assign(:chat_typing_users, [])
          |> assign(:reply_to, nil)
          |> assign(:editing_message, nil)

        {:ok, socket}

      true ->
        case Classrooms.get_user_membership(id, user.id) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, gettext("You are not a member of this classroom."))
             |> push_navigate(to: ~p"/classrooms")}

          membership ->
            if membership.status != :approved do
              {:ok,
               socket
               |> put_flash(:error, gettext("Your membership is pending approval."))
               |> push_navigate(to: ~p"/classrooms")}
            else
              members = Classrooms.list_classroom_members(id)
              published_tests = Classrooms.list_classroom_tests(id, status: :active)
              user_attempts = Classrooms.list_user_test_attempts(id, user.id)
              published_games = Games.list_classroom_games(id, status: :published)
              conversation = Chat.get_classroom_conversation(id)

              socket =
                socket
                |> assign(:page_title, classroom.name)
                |> assign(:classroom, classroom)
                |> assign(:membership, membership)
                |> assign(:members, members)
                |> assign(:published_tests, published_tests)
                |> assign(:user_attempts, user_attempts)
                |> assign(:published_games, published_games)
                |> assign(:lessons_filter, :all)
                |> assign(:lessons_page, 1)
                |> assign(:lessons_per_page, 10)
                |> assign(:active_tab, "overview")
                |> assign(:copy_lesson_modal_open, false)
                |> assign(:copy_lesson_id, nil)
                |> assign(:copy_lesson_title, nil)
                |> assign(:conversation, conversation)
                |> assign(:chat_messages, [])
                |> assign(:chat_has_more, false)
                |> assign(:chat_typing_users, [])
                |> assign(:reply_to, nil)
                |> assign(:editing_message, nil)

              {:ok, socket}
            end
        end
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "overview"

    # Load tab-specific data
    socket =
      cond do
        tab == "lessons" ->
          load_lessons_data(socket)

        tab == "games" ->
          load_games_data(socket)

        tab == "chat" ->
          load_chat_data(socket)

        true ->
          socket
      end

    {:noreply, assign(socket, :active_tab, tab)}
  end

  defp load_lessons_data(socket) do
    classroom_id = socket.assigns.classroom.id
    user_id = socket.assigns.current_scope.current_user.id
    filter = socket.assigns.lessons_filter
    page = socket.assigns.lessons_page
    per_page = socket.assigns.lessons_per_page

    result =
      Classrooms.list_classroom_lessons_with_progress(classroom_id, user_id,
        filter: filter,
        page: page,
        per_page: per_page
      )

    socket
    |> assign(:custom_lessons, result.lessons)
    |> assign(:lesson_progress, result.progress)
    |> assign(:lessons_page, result.page)
    |> assign(:lessons_total_pages, result.total_pages)
    |> assign(:lessons_total_count, result.total_count)
  end

  defp load_games_data(socket) do
    classroom_id = socket.assigns.classroom.id
    user_id = socket.assigns.current_scope.current_user.id
    published_games = Games.list_classroom_games(classroom_id, status: :published)

    game_sessions =
      Enum.map(published_games, fn game ->
        session = Games.get_user_session(game.id, user_id)
        {game.id, session}
      end)
      |> Enum.into(%{})

    socket
    |> assign(:published_games, published_games)
    |> assign(:game_sessions, game_sessions)
  end

  defp load_chat_data(socket) do
    conversation = socket.assigns.conversation

    if conversation do
      if connected?(socket) do
        Chat.subscribe_to_conversation(conversation.id)
        Chat.mark_read(socket.assigns.current_scope.current_user.id, conversation.id)

        # Mark chat notifications for this conversation as read
        {:ok, _} = Medoru.Notifications.mark_chat_notifications_as_read(
          socket.assigns.current_scope.current_user.id,
          conversation.id
        )

        # Broadcast notification count update to dropdown
        unread_count = Medoru.Notifications.count_unread_notifications(
          socket.assigns.current_scope.current_user.id
        )

        Phoenix.PubSub.broadcast(
          Medoru.PubSub,
          "notifications:#{socket.assigns.current_scope.current_user.id}",
          {:unread_count_updated, unread_count}
        )
      end

      messages = Chat.list_messages(conversation.id, limit: @chat_message_limit)
      has_more = length(messages) == @chat_message_limit

      socket
      |> assign(:chat_messages, messages)
      |> assign(:chat_has_more, has_more)
      |> assign(:chat_offset, 0)
    else
      socket
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:active_tab, tab)
     |> push_patch(to: ~p"/classrooms/#{socket.assigns.classroom.id}?tab=#{tab}")}
  end

  @impl true
  def handle_event("filter_lessons", %{"filter" => filter}, socket) do
    filter_atom =
      case filter do
        "completed" -> :completed
        "learned" -> :completed
        "not_started" -> :not_started
        "unlearned" -> :not_started
        "in_progress" -> :in_progress
        _ -> :all
      end

    socket =
      socket
      |> assign(:lessons_filter, filter_atom)
      |> assign(:lessons_page, 1)
      |> load_lessons_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_lessons_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:lessons_page, page)
      |> load_lessons_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_classroom", _, socket) do
    membership = socket.assigns.membership

    if is_nil(membership) do
      {:noreply, socket}
    else
      case Classrooms.leave_classroom(membership) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("You have left the classroom."))
           |> push_navigate(to: ~p"/classrooms")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to leave classroom."))}
      end
    end
  end

  @impl true
  def handle_event(
        "open_copy_modal",
        %{"lesson_id" => lesson_id, "lesson_title" => lesson_title},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:copy_lesson_modal_open, true)
     |> assign(:copy_lesson_id, lesson_id)
     |> assign(:copy_lesson_title, lesson_title)}
  end

  @impl true
  def handle_event("close_copy_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:copy_lesson_modal_open, false)
     |> assign(:copy_lesson_id, nil)
     |> assign(:copy_lesson_title, nil)}
  end

  @impl true
  def handle_event("confirm_copy_lesson", _, socket) do
    user_id = socket.assigns.current_scope.current_user.id
    lesson_id = socket.assigns.copy_lesson_id

    case WordSets.create_word_set_from_lesson(user_id, lesson_id) do
      {:ok, word_set} ->
        {:noreply,
         socket
         |> assign(:copy_lesson_modal_open, false)
         |> assign(:copy_lesson_id, nil)
         |> assign(:copy_lesson_title, nil)
         |> put_flash(
           :info,
           gettext("Words copied to new word set: %{name}", name: word_set.name)
         )
         |> push_navigate(to: ~p"/words/sets/#{word_set.id}")}

      {:error, :no_words_in_lesson} ->
        {:noreply,
         socket
         |> assign(:copy_lesson_modal_open, false)
         |> put_flash(:error, gettext("This lesson has no words to copy."))}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:copy_lesson_modal_open, false)
         |> put_flash(:error, gettext("Failed to copy words to word set."))}
    end
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    conversation = socket.assigns.conversation
    user = socket.assigns.current_scope.current_user
    trimmed = String.trim(content)

    if conversation && trimmed != "" do
      reply_to = socket.assigns.reply_to
      opts = if reply_to, do: [reply_to_message_id: reply_to.id], else: []

      case Chat.store_plaintext_message(conversation.id, user.id, trimmed, opts) do
        {:ok, _message} ->
          {:noreply, assign(socket, :reply_to, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send message."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_voice_message", %{"audio_base64" => audio_b64, "mime_type" => mime_type, "duration" => duration}, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_scope.current_user
    reply_to = socket.assigns.reply_to

    uploads_dir = Application.get_env(:medoru, :uploads_dir)

    ext =
      cond do
        String.contains?(mime_type, "webm") -> ".webm"
        String.contains?(mime_type, "ogg") -> ".ogg"
        String.contains?(mime_type, "mp4") -> ".m4a"
        true -> ".webm"
      end

    filename = "#{Ecto.UUID.generate()}#{ext}"
    dest_dir = Path.join(uploads_dir, "voice_messages")
    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)

    try do
      File.write!(dest_path, Base.decode64!(audio_b64))

      voice_path = "/uploads/voice_messages/#{filename}"

      opts = [
        reply_to_message_id: reply_to && reply_to.id,
        attachment_path: voice_path,
        attachment_type: "voice",
        duration_seconds: duration
      ]

      case Chat.store_plaintext_message(conversation.id, current_user.id, "🎤 Voice message", opts) do
        {:ok, _message} ->
          {:noreply, assign(socket, :reply_to, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send voice message."))}
      end
    rescue
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Failed to process voice message."))}
    end
  end

  @impl true
  def handle_event("send_image_message", %{"image_base64" => img_b64, "mime_type" => mime_type}, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_scope.current_user
    reply_to = socket.assigns.reply_to

    valid_image_type =
      String.starts_with?(mime_type, "image/jpeg") or
        String.starts_with?(mime_type, "image/png") or
        String.starts_with?(mime_type, "image/gif") or
        String.starts_with?(mime_type, "image/webp")

    if not valid_image_type do
      {:noreply, put_flash(socket, :error, gettext("Invalid image format. Only JPEG, PNG, GIF, and WebP are supported."))}
    else
      uploads_dir = Application.get_env(:medoru, :uploads_dir)

      ext =
        cond do
          String.contains?(mime_type, "png") -> ".png"
          String.contains?(mime_type, "gif") -> ".gif"
          String.contains?(mime_type, "webp") -> ".webp"
          true -> ".jpg"
        end

      filename = "#{Ecto.UUID.generate()}#{ext}"
      dest_dir = Path.join(uploads_dir, "chat_images")
      File.mkdir_p!(dest_dir)
      dest_path = Path.join(dest_dir, filename)

      try do
        decoded = Base.decode64!(img_b64)

        if byte_size(decoded) > 5_000_000 do
          {:noreply, put_flash(socket, :error, gettext("Image is too large. Maximum size is 5MB."))}
        else
          File.write!(dest_path, decoded)
          image_path = "/uploads/chat_images/#{filename}"

          opts = [
            reply_to_message_id: reply_to && reply_to.id,
            attachment_path: image_path,
            attachment_type: "image"
          ]

          case Chat.store_plaintext_message(conversation.id, current_user.id, "📷 Image", opts) do
            {:ok, _message} ->
              {:noreply, assign(socket, :reply_to, nil)}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, gettext("Failed to send image."))}
          end
        end
      rescue
        _ ->
          {:noreply, put_flash(socket, :error, gettext("Failed to process image."))}
      end
    end
  end

  @impl true
  def handle_event("set_reply", %{"id" => message_id}, socket) do
    message = Enum.find(socket.assigns.chat_messages, &(&1.id == message_id))
    {:noreply, assign(socket, :reply_to, message)}
  end

  @impl true
  def handle_event("cancel_reply", _params, socket) do
    {:noreply, assign(socket, :reply_to, nil)}
  end

  @impl true
  def handle_event("start_edit", %{"id" => message_id}, socket) do
    message = Enum.find(socket.assigns.chat_messages, &(&1.id == message_id))

    if message && message.sender_id == socket.assigns.current_scope.current_user.id do
      {:noreply,
       socket
       |> assign(:editing_message, message)
       |> push_event("start_edit_text", %{text: message.content, message_id: message.id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_message, nil)}
  end

  @impl true
  def handle_event("edit_message", %{"content" => content, "message_id" => message_id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    case Chat.edit_message(message_id, current_user.id, %{"content" => String.trim(content)}) do
      {:ok, _} ->
        {:noreply, assign(socket, :editing_message, nil)}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You can only edit your own messages."))}

      {:error, :edit_window_expired} ->
        {:noreply, put_flash(socket, :error, gettext("Message can only be edited within 15 minutes."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to edit message."))}
    end
  end

  @impl true
  def handle_event("delete_message", %{"id" => message_id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    case Chat.delete_message(message_id, current_user.id) do
      {:ok, _} -> {:noreply, socket}
      {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Failed to delete message."))}
    end
  end

  @impl true
  def handle_event("set_typing", %{"typing" => is_typing}, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation
    if conversation do
      Chat.set_typing(current_user.id, conversation.id, is_typing)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_messages", _, socket) do
    conversation = socket.assigns.conversation
    current_offset = socket.assigns.chat_offset

    if conversation do
      new_offset = current_offset + @chat_message_limit
      all_messages = Chat.list_messages(conversation.id, limit: @chat_message_limit, offset: new_offset)
      has_more = length(all_messages) == @chat_message_limit

      {:noreply,
       socket
       |> assign(:chat_messages, socket.assigns.chat_messages ++ all_messages)
       |> assign(:chat_has_more, has_more)
       |> assign(:chat_offset, new_offset)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    current_user = socket.assigns.current_scope.current_user

    if connected?(socket) do
      Chat.mark_read(current_user.id, message.conversation_id)
    end

    message = Medoru.Repo.preload(message, sender: [:profile], reply_to_message: [sender: [:profile]])

    {:noreply,
     socket
     |> assign(:chat_messages, socket.assigns.chat_messages ++ [message])
     |> push_event("scroll_to_bottom", %{})}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    messages =
      Enum.map(socket.assigns.chat_messages, fn msg ->
        if msg.id == message_id do
          %{msg | is_deleted: true}
        else
          msg
        end
      end)

    {:noreply, assign(socket, :chat_messages, messages)}
  end

  @impl true
  def handle_info({:message_edited, message}, socket) do
    message = Medoru.Repo.preload(message, [:sender, :reply_to_message])

    messages =
      Enum.map(socket.assigns.chat_messages, fn msg ->
        if msg.id == message.id do
          message
        else
          msg
        end
      end)

    {:noreply, assign(socket, :chat_messages, messages)}
  end

  @impl true
  def handle_info({:typing, user_id, is_typing}, socket) do
    current_user = socket.assigns.current_scope.current_user

    typing_users =
      if user_id != current_user.id do
        if is_typing do
          [user_id | socket.assigns.chat_typing_users] |> Enum.uniq()
        else
          Enum.reject(socket.assigns.chat_typing_users, &(&1 == user_id))
        end
      else
        socket.assigns.chat_typing_users
      end

    {:noreply, assign(socket, :chat_typing_users, typing_users)}
  end

  @impl true
  def handle_info({:read_receipt, user_id, read_at}, socket) do
    conversation = socket.assigns.conversation

    if conversation do
      updated_participants =
        Enum.map(conversation.participants, fn p ->
          if p.user_id == user_id do
            %{p | last_read_at: read_at}
          else
            p
          end
        end)

      updated_conversation = %{conversation | participants: updated_participants}

      {:noreply, assign(socket, :conversation, updated_conversation)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-6 sm:mb-8">
          <.link
            navigate={~p"/classrooms"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-3 sm:mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to My Classrooms")}
          </.link>

          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div class="flex-1 min-w-0">
              <h1 class="text-2xl sm:text-3xl font-bold text-base-content truncate">
                {@classroom.name}
              </h1>
              <p class="text-secondary max-w-2xl mt-1 sm:mt-2 text-sm sm:text-base">
                {@classroom.description || gettext("No description")}
              </p>
            </div>

            <%= if @membership do %>
              <button
                phx-click="leave_classroom"
                data-confirm={gettext("Are you sure you want to leave this classroom?")}
                class="btn btn-error btn-outline btn-sm self-start"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4 mr-1" /> {gettext("Leave")}
              </button>
            <% end %>
          </div>
        </div>

        <%= if @membership do %>
          <%!-- My Stats Card --%>
          <div class="card bg-gradient-to-br from-primary/10 to-secondary/10 border border-primary/20 mb-6 sm:mb-8">
            <div class="card-body p-4 sm:p-6">
              <div class="flex items-center gap-3 sm:gap-4">
                <div class="w-12 h-12 sm:w-16 sm:h-16 bg-primary/20 rounded-full flex items-center justify-center shrink-0">
                  <.icon name="hero-trophy" class="w-6 h-6 sm:w-8 sm:h-8 text-primary" />
                </div>
                <div class="min-w-0">
                  <p class="text-xs sm:text-sm text-secondary">{gettext("My Points")}</p>
                  <p class="text-2xl sm:text-3xl font-bold text-base-content">{@membership.points}</p>
                </div>
                <div class="ml-auto text-right">
                  <p class="text-xs sm:text-sm text-secondary">{gettext("Rank")}</p>
                  <p class="text-xl sm:text-2xl font-bold text-base-content">
                    #{get_rank(@members, @current_scope.current_user.id)}
                  </p>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Tabs - Scrollable on mobile --%>
        <div class="border-b border-base-300 mb-6 overflow-x-auto">
          <div class="flex gap-1 min-w-max">
            <.tab_button
              active={@active_tab == "overview"}
              tab="overview"
              label={gettext("Overview")}
            />
            <.tab_button
              active={@active_tab == "rankings"}
              tab="rankings"
              label={gettext("Rankings")}
            />
            <.tab_button active={@active_tab == "lessons"} tab="lessons" label={gettext("Lessons")} />
            <.tab_button active={@active_tab == "tests"} tab="tests" label={gettext("Tests")} />
            <.tab_button active={@active_tab == "games"} tab="games" label={gettext("Games")} />
            <.tab_button active={@active_tab == "chat"} tab="chat" label={gettext("Chat")} />
          </div>
        </div>

        <%!-- Tab Content --%>
        <div class="min-h-[400px]">
          <%= case @active_tab do %>
            <% "overview" -> %>
              <.overview_tab
                classroom={@classroom}
                members={@members}
                current_user={@current_scope.current_user}
              />
            <% "rankings" -> %>
              <.rankings_tab members={@members} current_user={@current_scope.current_user} />
            <% "lessons" -> %>
              <.lessons_tab
                classroom={@classroom}
                custom_lessons={@custom_lessons}
                lesson_progress={@lesson_progress}
                current_user={@current_scope.current_user}
                lessons_filter={@lessons_filter}
                lessons_total_count={@lessons_total_count}
                lessons_page={@lessons_page}
                lessons_total_pages={@lessons_total_pages}
                copy_lesson_modal_open={@copy_lesson_modal_open}
                copy_lesson_id={@copy_lesson_id}
                copy_lesson_title={@copy_lesson_title}
              />
            <% "tests" -> %>
              <.tests_tab
                classroom={@classroom}
                published_tests={@published_tests}
                user_attempts={@user_attempts}
                current_user={@current_scope.current_user}
              />
            <% "games" -> %>
              <.games_tab
                classroom={@classroom}
                published_games={@published_games}
                game_sessions={@game_sessions}
                current_user={@current_scope.current_user}
              />
            <% "chat" -> %>
              <.chat_tab
                classroom={@classroom}
                conversation={@conversation}
                messages={@chat_messages}
                has_more={@chat_has_more}
                current_user={@current_scope.current_user}
                reply_to={@reply_to}
                editing_message={@editing_message}
                typing_users={@chat_typing_users}
              />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Tab Components
  # ============================================================================

  defp overview_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Classroom Info --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-base-content mb-4">About this Classroom</h3>
          <div class="space-y-3">
            <div class="flex justify-between items-center py-2 border-b border-base-200">
              <span class="text-secondary">Teacher</span>
              <span class="font-medium text-base-content">
                {display_name(@classroom.teacher, @current_user.id, @current_user.type == "admin")}
              </span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-base-200">
              <span class="text-secondary">Members</span>
              <span class="font-medium text-base-content">{length(@members)} students</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-base-200">
              <span class="text-secondary">Created</span>
              <span class="text-base-content">
                {Calendar.strftime(@classroom.inserted_at, "%B %d, %Y")}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Top Students --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-base-content mb-4">Top Students</h3>
          <%= if @members == [] do %>
            <p class="text-secondary">No members yet.</p>
          <% else %>
            <div class="space-y-2">
              <%= for {member, index} <- Enum.take(@members, 5) |> Enum.with_index(1) do %>
                <div class={[
                  "flex items-center justify-between p-3 rounded-xl",
                  member.user_id == @current_user.id && "bg-primary/10"
                ]}>
                  <div class="flex items-center gap-3">
                    <span class={[
                      "w-8 h-8 rounded-lg flex items-center justify-center font-bold text-sm shrink-0",
                      index == 1 && "bg-yellow-100 text-yellow-700",
                      index == 2 && "bg-gray-200 text-gray-700",
                      index == 3 && "bg-orange-100 text-orange-700",
                      index > 3 && "bg-base-200 text-secondary"
                    ]}>
                      {index}
                    </span>
                    <% avatar_src =
                      (member.user.profile && member.user.profile.avatar) || member.user.avatar_url %>
                    <%= if avatar_src do %>
                      <div class="avatar shrink-0">
                        <div class="w-8 h-8 rounded-full">
                          <img src={avatar_src} alt="" class="object-cover" />
                        </div>
                      </div>
                    <% else %>
                      <div class="avatar placeholder shrink-0">
                        <div class="bg-primary text-primary-content rounded-full w-8 h-8 flex items-center justify-center">
                          <% initial =
                            if member.user.profile && member.user.profile.display_name,
                              do: String.first(member.user.profile.display_name) |> String.upcase(),
                              else:
                                String.first(member.user.name || member.user.email) |> String.upcase() %>
                          <span class="text-xs">{initial}</span>
                        </div>
                      </div>
                    <% end %>
                    <span class={[
                      "truncate",
                      member.user_id == @current_user.id && "font-medium text-base-content"
                    ]}>
                      {display_name(member.user, @current_user.id, @current_user.type == "admin")}
                      <%= if member.user_id == @current_user.id do %>
                        <span class="badge badge-primary badge-sm ml-2">You</span>
                      <% end %>
                    </span>
                  </div>
                  <span class="font-semibold text-base-content shrink-0">{member.points} pts</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp rankings_tab(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm">
      <div class="card-body p-4 sm:p-6">
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
          <h3 class="card-title text-lg sm:text-xl text-base-content">
            {gettext("Classroom Rankings")}
          </h3>
          <.link
            navigate={~p"/classrooms/#{@current_user.id}/rankings"}
            class="btn btn-primary btn-sm w-full sm:w-auto"
          >
            <.icon name="hero-chart-bar" class="w-4 h-4 mr-1" /> {gettext("Full Rankings")}
          </.link>
        </div>
        <%= if @members == [] do %>
          <p class="text-secondary">{gettext("No members yet.")}</p>
        <% else %>
          <div class="space-y-2">
            <%= for {member, index} <- Enum.with_index(@members, 1) do %>
              <div class={[
                "flex items-center justify-between p-3 sm:p-4 rounded-xl",
                member.user_id == @current_user.id && "bg-primary/10 border border-primary/30"
              ]}>
                <div class="flex items-center gap-2 sm:gap-4 min-w-0 flex-1">
                  <span class={[
                    "w-8 h-8 sm:w-10 sm:h-10 rounded-lg sm:rounded-xl flex items-center justify-center font-bold text-sm shrink-0",
                    index == 1 && "bg-yellow-100 text-yellow-700",
                    index == 2 && "bg-gray-200 text-gray-700",
                    index == 3 && "bg-orange-100 text-orange-700",
                    index > 3 && "bg-base-200 text-secondary"
                  ]}>
                    {index}
                  </span>
                  <% avatar_src =
                    (member.user.profile && member.user.profile.avatar) || member.user.avatar_url %>
                  <%= if avatar_src do %>
                    <div class="avatar shrink-0">
                      <div class="w-8 h-8 sm:w-10 sm:h-10 rounded-full">
                        <img src={avatar_src} alt="" class="object-cover" />
                      </div>
                    </div>
                  <% else %>
                    <div class="avatar placeholder shrink-0">
                      <div class="bg-primary text-primary-content rounded-full w-8 h-8 sm:w-10 sm:h-10 flex items-center justify-center">
                        <% initial =
                          if member.user.profile && member.user.profile.display_name,
                            do: String.first(member.user.profile.display_name) |> String.upcase(),
                            else:
                              String.first(member.user.name || member.user.email) |> String.upcase() %>
                        <span class="text-xs sm:text-sm">{initial}</span>
                      </div>
                    </div>
                  <% end %>
                  <div class="min-w-0">
                    <p class={[
                      "text-sm sm:text-base truncate",
                      member.user_id == @current_user.id && "font-medium text-base-content"
                    ]}>
                      {display_name(member.user, @current_user.id, @current_user.type == "admin")}
                      <%= if member.user_id == @current_user.id do %>
                        <span class="badge badge-primary badge-xs sm:badge-sm ml-1 sm:ml-2">
                          {gettext("You")}
                        </span>
                      <% end %>
                    </p>
                    <p class="text-xs sm:text-sm text-secondary">
                      {gettext("Joined")} {Calendar.strftime(
                        member.joined_at || member.inserted_at,
                        "%b %d, %Y"
                      )}
                    </p>
                  </div>
                </div>
                <span class="font-bold text-base sm:text-lg text-base-content ml-2 shrink-0">
                  {member.points} {gettext("pts")}
                </span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :classroom, :map, required: true
  attr :custom_lessons, :list, required: true
  attr :lesson_progress, :list, required: true
  attr :current_user, :map, required: true
  attr :lessons_filter, :atom, required: true
  attr :lessons_total_count, :integer, required: true
  attr :lessons_page, :integer, required: true
  attr :lessons_total_pages, :integer, required: true
  attr :copy_lesson_modal_open, :boolean, required: true
  attr :copy_lesson_id, :any, required: true
  attr :copy_lesson_title, :any, required: true

  defp lessons_tab(assigns) do
    ~H"""
    <div class="space-y-4 sm:space-y-6">
      <%!-- Filter Buttons --%>
      <div class="flex flex-wrap gap-2">
        <.filter_button
          active={@lessons_filter == :all}
          label={gettext("All")}
          filter="all"
          count={@lessons_total_count}
        />
        <.filter_button
          active={@lessons_filter == :not_started}
          label={gettext("Not Started")}
          filter="not_started"
        />
        <.filter_button
          active={@lessons_filter == :in_progress}
          label={gettext("In Progress")}
          filter="in_progress"
        />
        <.filter_button
          active={@lessons_filter == :completed}
          label={gettext("Completed")}
          filter="completed"
        />
      </div>

      <%= if @custom_lessons == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-6 sm:p-8 text-center">
          <.icon
            name="hero-book-open"
            class="w-12 h-12 sm:w-16 sm:h-16 text-secondary/20 mx-auto mb-3 sm:mb-4"
          />
          <h3 class="text-lg sm:text-xl font-semibold text-base-content mb-2">
            {gettext("No Lessons Available")}
          </h3>
          <p class="text-secondary max-w-md mx-auto text-sm sm:text-base">
            {gettext(
              "Your teacher hasn't published any lessons to this classroom yet. Check back later!"
            )}
          </p>
        </div>
      <% else %>
        <div class="space-y-3 sm:space-y-4">
          <%= for classroom_lesson <- @custom_lessons do %>
            <% lesson = classroom_lesson.custom_lesson %>
            <% progress = get_lesson_progress_map(@lesson_progress, lesson.id) %>
            <% progress_status = progress.status %>
            <div class={[
              "card border shadow-sm hover:shadow-md transition-shadow",
              skill_level_card_bg(lesson.difficulty)
            ]}>
              <div class="card-body p-4 sm:p-6">
                <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 sm:gap-4">
                  <div class="flex-1 min-w-0">
                    <h3 class="card-title text-base sm:text-lg text-base-content mb-1">
                      {lesson.title}
                    </h3>
                    <div class="text-secondary text-sm mb-2 sm:mb-3 line-clamp-2">
                      {raw(render_markdown(lesson.description || gettext("No description")))}
                    </div>

                    <div class="flex flex-wrap gap-2 sm:gap-3 text-xs sm:text-sm">
                      <span class="badge badge-outline badge-sm">
                        <.icon name="hero-bookmark" class="w-3 h-3 mr-1" />
                        {lesson.word_count} {gettext("words")}
                      </span>

                      <span class={[
                        "px-2 py-0.5 rounded-full border text-xs font-medium",
                        skill_level_color(lesson.difficulty)
                      ]}>
                        {skill_level_label(lesson.difficulty)}
                      </span>

                      <%= if lesson.requires_test do %>
                        <span
                          class="badge badge-info badge-sm"
                          title={gettext("Requires test to complete")}
                        >
                          <.icon name="hero-pencil" class="w-3 h-3 mr-1" /> {gettext("Test")}
                        </span>
                      <% end %>

                      <%= case progress_status do %>
                        <% "completed" -> %>
                          <span class="badge badge-success badge-sm">
                            <.icon name="hero-check" class="w-3 h-3 mr-1" /> {gettext("Completed")}
                          </span>
                        <% "in_progress" -> %>
                          <span class="badge badge-warning badge-sm">
                            <.icon name="hero-play" class="w-3 h-3 mr-1" /> {gettext("In Progress")}
                          </span>
                        <% _ -> %>
                          <span class="badge badge-ghost badge-sm">
                            {gettext("Not Started")}
                          </span>
                      <% end %>
                    </div>
                  </div>

                  <div class="sm:ml-4 self-start sm:self-auto">
                    <div class="flex items-center gap-2">
                      <%!-- Copy to Word Set button --%>
                      <button
                        type="button"
                        phx-click="open_copy_modal"
                        phx-value-lesson_id={lesson.id}
                        phx-value-lesson_title={lesson.title}
                        class="btn btn-ghost btn-sm"
                        title={gettext("Copy words to word set")}
                      >
                        <.icon name="hero-document-plus" class="w-4 h-4" />
                      </button>

                      <%= case progress_status do %>
                        <% "completed" -> %>
                          <div class="flex items-center gap-2">
                            <span class="badge badge-success">
                              +{progress.points_earned} {gettext("pts")}
                            </span>
                            <.link
                              navigate={~p"/classrooms/#{@classroom.id}/custom-lessons/#{lesson.id}"}
                              class="btn btn-secondary btn-sm"
                            >
                              <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> {gettext("Review")}
                            </.link>
                          </div>
                        <% _ -> %>
                          <.link
                            navigate={~p"/classrooms/#{@classroom.id}/custom-lessons/#{lesson.id}"}
                            class="btn btn-primary btn-sm sm:btn-md"
                          >
                            <%= if progress_status == "in_progress" do %>
                              <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Continue")}
                            <% else %>
                              <.icon name="hero-book-open" class="w-4 h-4 mr-1" /> {gettext("Start")}
                            <% end %>
                          </.link>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Pagination --%>
        <%= if @lessons_total_pages > 1 do %>
          <div class="flex justify-center gap-2 pt-4">
            <%= for page_num <- 1..@lessons_total_pages do %>
              <button
                phx-click="change_lessons_page"
                phx-value-page={page_num}
                class={[
                  "btn btn-sm",
                  @lessons_page == page_num && "btn-primary",
                  @lessons_page != page_num && "btn-ghost"
                ]}
              >
                {page_num}
              </button>
            <% end %>
          </div>
        <% end %>

        <%!-- Copy to Word Set Modal --%>
        <%= if @copy_lesson_modal_open do %>
          <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <div class="bg-base-100 rounded-2xl shadow-xl max-w-md w-full p-6">
              <h3 class="text-xl font-bold text-base-content mb-4">
                {gettext("Copy to Word Set")}
              </h3>
              <p class="text-secondary mb-6">
                {gettext("Create a new word set from '%{lesson}'?", lesson: @copy_lesson_title)}
              </p>
              <p class="text-sm text-secondary mb-6">
                {gettext(
                  "All words from this lesson will be copied to a new word set with the same name and description."
                )}
              </p>
              <div class="flex gap-3 justify-end">
                <button
                  type="button"
                  phx-click="close_copy_modal"
                  class="btn btn-ghost"
                >
                  {gettext("Cancel")}
                </button>
                <button
                  type="button"
                  phx-click="confirm_copy_lesson"
                  class="btn btn-primary"
                >
                  {gettext("Confirm")}
                </button>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp get_lesson_progress_map(progress_map, lesson_id) do
    case Map.get(progress_map, lesson_id) do
      nil -> %{status: "not_started", points_earned: 0}
      progress when is_map(progress) -> progress
      status -> %{status: status, points_earned: 0}
    end
  end

  attr :active, :boolean, required: true
  attr :label, :string, required: true
  attr :filter, :string, required: true
  attr :count, :integer, default: nil

  defp filter_button(assigns) do
    ~H"""
    <button
      phx-click="filter_lessons"
      phx-value-filter={@filter}
      class={[
        "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
        @active && "bg-primary text-primary-content",
        !@active && "bg-base-200 text-secondary hover:bg-base-300"
      ]}
    >
      {@label}
      <%= if @count do %>
        <span class="ml-1 opacity-75">({@count})</span>
      <% end %>
    </button>
    """
  end

  attr :classroom, :map, required: true
  attr :published_tests, :list, required: true
  attr :user_attempts, :list, required: true
  attr :current_user, :map, required: true

  defp tests_tab(assigns) do
    ~H"""
    <div class="space-y-3 sm:space-y-4">
      <%= if @published_tests == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-6 sm:p-8 text-center">
          <.icon
            name="hero-clipboard-document-list"
            class="w-12 h-12 sm:w-16 sm:h-16 text-secondary/20 mx-auto mb-3 sm:mb-4"
          />
          <h3 class="text-lg sm:text-xl font-semibold text-base-content mb-2">
            {gettext("No Tests Available")}
          </h3>
          <p class="text-secondary max-w-md mx-auto text-sm sm:text-base">
            {gettext(
              "Your teacher hasn't published any tests to this classroom yet. Check back later!"
            )}
          </p>
        </div>
      <% else %>
        <%= for classroom_test <- @published_tests do %>
          <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow">
            <div class="card-body p-4 sm:p-6">
              <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 sm:gap-4">
                <div class="flex-1 min-w-0">
                  <h3 class="card-title text-base sm:text-lg text-base-content mb-1">
                    {classroom_test.test.title}
                  </h3>
                  <p class="text-secondary text-sm mb-2 sm:mb-3">
                    {classroom_test.test.description || gettext("No description")}
                  </p>

                  <div class="flex flex-wrap gap-2 sm:gap-3 text-xs sm:text-sm">
                    <span class="badge badge-outline badge-sm">
                      <.icon name="hero-clock" class="w-3 h-3 mr-1" />
                      <%= if classroom_test.test.time_limit_seconds do %>
                        {format_duration(classroom_test.test.time_limit_seconds)}
                      <% else %>
                        {gettext("No time limit")}
                      <% end %>
                    </span>

                    <span class="badge badge-outline badge-sm">
                      <.icon name="hero-star" class="w-3 h-3 mr-1" />
                      {classroom_test.test.total_points} {gettext("points")}
                    </span>

                    <%= if classroom_test.max_attempts do %>
                      <span class="badge badge-outline badge-sm">
                        <.icon name="hero-arrow-path" class="w-3 h-3 mr-1" />
                        {classroom_test.max_attempts} {if classroom_test.max_attempts != 1,
                          do: gettext("attempts"),
                          else: gettext("attempt")}
                      </span>
                    <% end %>

                    <%= if classroom_test.due_date do %>
                      <% is_overdue =
                        DateTime.compare(classroom_test.due_date, DateTime.utc_now()) == :lt %>
                      <span class={[
                        "badge badge-sm",
                        is_overdue && "badge-error",
                        !is_overdue && "badge-warning"
                      ]}>
                        <.icon name="hero-calendar" class="w-3 h-3 mr-1" />
                        <%= if is_overdue do %>
                          {gettext("Overdue")}
                        <% else %>
                          {gettext("Due")} {Calendar.strftime(classroom_test.due_date, "%b %d")}
                        <% end %>
                      </span>
                    <% end %>
                  </div>
                </div>

                <div class="sm:ml-4 self-start sm:self-auto">
                  <% attempt = get_attempt_for_test(@user_attempts, classroom_test.test_id) %>
                  <%= case get_test_status(@classroom.id, @current_user.id, classroom_test.test_id, attempt) do %>
                    <% :not_started -> %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/tests/#{classroom_test.test_id}"}
                        class="btn btn-primary btn-sm sm:btn-md"
                      >
                        <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Start Test")}
                      </.link>
                    <% :in_progress -> %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/tests/#{classroom_test.test_id}"}
                        class="btn btn-warning btn-sm sm:btn-md"
                      >
                        <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Continue")}
                      </.link>
                    <% :completed -> %>
                      <span class="badge badge-success">
                        {gettext("Completed")} {attempt.score}/{attempt.max_score}
                      </span>
                    <% :timed_out -> %>
                      <span class="badge badge-error">{gettext("Timed Out")}</span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :classroom, :map, required: true
  attr :published_games, :list, required: true
  attr :game_sessions, :map, required: true
  attr :current_user, :map, required: true

  defp games_tab(assigns) do
    ~H"""
    <div class="space-y-3 sm:space-y-4">
      <%= if @published_games == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-6 sm:p-8 text-center">
          <.icon
            name="hero-puzzle-piece"
            class="w-12 h-12 sm:w-16 sm:h-16 text-secondary/20 mx-auto mb-3 sm:mb-4"
          />
          <h3 class="text-lg sm:text-xl font-semibold text-base-content mb-2">
            {gettext("No Games Available")}
          </h3>
          <p class="text-secondary max-w-md mx-auto text-sm sm:text-base">
            {gettext(
              "Your teacher hasn't published any games to this classroom yet. Check back later!"
            )}
          </p>
        </div>
      <% else %>
        <%= for game <- @published_games do %>
          <% session = Map.get(@game_sessions, game.id) %>
          <div class={[
            "card shadow-sm hover:shadow-md transition-all",
            skill_level_card_bg(game.skill_level)
          ]}>
            <div class="card-body p-4 sm:p-6">
              <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 sm:gap-4">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <h3 class="card-title text-base sm:text-lg text-base-content">
                      {game.name}
                    </h3>
                    <span class={[
                      "text-xs px-2 py-0.5 rounded-full border font-medium",
                      skill_level_color(game.skill_level)
                    ]}>
                      {skill_level_label(game.skill_level)}
                    </span>
                  </div>
                  <%= cond do %>
                    <% game.memory_card_game -> %>
                      <div class="flex flex-wrap gap-2 text-xs sm:text-sm">
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-squares-2x2" class="w-3 h-3 mr-1" />
                          {game.memory_card_game.board_size}
                        </span>
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-heart" class="w-3 h-3 mr-1" />
                          {game.memory_card_game.max_attempts} {gettext("attempts")}
                        </span>
                      </div>
                    <% game.kana_memory_card_game -> %>
                      <div class="flex flex-wrap gap-2 text-xs sm:text-sm">
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-squares-2x2" class="w-3 h-3 mr-1" />
                          {game.kana_memory_card_game.board_size}
                        </span>
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-heart" class="w-3 h-3 mr-1" />
                          {game.kana_memory_card_game.max_attempts} {gettext("attempts")}
                        </span>
                        <%= if game.kana_memory_card_game.require_reading do %>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-pencil" class="w-3 h-3 mr-1" />
                            {gettext("Reading")}
                          </span>
                        <% end %>
                      </div>
                    <% game.kana_falling_game -> %>
                      <div class="flex flex-wrap gap-2 text-xs sm:text-sm">
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-bolt" class="w-3 h-3 mr-1" />
                          {gettext("Speed")} {game.kana_falling_game.initial_speed}
                        </span>
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-heart" class="w-3 h-3 mr-1" />
                          {game.kana_falling_game.lives} {gettext("lives")}
                        </span>
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-language" class="w-3 h-3 mr-1" />
                          {length(game.kana_falling_game.selected_kana)} {gettext("kana")}
                        </span>
                      </div>
                    <% game.kanji_falling_game -> %>
                      <div class="flex flex-wrap gap-2 text-xs sm:text-sm">
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-bolt" class="w-3 h-3 mr-1" />
                          {gettext("Speed")} {game.kanji_falling_game.initial_speed}
                        </span>
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-heart" class="w-3 h-3 mr-1" />
                          {game.kanji_falling_game.lives} {gettext("lives")}
                        </span>
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-language" class="w-3 h-3 mr-1" />
                          {length(game.kanji_falling_game.selected_kanji)} {gettext("kanji")}
                        </span>
                        <span class="badge badge-outline badge-sm">
                          <.icon name="hero-pencil" class="w-3 h-3 mr-1" />
                          {game.kanji_falling_game.reading_type}
                        </span>
                      </div>
                    <% true -> %>
                  <% end %>
                </div>

                <div class="sm:ml-4 self-start sm:self-auto">
                  <div class="flex items-center gap-2">
                    <% play_path =
                      cond do
                        game.type == "kana_falling" ->
                          ~p"/classrooms/#{@classroom.id}/kana-falling-games/#{game.id}"

                        game.type == "kanji_falling" ->
                          ~p"/classrooms/#{@classroom.id}/kanji-falling-games/#{game.id}"

                        true ->
                          ~p"/classrooms/#{@classroom.id}/games/#{game.id}"
                      end %>
                    <%= case get_game_status(session) do %>
                      <% :not_started -> %>
                        <.link
                          navigate={play_path}
                          class="btn btn-primary btn-sm sm:btn-md"
                        >
                          <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Play")}
                        </.link>
                      <% :in_progress -> %>
                        <.link
                          navigate={play_path}
                          class="btn btn-warning btn-sm sm:btn-md"
                        >
                          <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Continue")}
                        </.link>
                      <% :completed -> %>
                        <span class="badge badge-success">
                          {session.score} {gettext("pts")}
                        </span>
                        <.link
                          navigate={play_path}
                          class="btn btn-secondary btn-sm"
                        >
                          <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> {gettext("Play Again")}
                        </.link>
                    <% end %>
                    <%= if game.type in ["kana_falling", "kanji_falling"] do %>
                      <%!-- No rankings link for falling games (shown on game over instead) --%>
                    <% else %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/games/#{game.id}/rankings"}
                        class="btn btn-ghost btn-sm"
                      >
                        <.icon name="hero-trophy" class="w-4 h-4 mr-1" /> {gettext("Rankings")}
                      </.link>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :classroom, :map, required: true
  attr :conversation, :any, required: true
  attr :messages, :list, required: true
  attr :has_more, :boolean, required: true
  attr :current_user, :map, required: true
  attr :reply_to, :any, required: true
  attr :editing_message, :any, required: true
  attr :typing_users, :list, required: true

  defp chat_tab(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto flex flex-col h-[calc(100vh-20rem)] min-h-[400px]">
      <%= if @conversation do %>
        <%!-- Messages Area --%>
        <div
          id="classroom-chat-messages"
          class="flex-1 overflow-y-auto px-3 py-2 space-y-1"
          phx-hook="ClassroomChatScroll"
        >
          <%!-- Load More Button --%>
          <%= if @has_more do %>
            <div class="flex justify-center py-2">
              <button
                phx-click="load_more_messages"
                class="btn btn-ghost btn-xs text-secondary"
              >
                <.icon name="hero-arrow-up" class="w-3 h-3 mr-1" />
                {gettext("Load more messages")}
              </button>
            </div>
          <% end %>

          <%= for {message, index} <- Enum.with_index(@messages) do %>
            <% is_me = message.sender_id == @current_user.id %>
            <% is_teacher = message.sender_id == @classroom.teacher_id %>
            <% is_last_message = index == length(@messages) - 1 %>
            <% show_avatar =
              index == length(@messages) - 1 ||
                (Enum.at(@messages, index + 1) && Enum.at(@messages, index + 1).sender_id != message.sender_id) %>

            <%!-- Date Separator --%>
            <%= if index == 0 || !same_day?(message.inserted_at, Enum.at(@messages, index - 1).inserted_at) do %>
              <div class="flex items-center justify-center my-3">
                <span class="text-xs text-base-content/40 bg-base-200 px-3 py-1 rounded-full">
                  {format_message_date(message.inserted_at)}
                </span>
              </div>
            <% end %>

            <%!-- Reply Preview --%>
            <%= if message.reply_to_message do %>
              <div class={[
                "flex mb-1",
                is_me && "justify-end",
                not is_me && "justify-start"
              ]}>
                <div class={[
                  "max-w-[80%] px-3 py-1.5 rounded-lg text-xs",
                  "bg-base-200/70 text-base-content/60 border-l-2 border-primary/40"
                ]}>
                  <span class="font-medium text-primary/70">
                    {chat_sender_name(message.reply_to_message.sender, @current_user.id)}
                  </span>
                  <span class="truncate block">
                    <%= cond do %>
                      <% message.reply_to_message.is_deleted -> %>
                        {gettext("This message was deleted")}
                      <% message.reply_to_message.attachment_type == "image" -> %>
                        {gettext("📷 Image")}
                      <% message.reply_to_message.attachment_type == "voice" -> %>
                        {gettext("🎤 Voice message")}
                      <% true -> %>
                        {message.reply_to_message.content}
                    <% end %>
                  </span>
                </div>
              </div>
            <% end %>

            <div class={[
              "flex group/message",
              is_me && "justify-end",
              not is_me && "justify-start"
            ]}>
              <%= if not is_me do %>
                <%= if show_avatar do %>
                  <%= if avatar = chat_avatar(message.sender) do %>
                    <img
                      src={avatar}
                      alt=""
                      class={[
                        "w-7 h-7 rounded-full object-cover mr-1.5 shrink-0 self-end",
                        is_teacher && "ring-2 ring-primary"
                      ]}
                    />
                  <% else %>
                    <div class={[
                      "w-7 h-7 rounded-full flex items-center justify-center mr-1.5 shrink-0 self-end",
                      is_teacher && "bg-primary text-primary-content ring-2 ring-primary",
                      not is_teacher && "bg-primary/10"
                    ]}>
                      <.icon name="hero-user" class="w-3.5 h-3.5 text-primary/50" />
                    </div>
                  <% end %>
                <% else %>
                  <div class="w-7 mr-1.5 shrink-0"></div>
                <% end %>
              <% end %>

              <div class="flex flex-col max-w-[85%] sm:max-w-[70%]">
                <%= if not is_me do %>
                  <span class="text-[10px] text-base-content/40 px-1 mb-0.5 flex items-center gap-1">
                    {chat_sender_name(message.sender, @current_user.id)}
                    <%= if is_teacher do %>
                      <span class="badge badge-primary badge-xs">{gettext("Teacher")}</span>
                    <% end %>
                  </span>
                <% end %>
                <div class="flex items-end gap-1">
                  <% is_emoji_msg = not is_nil(message.content) && emoji_only?(message.content) && is_nil(message.attachment_type) %>
                  <div class={[
                    "message-bubble relative rounded-2xl",
                    is_emoji_msg && "bg-transparent border-transparent text-base-content",
                    not is_emoji_msg && is_me && "bg-primary text-primary-content rounded-br-md border border-primary",
                    not is_emoji_msg && not is_me && "bg-accent/15 text-base-content rounded-bl-md border border-accent/30",
                    if(message.is_deleted, do: "px-3 py-1.5", else: if(message.attachment_type in ["voice", "image"], do: "px-3 py-2", else: "px-3 py-1.5"))
                  ]}>
                    <%= cond do %>
                      <% message.is_deleted -> %>
                        <p class="text-[15px] leading-snug italic opacity-60">
                          {gettext("This message was deleted")}
                        </p>

                      <% message.attachment_type == "voice" && message.attachment_path -> %>
                        <div id={"classroom-audio-#{message.id}"} class="flex items-center gap-2" phx-hook="ChatAudioPlayer" data-src={message.attachment_path} data-duration={message.duration_seconds || 0}>
                          <button type="button" class="chat-audio-play w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center hover:bg-primary/30 transition-colors shrink-0">
                            <.icon name="hero-play" class="w-4 h-4 chat-audio-play-icon" />
                            <.icon name="hero-pause" class="w-4 h-4 chat-audio-pause-icon hidden" />
                          </button>
                          <div class="flex-1 min-w-0">
                            <div class="chat-audio-progress h-1.5 bg-base-300/50 rounded-full overflow-hidden cursor-pointer">
                              <div class="chat-audio-progress-bar h-full bg-primary rounded-full transition-all duration-100" style="width: 0%"></div>
                            </div>
                            <div class="flex justify-between mt-0.5">
                              <span class="chat-audio-current text-[10px] opacity-70 tabular-nums">0:00</span>
                              <span class="chat-audio-duration text-[10px] opacity-70 tabular-nums">
                                {format_audio_duration(message.duration_seconds)}
                              </span>
                            </div>
                          </div>
                          <audio class="chat-audio-el absolute w-0 h-0 opacity-0" src={message.attachment_path} preload="auto"></audio>
                        </div>

                      <% message.attachment_type == "image" && message.attachment_path -> %>
                        <div class="relative group/image">
                          <a href={message.attachment_path} target="_blank">
                            <img
                              src={message.attachment_path}
                              class="max-w-[240px] max-h-[240px] rounded-lg object-cover"
                              loading="lazy"
                            />
                          </a>
                          <a
                            href={message.attachment_path}
                            download
                            class="absolute bottom-1 right-1 p-1 rounded bg-black/50 text-white opacity-0 group-hover/image:opacity-100 transition-opacity"
                            title={gettext("Download")}
                          >
                            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" />
                          </a>
                        </div>

                      <% is_emoji_msg -> %>
                        <p class="text-4xl leading-none py-1">{message.content}</p>

                      <% true -> %>
                        <p class="text-[15px] leading-snug whitespace-pre-wrap break-words">{message.content}</p>
                    <% end %>
                  </div>
                  <div class="relative message-actions shrink-0 self-center">
                    <button
                      type="button"
                      class="message-menu-btn p-1 rounded-full text-base-content/30 hover:text-base-content/70 hover:bg-base-200 transition-colors"
                      data-message-id={message.id}
                    >
                      <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
                    </button>
                    <div
                      class={[
                        "message-menu-dropdown hidden absolute z-30 bg-base-100 border border-base-300 rounded-xl shadow-lg py-1 min-w-[120px]",
                        is_me && "right-0",
                        not is_me && "left-0"
                      ]}
                      data-message-id={message.id}
                    >
                      <button
                        type="button"
                        phx-click="set_reply"
                        phx-value-id={message.id}
                        class="w-full px-3 py-2 text-left text-sm hover:bg-base-200 flex items-center gap-2 transition-colors"
                      >
                        <.icon name="hero-arrow-uturn-left" class="w-4 h-4" />
                        {gettext("Reply")}
                      </button>
                      <%= if is_me && not message.is_deleted do %>
                        <%= if can_edit_message?(message, @current_user.id) do %>
                          <button
                            type="button"
                            phx-click="start_edit"
                            phx-value-id={message.id}
                            class="w-full px-3 py-2 text-left text-sm hover:bg-base-200 flex items-center gap-2 transition-colors"
                          >
                            <.icon name="hero-pencil" class="w-4 h-4" />
                            {gettext("Edit")}
                          </button>
                        <% end %>
                        <%= if can_delete_message?(message, @current_user.id) do %>
                          <button
                            type="button"
                            phx-click="delete_message"
                            phx-value-id={message.id}
                            data-confirm={gettext("Delete this message?")}
                            class="w-full px-3 py-2 text-left text-sm hover:bg-base-200 text-error flex items-center gap-2 transition-colors"
                          >
                            <.icon name="hero-trash" class="w-4 h-4" />
                            {gettext("Delete")}
                          </button>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                </div>
                <span class={[
                  "text-[10px] text-base-content/40 mt-0.5 px-1 flex items-center gap-1",
                  is_me && "justify-end",
                  not is_me && "justify-start"
                ]}>
                  {format_message_time(message.inserted_at)}
                  <%= if message.edited_at do %>
                    <span class="italic opacity-70">({gettext("edited")})</span>
                  <% end %>
                  <%= if is_me && is_last_message && not message.is_deleted do %>
                    <%= if message_read_by_others?(message, @conversation, @current_user.id) do %>
                      <span class="text-primary" title={gettext("Read")}>
                        <.icon name="hero-check" class="w-3 h-3" />
                        <.icon name="hero-check" class="w-3 h-3 -ml-1.5" />
                      </span>
                    <% else %>
                      <span class="opacity-50" title={gettext("Sent")}>
                        <.icon name="hero-check" class="w-3 h-3" />
                      </span>
                    <% end %>
                  <% end %>
                </span>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Reply Preview Bar --%>
        <%= if @reply_to do %>
          <div class="px-4 py-2 bg-base-200/50 border-t border-base-300 flex items-center gap-2">
            <div class="flex-1 min-w-0">
              <p class="text-xs text-base-content/60">
                {gettext("Replying to")}
                <span class="font-medium text-base-content">
                  {chat_sender_name(@reply_to.sender, @current_user.id)}
                </span>
              </p>
              <p class="text-sm text-base-content/80 truncate">
                <%= cond do %>
                  <% @reply_to.is_deleted -> %>
                    {gettext("This message was deleted")}
                  <% @reply_to.attachment_type == "image" -> %>
                    {gettext("📷 Image")}
                  <% @reply_to.attachment_type == "voice" -> %>
                    {gettext("🎤 Voice message")}
                  <% true -> %>
                    {@reply_to.content}
                <% end %>
              </p>
            </div>
            <button
              type="button"
              phx-click="cancel_reply"
              class="p-1 text-base-content/40 hover:text-base-content transition-colors"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>

        <%!-- Edit Preview Bar --%>
        <%= if @editing_message do %>
          <div class="px-4 py-2 bg-info/5 border-t border-base-300 flex items-center gap-2">
            <.icon name="hero-pencil" class="w-4 h-4 text-info shrink-0" />
            <div class="flex-1 min-w-0">
              <p class="text-xs text-base-content/60">
                {gettext("Editing message")}
              </p>
            </div>
            <button
              type="button"
              phx-click="cancel_edit"
              class="p-1 text-base-content/40 hover:text-base-content transition-colors"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>

        <%!-- Input Area --%>
        <div
          id="classroom-chat-input"
          class="px-4 py-3 border-t border-base-300 bg-base-100 shrink-0 relative"
          phx-hook="ClassroomChatInput"
        >
          <%!-- Image Preview --%>
          <div id="classroom-image-preview" class="hidden mb-2 relative inline-block">
            <img src="" class="h-16 w-16 object-cover rounded-lg border border-base-300" />
            <button
              type="button"
              id="classroom-image-cancel"
              class="absolute -top-1.5 -right-1.5 w-5 h-5 bg-error text-error-content rounded-full flex items-center justify-center text-xs"
            >
              <.icon name="hero-x-mark" class="w-3 h-3" />
            </button>
          </div>

          <input type="file" id="classroom-image-input" accept="image/*" class="hidden" />

          <%!-- Emoji Picker Panel --%>
          <div
            id="classroom-emoji-panel"
            class="hidden absolute bottom-20 left-4 right-4 sm:left-auto sm:right-4 sm:w-72 bg-base-100 border border-base-300 rounded-xl shadow-lg p-3 z-20 grid grid-cols-6 gap-2"
          >
            <%= for emoji <- ~w(😀 😂 ❤️ 👍 🎉 🔥 😊 😭 🙏 ✨ 🥰 🤔 😅 👏 🌸 🍀 ⭐ 💯 🎊 🌟 🎌 🗾 🍜 🍱 🍡 🍣 🍙 🍥 🍘 🍮) do %>
              <button
                type="button"
                data-emoji={emoji}
                class="text-2xl hover:bg-base-200 rounded-lg p-1 transition-colors"
              >
                {emoji}
              </button>
            <% end %>
          </div>

          <div class="flex flex-col sm:flex-row items-stretch sm:items-end gap-2">
            <div class="flex-1 relative">
              <textarea
                id="classroom-chat-textarea"
                placeholder={gettext("Type a message...")}
                rows="1"
                class="w-full px-4 py-3 bg-base-200 border-0 rounded-2xl text-base-content placeholder:text-base-content/40 focus:outline-none focus:ring-2 focus:ring-primary/20 resize-none max-h-32"
              ></textarea>
            </div>
            <div class="flex items-center gap-1 shrink-0">
              <div id="classroom-voice-recorder" phx-hook="ChatVoiceRecorder" class="relative flex items-center">
                <button
                  id="chat-voice-button"
                  type="button"
                  class="btn btn-ghost btn-circle text-base-content/60 hover:text-primary"
                  title={gettext("Voice message")}
                >
                  <.icon name="hero-microphone" class="w-5 h-5" />
                </button>
                <button
                  id="chat-mic-picker-button"
                  type="button"
                  class="absolute -top-1 -right-1 w-4 h-4 bg-base-200 hover:bg-primary hover:text-primary-content rounded-full flex items-center justify-center text-[10px] transition-colors"
                  title={gettext("Select microphone")}
                >
                  <.icon name="hero-chevron-down" class="w-3 h-3" />
                </button>
                <span
                  id="chat-voice-status"
                  class="hidden absolute -top-2 -right-2 bg-error text-error-content text-xs font-bold px-1.5 py-0.5 rounded-full"
                >
                  0s
                </span>
                <div
                  id="chat-mic-picker"
                  class="hidden absolute bottom-12 right-0 w-64 bg-base-100 border border-base-300 rounded-xl shadow-lg p-2 z-20 max-h-48 overflow-y-auto"
                >
                  <p class="text-xs text-base-content/60 px-2 py-1 font-medium">
                    {gettext("Select microphone")}
                  </p>
                  <div id="chat-mic-picker-list" class="space-y-1"></div>
                </div>
              </div>
              <button
                id="classroom-image-button"
                type="button"
                class="btn btn-ghost btn-circle text-base-content/60 hover:text-primary"
                title={gettext("Send image")}
              >
                <.icon name="hero-photo" class="w-5 h-5" />
              </button>
              <button
                id="classroom-emoji-button"
                type="button"
                class="btn btn-ghost btn-circle text-base-content/60 hover:text-primary"
                title={gettext("Emoji")}
              >
                <.icon name="hero-face-smile" class="w-5 h-5" />
              </button>
              <button
                id="classroom-chat-send-button"
                type="button"
                class="btn btn-primary btn-circle"
              >
                <.icon name="hero-paper-airplane" class="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
      <% else %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-6 sm:p-8 text-center">
          <.icon
            name="hero-chat-bubble-left-right"
            class="w-12 h-12 sm:w-16 sm:h-16 text-secondary/20 mx-auto mb-3 sm:mb-4"
          />
          <h3 class="text-lg sm:text-xl font-semibold text-base-content mb-2">
            {gettext("Chat Unavailable")}
          </h3>
          <p class="text-secondary max-w-md mx-auto text-sm sm:text-base">
            {gettext("The classroom chat could not be loaded. Please try again later.")}
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp chat_avatar(sender) do
    user = sender

    if user do
      (user.profile && user.profile.avatar) || user.avatar_url
    end
  end

  defp chat_sender_name(sender, current_user_id) do
    user = sender

    if user do
      name = (user.profile && user.profile.display_name) || user.name || gettext("Anonymous")

      if user.id == current_user_id do
        gettext("You")
      else
        name
      end
    else
      gettext("Unknown")
    end
  end

  defp format_message_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  defp format_message_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y")
  end

  defp same_day?(%DateTime{} = a, %DateTime{} = b) do
    DateTime.to_date(a) == DateTime.to_date(b)
  end

  defp can_edit_message?(message, current_user_id) do
    Chat.can_edit_message?(message, current_user_id)
  end

  defp can_delete_message?(message, current_user_id) do
    Chat.can_delete_message?(message, current_user_id)
  end

  defp message_read_by_others?(message, conversation, current_user_id) do
    other_participants = Enum.reject(conversation.participants, &(&1.user_id == current_user_id))

    Enum.any?(other_participants, fn participant ->
      participant.last_read_at && DateTime.compare(participant.last_read_at, message.inserted_at) != :lt
    end)
  end

  defp format_audio_duration(nil), do: "0:00"
  defp format_audio_duration(seconds) when seconds < 60, do: "0:#{String.pad_leading("#{seconds}", 2, "0")}"
  defp format_audio_duration(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}:#{String.pad_leading("#{s}", 2, "0")}"
  end

  defp emoji_only?(nil), do: false
  defp emoji_only?(text) do
    trimmed = String.trim(text)
    trimmed != "" and String.replace(trimmed, ~r/[\s\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{1F1E0}-\x{1F1FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{1F900}-\x{1F9FF}\x{1F004}\x{1F0CF}\x{1F170}-\x{1F251}\x{238C}\x{2B50}\x{2B55}\x{2764}\x{2795}-\x{2797}\x{27A1}\x{27B0}\x{27BF}\x{2B05}-\x{2B07}\x{3030}\x{303D}\x{3297}\x{3299}\x{23F0}-\x{23F3}\x{23E9}-\x{23EF}\x{1F18E}\x{00A9}\x{00AE}\x{FE0F}\x{200D}\x{1F3FB}-\x{1F3FF}]/u, "") == ""
  end

  defp get_game_status(nil), do: :not_started
  defp get_game_status(%{status: :in_progress}), do: :in_progress
  defp get_game_status(%{status: :completed}), do: :completed
  defp get_game_status(%{status: "in_progress"}), do: :in_progress
  defp get_game_status(%{status: "completed"}), do: :completed
  defp get_game_status(_), do: :not_started

  defp can_take_test?(classroom_id, user_id, test_id) do
    Classrooms.can_take_test?(classroom_id, user_id, test_id)
  end

  defp get_attempt_for_test(attempts, test_id) do
    Enum.find(attempts, &(&1.test_id == test_id))
  end

  defp get_test_status(classroom_id, user_id, test_id, nil) do
    if can_take_test?(classroom_id, user_id, test_id) do
      :not_started
    else
      :not_started
    end
  end

  defp get_test_status(_classroom_id, _user_id, _test_id, attempt) do
    case attempt.status do
      "in_progress" -> :in_progress
      "completed" -> :completed
      "timed_out" -> :timed_out
      _ -> :completed
    end
  end

  defp format_duration(seconds) when seconds < 60 do
    "#{seconds}s"
  end

  defp format_duration(seconds) when seconds < 3600 do
    "#{div(seconds, 60)}m"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    mins = rem(seconds, 3600) |> div(60)
    "#{hours}h #{mins}m"
  end

  # ============================================================================
  # Helper Components
  # ============================================================================

  attr :active, :boolean, required: true
  attr :tab, :string, required: true
  attr :label, :string, required: true

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click="change_tab"
      phx-value-tab={@tab}
      class={[
        "px-3 sm:px-4 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap",
        @active && "border-primary text-primary",
        !@active && "border-transparent text-secondary hover:text-base-content hover:border-base-300"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp get_rank(members, user_id) do
    members
    |> Enum.with_index(1)
    |> Enum.find(fn {member, _index} -> member.user_id == user_id end)
    |> case do
      nil -> "-"
      {_member, index} -> index
    end
  end

  defp skill_level_color(level),
    do: Map.get(@skill_level_colors, level, "bg-base-200 text-base-content border-base-300")

  defp skill_level_label(level), do: Map.get(@skill_level_labels, level, "")

  defp skill_level_card_bg(level),
    do: Map.get(@skill_level_card_bgs, level, "bg-base-100 border-base-300 hover:border-primary")

  defp render_markdown(text) when is_binary(text) do
    {:ok, html, _} = Earmark.as_html(text, escape: false, smartypants: false)
    html
  end

  defp render_markdown(nil), do: ""
end
