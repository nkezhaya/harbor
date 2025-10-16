defmodule HarborWeb.Router do
  @moduledoc """
  Defines application routes, pipelines, and LiveView sessions.
  """
  use HarborWeb, :router

  import HarborWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HarborWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :admin_layout do
    plug :put_root_layout, html: {HarborWeb.AdminLayouts, :root}
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:harbor, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", HarborWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{HarborWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password

    # Admin panel routes under a distinct layout
    scope "/admin", Admin do
      pipe_through [:admin_layout]

      live_session :require_authenticated_admin,
        on_mount: [
          {HarborWeb.UserAuth, :require_admin},
          {HarborWeb.LiveHooks, :global}
        ] do
        live "/", ProductLive.Index, :index
        live "/products", ProductLive.Index, :index
        live "/products/new", ProductLive.Form, :new
        live "/products/:id", ProductLive.Show, :show
        live "/products/:id/edit", ProductLive.Form, :edit

        live "/customers", CustomerLive.Index, :index
        live "/customers/new", CustomerLive.Form, :new
        live "/customers/:id", CustomerLive.Show, :show
        live "/customers/:id/edit", CustomerLive.Form, :edit
      end
    end
  end

  ## Public routes

  scope "/", HarborWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {HarborWeb.UserAuth, :mount_current_scope},
        {HarborWeb.LiveHooks, :global},
        {HarborWeb.LiveHooks, :storefront}
      ] do
      live "/", HomeLive, :index
      live "/products", ProductsLive.Index, :index
      live "/products/:slug", ProductsLive.Show, :show
      live "/cart", CartLive, :index
      live "/checkout", CheckoutLive, :index
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
