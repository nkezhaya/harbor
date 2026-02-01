defmodule Harbor.Web.Admin.CategoryLive.Form do
  use Harbor.Web, :live_view

  alias Harbor.Catalog
  alias Harbor.Catalog.Category
  alias Harbor.Tax

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
        {@page_title}
        <:subtitle>Use this form to manage category records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="category-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:slug]} type="text" label="Slug" />
        <.input field={@form[:position]} type="number" label="Position" />
        <.input
          field={@form[:tax_code_id]}
          type="select"
          label="Tax Code"
          prompt="Choose a tax code"
          options={@tax_code_options}
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Category</.button>
          <.button navigate={return_path(@return_to, @category)}>Cancel</.button>
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
     |> assign(:tax_code_options, tax_code_options())
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    category = Catalog.get_category!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Category")
    |> assign(:category, category)
    |> assign(:form, to_form(Catalog.change_category(socket.assigns.current_scope, category)))
  end

  defp apply_action(socket, :new, _params) do
    category = %Category{}

    socket
    |> assign(:page_title, "New Category")
    |> assign(:category, category)
    |> assign(:form, to_form(Catalog.change_category(socket.assigns.current_scope, category)))
  end

  @impl true
  def handle_event("validate", %{"category" => category_params}, socket) do
    changeset =
      Catalog.change_category(
        socket.assigns.current_scope,
        socket.assigns.category,
        category_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"category" => category_params}, socket) do
    save_category(socket, socket.assigns.live_action, category_params)
  end

  defp save_category(socket, :edit, category_params) do
    case Catalog.update_category(
           socket.assigns.current_scope,
           socket.assigns.category,
           category_params
         ) do
      {:ok, category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, category))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_category(socket, :new, category_params) do
    case Catalog.create_category(socket.assigns.current_scope, category_params) do
      {:ok, category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, category))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp tax_code_options do
    for tax_code <- Tax.list_tax_codes() do
      {tax_code.name, tax_code.id}
    end
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp return_path("index", _category), do: ~p"/admin/categories"
  defp return_path("show", category), do: ~p"/admin/categories/#{category}"
end
