defmodule HarborWeb.CheckoutLive.Form.ShippingStep do
  @moduledoc """
  LiveComponent for collecting the shipping address during checkout.
  """
  use HarborWeb, :live_component
  import HarborWeb.CheckoutComponents, only: [continue_button: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="shipping-form"
        class="space-y-4"
        phx-target={@myself}
        phx-submit="continue"
      >
        <p class="text-sm text-gray-700">Shipping form placeholder content.</p>

        <.continue_button id="shipping-continue">
          Continue to delivery
        </.continue_button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> to_form(%{}, as: :shipping) end)}
  end

  @impl true
  def handle_event("continue", _params, socket) do
    send(self(), {:step_continue, %{}, socket.assigns.next_step})

    {:noreply, socket}
  end
end
