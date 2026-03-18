defmodule MedoruWeb.CookiesLive do
  @moduledoc """
  Cookie Policy page for GDPR compliance.
  """
  use MedoruWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Cookie Policy"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-8">{gettext("Cookie Policy")}</h1>

        <div class="prose max-w-none">
          <p class="text-sm text-gray-500 mb-4">
            {gettext("Last updated")}: March 18, 2026
          </p>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("1. What Are Cookies")}</h2>
          <p>
            {gettext(
              "Cookies are small text files that are stored on your device when you visit a website. They help us provide you with a better experience by remembering your preferences and understanding how you use our platform."
            )}
          </p>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("2. How We Use Cookies")}</h2>
          <p>{gettext("We use cookies for the following purposes:")}</p>

          <h3 class="text-lg font-medium mt-4 mb-2">{gettext("2.1 Essential Cookies")}</h3>
          <p class="text-sm text-gray-600 mb-2">
            {gettext("(Required for the website to function)")}
          </p>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("Session cookies - to keep you logged in")}</li>
            <li>{gettext("CSRF tokens - to protect against cross-site request forgery")}</li>
            <li>{gettext("Language preference - to remember your selected language")}</li>
          </ul>

          <h3 class="text-lg font-medium mt-4 mb-2">{gettext("2.2 Functional Cookies")}</h3>
          <p class="text-sm text-gray-600 mb-2">{gettext("(Enhance your experience)")}</p>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("User preferences - theme, display settings")}</li>
            <li>{gettext("Learning progress - track your lesson completion")}</li>
            <li>{gettext("Cookie consent - remember your cookie preferences")}</li>
          </ul>

          <h3 class="text-lg font-medium mt-4 mb-2">{gettext("2.3 Analytics Cookies")}</h3>
          <p class="text-sm text-gray-600 mb-2">{gettext("(Help us improve our platform)")}</p>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("Usage statistics - understand how users interact with the platform")}</li>
            <li>{gettext("Feature popularity - identify which features are most used")}</li>
            <li>{gettext("Error tracking - help us fix technical issues")}</li>
          </ul>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("3. Cookie Duration")}</h2>
          <table class="table w-full mb-4">
            <thead>
              <tr>
                <th>{gettext("Cookie Type")}</th>
                <th>{gettext("Duration")}</th>
                <th>{gettext("Purpose")}</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>{gettext("Session")}</td>
                <td>{gettext("Browser session")}</td>
                <td>{gettext("Authentication")}</td>
              </tr>
              <tr>
                <td>{gettext("Locale")}</td>
                <td>1 {gettext("year")}</td>
                <td>{gettext("Language preference")}</td>
              </tr>
              <tr>
                <td>{gettext("Cookie Consent")}</td>
                <td>1 {gettext("year")}</td>
                <td>{gettext("Remember your cookie choice")}</td>
              </tr>
              <tr>
                <td>{gettext("User Preferences")}</td>
                <td>1 {gettext("year")}</td>
                <td>{gettext("Display settings")}</td>
              </tr>
            </tbody>
          </table>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("4. Managing Cookies")}</h2>
          <p>
            {gettext(
              "You can manage your cookie preferences at any time by clicking the \"Cookie Settings\" link in the footer. You can also:"
            )}
          </p>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("Accept all cookies")}</li>
            <li>{gettext("Reject non-essential cookies")}</li>
            <li>{gettext("Clear cookies through your browser settings")}</li>
          </ul>

          <h3 class="text-lg font-medium mt-4 mb-2">{gettext("Browser Settings")}</h3>
          <p>
            {gettext(
              "Most web browsers allow you to control cookies through their settings. Here's how to manage cookies in popular browsers:"
            )}
          </p>
          <ul class="list-disc pl-6 mb-4">
            <li>
              <a
                href="https://support.google.com/chrome/answer/95647"
                target="_blank"
                class="link link-primary"
              >
                Google Chrome
              </a>
            </li>
            <li>
              <a
                href="https://support.mozilla.org/kb/cookies-information-websites-store-on-your-computer"
                target="_blank"
                class="link link-primary"
              >
                Mozilla Firefox
              </a>
            </li>
            <li>
              <a
                href="https://support.apple.com/guide/safari/manage-cookies-sfri11471"
                target="_blank"
                class="link link-primary"
              >
                Safari
              </a>
            </li>
            <li>
              <a
                href="https://support.microsoft.com/help/17442/windows-internet-explorer-delete-manage-cookies"
                target="_blank"
                class="link link-primary"
              >
                Microsoft Edge
              </a>
            </li>
          </ul>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("5. Third-Party Cookies")}</h2>
          <p>
            {gettext("We do not use third-party advertising cookies. The only external cookies are:")}
          </p>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("Google OAuth - for authentication (only when you log in)")}</li>
          </ul>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("6. Changes to This Policy")}</h2>
          <p>
            {gettext(
              "We may update this Cookie Policy from time to time. Any changes will be posted on this page with an updated revision date."
            )}
          </p>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("7. Contact Us")}</h2>
          <p>
            {gettext("If you have any questions about our Cookie Policy, please contact us at:")}
            <a href="mailto:privacy@medoru.net" class="link link-primary">privacy@medoru.net</a>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
