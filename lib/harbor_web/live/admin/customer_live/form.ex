defmodule HarborWeb.Admin.CustomerLive.Form do
  use HarborWeb, :live_view

  alias Harbor.Customers
  alias Harbor.Customers.Customer

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
        <:subtitle>Use this form to manage customer records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="customer-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:first_name]} type="text" label="First name" />
        <.input field={@form[:last_name]} type="text" label="Last name" />
        <.input field={@form[:company_name]} type="text" label="Company name" />
        <.input field={@form[:email]} type="text" label="Email" />
        <.input field={@form[:phone]} type="text" label="Phone" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          prompt="Choose a value"
          options={Ecto.Enum.values(Customer, :status)}
        />
        <.input field={@form[:deleted_at]} type="text" label="Deleted at" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Customer</.button>
          <.button navigate={return_path(@return_to, @customer)}>Cancel</.button>
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

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    customer = Customers.get_customer!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Customer")
    |> assign(:customer, customer)
    |> assign(:form, to_form(Customers.change_customer(socket.assigns.current_scope, customer)))
  end

  defp apply_action(socket, :new, _params) do
    customer = %Customer{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Customer")
    |> assign(:customer, customer)
    |> assign(:form, to_form(Customers.change_customer(socket.assigns.current_scope, customer)))
  end

  @impl true
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    changeset =
      Customers.change_customer(
        socket.assigns.current_scope,
        socket.assigns.customer,
        customer_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"customer" => customer_params}, socket) do
    save_customer(socket, socket.assigns.live_action, customer_params)
  end

  defp save_customer(socket, :edit, customer_params) do
    case Customers.update_customer(
           socket.assigns.current_scope,
           socket.assigns.customer,
           customer_params
         ) do
      {:ok, customer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, customer))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_customer(socket, :new, customer_params) do
    case Customers.create_customer(socket.assigns.current_scope, customer_params) do
      {:ok, customer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, customer))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _customer), do: ~p"/admin/customers"
  defp return_path("show", customer), do: ~p"/admin/customers/#{customer}"
end
