# Installation

Harbor requires [Oban](https://hexdocs.pm/oban) for background job processing.
Follow Oban's [installation guide](https://hexdocs.pm/oban/installation.html)
before proceeding.

## Add the dependency

Add `:harbor` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:harbor, "~> 0.1"}
  ]
end
```

## Configure infrastructure

Harbor uses proxy modules for Repo, Oban, and Mailer so it can delegate to your
app's own implementations. Point each one at the corresponding module in your app:

```elixir
# config/config.exs
config :harbor, :repo, MyApp.Repo
config :harbor, :oban, MyApp.Oban
config :harbor, :mailer, MyApp.Mailer
```

Your Oban instance should include at least the `media_uploads` and `billing`
queues:

```elixir
config :my_app, MyApp.Oban,
  queues: [media_uploads: 10, billing: 10],
  # ...
```

## Configure money

Harbor uses [ex_money](https://hexdocs.pm/ex_money) for monetary values. Point
it at Harbor's CLDR backend:

```elixir
# config/config.exs
config :ex_money,
  default_cldr_backend: Harbor.Cldr,
  auto_start_exchange_rate_service: false,
  exchange_rates_retrieve_every: :never
```

## Configure providers

Harbor requires an S3 bucket and CDN URL for media storage:

```elixir
# config/config.exs
config :harbor, :s3_bucket, "my-bucket"
config :harbor, :cdn_url, "https://my-distribution.cloudfront.net"
```

## Run migrations

Generate a migration for Harbor's tables:

```bash
mix ecto.gen.migration add_harbor
```

```elixir
defmodule MyApp.Repo.Migrations.AddHarbor do
  use Ecto.Migration

  def up, do: Harbor.Migration.up()
  def down, do: Harbor.Migration.down()
end
```

Then run:

```bash
mix ecto.migrate
```

## Mount routes

Import `Harbor.Web.Router` and `Harbor.Web.UserAuth` in your router, add the
required plugs to your browser pipeline, and mount Harbor's route groups:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router
  import Harbor.Web.UserAuth
  import Harbor.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Harbor.Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  scope "/" do
    pipe_through :browser

    harbor_storefront()
    harbor_authenticated()
    harbor_admin()
  end
end
```

`harbor_admin/0` mounts under `/admin` by default. Pass a custom path to change
it:

```elixir
harbor_admin("/manage")
```

## Admin JavaScript

Harbor ships an ESM bundle with the LiveView hooks and uploaders needed by the
admin interface (image uploads, drag-and-drop reordering, etc.). Register them on
your LiveSocket so the admin LiveViews work correctly.

In your `assets/js/app.js`:

```js
import { hooks as harborHooks, Uploaders } from "harbor";

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: {...hooks, ...harborHooks},
  uploaders: Uploaders,
});
```

## Start supervision

Add Harbor's telemetry worker to your application's supervision tree:

```elixir
# lib/my_app/application.ex
children = [
  MyApp.Repo,
  Harbor.Web.Telemetry,
  MyAppWeb.Endpoint
]
```
