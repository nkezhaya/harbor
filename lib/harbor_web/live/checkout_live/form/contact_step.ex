defmodule HarborWeb.CheckoutLive.Form.ContactStep do
  @moduledoc """
  LiveComponent for the customer information step of the checkout form.
  """
  use HarborWeb, :live_component
  import HarborWeb.CheckoutComponents, only: [continue_button: 1]

  alias Harbor.Accounts.Scope
  alias Harbor.Customers
  alias Harbor.Customers.Customer

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="customer-form"
        class="space-y-4"
        phx-target={@myself}
        phx-submit="continue"
      >
        <.input field={@form[:email]} type="email" label="Email address" autocomplete="email" />

        <.continue_button>Continue</.continue_button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:changeset, fn ->
       email = customer_email(assigns.current_scope)
       customer_changeset(assigns.current_scope, %{"email" => email})
     end)
     |> assign_new(:form, fn %{changeset: changeset} -> to_form(changeset) end)}
  end

  @impl true
  def handle_event("continue", %{"customer" => customer_params}, socket) do
    case Customers.save_customer_profile(socket.assigns.current_scope, customer_params) do
      {:ok, _customer} ->
        send(self(), {:step_continue, %{}, socket.assigns.next_step})

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  def handle_event("continue", _params, socket), do: {:noreply, socket}

  defp customer_email(%Scope{customer: %Customer{email: email}}), do: email
  defp customer_email(_), do: ""

  defp customer_changeset(%Scope{} = scope, params) do
    base_customer = scope.customer || %Customer{}
    Customer.changeset(base_customer, params, scope)
  end
end
