defmodule MedoruWeb.WordLive.Index do
  use MedoruWeb, :live_view

  alias Medoru.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :difficulty, 5)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    difficulty = parse_difficulty(params["difficulty"])
    words = Content.list_words_by_difficulty(difficulty)

    {:noreply,
     socket
     |> assign(:difficulty, difficulty)
     |> assign(:words, words)
     |> assign(:page_title, "JLPT N#{difficulty} Vocabulary")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-slate-900 mb-2">Vocabulary Browser</h1>
          <p class="text-slate-600">Browse and learn Japanese words organized by JLPT level</p>
        </div>

        <%!-- Difficulty Selector --%>
        <div class="flex flex-wrap gap-2 mb-8">
          <%= for level <- [5, 4, 3, 2, 1] do %>
            <.link
              patch={~p"/words?difficulty=#{level}"}
              class={[
                "px-4 py-2 rounded-lg font-medium transition-colors",
                if(@difficulty == level,
                  do: "bg-indigo-600 text-white",
                  else: "bg-slate-100 text-slate-700 hover:bg-slate-200"
                )
              ]}
            >
              N{level}
            </.link>
          <% end %>
        </div>

        <%!-- Stats --%>
        <div class="mb-6 flex items-center gap-4 text-sm text-slate-600">
          <span class="bg-slate-100 px-3 py-1 rounded-full">
            {length(@words)} words
          </span>
          <span class="bg-slate-100 px-3 py-1 rounded-full">
            JLPT N{@difficulty}
          </span>
        </div>

        <%!-- Words Grid --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for word <- @words do %>
            <.link
              navigate={~p"/words/#{word.id}"}
              class="group"
            >
              <div class="bg-white border border-slate-200 rounded-xl p-4
                          shadow-sm hover:shadow-md hover:border-indigo-300 transition-all duration-200">
                <div class="flex items-baseline justify-between mb-2">
                  <span class="text-2xl font-medium text-slate-900 group-hover:text-indigo-600 transition-colors">
                    {word.text}
                  </span>
                  <span class="text-sm text-slate-500 font-medium">
                    {word.reading}
                  </span>
                </div>
                <p class="text-slate-700 text-sm">
                  {word.meaning}
                </p>
              </div>
            </.link>
          <% end %>
        </div>

        <%= if @words == [] do %>
          <div class="text-center py-16">
            <div class="text-6xl mb-4">📖</div>
            <h3 class="text-lg font-medium text-slate-900 mb-2">No words found</h3>
            <p class="text-slate-600">This difficulty level doesn't have any vocabulary yet.</p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp parse_difficulty(nil), do: 5

  defp parse_difficulty(difficulty) when is_binary(difficulty) do
    case Integer.parse(difficulty) do
      {n, _} when n in 1..5 -> n
      _ -> 5
    end
  end

  defp parse_difficulty(difficulty) when is_integer(difficulty) and difficulty in 1..5,
    do: difficulty

  defp parse_difficulty(_), do: 5
end
