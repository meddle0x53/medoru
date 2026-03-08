defmodule MedoruWeb.SettingsLive.Attribution do
  @moduledoc """
  LiveView for displaying third-party data attributions.
  """
  use MedoruWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Attribution")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold text-base-content mb-6">Attribution</h1>

        <p class="text-secondary mb-8">
          Medoru uses data from the following third-party sources. We are grateful to the contributors
          who make these resources available.
        </p>

        <div class="space-y-6">
          <%!-- KanjiVG --%>
          <div class="bg-base-100 rounded-2xl border border-base-300 p-6">
            <h2 class="text-xl font-semibold text-base-content mb-3">Kanji Stroke Data</h2>
            <p class="text-secondary mb-4">
              Kanji stroke diagrams and animation data are provided by <a
                href="http://kanjivg.tagaini.net"
                target="_blank"
                class="text-primary hover:underline"
              >KanjiVG</a>.
            </p>
            <div class="bg-base-200 rounded-lg p-4 text-sm text-secondary">
              <p class="font-medium text-base-content mb-2">License: CC BY-SA 3.0</p>
              <p>
                KanjiVG is copyright © 2009-2025 Ulrich Apel and released under the Creative Commons
                Attribution-Share Alike 3.0 license. You are free to share and remix the work under
                the same license.
              </p>
            </div>
          </div>

          <%!-- KANJIDIC2 --%>
          <div class="bg-base-100 rounded-2xl border border-base-300 p-6">
            <h2 class="text-xl font-semibold text-base-content mb-3">Kanji Dictionary Data</h2>
            <p class="text-secondary mb-4">
              Kanji readings, meanings, and metadata are provided by
              <a
                href="https://www.edrdg.org/wiki/index.php/KANJIDIC_Project"
                target="_blank"
                class="text-primary hover:underline"
              >
                KANJIDIC2
              </a>
              from the Electronic Dictionary Research and Development Group (EDRDG).
            </p>
            <div class="bg-base-200 rounded-lg p-4 text-sm text-secondary">
              <p class="font-medium text-base-content mb-2">License: CC BY-SA 4.0</p>
              <p>
                Copyright © EDRG (Electronic Dictionary Research and Development Group).
                Licensed under Creative Commons Attribution-ShareAlike 4.0 International.
              </p>
            </div>
          </div>

          <%!-- Additional info --%>
          <div class="bg-base-100 rounded-2xl border border-base-300 p-6">
            <h2 class="text-xl font-semibold text-base-content mb-3">About Our Data</h2>
            <p class="text-secondary">
              Medoru combines these open data sources with our own learning algorithms,
              lesson structure, and user experience design to create a unique Japanese
              learning platform. The stroke animations and dictionary information are
              processed from the sources above but presented in our own interface.
            </p>
          </div>
        </div>

        <div class="mt-8 text-center">
          <.link navigate={~p"/"} class="text-primary hover:underline">
            ← Back to Home
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
