defmodule MedoruWeb.PrivacyLive do
  @moduledoc """
  Privacy Policy page for GDPR compliance.
  """
  use MedoruWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Privacy Policy"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-8">{gettext("Privacy Policy")}</h1>

        <div class="prose max-w-none">
          <p class="text-sm text-gray-500 mb-4">
            {gettext("Last updated")}: March 18, 2026
          </p>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("1. Introduction")}</h2>
          <p>
            {gettext(
              "Medoru (\"we\", \"our\", or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our Japanese learning platform."
            )}
          </p>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("2. Information We Collect")}</h2>
          <h3 class="text-lg font-medium mt-4 mb-2">{gettext("2.1 Personal Information")}</h3>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("Email address (via Google OAuth)")}</li>
            <li>{gettext("Name and profile picture")}</li>
            <li>{gettext("Learning progress and statistics")}</li>
            <li>{gettext("Test scores and completion data")}</li>
          </ul>

          <h3 class="text-lg font-medium mt-4 mb-2">{gettext("2.2 Usage Data")}</h3>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("IP address and browser information")}</li>
            <li>{gettext("Pages visited and features used")}</li>
            <li>{gettext("Learning session duration")}</li>
            <li>{gettext("Device and operating system")}</li>
          </ul>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("3. How We Use Your Information")}</h2>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("Provide and maintain the learning platform")}</li>
            <li>{gettext("Track your learning progress")}</li>
            <li>{gettext("Personalize your learning experience")}</li>
            <li>{gettext("Send notifications and updates")}</li>
            <li>{gettext("Improve our services")}</li>
          </ul>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("4. Data Storage and Security")}</h2>
          <p>
            {gettext(
              "Your data is stored securely in our database. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction."
            )}
          </p>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("5. Your Rights (GDPR)")}</h2>
          <p>
            {gettext(
              "Under the General Data Protection Regulation (GDPR), you have the following rights:"
            )}
          </p>
          <ul class="list-disc pl-6 mb-4">
            <li>
              <strong>{gettext("Right to Access")}</strong>: {gettext(
                "Request a copy of your personal data"
              )}
            </li>
            <li>
              <strong>{gettext("Right to Rectification")}</strong>: {gettext(
                "Correct inaccurate or incomplete data"
              )}
            </li>
            <li>
              <strong>{gettext("Right to Erasure")}</strong>: {gettext(
                "Request deletion of your personal data"
              )}
            </li>
            <li>
              <strong>{gettext("Right to Restrict Processing")}</strong>: {gettext(
                "Limit how we use your data"
              )}
            </li>
            <li>
              <strong>{gettext("Right to Data Portability")}</strong>: {gettext(
                "Receive your data in a structured format"
              )}
            </li>
            <li>
              <strong>{gettext("Right to Object")}</strong>: {gettext(
                "Object to certain types of processing"
              )}
            </li>
          </ul>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("6. Cookies")}</h2>
          <p>
            {gettext("We use cookies to enhance your experience. See our")}
            <.link navigate={~p"/cookies"} class="link link-primary">
              {gettext("Cookie Policy")}
            </.link>
            {gettext("for more information.")}
          </p>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("7. Third-Party Services")}</h2>
          <p>{gettext("We use the following third-party services:")}</p>
          <ul class="list-disc pl-6 mb-4">
            <li>{gettext("Google OAuth - for authentication")}</li>
            <li>{gettext("PostgreSQL - for data storage")}</li>
          </ul>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("8. Contact Us")}</h2>
          <p>
            {gettext(
              "If you have questions about this Privacy Policy or your data rights, please contact us at:"
            )}
            <a href="mailto:privacy@medoru.net" class="link link-primary">privacy@medoru.net</a>
          </p>

          <h2 class="text-xl font-semibold mt-6 mb-3">{gettext("9. Data Controller")}</h2>
          <p>
            <strong>Medoru</strong> <br />
            {gettext("Email")}: privacy@medoru.net<br />
            {gettext("Address")}: {gettext("Bulgaria")}
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
