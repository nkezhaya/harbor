defmodule Harbor.Web.Admin.TaxonLive.Show do
  use Harbor.Web, :live_view

  alias Harbor.Taxonomies

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
        <span id="taxon-name">{@taxon.name}</span>
        <:subtitle>Taxonomy: {@taxonomy.name}</:subtitle>
        <:actions>
          <.button id="back-to-taxonomy" navigate={admin_path(@socket, "/taxonomies/#{@taxonomy.id}")}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            id="edit-taxon"
            variant="primary"
            navigate={
              admin_path(
                @socket,
                "/taxonomies/#{@taxonomy.id}/taxons/#{@taxon.id}/edit?return_to=show"
              )
            }
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
          <span :if={@taxon.parent}>{@taxon.parent.name}</span>
        </:item>
      </.list>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(%{"taxonomy_id" => taxonomy_id, "id" => id}, _session, socket) do
    taxonomy = Taxonomies.get_taxonomy!(taxonomy_id)
    taxon = Taxonomies.get_taxon!(taxonomy.id, id)

    {:ok,
     socket
     |> assign(:page_title, "Show Taxon")
     |> assign(:taxonomy, taxonomy)
     |> assign(:taxon, taxon)}
  end
end
