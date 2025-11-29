defmodule HarborWeb.CheckoutLive.Form.ContactStep do
  @moduledoc """
  LiveComponent for the contact information step of the checkout form.
  """
  use HarborWeb, :live_component
  import HarborWeb.CheckoutComponents, only: [continue_button: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="contact-form"
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
     |> assign_new(:form, fn -> to_form(%{"email" => ""}, as: :contact) end)}
  end

  @impl true
  def handle_event("continue", _params, socket) do
    send(self(), {:step_continue, %{}, socket.assigns.next_step})

    {:noreply, socket}
  end
end
