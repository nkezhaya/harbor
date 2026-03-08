defmodule Harbor.Web.Admin.TaxonLive.Index do
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
      <.header :if={not @taxons_empty?}>
        Listing Taxons
        <:actions>
          <.button variant="primary" navigate={admin_path(@socket, "/taxons/new")}>
            <.icon name="hero-plus" /> New Taxon
          </.button>
        </:actions>
      </.header>

      <div :if={@taxons_empty?} class="mt-8">
        <.empty_state
          icon="hero-rectangle-group"
          action_label="New Taxon"
          navigate={admin_path(@socket, "/taxons/new")}
        >
          <:header>No taxons</:header>
          <:subheader>Get started by creating your first taxon.</:subheader>
        </.empty_state>
      </div>

      <.table
        :if={not @taxons_empty?}
        id="taxons"
        rows={@streams.taxons}
        row_click={fn {_id, taxon} -> JS.navigate(admin_path(@socket, "/taxons/#{taxon.id}")) end}
      >
        <:col :let={{_id, taxon}} label="Name">{taxon.name}</:col>
        <:col :let={{_id, taxon}} label="Parent">
          <%= if taxon.parent do %>
            {taxon.parent.name}
          <% end %>
        </:col>
        <:col :let={{_id, taxon}} label="Slug">{taxon.slug}</:col>
        <:action :let={{_id, taxon}}>
          <div class="sr-only">
            <.link navigate={admin_path(@socket, "/taxons/#{taxon.id}")}>Show</.link>
          </div>
          <.link
            navigate={admin_path(@socket, "/taxons/#{taxon.id}/edit")}
            class="text-indigo-600 transition hover:text-indigo-500 dark:text-indigo-400 dark:hover:text-indigo-300"
          >
            Edit
          </.link>
        </:action>
        <:action :let={{id, taxon}}>
          <.link
            phx-click={JS.push("delete", value: %{id: taxon.id}) |> hide("##{id}")}
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
    taxons = Catalog.list_taxons(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Listing Taxons")
     |> assign(:taxons_empty?, taxons == [])
     |> stream(:taxons, taxons)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: %{current_scope: current_scope}} = socket) do
    taxon = Catalog.get_taxon!(current_scope, id)
    {:ok, _} = Catalog.delete_taxon(current_scope, taxon)

    taxons = Catalog.list_taxons(current_scope)

    {:noreply,
     socket
     |> assign(:taxons_empty?, taxons == [])
     |> stream(:taxons, taxons, reset: true)}
  end
end
