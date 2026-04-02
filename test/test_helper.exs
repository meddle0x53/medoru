# Limit max concurrency to avoid PostgreSQL connection exhaustion
# With pool_size: 10 in test.exs, we can safely run 8 concurrent tests
ExUnit.start(max_concurrency: 8)
Ecto.Adapters.SQL.Sandbox.mode(Medoru.Repo, :manual)
