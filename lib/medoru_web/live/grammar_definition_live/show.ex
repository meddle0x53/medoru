defmodule MedoruWeb.GrammarDefinitionLive.Show do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Content.GrammarDefinition
  alias Medoru.Grammar.Validator
  alias Medoru.Learning

  embed_templates "show.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:user_sentence, "")
     |> assign(:validation_result, nil)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    case Content.get_grammar_definition_by_slug(slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Grammar point not found."))
         |> push_navigate(to: ~p"/grammars")}

      grammar_definition ->
        grammar_learned =
          if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
            Learning.grammar_learned?(socket.assigns.current_scope.current_user.id, grammar_definition.id)
          else
            false
          end

        {:noreply,
         socket
         |> assign(:page_title, grammar_definition.title)
         |> assign(:grammar_definition, grammar_definition)
         |> assign(:grammar_learned, grammar_learned)}
    end
  end

  @impl true
  def handle_event("update_sentence", %{"sentence" => sentence}, socket) do
    {:noreply, assign(socket, :user_sentence, sentence)}
  end

  @impl true
  def handle_event("validate_sentence", _, socket) do
    sentence = String.trim(socket.assigns.user_sentence)
    grammar = socket.assigns.grammar_definition

    if sentence == "" do
      {:noreply,
       put_flash(socket, :error, gettext("Please enter a sentence to validate."))}
    else
      result =
        case Validator.validate_sentence(sentence, grammar.pattern_elements) do
          {:ok, _} ->
            %{valid: true, message: gettext("Your sentence matches the pattern!")}

          {:error, %{expected: expected, got: got}} when got == "" or is_nil(got) ->
            %{
              valid: false,
              message:
                gettext(
                  "Doesn't match. Expected: %{expected}.",
                  expected: expected
                )
            }

          {:error, reason} ->
            %{
              valid: false,
              message:
                gettext(
                  "Doesn't match. Expected: %{expected}, but got: %{got}.",
                  expected: reason[:expected] || gettext("pattern"),
                  got: reason[:got] || gettext("nothing")
                )
            }
        end

      {:noreply, assign(socket, :validation_result, result)}
    end
  end

  @impl true
  def handle_event("mark_grammar_learned", _params, socket) do
    user_id = socket.assigns.current_scope.current_user.id
    grammar = socket.assigns.grammar_definition

    case Learning.track_grammar_learned(user_id, grammar.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:grammar_learned, true)
         |> put_flash(:info, gettext("%{grammar} marked as learned!", grammar: grammar.title))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not mark grammar as learned."))}
    end
  end

  @impl true
  def handle_event("unlearn_grammar", _params, socket) do
    user_id = socket.assigns.current_scope.current_user.id
    grammar = socket.assigns.grammar_definition

    case Learning.unlearn_grammar(user_id, grammar.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:grammar_learned, false)
         |> put_flash(:info, gettext("%{grammar} removed from learned list.", grammar: grammar.title))}

      {:error, :not_learned} ->
        {:noreply,
         socket
         |> assign(:grammar_learned, false)
         |> put_flash(:error, gettext("Grammar was not learned."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not unlearn grammar."))}
    end
  end

  def localized_description(%GrammarDefinition{} = gd, locale) do
    GrammarDefinition.localized_description(gd, locale)
  end

  def localized_example_meaning(example, locale) do
    GrammarDefinition.localized_example_meaning(example, locale)
  end

  def render_description(description) when is_binary(description) do
    case Earmark.as_html(description, escape: false, smartypants: false) do
      {:ok, html, _} -> html
      _ -> description
    end
  end

  def render_description(_), do: ""

  defp level_badge_color(5), do: "badge-success"
  defp level_badge_color(4), do: "badge-info"
  defp level_badge_color(3), do: "badge-warning"
  defp level_badge_color(2), do: "badge-error"
  defp level_badge_color(1), do: "badge-secondary"
  defp level_badge_color(_), do: "badge-ghost"
end
