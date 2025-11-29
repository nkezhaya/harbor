defmodule HarborWeb.CheckoutLive.Form.ReviewStep do
  @moduledoc """
  LiveComponent for the final review step prior to placing an order.
  """
  use HarborWeb, :live_component
  import HarborWeb.CheckoutComponents, only: [continue_button: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="review-form"
        class="space-y-4"
        phx-target={@myself}
        phx-submit="continue"
      >
        <p class="text-sm text-gray-700">Order review placeholder content.</p>

        <.continue_button id="review-continue">
          Place order
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
     |> assign_new(:form, fn -> to_form(%{}, as: :review) end)
     |> assign_new(:next_step, fn -> nil end)}
  end

  @impl true
  def handle_event("continue", _params, socket) do
    send(self(), {:step_continue, %{}, socket.assigns.next_step})

    {:noreply, socket}
  end
end
