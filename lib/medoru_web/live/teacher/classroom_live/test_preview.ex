defmodule MedoruWeb.Teacher.ClassroomLive.TestPreview do
  @moduledoc """
  LiveView that lets a teacher preview a test that is published to one of their classrooms.

  Differences from the student test flow:
  - No classroom attempt or persistent test session is created.
  - No points are awarded to the classroom or the teacher.
  - The teacher can retake the preview as many times as they want.
  - Correct answers and explanations are revealed immediately after each step.
  - Timers are informational only.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Grammar.Validator
  alias Medoru.Tests
  alias Medoru.Tests.ReadingAnswerValidator
  alias MedoruWeb.ClassroomLive.GrammarComponents
  alias MedoruWeb.WritingFillInComponents

  @impl true
  def mount(%{"id" => classroom_id, "test_id" => test_id}, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user

    classroom = Classrooms.get_classroom!(classroom_id)
    test = Tests.get_test!(test_id)

    cond do
      classroom.teacher_id != user.id ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Only the classroom teacher can preview this test."))
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=tests")}

      test.creator_id != user.id and user.type != "admin" ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You can only preview tests you created."))
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=tests")}

      true ->
        classroom_test = Classrooms.get_classroom_test(classroom_id, test_id)

        if is_nil(classroom_test) || classroom_test.status != :active do
          {:ok,
           socket
           |> put_flash(:error, gettext("This test is not published to this classroom."))
           |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=tests")}
        else
          steps = Tests.list_test_steps(test_id)
          first_step = List.first(steps)

          {:ok,
           socket
           |> assign(:locale, locale)
           |> assign(:page_title, gettext("Preview: %{title}", title: test.title))
           |> assign(:classroom, classroom)
           |> assign(:test, test)
           |> assign(:steps, steps)
           |> assign(:current_step_index, 0)
           |> assign(:current_step, first_step)
           |> assign(:total_steps, length(steps))
           |> assign(:selected_answer, nil)
           |> assign(:feedback, nil)
           |> assign(:meaning_answer, "")
           |> assign(:reading_answer, "")
           |> assign(:answer, initial_answer_for_step(first_step))
           |> assign(:show_hint, false)
           |> assign(:correct_meaning, nil)
           |> assign(:correct_reading, nil)
           |> assign(:meaning_error, false)
           |> assign(:reading_error, false)
           |> assign(:correct_count, 0)
           |> assign(:incorrect_count, 0)
           |> assign(:test_completed, false)
           |> assign(:writing_start_time, writing_start_time(first_step))
           |> assign(:current_wrong_strokes, 0)}
        end
    end
  end

  # ============================================================================
  # Event handlers - generic navigation
  # ============================================================================

  @impl true
  def handle_event("select_answer", %{"answer" => answer}, socket) do
    {:noreply, assign(socket, :selected_answer, answer)}
  end

  @impl true
  def handle_event("update_meaning", params, socket) do
    value = Map.get(params, "meaning_answer", params["value"] || "")
    {:noreply, assign(socket, :meaning_answer, value)}
  end

  @impl true
  def handle_event("update_reading", params, socket) do
    value = Map.get(params, "reading_answer", params["value"] || "")
    {:noreply, assign(socket, :reading_answer, value)}
  end

  @impl true
  def handle_event("update_writing_fill_in", params, socket) do
    index = params["index"]
    value = params["value"] || get_in(params, ["writing_fill_in_answer", to_string(index)]) || ""
    answer = Map.put(socket.assigns.answer, index, value)
    {:noreply, assign(socket, :answer, answer)}
  end

  @impl true
  def handle_event("show_hint", _params, socket) do
    {:noreply, assign(socket, :show_hint, true)}
  end

  @impl true
  def handle_event("skip_question", _params, socket) do
    move_to_next_step(mark_feedback(socket, false))
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    move_to_next_step(socket)
  end

  # ============================================================================
  # Event handlers - answer submission
  # ============================================================================

  @impl true
  def handle_event("submit_answer", params, socket) do
    step = socket.assigns.current_step

    case step.question_type do
      :reading_text ->
        handle_reading_text_answer(socket)

      :writing ->
        handle_writing_answer(socket, true)

      :writing_fill_in ->
        handle_writing_fill_in_answer(socket)

      :sentence_validation ->
        handle_sentence_validation_answer(socket, params["answer"], step)

      :conjugation ->
        handle_conjugation_answer(socket, params["answer"], step)

      :conjugation_multichoice ->
        handle_conjugation_multichoice_answer(socket, params["answer"], step)

      :word_order ->
        answer = Enum.join(socket.assigns.answer || [], "")
        handle_word_order_answer(socket, answer, step)

      :grammar_pattern ->
        handle_grammar_pattern_answer(socket, params["answer"], step)

      :image_to_meaning ->
        handle_image_to_meaning_answer(socket, params["answer"] || socket.assigns.selected_answer)

      :listening ->
        handle_listening_answer(socket, params["answer"], step)

      :fill ->
        handle_fill_answer(socket, params["answer"], step)

      :multichoice ->
        handle_multichoice_answer(
          socket,
          params["answer"] || socket.assigns.selected_answer,
          step
        )

      :picture_multichoice ->
        handle_multichoice_answer(socket, socket.assigns.selected_answer, step)

      _ ->
        {:noreply,
         put_flash(socket, :error, gettext("This question type is not supported in preview."))}
    end
  end

  @impl true
  def handle_event("submit_reading_text", _params, socket) do
    handle_reading_text_answer(socket)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => completed}, socket)
      when completed in ["true", true] do
    handle_writing_answer(socket, true)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => completed}, socket)
      when completed in ["false", false] do
    handle_writing_answer(socket, false)
  end

  @impl true
  def handle_event("kanji_complete", _params, socket) do
    handle_writing_answer(socket, true)
  end

  @impl true
  def handle_event("wrong_stroke", params, socket) do
    count = parse_wrong_strokes(params)
    {:noreply, assign(socket, :current_wrong_strokes, count)}
  end

  # Word order interactions
  @impl true
  def handle_event("word_order_click", %{"word" => word, "action" => "add"}, socket) do
    step = socket.assigns.current_step
    current_answer = socket.assigns.answer || []
    question_data = step.question_data || %{}
    available_words = parse_word_order_words(question_data["words"])

    used_count = Enum.count(current_answer, &(&1 == word))
    available_count = Enum.count(available_words, &(&1 == word))

    if used_count < available_count do
      {:noreply, assign(socket, :answer, current_answer ++ [word])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("word_order_remove", %{"index" => index}, socket) do
    index = String.to_integer(index)
    current_answer = socket.assigns.answer || []
    {:noreply, assign(socket, :answer, List.delete_at(current_answer, index))}
  end

  @impl true
  def handle_event("word_order_clear", _params, socket) do
    {:noreply, assign(socket, :answer, [])}
  end

  # ============================================================================
  # Answer evaluation (no DB writes)
  # ============================================================================

  defp handle_multichoice_answer(socket, answer, step) do
    if is_nil(answer) or String.trim(answer) == "" do
      {:noreply, socket}
    else
      is_correct = normalize_answer(answer) == normalize_answer(step.correct_answer)
      {:noreply, mark_feedback(socket, is_correct)}
    end
  end

  defp handle_listening_answer(socket, answer, step) do
    handle_multichoice_answer(socket, answer, step)
  end

  defp handle_image_to_meaning_answer(socket, answer) do
    step = socket.assigns.current_step

    if is_nil(answer) or String.trim(answer) == "" do
      {:noreply, put_flash(socket, :error, gettext("Please select an image"))}
    else
      is_correct = normalize_answer(answer) == normalize_answer(step.correct_answer)
      {:noreply, mark_feedback(socket, is_correct)}
    end
  end

  defp handle_fill_answer(socket, answer_map, step) when is_map(answer_map) do
    meaning = answer_map["meaning"] || ""
    include_reading = get_in(step.question_data, ["include_reading"]) || false
    correct_meaning = step.correct_answer
    correct_reading = get_in(step.question_data, ["reading_answer"]) || ""

    meaning_correct = validate_meaning(meaning, correct_meaning)

    reading_correct =
      if include_reading,
        do: validate_reading(answer_map["reading"] || "", correct_reading),
        else: true

    is_correct = meaning_correct and reading_correct

    socket =
      socket
      |> assign(:meaning_error, not meaning_correct)
      |> assign(:reading_error, include_reading and not reading_correct)
      |> assign(:correct_meaning, correct_meaning)
      |> assign(:correct_reading, correct_reading)
      |> assign(:show_hint, true)

    {:noreply, mark_feedback(socket, is_correct)}
  end

  defp handle_fill_answer(socket, _answer, _step) do
    {:noreply, put_flash(socket, :error, gettext("Please enter an answer"))}
  end

  defp handle_reading_text_answer(socket) do
    step = socket.assigns.current_step
    is_kana_only = step.question_data["is_kana_only"] || false
    meaning = String.trim(socket.assigns.meaning_answer)
    reading = String.trim(socket.assigns.reading_answer)

    if meaning == "" or (not is_kana_only and reading == "") do
      {:noreply, put_flash(socket, :error, gettext("Please enter both meaning and reading"))}
    else
      word = if step.word_id, do: Content.get_word!(step.word_id), else: nil

      if word do
        locale = socket.assigns.locale

        {:ok, validation} =
          ReadingAnswerValidator.validate_answer(
            word,
            meaning,
            reading,
            locale,
            skip_reading: is_kana_only
          )

        socket =
          socket
          |> assign(:feedback, if(validation.both_correct, do: :correct, else: :incorrect))
          |> assign(:meaning_error, not validation.meaning_correct)
          |> assign(:reading_error, not validation.reading_correct)
          |> assign(:correct_meaning, word.meaning)
          |> assign(:correct_reading, word.reading)
          |> assign(:show_hint, true)
          |> update_stats(validation.both_correct)

        {:noreply, socket}
      else
        {:noreply, put_flash(socket, :error, gettext("Error: word not found"))}
      end
    end
  end

  defp handle_writing_answer(socket, completed) do
    step = socket.assigns.current_step

    is_correct =
      if socket.assigns.test.metadata["kanji_drawing"] == true do
        step.points - socket.assigns.current_wrong_strokes > 0
      else
        completed
      end

    {:noreply, mark_feedback(socket, is_correct)}
  end

  defp handle_writing_fill_in_answer(socket) do
    step = socket.assigns.current_step

    answer =
      WritingFillInComponents.build_filled_sentence(
        step.question_data["template"] || "",
        socket.assigns.answer
      )

    question_data = step.question_data || %{}
    correct_answer = step.correct_answer
    alt_answers = question_data["alt_correct_answers"] || []
    normalized = normalize_answer(answer)

    is_correct =
      normalized == normalize_answer(correct_answer) ||
        Enum.any?(alt_answers, &(normalize_answer(&1) == normalized))

    {:noreply, mark_feedback(socket, is_correct)}
  end

  defp handle_sentence_validation_answer(socket, answer, step) do
    pattern = get_in(step.question_data, ["pattern"]) || []

    is_correct =
      case Validator.validate_sentence(answer, pattern) do
        {:ok, _breakdown} -> true
        {:error, _reason} -> false
      end

    {:noreply, mark_feedback(socket, is_correct)}
  end

  defp handle_conjugation_answer(socket, answer, step) do
    question_data = step.question_data || %{}
    correct_answer = question_data["generated_answer"] || step.correct_answer
    is_correct = normalize_answer(answer) == normalize_answer(correct_answer)

    {:noreply, mark_feedback(socket, is_correct)}
  end

  defp handle_conjugation_multichoice_answer(socket, answer, step) do
    question_data = step.question_data || %{}
    correct_answer = question_data["generated_answer"] || step.correct_answer
    is_correct = normalize_answer(answer) == normalize_answer(correct_answer)

    {:noreply, mark_feedback(socket, is_correct)}
  end

  defp handle_word_order_answer(socket, answer, step) do
    correct_answer = step.correct_answer
    is_correct = normalize_answer(answer) == normalize_answer(correct_answer)

    {:noreply, mark_feedback(socket, is_correct)}
  end

  defp handle_grammar_pattern_answer(socket, answer, step) do
    question_data = step.question_data || %{}
    correct_answer = step.correct_answer
    alt_answers = question_data["alt_correct_answers"] || []
    normalized = normalize_answer(answer)

    is_correct =
      normalized == normalize_answer(correct_answer) ||
        Enum.any?(alt_answers, &(normalize_answer(&1) == normalized))

    {:noreply, mark_feedback(socket, is_correct)}
  end

  # ============================================================================
  # State management helpers
  # ============================================================================

  defp mark_feedback(socket, is_correct) do
    socket
    |> assign(:feedback, if(is_correct, do: :correct, else: :incorrect))
    |> update_stats(is_correct)
  end

  defp update_stats(socket, true) do
    assign(socket, :correct_count, socket.assigns.correct_count + 1)
  end

  defp update_stats(socket, false) do
    assign(socket, :incorrect_count, socket.assigns.incorrect_count + 1)
  end

  defp move_to_next_step(socket) do
    next_index = socket.assigns.current_step_index + 1

    if next_index >= socket.assigns.total_steps do
      {:noreply, assign(socket, :test_completed, true)}
    else
      next_step = Enum.at(socket.assigns.steps, next_index)

      {:noreply,
       socket
       |> assign(:current_step_index, next_index)
       |> assign(:current_step, next_step)
       |> assign(:selected_answer, nil)
       |> assign(:feedback, nil)
       |> assign(:meaning_answer, "")
       |> assign(:reading_answer, "")
       |> assign(:answer, initial_answer_for_step(next_step))
       |> assign(:show_hint, false)
       |> assign(:correct_meaning, nil)
       |> assign(:correct_reading, nil)
       |> assign(:meaning_error, false)
       |> assign(:reading_error, false)
       |> assign(:writing_start_time, writing_start_time(next_step))
       |> assign(:current_wrong_strokes, 0)}
    end
  end

  defp initial_answer_for_step(nil), do: ""
  defp initial_answer_for_step(%{question_type: :fill}), do: %{"meaning" => "", "reading" => ""}
  defp initial_answer_for_step(%{question_type: :word_order}), do: []
  defp initial_answer_for_step(%{question_type: :sentence_validation}), do: ""
  defp initial_answer_for_step(%{question_type: :conjugation}), do: ""
  defp initial_answer_for_step(%{question_type: :grammar_pattern}), do: ""
  defp initial_answer_for_step(%{question_type: :writing_fill_in}), do: %{}

  defp initial_answer_for_step(%{question_type: :reading_text}),
    do: %{"meaning" => "", "reading" => ""}

  defp initial_answer_for_step(_), do: ""

  defp writing_start_time(%{question_type: :writing}), do: DateTime.utc_now()
  defp writing_start_time(_), do: nil

  # ============================================================================
  # Validation helpers
  # ============================================================================

  defp normalize_answer(answer) when is_binary(answer) do
    answer
    |> String.trim()
    |> String.replace(~r/\s+/, "")
    |> String.replace(~r/\p{P}/u, "")
  end

  defp normalize_answer(answer), do: to_string(answer)

  defp validate_meaning(answer, correct) do
    answer_normalized = String.downcase(String.trim(answer))
    correct_normalized = String.downcase(String.trim(correct))

    answer_normalized == correct_normalized or
      String.contains?(answer_normalized, correct_normalized) or
      String.contains?(correct_normalized, answer_normalized)
  end

  defp validate_reading(answer, correct) do
    answer_normalized =
      answer
      |> String.trim()
      |> String.replace(~r/[\s\-]/, "")

    correct_normalized =
      correct
      |> String.trim()
      |> String.replace(~r/[\s\-]/, "")

    answer_normalized == correct_normalized
  end

  defp parse_word_order_words(nil), do: []
  defp parse_word_order_words(words) when is_list(words), do: words

  defp parse_word_order_words(words) when is_binary(words) do
    words
    |> String.split(~r/[\n,]/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_wrong_strokes(params) when is_map(params) do
    case params do
      %{"wrong_strokes" => n} when is_integer(n) -> n
      %{"wrong_strokes" => n} when is_binary(n) -> String.to_integer(n)
      %{"count" => n} when is_integer(n) -> n
      %{"count" => n} when is_binary(n) -> String.to_integer(n)
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp parse_wrong_strokes(_), do: 0

  defp localize_option(option_text, locale) when locale in ["bg", "ja"] do
    case Content.get_word_by_meaning(option_text) do
      nil -> option_text
      word -> Content.get_localized_meaning(word, locale)
    end
  end

  defp localize_option(option_text, _locale), do: option_text

  defp vocabulary_question_prompt(step) do
    label = step.question_data["question_label"]

    cond do
      step.question_type == :image_to_meaning ->
        gettext("Choose the picture that matches this word")

      label == "reading" ->
        gettext("How do you read this word?")

      true ->
        gettext("What is the meaning of this word?")
    end
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto px-3 sm:px-4 py-4 sm:py-8" data-theme={@classroom.theme}>
        <%= if @test_completed do %>
          <%!-- Completion summary --%>
          <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 p-6 sm:p-8 text-center">
            <div class="w-16 h-16 sm:w-24 sm:h-24 bg-info/20 rounded-full flex items-center justify-center mx-auto mb-4 sm:mb-6">
              <.icon name="hero-eye" class="w-8 h-8 sm:w-12 sm:h-12 text-info" />
            </div>
            <h1 class="text-xl sm:text-2xl font-bold text-base-content mb-2">
              {gettext("Preview Complete")}
            </h1>
            <p class="text-secondary mb-4 sm:mb-6 text-sm sm:text-base">
              {gettext("You previewed '%{title}'", title: @test.title)}
            </p>

            <div class="grid grid-cols-3 gap-3 mb-6">
              <div class="bg-success/10 rounded-xl p-4">
                <div class="text-2xl sm:text-3xl font-bold text-success">{@correct_count}</div>
                <div class="text-xs sm:text-sm text-success-content/70">{gettext("Correct")}</div>
              </div>
              <div class="bg-error/10 rounded-xl p-4">
                <div class="text-2xl sm:text-3xl font-bold text-error">{@incorrect_count}</div>
                <div class="text-xs sm:text-sm text-error-content/70">{gettext("Incorrect")}</div>
              </div>
              <div class="bg-primary/10 rounded-xl p-4">
                <% percentage =
                  if @correct_count + @incorrect_count > 0,
                    do: round(@correct_count / (@correct_count + @incorrect_count) * 100),
                    else: 0 %>
                <div class="text-2xl sm:text-3xl font-bold text-primary">{percentage}{"%"}</div>
                <div class="text-xs sm:text-sm text-primary-content/70">{gettext("Score")}</div>
              </div>
            </div>

            <div class="flex flex-col sm:flex-row gap-3 justify-center">
              <.link
                navigate={~p"/teacher/classrooms/#{@classroom.id}?tab=tests"}
                class="inline-flex items-center justify-center gap-2 px-4 sm:px-6 py-2.5 sm:py-3 bg-primary text-primary-content rounded-xl font-medium hover:bg-primary/90 transition-colors min-h-[44px]"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5" /> {gettext("Back to Classroom")}
              </.link>
              <.link
                navigate={~p"/classrooms/#{@classroom.id}/tests/#{@test.id}/preview"}
                class="inline-flex items-center justify-center gap-2 px-4 sm:px-6 py-2.5 sm:py-3 bg-base-200 text-base-content rounded-xl font-medium hover:bg-base-300 transition-colors min-h-[44px]"
              >
                <.icon name="hero-arrow-path" class="w-5 h-5" /> {gettext("Preview Again")}
              </.link>
            </div>
          </div>
        <% else %>
          <%!-- Header --%>
          <div class="mb-4 sm:mb-8">
            <div class="flex items-center gap-2 text-xs sm:text-sm text-secondary mb-1 sm:mb-2">
              <.link
                navigate={~p"/teacher/classrooms/#{@classroom.id}?tab=tests"}
                class="hover:text-primary transition-colors flex items-center gap-1"
              >
                <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Classroom")}
              </.link>
            </div>
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-xl sm:text-2xl font-bold text-base-content">
                  {gettext("Preview Test")}
                </h1>
                <p class="text-secondary mt-1 text-sm sm:text-base">
                  {@test.title}
                </p>
              </div>
              <span class="badge badge-info badge-sm">
                <.icon name="hero-eye" class="w-3 h-3 mr-1" /> {gettext("Teacher Preview")}
              </span>
            </div>
          </div>

          <%= if @current_step do %>
            <%!-- Progress --%>
            <div class="mb-4 sm:mb-8">
              <div class="flex justify-between text-xs sm:text-sm mb-1 sm:mb-2">
                <span class="text-secondary">
                  {gettext("Question %{current} of %{total}",
                    current: @current_step_index + 1,
                    total: @total_steps
                  )}
                </span>
                <% progress = round((@current_step_index + 1) / @total_steps * 100) %>
                <span class="text-secondary">{progress}{"%"} {gettext("complete")}</span>
              </div>
              <div class="h-1.5 sm:h-2 bg-base-200 rounded-full overflow-hidden">
                <div
                  class="h-full bg-primary transition-all duration-300"
                  style={"width: #{(@current_step_index + 1) / @total_steps * 100}%"}
                >
                </div>
              </div>
            </div>

            <%!-- Question card --%>
            <div
              id="question-card"
              data-share-picture
              class="bg-base-100 rounded-2xl shadow-sm border border-base-200 p-4 sm:p-6 mb-4 sm:mb-6"
            >
              <%!-- Question header --%>
              <div class="mb-4 sm:mb-6">
                <span class="badge badge-outline badge-xs sm:badge-sm mb-2 sm:mb-4">
                  {@current_step.question_type
                  |> to_string()
                  |> String.replace("_", " ")
                  |> String.capitalize()}
                </span>

                <%= if @current_step.step_type == :vocabulary do %>
                  <p class="text-sm sm:text-base text-secondary mb-2 sm:mb-3">
                    {vocabulary_question_prompt(@current_step)}
                  </p>
                  <h2 class="text-2xl sm:text-3xl font-bold text-primary font-japanese text-center">
                    {@current_step.question_data["word_text"] || @current_step.question}
                  </h2>
                  <%= if @current_step.question_data["word_reading"] && @current_step.question_data["question_label"] != "reading" do %>
                    <p class="text-center text-secondary text-sm sm:text-base mt-2">
                      {gettext("Reading:")} {@current_step.question_data["word_reading"]}
                    </p>
                  <% end %>
                  <%= if @current_step.question_data["word_meaning"] && @current_step.question_data["question_label"] == "reading" do %>
                    <p class="text-center text-secondary text-sm sm:text-base mt-2">
                      {gettext("Meaning:")} {@current_step.question_data["word_meaning"]}
                    </p>
                  <% end %>
                <% else %>
                  <%= if @current_step.question_type != :writing do %>
                    <h2 class="text-lg sm:text-xl font-medium text-base-content leading-relaxed">
                      {@current_step.question}
                    </h2>
                  <% end %>
                <% end %>
              </div>

              <%!-- Feedback --%>
              <%= if @feedback == :correct do %>
                <div class="bg-success/10 rounded-xl p-4 sm:p-6 mb-4 sm:mb-6">
                  <div class="flex items-center gap-3">
                    <.icon name="hero-check-circle" class="w-8 h-8 text-success" />
                    <div>
                      <p class="font-semibold text-success text-lg">{gettext("Correct!")}</p>
                      <%= if @current_step.explanation do %>
                        <p class="text-success-content/80">{@current_step.explanation}</p>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if @feedback == :incorrect do %>
                <div class="bg-error/10 rounded-xl p-4 sm:p-6 mb-4 sm:mb-6">
                  <div class="flex items-start gap-3">
                    <.icon name="hero-x-circle" class="w-8 h-8 text-error shrink-0" />
                    <div>
                      <p class="font-semibold text-error text-lg">{gettext("Incorrect")}</p>
                      <p class="text-error-content/80">
                        {gettext("The correct answer is: %{answer}",
                          answer: @current_step.correct_answer
                        )}
                      </p>
                      <%= if @current_step.explanation do %>
                        <p class="text-error-content/80 mt-1">{@current_step.explanation}</p>
                      <% end %>
                      <%= if @correct_meaning do %>
                        <div class="mt-2 text-error-content/80">
                          <p>{gettext("Meaning:")} {@correct_meaning}</p>
                          <%= if @correct_reading do %>
                            <p>{gettext("Reading:")} {@correct_reading}</p>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>

              <%!-- Answer form --%>
              <form
                phx-submit={
                  if @current_step.question_type == :reading_text,
                    do: "submit_reading_text",
                    else: "submit_answer"
                }
                class="space-y-4"
              >
                <%= case @current_step.question_type do %>
                  <% :multichoice -> %>
                    {render_options(assigns, @current_step.options, false)}
                  <% :picture_multichoice -> %>
                    {render_options(assigns, @current_step.options, true)}
                  <% :listening -> %>
                    <div class="space-y-4">
                      <%= if @current_step.question_data["audio_path"] do %>
                        <div class="bg-base-200 rounded-xl p-4">
                          <audio controls class="w-full">
                            <source src={@current_step.question_data["audio_path"]} />
                            {gettext("Your browser does not support the audio element.")}
                          </audio>
                        </div>
                      <% end %>
                      {render_options(assigns, @current_step.options, false)}
                    </div>
                  <% :reading_text -> %>
                    <MedoruWeb.LessonTestLive.ReadingTextComponent.reading_text_question
                      step={@current_step}
                      meaning_answer={@meaning_answer}
                      reading_answer={@reading_answer}
                      feedback={@feedback}
                      show_hint={@show_hint}
                      meaning_error={@meaning_error}
                      reading_error={@reading_error}
                      correct_meaning={@correct_meaning}
                      correct_reading={@correct_reading}
                    />
                  <% :writing -> %>
                    <MedoruWeb.LessonTestLive.WritingComponent.writing_question
                      step={@current_step}
                      target="writing-component"
                      locale={@locale}
                      show_submit={is_nil(@feedback)}
                      kanji_drawing={@test.metadata["kanji_drawing"] == true}
                      challenge_base={0}
                      total_points={@test.total_points}
                      current_wrong_strokes={@current_wrong_strokes}
                    />
                    <input type="hidden" name="answer" value="skipped" />
                  <% :fill -> %>
                    <div class="space-y-4" id={"fill-inputs-#{@current_step.id}"}>
                      <input type="hidden" name="answer[_dummy]" value="1" />
                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          {gettext("Meaning (in English):")}
                        </label>
                        <.input
                          type="text"
                          name="answer[meaning]"
                          id={"answer-meaning-#{@current_step.id}"}
                          value={@answer["meaning"] || ""}
                          placeholder={gettext("Type the meaning...")}
                          class="w-full"
                          disabled={@feedback != nil}
                        />
                      </div>
                      <%= if @current_step.question_data && @current_step.question_data["include_reading"] do %>
                        <div>
                          <label class="block text-sm font-medium text-base-content mb-2">
                            {gettext("Reading (in Hiragana):")}
                          </label>
                          <.input
                            type="text"
                            name="answer[reading]"
                            id={"answer-reading-#{@current_step.id}"}
                            value={@answer["reading"] || ""}
                            placeholder={gettext("Type the hiragana reading...")}
                            class="w-full"
                            disabled={@feedback != nil}
                          />
                        </div>
                      <% end %>
                    </div>
                  <% :sentence_validation -> %>
                    <GrammarComponents.sentence_validation_question
                      step={@current_step}
                      answer={@answer}
                      step_id={@current_step.id}
                    />
                  <% :conjugation -> %>
                    <GrammarComponents.conjugation_question
                      step={@current_step}
                      answer={@answer}
                      step_id={@current_step.id}
                    />
                  <% :conjugation_multichoice -> %>
                    <GrammarComponents.conjugation_multichoice_question
                      step={@current_step}
                      step_id={@current_step.id}
                    />
                  <% :word_order -> %>
                    <GrammarComponents.word_order_question
                      step={@current_step}
                      step_id={@current_step.id}
                      answer={@answer}
                    />
                  <% :grammar_pattern -> %>
                    <GrammarComponents.grammar_pattern_question
                      step={@current_step}
                      step_id={@current_step.id}
                      answer={@answer}
                    />
                  <% :writing_fill_in -> %>
                    <WritingFillInComponents.fill_in_question
                      step={@current_step}
                      answers={@answer}
                      input_event="update_writing_fill_in"
                      disabled={@feedback != nil}
                    />
                  <% :image_to_meaning -> %>
                    <div class="space-y-4">
                      <%= if @current_step.question_data["word_reading"] do %>
                        <p class="text-center text-secondary text-sm sm:text-base">
                          {gettext("Reading:")} {@current_step.question_data["word_reading"]}
                        </p>
                      <% end %>
                      <div class="grid grid-cols-2 gap-3 sm:gap-4">
                        <%= for {option, index} <- Enum.with_index(@current_step.options) do %>
                          <% image_data =
                            @current_step.question_data["image_options"] |> Enum.at(index) %>
                          <% is_selected = @selected_answer == option %>
                          <% is_correct =
                            @feedback != nil and
                              normalize_answer(option) ==
                                normalize_answer(@current_step.correct_answer) %>
                          <% is_wrong_selected = @feedback != nil and is_selected and not is_correct %>
                          <button
                            type="button"
                            phx-click="select_answer"
                            phx-value-answer={option}
                            disabled={@feedback != nil}
                            class={[
                              "relative rounded-xl border-2 overflow-hidden aspect-square transition-all duration-200",
                              if(is_correct,
                                do: "border-success ring-2 ring-success",
                                else: ""
                              ),
                              if(is_wrong_selected,
                                do: "border-error ring-2 ring-error",
                                else: ""
                              ),
                              if(@feedback == nil and is_selected,
                                do: "border-primary ring-2 ring-primary",
                                else: ""
                              ),
                              if(@feedback == nil and not is_selected,
                                do: "border-base-200 hover:border-primary/50 hover:shadow-md",
                                else: ""
                              ),
                              if(@feedback != nil and not is_correct and not is_wrong_selected,
                                do: "border-base-200 opacity-60",
                                else: ""
                              )
                            ]}
                          >
                            <%= if image_data && image_data["image_path"] do %>
                              <img
                                src={image_data["image_path"]}
                                alt={option}
                                class="w-full h-full object-cover"
                                loading="lazy"
                              />
                            <% else %>
                              <div class="w-full h-full flex items-center justify-center bg-base-200">
                                <span class="text-secondary text-sm text-center px-2">
                                  {option}
                                </span>
                              </div>
                            <% end %>
                            <%= if is_correct do %>
                              <div class="absolute top-2 right-2 bg-success text-success-content rounded-full p-1">
                                <.icon name="hero-check" class="w-4 h-4" />
                              </div>
                            <% end %>
                            <%= if is_wrong_selected do %>
                              <div class="absolute top-2 right-2 bg-error text-error-content rounded-full p-1">
                                <.icon name="hero-x-mark" class="w-4 h-4" />
                              </div>
                            <% end %>
                          </button>
                        <% end %>
                      </div>
                      <%= if is_nil(@selected_answer) do %>
                        <input type="hidden" name="answer" value="" />
                      <% else %>
                        <input type="hidden" name="answer" value={@selected_answer} />
                      <% end %>
                    </div>
                  <% _ -> %>
                    <div class="bg-warning/10 border border-warning/30 rounded-xl p-4">
                      <p class="text-warning">
                        <.icon name="hero-exclamation-triangle" class="w-5 h-5 mr-2" />
                        {gettext("Preview is not available for this question type yet.")}
                      </p>
                    </div>
                <% end %>

                <%!-- Actions --%>
                <div
                  data-share-exclude
                  class="flex flex-col sm:flex-row justify-between items-stretch gap-3 pt-4 border-t border-base-200"
                >
                  <%= if is_nil(@feedback) do %>
                    <button
                      type="submit"
                      class="w-full sm:w-auto btn btn-primary order-1 min-h-[48px]"
                    >
                      <%= if @current_step_index == @total_steps - 1 do %>
                        <.icon name="hero-check" class="w-4 h-4 mr-2" /> {gettext("Finish Preview")}
                      <% else %>
                        <.icon name="hero-arrow-right" class="w-4 h-4 mr-2" />
                        {gettext("Submit Answer")}
                      <% end %>
                    </button>

                    <button
                      type="button"
                      phx-click="skip_question"
                      class="w-full sm:w-auto sm:ml-auto btn btn-outline order-3 min-h-[48px]"
                    >
                      {gettext("Skip →")}
                    </button>
                  <% else %>
                    <button
                      type="button"
                      phx-click="next_step"
                      class="w-full sm:w-auto btn btn-primary order-1 min-h-[48px]"
                    >
                      <%= if @current_step_index == @total_steps - 1 do %>
                        <.icon name="hero-check" class="w-4 h-4 mr-2" /> {gettext("Finish Preview")}
                      <% else %>
                        {gettext("Continue →")}
                      <% end %>
                    </button>
                  <% end %>

                  <button
                    type="button"
                    id={"share-picture-button-#{@current_step.id}"}
                    phx-hook="ShareAsPicture"
                    data-filename={"medoru-#{safe_filename(@test.title)}-q#{@current_step_index + 1}.png"}
                    disabled={@current_step.question_type == :writing}
                    class="w-full sm:w-auto btn btn-outline order-2 min-h-[48px]"
                  >
                    <.icon name="hero-camera" class="w-4 h-4 mr-2" />
                    {gettext("Share as picture")}
                  </button>
                </div>
              </form>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp safe_filename(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\-]+/u, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "question"
      name -> name
    end
  end

  defp render_options(assigns, options, picture) do
    assigns =
      assigns
      |> assign(:options, options)
      |> assign(:picture, picture)

    ~H"""
    <div class="space-y-2">
      <%= for option <- @options do %>
        <% display_option =
          if @current_step.question_data["question_label"] != "reading",
            do: localize_option(option, @locale),
            else: option %>
        <% is_correct =
          @feedback != nil and
            normalize_answer(option) == normalize_answer(@current_step.correct_answer) %>
        <% is_wrong_selected = @feedback != nil and @selected_answer == option and not is_correct %>
        <%= if @picture do %>
          <% image_option =
            Enum.find(@current_step.question_data["image_options"] || [], &(&1["word"] == option)) %>
          <button
            type="button"
            phx-click="select_answer"
            phx-value-answer={option}
            disabled={@feedback != nil}
            class={[
              "w-full flex items-center gap-3 p-4 bg-base-200 rounded-lg transition-colors border-2",
              if(is_correct,
                do: "border-success bg-success/10",
                else: ""
              ),
              if(is_wrong_selected,
                do: "border-error bg-error/10",
                else: ""
              ),
              if(@feedback == nil and @selected_answer == option,
                do: "border-primary bg-primary/5",
                else: ""
              ),
              if(@feedback == nil and @selected_answer != option,
                do: "border-transparent hover:bg-base-300",
                else: ""
              ),
              if(@feedback != nil and not is_correct and not is_wrong_selected,
                do: "border-transparent opacity-60",
                else: ""
              )
            ]}
          >
            <%= if image_option && image_option["image_path"] do %>
              <img
                src={image_option["image_path"]}
                alt={option}
                class="w-12 h-12 object-cover rounded-lg"
              />
            <% end %>
            <span class="text-base-content">{display_option}</span>
            <%= if is_correct do %>
              <.icon name="hero-check-circle" class="w-5 h-5 text-success ml-auto" />
            <% end %>
            <%= if is_wrong_selected do %>
              <.icon name="hero-x-circle" class="w-5 h-5 text-error ml-auto" />
            <% end %>
          </button>
        <% else %>
          <label class={[
            "flex items-center gap-3 p-4 rounded-lg transition-colors border-2",
            if(@feedback == nil, do: "cursor-pointer", else: ""),
            if(is_correct,
              do: "bg-success/10 border-success",
              else: ""
            ),
            if(is_wrong_selected,
              do: "bg-error/10 border-error",
              else: ""
            ),
            if(@feedback == nil and @selected_answer == option,
              do: "bg-primary/5 border-primary",
              else: ""
            ),
            if(@feedback == nil and @selected_answer != option,
              do: "bg-base-200 border-transparent hover:bg-base-300",
              else: ""
            ),
            if(@feedback != nil and not is_correct and not is_wrong_selected,
              do: "bg-base-200 border-transparent opacity-60",
              else: ""
            )
          ]}>
            <input
              type="radio"
              name="answer"
              value={option}
              checked={@selected_answer == option}
              disabled={@feedback != nil}
              required
              class={[
                "radio",
                if(is_correct, do: "radio-success", else: ""),
                if(is_wrong_selected, do: "radio-error", else: ""),
                if(@feedback == nil, do: "radio-primary", else: "")
              ]}
            />
            <span class="text-base-content">{display_option}</span>
            <%= if is_correct do %>
              <.icon name="hero-check-circle" class="w-5 h-5 text-success ml-auto" />
            <% end %>
            <%= if is_wrong_selected do %>
              <.icon name="hero-x-circle" class="w-5 h-5 text-error ml-auto" />
            <% end %>
          </label>
        <% end %>
      <% end %>
    </div>
    """
  end
end
