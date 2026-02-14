defmodule Harbor.Web.TestRouter do
  @moduledoc false
  use Harbor.Web, :router

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
