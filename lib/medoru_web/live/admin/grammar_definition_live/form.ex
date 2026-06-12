defmodule MedoruWeb.Admin.GrammarDefinitionLive.Form do
  @moduledoc """
  Admin form for creating and editing grammar definitions.
  Reuses the pattern builder from grammar lessons.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Content.GrammarDefinition
  alias Medoru.Grammar.Validator

  embed_templates "form/*"

  @word_types [
    {"Verb", "verb"},
    {"Adjective", "adjective"},
    {"Noun", "noun"},
    {"Particle", "particle"},
    {"Expression", "expression"}
  ]

  @particles [
    {"は (wa)", "は"},
    {"が (ga)", "が"},
    {"を (wo)", "を"},
    {"に (ni)", "に"},
    {"で (de)", "で"},
    {"へ (e)", "へ"},
    {"と (to)", "と"},
    {"から (kara)", "から"},
    {"まで (made)", "まで"},
    {"より (yori)", "より"},
    {"も (mo)", "も"},
    {"や (ya)", "や"},
    {"の (no)", "の"},
    {"か (ka)", "か"},
    {"ね (ne)", "ね"},
    {"よ (yo)", "よ"},
    {"わ (wa)", "わ"},
    {"ぞ (zo)", "ぞ"},
    {"ぜ (ze)", "ぜ"},
    {"な (na)", "な"},
    {"さ (sa)", "さ"},
    {"っけ (kke)", "っけ"},
    {"もの (mono)", "もの"},
    {"くらい (kurai)", "くらい"},
    {"ぐらい (gurai)", "ぐらい"},
    {"だけ (dake)", "だけ"},
    {"しか (shika)", "しか"},
    {"など (nado)", "など"}
  ]

  @word_type_colors %{
    "verb" => "bg-emerald-500 text-white",
    "noun" => "bg-blue-500 text-white",
    "adjective" => "bg-rose-500 text-white",
    "expression" => "bg-amber-400 text-amber-950",
    "particle" => "bg-orange-500 text-white"
  }

  @color_palette [
    "bg-red-200",
    "bg-red-300",
    "bg-orange-200",
    "bg-orange-300",
    "bg-amber-200",
    "bg-amber-300",
    "bg-yellow-200",
    "bg-yellow-300",
    "bg-lime-200",
    "bg-lime-300",
    "bg-green-200",
    "bg-green-300",
    "bg-emerald-200",
    "bg-emerald-300",
    "bg-teal-200",
    "bg-teal-300",
    "bg-cyan-200",
    "bg-cyan-300",
    "bg-sky-200",
    "bg-sky-300",
    "bg-blue-200",
    "bg-blue-300",
    "bg-indigo-200",
    "bg-indigo-300",
    "bg-violet-200",
    "bg-violet-300",
    "bg-purple-200",
    "bg-purple-300",
    "bg-fuchsia-200",
    "bg-fuchsia-300",
    "bg-pink-200",
    "bg-pink-300",
    "bg-rose-200",
    "bg-rose-300"
  ]

  @impl true
  def render(assigns) do
    ~H"""
    {form_template(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    grammar_forms = Content.list_grammar_forms()
    word_classes = Content.list_word_classes()

    {:ok,
     socket
     |> assign(:word_types, @word_types)
     |> assign(:particles, @particles)
     |> assign(:word_type_colors, @word_type_colors)
     |> assign(:color_palette, @color_palette)
     |> assign(:grammar_forms, grammar_forms)
     |> assign(:word_classes, word_classes)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {grammar_definition, changeset, form_data} =
      case socket.assigns.live_action do
        :new ->
          gd = %GrammarDefinition{}
          changeset = Content.change_grammar_definition(gd)

          form_data = %{
            title: "",
            slug: "",
            jlpt_level: 5,
            frequency: 1000,
            pattern_elements: [],
            word_colors: [],
            description: "",
            description_bg: "",
            description_ja: "",
            examples: []
          }

          {gd, changeset, form_data}

        :edit ->
          gd = Content.get_grammar_definition!(params["id"])
          changeset = Content.change_grammar_definition(gd)

          form_data = %{
            title: gd.title,
            slug: gd.slug,
            jlpt_level: gd.jlpt_level || 5,
            frequency: gd.frequency || 1000,
            pattern_elements: gd.pattern_elements || [],
            word_colors: gd.word_colors || [],
            description: gd.description || "",
            description_bg: gd.description_bg || "",
            description_ja: gd.description_ja || "",
            examples: gd.examples || []
          }

          {gd, changeset, form_data}
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:grammar_definition, grammar_definition)
     |> assign(:changeset, changeset)
     |> assign(:form_data, form_data)
     |> assign(:errors, %{})}
  end

  @impl true
  def handle_event("validate", %{"grammar_definition" => params}, socket) do
    changeset =
      socket.assigns.grammar_definition
      |> Content.change_grammar_definition(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    save_grammar_definition(socket, socket.assigns.live_action, %{})
  end

  @impl true
  def handle_event("update_field", params, socket) do
    field = params["field"]
    value = params[field] || params["value"] || ""
    form_data = put_in_form_data(socket.assigns.form_data, field, value)
    {:noreply, assign(socket, :form_data, form_data)}
  end

  # Pattern element events
  @impl true
  def handle_event("add_pattern_element", %{"type" => type}, socket) do
    form_data = socket.assigns.form_data
    element = create_pattern_element(type)
    elements = form_data.pattern_elements ++ [element]
    {:noreply, assign(socket, :form_data, %{form_data | pattern_elements: elements})}
  end

  @impl true
  def handle_event("update_element_word_type", %{"index" => index, "value" => value}, socket) do
    form_data = socket.assigns.form_data

    elements =
      update_in_list(form_data.pattern_elements, String.to_integer(index), fn el ->
        el
        |> Map.put("word_type", value)
        |> Map.put("forms", [])
      end)

    {:noreply, assign(socket, :form_data, %{form_data | pattern_elements: elements})}
  end

  @impl true
  def handle_event("update_element_form", %{"index" => index, "value" => value}, socket) do
    form_data = socket.assigns.form_data

    elements =
      update_in_list(form_data.pattern_elements, String.to_integer(index), fn el ->
        forms = if value == "", do: [], else: [value]
        Map.put(el, "forms", forms)
      end)

    {:noreply, assign(socket, :form_data, %{form_data | pattern_elements: elements})}
  end

  @impl true
  def handle_event("update_element_word_class", %{"index" => index, "value" => value}, socket) do
    form_data = socket.assigns.form_data

    elements =
      update_in_list(form_data.pattern_elements, String.to_integer(index), fn el ->
        Map.put(el, "word_class_id", value)
      end)

    {:noreply, assign(socket, :form_data, %{form_data | pattern_elements: elements})}
  end

  @impl true
  def handle_event("update_element_text", %{"index" => index, "value" => value}, socket) do
    form_data = socket.assigns.form_data

    elements =
      update_in_list(form_data.pattern_elements, String.to_integer(index), fn el ->
        Map.put(el, "text", value)
      end)

    {:noreply, assign(socket, :form_data, %{form_data | pattern_elements: elements})}
  end

  @impl true
  def handle_event("remove_pattern_element", %{"index" => index}, socket) do
    form_data = socket.assigns.form_data
    elements = List.delete_at(form_data.pattern_elements, String.to_integer(index))
    {:noreply, assign(socket, :form_data, %{form_data | pattern_elements: elements})}
  end

  @impl true
  def handle_event("toggle_optional", %{"index" => index}, socket) do
    form_data = socket.assigns.form_data

    elements =
      update_in_list(form_data.pattern_elements, String.to_integer(index), fn el ->
        Map.put(el, "optional", !Map.get(el, "optional", false))
      end)

    {:noreply, assign(socket, :form_data, %{form_data | pattern_elements: elements})}
  end

  # Example events
  @impl true
  def handle_event("add_example", _, socket) do
    form_data = socket.assigns.form_data

    if length(form_data.examples) >= 5 do
      {:noreply, put_flash(socket, :error, gettext("Maximum 5 examples allowed."))}
    else
      examples =
        form_data.examples ++
          [
            %{
              "sentence" => "",
              "reading" => "",
              "meaning" => "",
              "meaning_bg" => "",
              "meaning_ja" => ""
            }
          ]

      {:noreply, assign(socket, :form_data, %{form_data | examples: examples})}
    end
  end

  @impl true
  def handle_event(
        "update_example",
        %{"index" => index, "field" => field, "value" => value},
        socket
      ) do
    form_data = socket.assigns.form_data

    examples =
      update_in_list(form_data.examples, String.to_integer(index), fn ex ->
        Map.put(ex, field, value)
      end)

    {:noreply, assign(socket, :form_data, %{form_data | examples: examples})}
  end

  @impl true
  def handle_event("remove_example", %{"index" => index}, socket) do
    form_data = socket.assigns.form_data
    examples = List.delete_at(form_data.examples, String.to_integer(index))
    {:noreply, assign(socket, :form_data, %{form_data | examples: examples})}
  end

  @impl true
  def handle_event("validate_example", %{"index" => index}, socket) do
    form_data = socket.assigns.form_data
    example = Enum.at(form_data.examples, String.to_integer(index))
    sentence = example["sentence"] || ""

    if String.trim(sentence) == "" do
      {:noreply,
       put_flash(socket, :error, gettext("Please enter a Japanese sentence before validating."))}
    else
      case Validator.validate_sentence(sentence, form_data.pattern_elements) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, gettext("Example is valid!"))}

        {:error, %{expected: expected, got: got}} when got == "" or is_nil(got) ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext("Example doesn't match pattern. Expected: %{expected}.", expected: expected)
           )}

        {:error, reason} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext(
               "Example doesn't match pattern. Expected: %{expected}, but got: %{got}.",
               expected: reason[:expected] || gettext("pattern"),
               got: reason[:got] || gettext("nothing")
             )
           )}
      end
    end
  end

  # Word color events
  @impl true
  def handle_event("add_word_color", _, socket) do
    form_data = socket.assigns.form_data

    colors =
      form_data.word_colors ++ [%{"word" => "", "color_index" => 0, "apply_to" => "both"}]

    {:noreply, assign(socket, :form_data, %{form_data | word_colors: colors})}
  end

  @impl true
  def handle_event(
        "update_word_color",
        %{"index" => index, "field" => field, "value" => value},
        socket
      ) do
    form_data = socket.assigns.form_data

    colors =
      update_in_list(form_data.word_colors, String.to_integer(index), fn color ->
        value = if field == "color_index", do: String.to_integer(value), else: value
        Map.put(color, field, value)
      end)

    {:noreply, assign(socket, :form_data, %{form_data | word_colors: colors})}
  end

  @impl true
  def handle_event("remove_word_color", %{"index" => index}, socket) do
    form_data = socket.assigns.form_data
    colors = List.delete_at(form_data.word_colors, String.to_integer(index))
    {:noreply, assign(socket, :form_data, %{form_data | word_colors: colors})}
  end

  defp save_grammar_definition(socket, :edit, _params) do
    form_data = socket.assigns.form_data

    attrs = %{
      "title" => form_data.title,
      "jlpt_level" => form_data.jlpt_level,
      "frequency" => form_data.frequency,
      "pattern_elements" => form_data.pattern_elements,
      "word_colors" => form_data.word_colors,
      "description" => form_data.description,
      "description_bg" => form_data.description_bg,
      "description_ja" => form_data.description_ja,
      "examples" => form_data.examples
    }

    case Content.update_grammar_definition(socket.assigns.grammar_definition, attrs) do
      {:ok, _grammar_definition} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Grammar point updated successfully."))
         |> push_navigate(to: ~p"/admin/grammars")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)
        {:noreply, socket |> assign(:changeset, changeset) |> assign(:errors, errors)}
    end
  end

  defp save_grammar_definition(socket, :new, _params) do
    form_data = socket.assigns.form_data

    attrs = %{
      "title" => form_data.title,
      "jlpt_level" => form_data.jlpt_level,
      "frequency" => form_data.frequency,
      "pattern_elements" => form_data.pattern_elements,
      "word_colors" => form_data.word_colors,
      "description" => form_data.description,
      "description_bg" => form_data.description_bg,
      "description_ja" => form_data.description_ja,
      "examples" => form_data.examples
    }

    case Content.create_grammar_definition(attrs) do
      {:ok, _grammar_definition} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Grammar point created successfully."))
         |> push_navigate(to: ~p"/admin/grammars")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)
        {:noreply, socket |> assign(:changeset, changeset) |> assign(:errors, errors)}
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Map.new()
  end

  defp put_in_form_data(form_data, "title", value), do: %{form_data | title: value}

  defp put_in_form_data(form_data, "jlpt_level", value),
    do: %{form_data | jlpt_level: String.to_integer(value)}

  defp put_in_form_data(form_data, "frequency", value),
    do: %{form_data | frequency: String.to_integer(value)}

  defp put_in_form_data(form_data, "description", value), do: %{form_data | description: value}

  defp put_in_form_data(form_data, "description_bg", value),
    do: %{form_data | description_bg: value}

  defp put_in_form_data(form_data, "description_ja", value),
    do: %{form_data | description_ja: value}

  defp put_in_form_data(form_data, _, _), do: form_data

  defp update_in_list(list, index, fun) do
    item = Enum.at(list, index)
    List.replace_at(list, index, fun.(item))
  end

  defp create_pattern_element("word_slot") do
    %{
      "type" => "word_slot",
      "word_type" => "verb",
      "forms" => [],
      "optional" => false
    }
  end

  defp create_pattern_element("word_class") do
    %{
      "type" => "word_class",
      "word_class_id" => nil,
      "optional" => false
    }
  end

  defp create_pattern_element("literal") do
    %{
      "type" => "literal",
      "text" => "",
      "optional" => false
    }
  end

  defp create_pattern_element(_), do: create_pattern_element("literal")

  def get_forms_for_word_type(grammar_forms, word_type) do
    Enum.filter(grammar_forms, fn form -> form.word_type == word_type end)
  end

  defp page_title(:new), do: gettext("New Grammar Point")
  defp page_title(:edit), do: gettext("Edit Grammar Point")
end
