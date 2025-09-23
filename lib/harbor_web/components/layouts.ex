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

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="border-b border-gray-200 bg-white dark:border-white/10 dark:bg-gray-950">
        <div class="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-4 py-6 sm:flex-nowrap sm:px-6 lg:px-8">
          <a
            href="/"
            class="flex items-center gap-3 text-sm font-semibold text-gray-900 dark:text-white"
          >
            <img src={~p"/images/logo.svg"} width="36" alt="Harbor" class="h-9 w-9" />
            <span class="hidden text-xs font-normal text-gray-500 sm:block dark:text-gray-400">
              Phoenix v{Application.spec(:phoenix, :vsn)}
            </span>
          </a>
          <nav class="flex flex-wrap items-center gap-3 text-sm font-medium text-gray-600 sm:gap-4 dark:text-gray-300">
            <a
              href="https://phoenixframework.org/"
              class="transition hover:text-gray-900 dark:hover:text-white"
            >
              Website
            </a>
            <a
              href="https://github.com/phoenixframework/phoenix"
              class="transition hover:text-gray-900 dark:hover:text-white"
            >
              GitHub
            </a>
            <.theme_toggle />
            <.button
              href="https://hexdocs.pm/phoenix/overview.html"
              variant="primary"
              class="hidden sm:inline-flex"
            >
              Get Started <span aria-hidden="true" class="ml-1">→</span>
            </.button>
          </nav>
        </div>
      </header>

      <main class="px-4 py-16 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-2xl space-y-8">
          {render_slot(@inner_block)}
        </div>
      </main>

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
    <section
      id={@id}
      aria-live="polite"
      class="pointer-events-none fixed inset-x-4 top-4 z-50 flex flex-col items-end gap-3 sm:inset-x-auto sm:right-4"
    >
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
    </section>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="flex items-center gap-2 rounded-full bg-gray-100 p-1 text-gray-500 shadow-inner dark:bg-white/5 dark:text-gray-400">
      <button
        class="inline-flex size-8 items-center justify-center rounded-full transition hover:bg-white hover:text-gray-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 dark:hover:bg-white/10 dark:hover:text-white dark:focus-visible:outline-indigo-500"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="Use system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>
      <button
        class="inline-flex size-8 items-center justify-center rounded-full transition hover:bg-white hover:text-gray-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 dark:hover:bg-white/10 dark:hover:text-white dark:focus-visible:outline-indigo-500"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Use light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>
      <button
        class="inline-flex size-8 items-center justify-center rounded-full transition hover:bg-white hover:text-gray-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 dark:hover:bg-white/10 dark:hover:text-white dark:focus-visible:outline-indigo-500"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Use dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
