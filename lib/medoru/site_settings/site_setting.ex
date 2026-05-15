defmodule Medoru.SiteSettings.SiteSetting do
  @moduledoc """
  Schema for site-wide settings.
  Currently stores the featured public classroom for anonymous access.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Classrooms.Classroom

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "site_settings" do
    belongs_to :featured_classroom, Classroom

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(site_setting, attrs) do
    site_setting
    |> cast(attrs, [:featured_classroom_id])
    |> foreign_key_constraint(:featured_classroom_id)
  end
end
