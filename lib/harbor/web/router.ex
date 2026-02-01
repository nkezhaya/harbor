defmodule Harbor.Web.Router do
  @moduledoc """
  Defines application routes, pipelines, and LiveView sessions.
  """
  use Harbor.Web, :router

  import Harbor.Web.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Harbor.Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :admin_layout do
    plug :put_root_layout, html: {Harbor.Web.AdminLayouts, :root}
  end

  @doc """
  Defines Harbor routes for host apps.

  The caller is responsible for placing these routes inside the appropriate
  pipelines and LiveView sessions.
  """
  defmacro harbor_routes(:authenticated) do
    quote do
      live "/users/settings", Harbor.Web.UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", Harbor.Web.UserLive.Settings, :confirm_email
      post "/users/update-password", Harbor.Web.UserSessionController, :update_password
    end
  end

  defmacro harbor_routes(:admin) do
    quote do
      live "/", Harbor.Web.Admin.ProductLive.Index, :index
      live "/products", Harbor.Web.Admin.ProductLive.Index, :index
      live "/products/new", Harbor.Web.Admin.ProductLive.Form, :new
      live "/products/:id", Harbor.Web.Admin.ProductLive.Show, :show
      live "/products/:id/edit", Harbor.Web.Admin.ProductLive.Form, :edit

      live "/customers", Harbor.Web.Admin.CustomerLive.Index, :index
      live "/customers/new", Harbor.Web.Admin.CustomerLive.Form, :new
      live "/customers/:id", Harbor.Web.Admin.CustomerLive.Show, :show
      live "/customers/:id/edit", Harbor.Web.Admin.CustomerLive.Form, :edit

      live "/categories", Harbor.Web.Admin.CategoryLive.Index, :index
      live "/categories/new", Harbor.Web.Admin.CategoryLive.Form, :new
      live "/categories/:id", Harbor.Web.Admin.CategoryLive.Show, :show
      live "/categories/:id/edit", Harbor.Web.Admin.CategoryLive.Form, :edit
    end
  end

  defmacro harbor_routes(:public) do
    quote do
      live "/", Harbor.Web.HomeLive, :index
      live "/products", Harbor.Web.ProductLive.Index, :index
      live "/shop/:slug", Harbor.Web.ProductLive.Index, :index
      live "/products/:slug", Harbor.Web.ProductLive.Show, :show
      live "/cart", Harbor.Web.CartLive.Show, :show
      live "/checkout/:id", Harbor.Web.CheckoutLive.Form, :form
      live "/checkout/:id/receipt", Harbor.Web.CheckoutLive.Receipt, :receipt
      live "/users/register", Harbor.Web.UserLive.Registration, :new
      live "/users/log-in", Harbor.Web.UserLive.Login, :new
      live "/users/log-in/:token", Harbor.Web.UserLive.Confirmation, :new
      post "/users/log-in", Harbor.Web.UserSessionController, :create
      delete "/users/log-out", Harbor.Web.UserSessionController, :delete
    end
  end

  defmacro harbor_routes(other) do
    raise ArgumentError,
          "unknown Harbor.Web.Router.harbor_routes/1 section: #{inspect(other)}"
  end

  ## Authentication routes

  scope "/", Harbor.Web do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{Harbor.Web.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password

    # Admin panel routes under a distinct layout
    scope "/admin", Admin do
      pipe_through [:admin_layout]

      live_session :require_authenticated_admin,
        on_mount: [
          {Harbor.Web.UserAuth, :require_admin},
          {Harbor.Web.LiveHooks, :global}
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

        live "/categories", CategoryLive.Index, :index
        live "/categories/new", CategoryLive.Form, :new
        live "/categories/:id", CategoryLive.Show, :show
        live "/categories/:id/edit", CategoryLive.Form, :edit
      end
    end
  end

  ## Public routes

  scope "/", Harbor.Web do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {Harbor.Web.UserAuth, :mount_current_scope},
        {Harbor.Web.LiveHooks, :global},
        {Harbor.Web.LiveHooks, :storefront}
      ] do
      live "/", HomeLive, :index
      live "/products", ProductLive.Index, :index
      live "/shop/:slug", ProductLive.Index, :index
      live "/products/:slug", ProductLive.Show, :show
      live "/cart", CartLive.Show, :show
      live "/checkout/:id", CheckoutLive.Form, :form
      live "/checkout/:id/receipt", CheckoutLive.Receipt, :receipt
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
