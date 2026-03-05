defmodule Medoru.Repo do
  use Ecto.Repo,
    otp_app: :medoru,
    adapter: Ecto.Adapters.Postgres
end
