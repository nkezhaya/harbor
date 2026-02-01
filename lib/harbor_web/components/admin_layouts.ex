defmodule Harbor.Web.AdminLayouts do
  @moduledoc """
  Admin layout components and helpers for the admin panel.
  """
  use Harbor.Web, :html

  embed_templates "admin_layouts/*"

  @doc """
  Renders the admin app layout with a responsive sidebar.
  """
  attr :flash, :map, required: true
  attr :current_scope, Harbor.Accounts.Scope, required: true
  attr :page_title, :string, default: nil
  attr :current_path, :string, required: true
  slot :inner_block, required: true

  def app(assigns) do
    nav_items =
      [
        %{
          label: "Products",
          href: ~p"/admin/products",
          icon: "hero-tag-solid"
        },
        %{
          label: "Categories",
          href: ~p"/admin/categories",
          icon: "hero-squares-2x2"
        },
        %{
          label: "Customers",
          href: ~p"/admin/customers",
          icon: "hero-user-group"
        }
      ]
      |> Enum.map(&Map.put(&1, :active?, String.starts_with?(assigns.current_path, &1.href)))

    assigns =
      assigns
      |> assign(:nav_items, nav_items)
      |> assign(:current_user, assigns.current_scope.user)

    ~H"""
    <div class="min-h-svh bg-neutral-50 text-gray-900 dark:bg-gray-900 dark:text-gray-100">
      <div
        id="admin-mobile-sidebar"
        class="relative z-50 hidden lg:hidden"
        role="dialog"
        aria-modal="true"
        phx-window-keydown={close_sidebar()}
        phx-key="escape"
      >
        <div class="fixed inset-0 flex">
          <div
            id="admin-mobile-sidebar-backdrop"
            class="fixed inset-0 bg-gray-900/80"
            aria-hidden="true"
            phx-click={close_sidebar()}
          >
          </div>

          <div class="relative flex w-full max-w-xs">
            <div
              id="admin-mobile-sidebar-panel"
              class="relative mr-16 flex w-full flex-1 transform bg-white px-6 pb-2 pt-5 shadow-xl ring-1 ring-black/10 transition duration-200 ease-out dark:bg-gray-900 dark:ring-white/10"
              phx-click-away={close_sidebar()}
            >
              <div class="absolute left-full top-0 flex w-16 justify-center pt-5">
                <button
                  type="button"
                  class="-m-2.5 rounded-md p-2.5 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                  phx-click={close_sidebar()}
                >
                  <span class="sr-only">Close sidebar</span>
                  <.icon name="hero-x-mark" class="size-6" />
                </button>
              </div>

              <div class="flex grow flex-col gap-y-6 overflow-y-auto">
                <.sidebar_brand />
                <.sidebar_nav nav_items={@nav_items} />
                <.sidebar_profile current_user={@current_user} />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="hidden lg:fixed lg:inset-y-0 lg:z-40 lg:flex lg:w-72 lg:flex-col lg:border-r lg:border-gray-200 lg:bg-white lg:px-6 lg:py-8 dark:lg:border-white/10 dark:lg:bg-gray-900">
        <div class="flex grow flex-col gap-y-6">
          <.sidebar_brand />
          <.sidebar_nav nav_items={@nav_items} />
          <.sidebar_profile current_user={@current_user} />
        </div>
      </div>

      <div class="lg:pl-72">
        <div class="sticky top-0 z-30 flex items-center gap-x-6 border-b border-gray-200 bg-white px-4 py-4 shadow-sm sm:px-6 lg:hidden dark:border-white/10 dark:bg-gray-900 dark:shadow-none">
          <button
            type="button"
            class="-m-2.5 rounded-md p-2.5 text-gray-600 hover:text-gray-900 dark:text-gray-300 dark:hover:text-gray-100"
            aria-controls="admin-mobile-sidebar"
            aria-expanded="false"
            phx-click={open_sidebar()}
          >
            <span class="sr-only">Open sidebar</span>
            <.icon name="hero-bars-3" class="size-6" />
          </button>
          <div class="flex-1 text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100">
            {@page_title || "Admin"}
          </div>
          <.sidebar_profile_avatar current_user={@current_user} />
        </div>

        <main class="py-10">
          <div class="px-4 sm:px-6 lg:px-8">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  attr :nav_items, :list, required: true

  defp sidebar_nav(assigns) do
    ~H"""
    <nav class="flex flex-1 flex-col" aria-label="Sidebar">
      <ul class="flex flex-1 flex-col gap-y-8">
        <li>
          <ul role="list" class="-mx-2 space-y-1">
            <li :for={item <- @nav_items}>
              <.link navigate={item.href} class={nav_link_classes(item)}>
                <.icon name={item.icon} class={nav_icon_classes(item)} />
                {item.label}
              </.link>
            </li>
          </ul>
        </li>
      </ul>
    </nav>
    """
  end

  defp sidebar_brand(assigns) do
    ~H"""
    <div class="flex h-14 shrink-0 items-center gap-x-2">
      <span class="inline-flex items-center rounded-md bg-indigo-600/10 px-2 py-1 text-xs font-semibold text-indigo-600 dark:bg-indigo-500/10 dark:text-indigo-300">
        Harbor Admin
      </span>
    </div>
    """
  end

  attr :current_user, Harbor.Accounts.User, required: true

  defp sidebar_profile(assigns) do
    ~H"""
    <div class="mt-auto -mx-3">
      <.link
        navigate={~p"/users/settings"}
        class="flex items-center gap-x-3 rounded-md px-3 py-3 text-sm font-semibold leading-6 text-gray-900 transition hover:bg-gray-100 dark:text-gray-100 dark:hover:bg-white/10"
      >
        <span class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-gray-100 text-base font-medium text-gray-700 dark:bg-gray-800 dark:text-gray-100">
          {user_initials(@current_user)}
        </span>
        <span class="truncate">
          {user_label(@current_user)}
        </span>
      </.link>
    </div>
    """
  end

  attr :current_user, Harbor.Accounts.User, required: true

  defp sidebar_profile_avatar(assigns) do
    ~H"""
    <div class="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100 text-sm font-semibold text-gray-700 dark:bg-gray-800 dark:text-gray-100">
      {user_initials(@current_user)}
    </div>
    """
  end

  defp nav_link_classes(%{active?: true}) do
    [
      "group flex items-center gap-x-3 rounded-md px-2.5 py-2 text-sm font-semibold leading-6",
      "bg-gray-100 text-indigo-600 dark:bg-white/10 dark:text-white"
    ]
  end

  defp nav_link_classes(%{active?: false}) do
    [
      "group flex items-center gap-x-3 rounded-md px-2.5 py-2 text-sm font-semibold leading-6",
      "text-gray-600 hover:bg-gray-100 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/10 dark:hover:text-white"
    ]
  end

  defp nav_icon_classes(%{active?: true}) do
    ["size-5 text-indigo-600 dark:text-white"]
  end

  defp nav_icon_classes(%{active?: false}) do
    ["size-5 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"]
  end

  defp user_initials(%{email: email}) when is_binary(email) do
    email
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "?"
      char -> String.upcase(char)
    end
  end

  defp user_initials(_), do: "?"

  defp user_label(%{email: email}) when is_binary(email), do: email
  defp user_label(_), do: "Profile"

  defp open_sidebar(js \\ %JS{}) do
    js
    |> JS.show(to: "#admin-mobile-sidebar")
    |> JS.show(
      to: "#admin-mobile-sidebar-backdrop",
      transition: {"ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "#admin-mobile-sidebar-panel",
      transition: {"transform ease-out duration-200", "-translate-x-full", "translate-x-0"}
    )
  end

  defp close_sidebar(js \\ %JS{}) do
    js
    |> JS.hide(
      to: "#admin-mobile-sidebar-panel",
      transition: {"transform ease-in duration-150", "translate-x-0", "-translate-x-full"}
    )
    |> JS.hide(
      to: "#admin-mobile-sidebar-backdrop",
      transition: {"ease-out duration-150", "opacity-100", "opacity-0"}
    )
    |> JS.hide(to: "#admin-mobile-sidebar", transition: "ease-out")
  end
end
