defmodule Harbor.Web.Admin.TaxonomyLive.Index do
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
      <.header :if={not @taxonomies_empty?}>
        Taxonomies
        <:subtitle>Organize taxons into categories, departments, or other groupings.</:subtitle>
        <:actions>
          <.button
            id="new-taxonomy"
            variant="primary"
            navigate={admin_path(@socket, "/taxonomies/new")}
          >
            <.icon name="hero-plus" /> New Taxonomy
          </.button>
        </:actions>
      </.header>

      <div :if={@taxonomies_empty?} id="taxonomies-empty" class="mt-8">
        <.empty_state
          id="new-taxonomy"
          icon="hero-squares-2x2"
          action_label="New Taxonomy"
          navigate={admin_path(@socket, "/taxonomies/new")}
        >
          <:header>No taxonomies</:header>
          <:subheader>Create a taxonomy before adding taxons.</:subheader>
        </.empty_state>
      </div>

      <.table
        :if={not @taxonomies_empty?}
        id="taxonomies"
        rows={@streams.taxonomies}
        row_click={
          fn {_id, taxonomy} -> JS.navigate(admin_path(@socket, "/taxonomies/#{taxonomy.id}")) end
        }
      >
        <:col :let={{_id, taxonomy}} label="Name">{taxonomy.name}</:col>
        <:col :let={{_id, taxonomy}} label="Slug">{taxonomy.slug}</:col>
        <:col :let={{_id, taxonomy}} label="Position">{taxonomy.position}</:col>
        <:action :let={{_id, taxonomy}}>
          <.link
            id={"view-taxonomy-#{taxonomy.id}"}
            navigate={admin_path(@socket, "/taxonomies/#{taxonomy.id}")}
          >
            View taxons
          </.link>
        </:action>
        <:action :let={{_id, taxonomy}}>
          <.link
            id={"edit-taxonomy-#{taxonomy.id}"}
            navigate={admin_path(@socket, "/taxonomies/#{taxonomy.id}/edit")}
          >
            Edit
          </.link>
        </:action>
        <:action :let={{_id, taxonomy}}>
          <.link
            id={"delete-taxonomy-#{taxonomy.id}"}
            phx-click="delete"
            phx-value-id={taxonomy.id}
            data-confirm="Delete this taxonomy? It must not contain any taxons."
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
    taxonomies = Taxonomies.list_taxonomies()

    {:ok,
     socket
     |> assign(:page_title, "Taxonomies")
     |> assign(:taxonomies_empty?, taxonomies == [])
     |> stream(:taxonomies, taxonomies)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    taxonomy = Taxonomies.get_taxonomy!(id)

    case Taxonomies.delete_taxonomy(socket.assigns.current_scope, taxonomy) do
      {:ok, _taxonomy} ->
        taxonomies = Taxonomies.list_taxonomies()

        {:noreply,
         socket
         |> put_flash(:info, "Taxonomy deleted successfully")
         |> assign(:taxonomies_empty?, taxonomies == [])
         |> stream(:taxonomies, taxonomies, reset: true)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Delete this taxonomy's taxons before deleting the taxonomy.")}
    end
  end
end
