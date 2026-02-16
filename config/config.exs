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

import_config "#{config_env()}.exs"
