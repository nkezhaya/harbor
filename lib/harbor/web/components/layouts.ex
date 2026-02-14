defmodule Harbor.Web.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use Harbor.Web, :html

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

  attr :current_scope, Harbor.Accounts.Scope,
    required: true,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :cart, Harbor.Checkout.Cart, default: nil
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
            <.logo class="h-10 w-10" />
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
            href={"/shop/#{category.slug}"}
            class="block"
          >
            {category.name}
          </a>
        </nav>

        <div class="mt-auto space-y-4 border-t border-gray-200 pt-6 text-sm font-medium text-gray-700">
          <%= if @current_scope.authenticated? do %>
            <p class="text-gray-500">
              Signed in as {@current_scope.user.email}
            </p>
            <.link href="/users/settings" class="block hover:text-gray-900">
              Account settings
            </.link>
            <.link href="/users/log-out" method="delete" class="block hover:text-gray-900">
              Log out
            </.link>
          <% else %>
            <.link href="/users/register" class="block hover:text-gray-900">
              Register
            </.link>
            <.link href="/users/log-in" class="block hover:text-gray-900">
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
                <.logo class="h-10 w-10" />
                <span class="hidden text-lg font-semibold text-gray-900 sm:block">Harbor</span>
              </a>
            </div>

            <div class="hidden lg:flex lg:h-full lg:items-center lg:justify-center">
              <div class="flex gap-10 text-sm font-medium text-gray-700">
                <a
                  :for={category <- @root_categories}
                  href={"/shop/#{category.slug}"}
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
                <%= if @current_scope.authenticated? do %>
                  <span class="text-gray-500">{@current_scope.user.email}</span>
                  <.link href="/users/settings" class="transition hover:text-gray-900">
                    Settings
                  </.link>
                  <.link
                    href="/users/log-out"
                    method="delete"
                    class="transition hover:text-gray-900"
                  >
                    Log out
                  </.link>
                <% else %>
                  <.link href="/users/register" class="transition hover:text-gray-900">
                    Register
                  </.link>
                  <.link href="/users/log-in" class="transition hover:text-gray-900">
                    Log in
                  </.link>
                <% end %>
              </div>

              <CartComponents.cart_popover current_scope={@current_scope} cart={@cart} />
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
            <.logo class="h-9 w-9" />
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
  Renders the checkout layout.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  slot :inner_block, required: true

  def checkout(assigns) do
    ~H"""
    <main class="flex-1 lg:flex lg:min-h-full lg:flex-row-reverse lg:overflow-hidden">
      <h1 class="sr-only">Checkout</h1>

      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
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

  attr :class, :string, default: nil

  defp logo(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 71 48" fill="currentColor" aria-hidden="true" class={@class}>
      <path
        d="m26.371 33.477-.552-.1c-3.92-.729-6.397-3.1-7.57-6.829-.733-2.324.597-4.035 3.035-4.148 1.995-.092 3.362 1.055 4.57 2.39 1.557 1.72 2.984 3.558 4.514 5.305 2.202 2.515 4.797 4.134 8.347 3.634 3.183-.448 5.958-1.725 8.371-3.828.363-.316.761-.592 1.144-.886l-.241-.284c-2.027.63-4.093.841-6.205.735-3.195-.16-6.24-.828-8.964-2.582-2.486-1.601-4.319-3.746-5.19-6.611-.704-2.315.736-3.934 3.135-3.6.948.133 1.746.56 2.463 1.165.583.493 1.143 1.015 1.738 1.493 2.8 2.25 6.712 2.375 10.265-.068-5.842-.026-9.817-3.24-13.308-7.313-1.366-1.594-2.7-3.216-4.095-4.785-2.698-3.036-5.692-5.71-9.79-6.623C12.8-.623 7.745.14 2.893 2.361 1.926 2.804.997 3.319 0 4.149c.494 0 .763.006 1.032 0 2.446-.064 4.28 1.023 5.602 3.024.962 1.457 1.415 3.104 1.761 4.798.513 2.515.247 5.078.544 7.605.761 6.494 4.08 11.026 10.26 13.346 2.267.852 4.591 1.135 7.172.555ZM10.751 3.852c-.976.246-1.756-.148-2.56-.962 1.377-.343 2.592-.476 3.897-.528-.107.848-.607 1.306-1.336 1.49Zm32.002 37.924c-.085-.626-.62-.901-1.04-1.228-1.857-1.446-4.03-1.958-6.333-2-1.375-.026-2.735-.128-4.031-.61-.595-.22-1.26-.505-1.244-1.272.015-.78.693-1 1.31-1.184.505-.15 1.026-.247 1.6-.382-1.46-.936-2.886-1.065-4.787-.3-2.993 1.202-5.943 1.06-8.926-.017-1.684-.608-3.179-1.563-4.735-2.408l-.077.057c1.29 2.115 3.034 3.817 5.004 5.271 3.793 2.8 7.936 4.471 12.784 3.73A66.714 66.714 0 0 1 37 40.877c1.98-.16 3.866.398 5.753.899Zm-9.14-30.345c-.105-.076-.206-.266-.42-.069 1.745 2.36 3.985 4.098 6.683 5.193 4.354 1.767 8.773 2.07 13.293.51 3.51-1.21 6.033-.028 7.343 3.38.19-3.955-2.137-6.837-5.843-7.401-2.084-.318-4.01.373-5.962.94-5.434 1.575-10.485.798-15.094-2.553Zm27.085 15.425c.708.059 1.416.123 2.124.185-1.6-1.405-3.55-1.517-5.523-1.404-3.003.17-5.167 1.903-7.14 3.972-1.739 1.824-3.31 3.87-5.903 4.604.043.078.054.117.066.117.35.005.699.021 1.047.005 3.768-.17 7.317-.965 10.14-3.7.89-.86 1.685-1.817 2.544-2.71.716-.746 1.584-1.159 2.645-1.07Zm-8.753-4.67c-2.812.246-5.254 1.409-7.548 2.943-1.766 1.18-3.654 1.738-5.776 1.37-.374-.066-.75-.114-1.124-.17l-.013.156c.135.07.265.151.405.207.354.14.702.308 1.07.395 4.083.971 7.992.474 11.516-1.803 2.221-1.435 4.521-1.707 7.013-1.336.252.038.503.083.756.107.234.022.479.255.795.003-2.179-1.574-4.526-2.096-7.094-1.872Zm-10.049-9.544c1.475.051 2.943-.142 4.486-1.059-.452.04-.643.04-.827.076-2.126.424-4.033-.04-5.733-1.383-.623-.493-1.257-.974-1.889-1.457-2.503-1.914-5.374-2.555-8.514-2.5.05.154.054.26.108.315 3.417 3.455 7.371 5.836 12.369 6.008Zm24.727 17.731c-2.114-2.097-4.952-2.367-7.578-.537 1.738.078 3.043.632 4.101 1.728a13 13 0 0 0 1.182 1.106c1.6 1.29 4.311 1.352 5.896.155-1.861-.726-1.861-.726-3.601-2.452Zm-21.058 16.06c-1.858-3.46-4.981-4.24-8.59-4.008a9.667 9.667 0 0 1 2.977 1.39c.84.586 1.547 1.311 2.243 2.055 1.38 1.473 3.534 2.376 4.962 2.07-.656-.412-1.238-.848-1.592-1.507Zl-.006.006-.036-.004.021.018.012.053Za.127.127 0 0 0 .015.043c.005.008.038 0 .058-.002Zl-.008.01.005.026.024.014Z"
        fill="#FD4F00"
      />
    </svg>
    """
  end
end
