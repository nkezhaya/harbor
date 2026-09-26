defmodule Harbor.Web.Admin.TaxonomyLive.Show do
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
        <span id="taxonomy-name">{@taxonomy.name}</span>
        <:subtitle>Manage the taxons belonging to this taxonomy.</:subtitle>
        <:actions>
          <.button navigate={admin_path(@socket, "/taxonomies")}>
            <.icon name="hero-arrow-left" /> Taxonomies
          </.button>
          <.button
            id="edit-taxonomy"
            navigate={admin_path(@socket, "/taxonomies/#{@taxonomy.id}/edit?return_to=show")}
          >
            Edit Taxonomy
          </.button>
          <.button
            :if={not @taxons_empty?}
            id="new-taxon"
            variant="primary"
            navigate={admin_path(@socket, "/taxonomies/#{@taxonomy.id}/taxons/new")}
          >
            <.icon name="hero-plus" /> New Taxon
          </.button>
        </:actions>
      </.header>

      <div class="mb-8">
        <.list>
          <:item title="Slug">{@taxonomy.slug}</:item>
          <:item title="Position">{@taxonomy.position}</:item>
        </.list>
      </div>

      <div :if={@taxons_empty?} id="taxons-empty">
        <.empty_state
          id="new-taxon"
          icon="hero-folder"
          action_label="New Taxon"
          navigate={admin_path(@socket, "/taxonomies/#{@taxonomy.id}/taxons/new")}
        >
          <:header>No taxons</:header>
          <:subheader>Add the first taxon to this taxonomy.</:subheader>
        </.empty_state>
      </div>

      <.table
        :if={not @taxons_empty?}
        id="taxons"
        rows={@streams.taxons}
        row_click={
          fn {_id, taxon} ->
            JS.navigate(admin_path(@socket, "/taxonomies/#{@taxonomy.id}/taxons/#{taxon.id}"))
          end
        }
      >
        <:col :let={{_id, taxon}} label="Name">{taxon.name}</:col>
        <:col :let={{_id, taxon}} label="Parent">
          <span :if={taxon.parent}>{taxon.parent.name}</span>
        </:col>
        <:col :let={{_id, taxon}} label="Slug">{taxon.slug}</:col>
        <:col :let={{_id, taxon}} label="Position">{taxon.position}</:col>
        <:action :let={{_id, taxon}}>
          <.link
            id={"view-taxon-#{taxon.id}"}
            navigate={admin_path(@socket, "/taxonomies/#{@taxonomy.id}/taxons/#{taxon.id}")}
          >
            View
          </.link>
        </:action>
        <:action :let={{_id, taxon}}>
          <.link
            id={"edit-taxon-#{taxon.id}"}
            navigate={admin_path(@socket, "/taxonomies/#{@taxonomy.id}/taxons/#{taxon.id}/edit")}
          >
            Edit
          </.link>
        </:action>
        <:action :let={{_id, taxon}}>
          <.link
            id={"delete-taxon-#{taxon.id}"}
            phx-click="delete"
            phx-value-id={taxon.id}
            data-confirm="Delete this taxon?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    taxonomy = Catalog.get_taxonomy!(id)
    taxons = Catalog.list_taxons(taxonomy.id)

    {:ok,
     socket
     |> assign(:page_title, taxonomy.name)
     |> assign(:taxonomy, taxonomy)
     |> assign(:taxons_empty?, taxons == [])
     |> stream(:taxons, taxons)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    taxon = Catalog.get_taxon!(socket.assigns.taxonomy.id, id)

    case Catalog.delete_taxon(socket.assigns.current_scope, taxon) do
      {:ok, _taxon} ->
        taxons = Catalog.list_taxons(socket.assigns.taxonomy.id)

        {:noreply,
         socket
         |> put_flash(:info, "Taxon deleted successfully")
         |> assign(:taxons_empty?, taxons == [])
         |> stream(:taxons, taxons, reset: true)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Taxons with children or primary product assignments cannot be deleted."
         )}
    end
  end
end
