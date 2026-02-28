import Config

config :harbor,
  binary_id: true,
  generators: [timestamp_type: :utc_datetime_usec]

config :harbor, :scopes,
  user: [
    default: true,
    module: Harbor.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: Harbor.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :ex_money,
  default_cldr_backend: Harbor.Cldr,
  auto_start_exchange_rate_service: false,
  exchange_rates_retrieve_every: :never

import_config "#{config_env()}.exs"
