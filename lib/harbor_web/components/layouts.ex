defmodule HarborWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HarborWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :root_categories, :list, default: [], doc: "top-level product categories for navigation"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-white text-gray-900">
      <div
        id="mobile-menu-backdrop"
        class="fixed inset-0 z-40 hidden bg-black/25"
        aria-hidden="true"
        phx-click={hide_mobile_menu()}
      >
      </div>

      <div
        id="mobile-menu-panel"
        class="fixed inset-y-0 left-0 z-50 hidden w-full max-w-xs flex-col bg-white px-6 py-6 shadow-xl sm:max-w-sm"
        role="dialog"
        aria-modal="true"
      >
        <div class="flex items-center justify-between">
          <a href="/" class="flex items-center gap-3">
            <img src={~p"/images/logo.svg"} alt="Harbor logo" class="h-10 w-10" />
            <span class="text-lg font-semibold text-gray-900">Harbor</span>
          </a>
          <button
            type="button"
            class="rounded-md p-2 text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            phx-click={hide_mobile_menu()}
          >
            <span class="sr-only">Close menu</span>
            <.icon name="hero-x-mark" class="h-6 w-6" />
          </button>
        </div>

        <nav class="mt-8 space-y-6 text-base font-medium text-gray-900">
          <a
            :for={category <- @root_categories}
            href={~p"/products/#{category.slug}"}
            class="block"
          >
            {category.name}
          </a>
        </nav>

        <div class="mt-auto space-y-4 border-t border-gray-200 pt-6 text-sm font-medium text-gray-700">
          <%= if @current_scope && @current_scope.user do %>
            <p class="text-gray-500">
              Signed in as {@current_scope.user.email}
            </p>
            <.link href={~p"/users/settings"} class="block hover:text-gray-900">
              Account settings
            </.link>
            <.link href={~p"/users/log-out"} method="delete" class="block hover:text-gray-900">
              Log out
            </.link>
          <% else %>
            <.link href={~p"/users/register"} class="block hover:text-gray-900">
              Register
            </.link>
            <.link href={~p"/users/log-in"} class="block hover:text-gray-900">
              Log in
            </.link>
          <% end %>
        </div>
      </div>

      <header class="relative border-b border-gray-200">
        <nav aria-label="Primary" class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 items-center justify-between">
            <div class="flex flex-1 items-center gap-3">
              <button
                type="button"
                class="inline-flex items-center justify-center rounded-md p-2 text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 lg:hidden"
                phx-click={show_mobile_menu()}
              >
                <span class="sr-only">Open menu</span>
                <.icon name="hero-bars-3" class="h-6 w-6" />
              </button>

              <a href="/" class="flex items-center gap-3">
                <img src={~p"/images/logo.svg"} alt="Harbor logo" class="h-10 w-10" />
                <span class="hidden text-lg font-semibold text-gray-900 sm:block">Harbor</span>
              </a>
            </div>

            <div class="hidden lg:flex lg:h-full lg:items-center lg:justify-center">
              <div class="flex gap-10 text-sm font-medium text-gray-700">
                <a
                  :for={category <- @root_categories}
                  href={~p"/products/#{category.slug}"}
                  class="transition hover:text-gray-900"
                >
                  {category.name}
                </a>
              </div>
            </div>

            <div class="flex flex-1 items-center justify-end gap-4">
              <button
                type="button"
                class="rounded-full p-2 text-gray-500 transition hover:text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                aria-label="Search"
              >
                <.icon name="hero-magnifying-glass" class="h-6 w-6" />
              </button>

              <div class="hidden gap-4 text-sm font-medium text-gray-700 lg:flex lg:items-center">
                <%= if @current_scope && @current_scope.user do %>
                  <span class="text-gray-500">{@current_scope.user.email}</span>
                  <.link href={~p"/users/settings"} class="transition hover:text-gray-900">
                    Settings
                  </.link>
                  <.link
                    href={~p"/users/log-out"}
                    method="delete"
                    class="transition hover:text-gray-900"
                  >
                    Log out
                  </.link>
                <% else %>
                  <.link href={~p"/users/register"} class="transition hover:text-gray-900">
                    Register
                  </.link>
                  <.link href={~p"/users/log-in"} class="transition hover:text-gray-900">
                    Log in
                  </.link>
                <% end %>
              </div>

              <StoreComponents.cart_popover current_scope={@current_scope} />
            </div>
          </div>
        </nav>
      </header>

      <main class="flex-1">
        <div class="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer class="border-t border-gray-200">
        <div class="mx-auto flex max-w-7xl flex-col gap-6 px-4 py-10 text-sm text-gray-500 sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
          <a href="/" class="flex items-center gap-3 text-gray-900">
            <img src={~p"/images/logo.svg"} alt="Harbor logo" class="h-9 w-9" />
            <span class="text-base font-semibold">Harbor</span>
          </a>
          <p class="text-sm text-gray-500">
            &copy; {Date.utc_today().year} Harbor. All rights reserved.
          </p>
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="assertive"
      class="pointer-events-none fixed inset-0 z-50 flex items-end px-4 py-6 sm:items-start sm:p-6"
    >
      <div class="flex w-full flex-col items-center space-y-4 sm:items-end">
        <.flash kind={:info} flash={@flash} />
        <.flash kind={:error} flash={@flash} />

        <.flash
          id="client-error"
          kind={:error}
          title={gettext("We can't find the internet")}
          phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
          phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
          hidden
        >
          {gettext("Attempting to reconnect")}
          <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
        </.flash>

        <.flash
          id="server-error"
          kind={:error}
          title={gettext("Something went wrong!")}
          phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
          phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
          hidden
        >
          {gettext("Attempting to reconnect")}
          <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
        </.flash>
      </div>
    </div>
    """
  end

  defp show_mobile_menu(js \\ %JS{}) do
    js
    |> JS.show(to: "#mobile-menu-backdrop")
    |> JS.show(to: "#mobile-menu-panel", display: "flex")
  end

  defp hide_mobile_menu(js \\ %JS{}) do
    js
    |> JS.hide(to: "#mobile-menu-panel")
    |> JS.hide(to: "#mobile-menu-backdrop")
  end
end
