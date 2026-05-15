defmodule MedoruWeb.PublicAccess do
  @moduledoc """
  Helpers for anonymous public access to the featured classroom.
  """

  alias Medoru.SiteSettings

  @doc """
  Returns true if the given classroom ID is the featured public classroom.
  """
  def featured_classroom?(classroom_id) do
    featured_id = SiteSettings.featured_classroom_id()
    is_binary(classroom_id) and not is_nil(featured_id) and featured_id == classroom_id
  end

  @doc """
  Returns the featured classroom ID, or nil.
  """
  def featured_classroom_id, do: SiteSettings.featured_classroom_id()
end
