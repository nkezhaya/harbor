defmodule HarborWeb.CheckoutLive.Form.ReviewStep do
  @moduledoc """
  LiveComponent for the final review step prior to placing an order.
  """
  use HarborWeb, :live_component

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

        <button
          type="submit"
          id="review-continue"
          class="w-full rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-xs hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-hidden"
        >
          Place order
        </button>
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
