defmodule Harbor.Web.Admin.TaxonLive.Form do
  use Harbor.Web, :live_view

  alias Harbor.Catalog
  alias Harbor.Catalog.Taxon

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
        {@page_title}
        <:subtitle>Use this form to manage taxon records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="taxon-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:slug]} type="text" label="Slug" />
        <.input field={@form[:position]} type="number" label="Position" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Taxon</.button>
          <.button navigate={return_path(@socket, @return_to, @taxon)}>Cancel</.button>
        </footer>
      </.form>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    taxon = Catalog.get_taxon!(id)

    socket
    |> assign(:page_title, "Edit Taxon")
    |> assign(:taxon, taxon)
    |> assign(:form, to_form(Catalog.change_taxon(socket.assigns.current_scope, taxon)))
  end

  defp apply_action(socket, :new, _params) do
    taxon = %Taxon{}

    socket
    |> assign(:page_title, "New Taxon")
    |> assign(:taxon, taxon)
    |> assign(:form, to_form(Catalog.change_taxon(socket.assigns.current_scope, taxon)))
  end

  @impl true
  def handle_event("validate", %{"taxon" => taxon_params}, socket) do
    changeset =
      Catalog.change_taxon(
        socket.assigns.current_scope,
        socket.assigns.taxon,
        taxon_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"taxon" => taxon_params}, socket) do
    save_taxon(socket, socket.assigns.live_action, taxon_params)
  end

  defp save_taxon(socket, :edit, taxon_params) do
    case Catalog.update_taxon(socket.assigns.current_scope, socket.assigns.taxon, taxon_params) do
      {:ok, taxon} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxon updated successfully")
         |> push_navigate(to: return_path(socket, socket.assigns.return_to, taxon))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_taxon(socket, :new, taxon_params) do
    case Catalog.create_taxon(socket.assigns.current_scope, taxon_params) do
      {:ok, taxon} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxon created successfully")
         |> push_navigate(to: return_path(socket, socket.assigns.return_to, taxon))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp return_path(socket, "index", _taxon), do: admin_path(socket, "/taxons")
  defp return_path(socket, "show", taxon), do: admin_path(socket, "/taxons/#{taxon.id}")
end
