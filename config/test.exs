import Config

# Configure your database
# Using Unix socket for peer authentication
config :medoru, Medoru.Repo,
  username: "meddle",
  password: nil,
  hostname: nil,
  socket_dir: "/var/run/postgresql",
  database: "medoru_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Keep pool size reasonable to avoid PostgreSQL connection limits
  # Each async test needs a connection, so this limits concurrent tests
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :medoru, MedoruWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "vfqSXmecaYm+1rRT8GJItBx3yg0jThKqG0vwT5qJUFe5HJq/O6eTv3FNU3pEBoaS",
  server: false

# In test we don't send emails
config :medoru, Medoru.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
