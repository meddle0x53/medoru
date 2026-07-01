defmodule Medoru.SiteSettings do
  @moduledoc """
  Context for site-wide settings.
  """
  import Ecto.Query, warn: false

  alias Medoru.Repo
  alias Medoru.SiteSettings.SiteSetting

  @doc """
  Returns the site settings, creating a default row if none exists.
  """
  def get_settings do
    case Repo.one(SiteSetting) do
      nil ->
        {:ok, settings} = Repo.insert(%SiteSetting{})
        settings

      settings ->
        settings
    end
  end

  @doc """
  Updates the site settings.
  """
  def update_settings(%SiteSetting{} = settings, attrs) do
    settings
    |> SiteSetting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns the featured classroom ID, or nil if none is set.

  The value can be overridden at runtime via the application environment
  (`:featured_classroom_id`), which is useful for tests and ephemeral config.
  """
  def featured_classroom_id do
    Application.get_env(:medoru, :featured_classroom_id) ||
      get_settings().featured_classroom_id
  end
end
