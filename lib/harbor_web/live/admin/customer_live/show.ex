defmodule HarborWeb.Admin.CustomerLive.Show do
  use HarborWeb, :live_view

  alias Harbor.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Customer {@customer.id}
        <:subtitle>This is a customer record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/customers"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/customers/#{@customer}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit customer
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="First name">{@customer.first_name}</:item>
        <:item title="Last name">{@customer.last_name}</:item>
        <:item title="Company name">{@customer.company_name}</:item>
        <:item title="Email">{@customer.email}</:item>
        <:item title="Phone">{@customer.phone}</:item>
        <:item title="Status">{@customer.status}</:item>
        <:item title="Deleted at">{@customer.deleted_at}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Customer")
     |> assign(:customer, Customers.get_customer!(socket.assigns.current_scope, id))}
  end
end
