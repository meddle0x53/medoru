import Config

# =============================================================================
# QA Environment Configuration
# =============================================================================
# This environment is for automated E2E testing with Playwright.
# - Runs on port 4001 (so dev can run on 4000 simultaneously)
# - Uses medoru_qa database (isolated from dev/test/prod)
# - Enables QA auth bypass for test users
# =============================================================================

# Configure database for QA
config :medoru, Medoru.Repo,
  username: "meddle",
  password: nil,
  hostname: nil,
  socket_dir: "/var/run/postgresql",
  database: "medoru_qa",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure endpoint - runs on port 4001
# Note: No code_reloader or watchers (those are dev-only features)
config :medoru, MedoruWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4001],
  check_origin: false,
  debug_errors: true,
  secret_key_base:
    "qa_secret_key_base_for_testing_only_not_for_production_64_bytes_long_need_more_chars"

# Enable dev routes for dashboard and mailbox
# Needed for QA bypass routes to work
config :medoru, dev_routes: true

# Enable QA mode features
config :medoru, :qa_mode, true

# Disable Google OAuth in QA - use bypass instead
config :ueberauth, Ueberauth, providers: []

# Configure mailer for QA (local adapter)
config :medoru, Medoru.Mailer, adapter: Swoosh.Adapters.Local
config :swoosh, :api_client, false

# Logging - verbose for debugging tests
config :logger, level: :info

config :logger, :default_formatter,
  format: "[$level] $time $metadata$message\n",
  metadata: [:request_id, :user_id, :module, :function, :line]

# Phoenix settings
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# LiveView settings (production-like for testing)
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
