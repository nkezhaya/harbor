defmodule Harbor.Web.Admin.CustomerLive.Index do
  use Harbor.Web, :live_view

  alias Harbor.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <AdminLayouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      current_path={@current_path}
    >
      <.header :if={not @customers_empty?}>
        Listing Customers
        <:actions>
          <.button variant="primary" navigate={~p"/admin/customers/new"}>
            <.icon name="hero-plus" /> New Customer
          </.button>
        </:actions>
      </.header>

      <div :if={@customers_empty?} class="mt-8">
        <.empty_state
          icon="hero-user-group"
          action_label="New Customer"
          navigate={~p"/admin/customers/new"}
        >
          <:header>No customers</:header>
          <:subheader>Get started by creating your first customer.</:subheader>
        </.empty_state>
      </div>

      <.table
        :if={not @customers_empty?}
        id="customers"
        rows={@streams.customers}
        row_click={fn {_id, customer} -> JS.navigate(~p"/admin/customers/#{customer}") end}
      >
        <:col :let={{_id, customer}} label="First name">{customer.first_name}</:col>
        <:col :let={{_id, customer}} label="Last name">{customer.last_name}</:col>
        <:col :let={{_id, customer}} label="Company name">{customer.company_name}</:col>
        <:col :let={{_id, customer}} label="Email">{customer.email}</:col>
        <:col :let={{_id, customer}} label="Phone">{customer.phone}</:col>
        <:col :let={{_id, customer}} label="Status">{customer.status}</:col>
        <:action :let={{_id, customer}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/customers/#{customer}"}>Show</.link>
          </div>
          <.link
            navigate={~p"/admin/customers/#{customer}/edit"}
            class="text-indigo-600 transition hover:text-indigo-500 dark:text-indigo-400 dark:hover:text-indigo-300"
          >
            Edit
          </.link>
        </:action>
        <:action :let={{id, customer}}>
          <.link
            phx-click={JS.push("delete", value: %{id: customer.id}) |> hide("##{id}")}
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
    customers = Customers.list_customers(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Listing Customers")
     |> assign(:customers_empty?, customers == [])
     |> stream(:customers, customers)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: %{current_scope: current_scope}} = socket) do
    customer = Customers.get_customer!(current_scope, id)
    {:ok, _} = Customers.delete_customer(current_scope, customer)

    customers = Customers.list_customers(current_scope)

    {:noreply,
     socket
     |> assign(:customers_empty?, customers == [])
     |> stream(:customers, customers, reset: true)}
  end
end
