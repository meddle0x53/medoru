defmodule MedoruWeb.WordLive.Conjugations do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content

  embed_templates "conjugations.html"

  # Color scheme for form suffixes - high contrast, accessible
  @form_colors %{
    # Te-forms (connecting) - Warm yellow/orange
    "te-form" => "bg-amber-100 text-amber-800 dark:bg-amber-900/50 dark:text-amber-200",
    "kute-form" => "bg-amber-100 text-amber-800 dark:bg-amber-900/50 dark:text-amber-200",
    "de-form" => "bg-amber-100 text-amber-800 dark:bg-amber-900/50 dark:text-amber-200",
    "nakute-form" => "bg-amber-100 text-amber-800 dark:bg-amber-900/50 dark:text-amber-200",

    # Negative forms - Cool blue
    "nai-form" => "bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-200",
    "kunai-form" => "bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-200",
    "dewa-nai-form" => "bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-200",

    # Past forms - Earthy brown
    "ta-form" => "bg-amber-800/20 text-amber-900 dark:bg-amber-800/40 dark:text-amber-100",
    "katta-form" => "bg-amber-800/20 text-amber-900 dark:bg-amber-800/40 dark:text-amber-100",
    "deshita-form" => "bg-amber-800/20 text-amber-900 dark:bg-amber-800/40 dark:text-amber-100",
    "nakatta-form" => "bg-amber-800/20 text-amber-900 dark:bg-amber-800/40 dark:text-amber-100",
    "kunakatta-form" => "bg-amber-800/20 text-amber-900 dark:bg-amber-800/40 dark:text-amber-100",
    "dewa-nakatta-form" =>
      "bg-amber-800/20 text-amber-900 dark:bg-amber-800/40 dark:text-amber-100",

    # Polite/masu form - Fresh green
    "masu-form" => "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/50 dark:text-emerald-200",

    # Potential form - Purple (possibility/ability)
    "potential" => "bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-200",

    # Passive form - Indigo (receiving action)
    "passive" => "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/50 dark:text-indigo-200",

    # Causative form - Rose/pink (making/letting)
    "causative" => "bg-rose-100 text-rose-800 dark:bg-rose-900/50 dark:text-rose-200",

    # Imperative/command - Red (strong)
    "imperative" => "bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-200",

    # Volitional/let's do - Teal (future intent)
    "volitional" => "bg-teal-100 text-teal-800 dark:bg-teal-900/50 dark:text-teal-200",

    # Conditional - Cyan (if/hypothetical)
    "conditional" => "bg-cyan-100 text-cyan-800 dark:bg-cyan-900/50 dark:text-cyan-200",

    # Dictionary form - Slate/gray (neutral base)
    "dictionary" => "bg-slate-100 text-slate-700 dark:bg-slate-800/50 dark:text-slate-300",

    # Adverbial forms (ku) - Violet
    "ku-form" => "bg-violet-100 text-violet-800 dark:bg-violet-900/50 dark:text-violet-200",

    # Attributive (na) - Pink
    "na-form" => "bg-pink-100 text-pink-800 dark:bg-pink-900/50 dark:text-pink-200"
  }

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    word = Content.get_word!(id)
    conjugations = Content.list_word_conjugations(id)

    # Group conjugations by word type (verb/adjective)
    grouped_conjugations =
      conjugations
      |> Enum.group_by(& &1.grammar_form.word_type)
      |> Enum.sort_by(fn {word_type, _} -> word_type end)

    {:noreply,
     socket
     |> assign(:word, word)
     |> assign(:conjugations, conjugations)
     |> assign(:grouped_conjugations, grouped_conjugations)
     |> assign(
       :page_title,
       gettext("%{word} - Conjugations", word: word.text)
     )}
  end

  @doc """
  Returns the CSS classes for a form's suffix badge based on form name.
  Provides consistent color coding for different grammatical forms.
  """
  def form_suffix_color(form_name) when is_binary(form_name) do
    Map.get(@form_colors, form_name, "bg-base-200 text-base-content/70")
  end
end
