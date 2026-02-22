defmodule Harbor.Web.Admin.OrderLive.Form do
  use Harbor.Web, :live_view

  alias Harbor.Customers
  alias Harbor.Orders
  alias Harbor.Orders.Order

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
        <:subtitle>Use this form to manage order records.</:subtitle>
      </.header>

      <.form for={@form} id="order-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input
          :if={@live_action == :new}
          field={@form[:customer_id]}
          type="select"
          label="Customer"
          prompt="Select a customer"
          options={@customer_options}
        />
        <.input field={@form[:email]} type="text" label="Email" />
        <.input
          :if={@live_action == :new}
          field={@form[:status]}
          type="select"
          label="Status"
          prompt="Choose a value"
          options={Ecto.Enum.values(Order, :status)}
        />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Order</.button>
          <.button navigate={return_path(@socket, @return_to, @order)}>Cancel</.button>
        </footer>
      </.form>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    customers = Customers.list_customers(socket.assigns.current_scope)

    customer_options =
      Enum.map(customers, fn c ->
        label = c.email || "#{c.first_name} #{c.last_name}"
        {label, c.id}
      end)

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(:customer_options, customer_options)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    order = Orders.get_order!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Order")
    |> assign(:order, order)
    |> assign(:form, to_form(Orders.change_order(socket.assigns.current_scope, order)))
  end

  defp apply_action(socket, :new, _params) do
    order = %Order{}

    socket
    |> assign(:page_title, "New Order")
    |> assign(:order, order)
    |> assign(:form, to_form(Orders.change_order(socket.assigns.current_scope, order)))
  end

  @impl true
  def handle_event("validate", %{"order" => order_params}, socket) do
    changeset =
      Orders.change_order(
        socket.assigns.current_scope,
        socket.assigns.order,
        order_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"order" => order_params}, socket) do
    save_order(socket, socket.assigns.live_action, order_params)
  end

  defp save_order(socket, :edit, order_params) do
    case Orders.update_order(
           socket.assigns.current_scope,
           socket.assigns.order,
           order_params
         ) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order updated successfully")
         |> push_navigate(to: return_path(socket, socket.assigns.return_to, order))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_order(socket, :new, order_params) do
    case Orders.create_order(socket.assigns.current_scope, order_params) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order created successfully")
         |> push_navigate(to: return_path(socket, socket.assigns.return_to, order))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(socket, "index", _order), do: admin_path(socket, "/orders")
  defp return_path(socket, "show", order), do: admin_path(socket, "/orders/#{order.id}")
end
