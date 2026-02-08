defmodule Harbor.Web do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use Harbor.Web, :controller
      use Harbor.Web, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: Harbor.Web.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: Harbor.Web.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import Harbor.Web.CoreComponents

      # Common modules used in templates
      alias Harbor.Web.{AdminLayouts, Layouts}
      alias Harbor.Web.{CartComponents, CheckoutComponents, StoreComponents}
      alias Harbor.Web.ImageHelpers
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Harbor.Web.verified_routes_endpoint(),
        router: Harbor.Web.verified_routes_router(),
        statics: Harbor.Web.static_paths()
    end
  end

  def verified_routes_endpoint do
    Application.get_env(:harbor, :verified_routes_endpoint) ||
      raise """
      Harbor requires :verified_routes_endpoint to be configured.

          config :harbor, :verified_routes_endpoint, MyAppWeb.Endpoint
      """
  end

  def verified_routes_router do
    Application.get_env(:harbor, :verified_routes_router, Harbor.Web.Router)
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
