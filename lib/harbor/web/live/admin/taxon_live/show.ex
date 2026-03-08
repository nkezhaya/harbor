defmodule Harbor.Web.Admin.TaxonLive.Show do
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
      socket={@socket}
    >
      <.header>
        Taxon {@taxon.name}
        <:subtitle>This is a taxon record from your database.</:subtitle>
        <:actions>
          <.button navigate={admin_path(@socket, "/taxons")}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={admin_path(@socket, "/taxons/#{@taxon.id}/edit?return_to=show")}
          >
            <.icon name="hero-pencil-square" /> Edit taxon
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@taxon.name}</:item>
        <:item title="Slug">{@taxon.slug}</:item>
        <:item title="Position">{@taxon.position}</:item>
        <:item title="Parent">
          <%= if @taxon.parent do %>
            {@taxon.parent.name}
          <% end %>
        </:item>
      </.list>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    taxon = Catalog.get_taxon!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Show Taxon")
     |> assign(:taxon, taxon)}
  end
end
