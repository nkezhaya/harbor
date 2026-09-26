defmodule Harbor.Web.Admin.TaxonomyLive.Form do
  use Harbor.Web, :live_view

  alias Harbor.Taxonomies
  alias Harbor.Taxonomies.Taxonomy

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
      <.header>{@page_title}</.header>

      <.form for={@form} id="taxonomy-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:slug]} type="text" label="Slug" />
        <.input field={@form[:position]} type="number" label="Position" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Taxonomy</.button>
          <.button navigate={return_path(@socket, @return_to, @taxonomy)}>Cancel</.button>
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
    taxonomy = Taxonomies.get_taxonomy!(id)

    socket
    |> assign(:page_title, "Edit Taxonomy")
    |> assign(:taxonomy, taxonomy)
    |> assign(:form, to_form(Taxonomies.change_taxonomy(socket.assigns.current_scope, taxonomy)))
  end

  defp apply_action(socket, :new, _params) do
    taxonomy = %Taxonomy{}

    socket
    |> assign(:page_title, "New Taxonomy")
    |> assign(:taxonomy, taxonomy)
    |> assign(:form, to_form(Taxonomies.change_taxonomy(socket.assigns.current_scope, taxonomy)))
  end

  @impl true
  def handle_event("validate", %{"taxonomy" => params}, socket) do
    changeset =
      Taxonomies.change_taxonomy(socket.assigns.current_scope, socket.assigns.taxonomy, params)

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"taxonomy" => params}, socket) do
    save_taxonomy(socket, socket.assigns.live_action, params)
  end

  defp save_taxonomy(socket, :new, params) do
    case Taxonomies.create_taxonomy(socket.assigns.current_scope, params) do
      {:ok, taxonomy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxonomy created successfully")
         |> push_navigate(to: return_path(socket, socket.assigns.return_to, taxonomy))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_taxonomy(socket, :edit, params) do
    case Taxonomies.update_taxonomy(socket.assigns.current_scope, socket.assigns.taxonomy, params) do
      {:ok, taxonomy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxonomy updated successfully")
         |> push_navigate(to: return_path(socket, socket.assigns.return_to, taxonomy))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp return_path(socket, "index", _taxonomy), do: admin_path(socket, "/taxonomies")
  defp return_path(socket, "show", taxonomy), do: admin_path(socket, "/taxonomies/#{taxonomy.id}")
end
