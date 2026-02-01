defmodule Harbor.Web.Admin.CategoryLive.Show do
  use Harbor.Web, :live_view

  alias Harbor.Catalog
  alias Harbor.Repo

  @impl true
  def render(assigns) do
    ~H"""
    <AdminLayouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      current_path={@current_path}
    >
      <.header>
        Category {@category.name}
        <:subtitle>This is a category record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/categories"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/categories/#{@category}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit category
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@category.name}</:item>
        <:item title="Slug">{@category.slug}</:item>
        <:item title="Position">{@category.position}</:item>
        <:item title="Tax code">
          {category_tax_code(@category)}
        </:item>
        <:item title="Parent">
          <%= if @category.parent do %>
            {@category.parent.name}
          <% end %>
        </:item>
      </.list>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    category =
      socket.assigns.current_scope
      |> Catalog.get_category!(id)
      |> Repo.preload(:tax_code)

    {:ok,
     socket
     |> assign(:page_title, "Show Category")
     |> assign(:category, category)}
  end

  defp category_tax_code(%{tax_code: %{name: name}}), do: name
  defp category_tax_code(%{tax_code_id: tax_code_id}), do: tax_code_id
end
