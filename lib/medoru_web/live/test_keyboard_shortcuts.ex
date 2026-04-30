defmodule MedoruWeb.TestKeyboardShortcuts do
  @moduledoc """
  Shared keyboard shortcut handling for test LiveViews.

  Supports 1-9 option selection and Enter/ArrowRight submission
  for multichoice questions.
  """

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Handles keyboard input for multichoice test steps.

  ## Options

    * `:options_from` - Function to extract options from the current step.
      Defaults to checking `step.question_data["options"]` then `step.options`.
    * `:submit_event` - Event to emit on Enter/ArrowRight when an answer is
      selected. Defaults to `"submit_answer"`.

  ## Returns

    * `{:noreply, socket}` - No action taken
    * `{:submit, event_name}` - Caller should delegate to `handle_event/3`
  """
  def handle_multichoice_key(socket, key, opts \\ []) do
    options = get_options(socket.assigns.current_step, opts)
    submit_event = Keyword.get(opts, :submit_event, "submit_answer")

    cond do
      key in ["1", "2", "3", "4", "5", "6", "7", "8", "9"] ->
        index = String.to_integer(key) - 1

        if index < length(options) do
          selected = Enum.at(options, index)
          {:noreply, assign(socket, :selected_answer, selected)}
        else
          {:noreply, socket}
        end

      key in ["Enter", "ArrowRight"] && socket.assigns.selected_answer != nil ->
        {:submit, submit_event}

      true ->
        {:noreply, socket}
    end
  end

  defp get_options(step, opts) do
    if fun = Keyword.get(opts, :options_from) do
      fun.(step) || []
    else
      step.options || (step.question_data || %{})["options"] || []
    end
  end
end
