defmodule Harbor.Web.Admin.CategoryLive.Index do
  use Harbor.Web, :live_view

  alias Harbor.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <AdminLayouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      current_path={@current_path}
    >
      <.header :if={not @categories_empty?}>
        Listing Categories
        <:actions>
          <.button variant="primary" navigate={~p"/admin/categories/new"}>
            <.icon name="hero-plus" /> New Category
          </.button>
        </:actions>
      </.header>

      <div :if={@categories_empty?} class="mt-8">
        <.empty_state
          icon="hero-rectangle-group"
          action_label="New Category"
          navigate={~p"/admin/categories/new"}
        >
          <:header>No categories</:header>
          <:subheader>Get started by creating your first category.</:subheader>
        </.empty_state>
      </div>

      <.table
        :if={not @categories_empty?}
        id="categories"
        rows={@streams.categories}
        row_click={fn {_id, category} -> JS.navigate(~p"/admin/categories/#{category}") end}
      >
        <:col :let={{_id, category}} label="Name">{category.name}</:col>
        <:col :let={{_id, category}} label="Parent">
          <%= if category.parent do %>
            {category.parent.name}
          <% end %>
        </:col>
        <:col :let={{_id, category}} label="Tax code">{category.tax_code.name}</:col>
        <:action :let={{_id, category}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/categories/#{category}"}>Show</.link>
          </div>
          <.link
            navigate={~p"/admin/categories/#{category}/edit"}
            class="text-indigo-600 transition hover:text-indigo-500 dark:text-indigo-400 dark:hover:text-indigo-300"
          >
            Edit
          </.link>
        </:action>
        <:action :let={{id, category}}>
          <.link
            phx-click={JS.push("delete", value: %{id: category.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
            class="text-red-600 transition hover:text-red-500 dark:text-red-400 dark:hover:text-red-300"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    categories = Catalog.list_categories(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Listing Categories")
     |> assign(:categories_empty?, categories == [])
     |> stream(:categories, categories)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: %{current_scope: current_scope}} = socket) do
    category = Catalog.get_category!(current_scope, id)
    {:ok, _} = Catalog.delete_category(current_scope, category)

    categories = Catalog.list_categories(current_scope)

    {:noreply,
     socket
     |> assign(:categories_empty?, categories == [])
     |> stream(:categories, categories, reset: true)}
  end
end
