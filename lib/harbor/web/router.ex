defmodule Harbor.Web.Router do
  @moduledoc """
  Provides self-contained macros for host apps to mount Harbor's routes.

  ## Usage

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        import Harbor.Web.UserAuth
        import Harbor.Web.Router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_live_flash
          plug :put_root_layout, html: {Harbor.Web.Layouts, :root}
          plug :protect_from_forgery
          plug :put_secure_browser_cookies
          plug :fetch_current_scope_for_user
        end

        scope "/" do
          pipe_through :browser

          harbor_storefront()
          harbor_authenticated()
          harbor_admin()
        end
      end
  """

  @doc """
  Mounts Harbor's public storefront routes.

  Generates a `live_session :harbor_storefront` with `on_mount` hooks for
  `mount_current_scope`, `global`, and `storefront`.
  """
  defmacro harbor_storefront(opts \\ []) do
    block = Keyword.get(opts, :do)

    quote do
      live_session :harbor_storefront,
        on_mount: [
          {Harbor.Web.UserAuth, :mount_current_scope},
          {Harbor.Web.LiveHooks, :global},
          {Harbor.Web.LiveHooks, :storefront}
        ] do
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
        unquote(block)
      end
    end
  end

  @doc """
  Mounts Harbor's authenticated user routes.

  Generates a `:harbor_require_auth` pipeline with `require_authenticated_user`,
  wraps routes in a scope with that pipeline, and creates a
  `live_session :harbor_authenticated` with `on_mount: require_authenticated`.
  """
  defmacro harbor_authenticated(opts \\ []) do
    block = Keyword.get(opts, :do)

    quote do
      import Harbor.Web.UserAuth, only: [require_authenticated_user: 2]

      pipeline :harbor_require_auth do
        plug :require_authenticated_user
      end

      scope "/" do
        pipe_through [:harbor_require_auth]

        live_session :harbor_authenticated,
          on_mount: [{Harbor.Web.UserAuth, :require_authenticated}] do
          live "/users/settings", Harbor.Web.UserLive.Settings, :edit

          live "/users/settings/confirm-email/:token",
               Harbor.Web.UserLive.Settings,
               :confirm_email

          post "/users/update-password", Harbor.Web.UserSessionController, :update_password
          unquote(block)
        end
      end
    end
  end

  @doc """
  Mounts Harbor's admin routes.

  Accepts an optional path prefix (default `"/admin"`) and an optional `do`
  block.

  Generates a `:harbor_admin` pipeline with `require_authenticated_user` and the
  admin root layout, wraps routes in a scope at the given path, and creates a
  `live_session :harbor_admin` with `on_mount: require_admin` and `global`.

  ## Examples

      harbor_admin()
      harbor_admin("/manage")
      harbor_admin do
        live "/custom", MyAppWeb.Admin.CustomLive
      end
      harbor_admin "/manage" do
        live "/custom", MyAppWeb.Admin.CustomLive
      end
  """
  defmacro harbor_admin(path_or_opts \\ "/admin", opts \\ []) do
    {path, block} =
      if is_binary(path_or_opts) do
        {path_or_opts, Keyword.get(opts, :do)}
      else
        {"/admin", Keyword.get(path_or_opts, :do)}
      end

    quote do
      import Harbor.Web.UserAuth, only: [require_authenticated_user: 2]

      @harbor_prefix Phoenix.Router.scoped_path(__MODULE__, unquote(path))
                     |> String.replace_suffix("/", "")
      def __harbor_prefix__, do: @harbor_prefix

      pipeline :harbor_require_admin do
        plug :require_authenticated_user
        plug :put_root_layout, html: {Harbor.Web.AdminLayouts, :root}
      end

      scope unquote(path) do
        pipe_through [:harbor_require_admin]

        live_session :harbor_admin,
          on_mount: [
            {Harbor.Web.UserAuth, :require_admin},
            {Harbor.Web.LiveHooks, :global}
          ] do
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

          live "/orders", Harbor.Web.Admin.OrderLive.Index, :index
          live "/orders/new", Harbor.Web.Admin.OrderLive.Form, :new
          live "/orders/:id", Harbor.Web.Admin.OrderLive.Show, :show
          live "/orders/:id/edit", Harbor.Web.Admin.OrderLive.Form, :edit
          unquote(block)
        end
      end
    end
  end

  defmacro harbor_routes(section) do
    raise ArgumentError,
          "harbor_routes/1 has been replaced. Use harbor_storefront/0, harbor_authenticated/0, or harbor_admin/0 instead. Got: #{inspect(section)}"
  end
end
