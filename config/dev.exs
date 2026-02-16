import Config

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON
config :ex_aws, json_codec: JSON

config :esbuild,
  version: "0.25.4",
  harbor: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.1.7",
  harbor: [
    args: ~w(
        --input=assets/css/app.css
        --output=priv/static/assets/css/app.css
      ),
    cd: Path.expand("..", __DIR__)
  ]

config :harbor, :tax_provider, {:stripe, Harbor.Tax.TaxProvider.Stripe}
config :harbor, :payment_provider, {:stripe, Harbor.Billing.PaymentProvider.Stripe}
