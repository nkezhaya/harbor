defmodule HarborWeb.CheckoutLive.Form.DeliveryStep do
  @moduledoc """
  LiveComponent for selecting delivery options during checkout.
  """
  use HarborWeb, :live_component
  import HarborWeb.CheckoutComponents, only: [continue_button: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="delivery-form"
        class="space-y-4"
        phx-target={@myself}
        phx-submit="continue"
      >
        <p class="text-sm text-gray-700">Delivery options placeholder content.</p>

        <.continue_button id="delivery-continue">
          Continue to {@next_step}
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
     |> assign_new(:form, fn -> to_form(%{}, as: :delivery) end)}
  end

  @impl true
  def handle_event("continue", _params, socket) do
    send(self(), {:step_continue, %{}, socket.assigns.next_step})

    {:noreply, socket}
  end
end
