defmodule HarborWeb.CheckoutLive.Form.ShippingStep do
  @moduledoc """
  LiveComponent for collecting the shipping address during checkout.
  """
  use HarborWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <.form
      for={@form}
      id="shipping-form"
      class="space-y-4"
      phx-target={@myself}
      phx-submit="continue"
    >
      <p class="text-sm text-gray-700">Shipping form placeholder content.</p>

      <button
        type="submit"
        id="shipping-continue"
        class="w-full rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-xs hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-hidden"
      >
        Continue to delivery
      </button>
    </.form>
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
