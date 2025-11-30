defmodule HarborWeb.CheckoutLive.Form do
  @moduledoc """
  Placeholder view for the checkout page.
  """
  use HarborWeb, :live_view
  import HarborWeb.CheckoutComponents

  alias Harbor.Accounts.Scope
  alias Harbor.Checkout
  alias Harbor.Customers
  alias Harbor.Customers.Customer

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.checkout flash={@flash}>
      <.order_summary cart={@cart} pricing={@pricing} />

      <section
        aria-labelledby="payment-heading"
        class="flex-auto overflow-y-auto px-4 pt-12 pb-16 sm:px-6 sm:pt-16 lg:px-8 lg:pb-24"
      >
        <h2 id="payment-heading" class="sr-only">Payment and shipping details</h2>

        <div class="mx-auto w-full max-w-lg">
          <button
            type="button"
            class="flex w-full items-center justify-center rounded-md border border-transparent bg-black py-2 text-white hover:bg-gray-800 focus:ring-2 focus:ring-gray-900 focus:ring-offset-2 focus:outline-hidden"
          >
            <span class="sr-only">Pay with Apple Pay</span>
            <svg viewBox="0 0 50 20" fill="currentColor" class="h-5 w-auto">
              <path d="M9.536 2.579c-.571.675-1.485 1.208-2.4 1.132-.113-.914.334-1.884.858-2.484C8.565.533 9.564.038 10.374 0c.095.951-.276 1.884-.838 2.579zm.829 1.313c-1.324-.077-2.457.751-3.085.751-.638 0-1.6-.713-2.647-.694-1.362.019-2.628.79-3.323 2.017-1.429 2.455-.372 6.09 1.009 8.087.676.99 1.485 2.075 2.552 2.036 1.009-.038 1.409-.656 2.628-.656 1.228 0 1.58.656 2.647.637 1.104-.019 1.8-.99 2.475-1.979.771-1.122 1.086-2.217 1.105-2.274-.02-.019-2.133-.828-2.152-3.263-.02-2.036 1.666-3.007 1.742-3.064-.952-1.408-2.437-1.56-2.951-1.598zm7.645-2.76v14.834h2.305v-5.072h3.19c2.913 0 4.96-1.998 4.96-4.89 0-2.893-2.01-4.872-4.885-4.872h-5.57zm2.305 1.941h2.656c2 0 3.142 1.066 3.142 2.94 0 1.875-1.142 2.95-3.151 2.95h-2.647v-5.89zM32.673 16.08c1.448 0 2.79-.733 3.4-1.893h.047v1.779h2.133V8.582c0-2.14-1.714-3.52-4.351-3.52-2.447 0-4.256 1.399-4.323 3.32h2.076c.171-.913 1.018-1.512 2.18-1.512 1.41 0 2.2.656 2.2 1.865v.818l-2.876.171c-2.675.162-4.123 1.256-4.123 3.159 0 1.922 1.495 3.197 3.637 3.197zm.62-1.76c-1.229 0-2.01-.59-2.01-1.494 0-.933.752-1.475 2.19-1.56l2.562-.162v.837c0 1.39-1.181 2.379-2.743 2.379zM41.1 20c2.247 0 3.304-.856 4.227-3.454l4.047-11.341h-2.342l-2.714 8.763h-.047l-2.714-8.763h-2.409l3.904 10.799-.21.656c-.352 1.114-.923 1.542-1.942 1.542-.18 0-.533-.02-.676-.038v1.779c.133.038.705.057.876.057z" />
            </svg>
          </button>

          <div class="relative mt-8">
            <div aria-hidden="true" class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-gray-200"></div>
            </div>
            <div class="relative flex justify-center">
              <span class="bg-white px-4 text-sm font-medium text-gray-500">or</span>
            </div>
          </div>

          <div class="divide-y divide-gray-200 border-b border-gray-200">
            <.step
              :if={:contact in @steps}
              id="contact"
              label="Contact information"
              status={step_status(@steps, @session.current_step, :contact)}
            >
              <:summary>{@current_scope.customer.email}</:summary>
              <:body>
                <.contact_step form={@contact_form} />
              </:body>
            </.step>
            <.step
              :if={:shipping in @steps}
              id="shipping"
              label="Shipping address"
              status={step_status(@steps, @session.current_step, :shipping)}
            >
              <:summary>123 Market Street, Springfield</:summary>
              <:body>
                <.shipping_step />
              </:body>
            </.step>
            <.step
              :if={:delivery in @steps}
              id="delivery"
              label="Delivery"
              status={step_status(@steps, @session.current_step, :delivery)}
            >
              <:summary>Standard delivery</:summary>
              <:body>
                <.delivery_step next_step={next_step_for(@steps, :delivery)} />
              </:body>
            </.step>
            <.step
              :if={:payment in @steps}
              id="payment"
              label="Payment details"
              status={step_status(@steps, @session.current_step, :payment)}
            >
              <:summary>•••• •••• •••• 4242</:summary>
              <:body>
                <.payment_step />
              </:body>
            </.step>
            <.step
              :if={:review in @steps}
              id="review"
              label="Review"
              status={step_status(@steps, @session.current_step, :review)}
            >
              <:summary>Ready to confirm</:summary>
              <:body>
                <.review_step />
              </:body>
            </.step>
          </div>
        </div>
      </section>
    </Layouts.checkout>
    """
  end

  attr :form, :any, required: true

  defp contact_step(assigns) do
    ~H"""
    <div>
      <.form for={@form} id="customer-form" class="space-y-4" phx-submit="contact_submit">
        <.input field={@form[:email]} type="email" label="Email address" autocomplete="email" />

        <.continue_button>Continue</.continue_button>
      </.form>
    </div>
    """
  end

  attr :form, :any, default: nil

  defp shipping_step(assigns) do
    assigns = assign_new(assigns, :form, fn -> to_form(%{}) end)

    ~H"""
    <div>
      <.form
        for={@form}
        id="shipping-form"
        class="space-y-4"
        phx-submit="shipping_submit"
      >
        <p class="text-sm text-gray-700">Shipping form placeholder content.</p>

        <.continue_button id="shipping-continue">Continue to delivery</.continue_button>
      </.form>
    </div>
    """
  end

  attr :form, :any, default: nil
  attr :next_step, :atom, default: :payment

  defp delivery_step(assigns) do
    assigns = assign_new(assigns, :form, fn -> to_form(%{}) end)

    ~H"""
    <div>
      <.form
        for={@form}
        id="delivery-form"
        class="space-y-4"
        phx-submit="delivery_submit"
      >
        <p class="text-sm text-gray-700">Delivery options placeholder content.</p>

        <.continue_button id="delivery-continue">Continue to {@next_step}</.continue_button>
      </.form>
    </div>
    """
  end

  attr :form, :any, default: nil

  defp payment_step(assigns) do
    assigns = assign_new(assigns, :form, fn -> to_form(%{}) end)

    ~H"""
    <div>
      <.form
        for={@form}
        id="payment-form"
        class="space-y-4"
        phx-submit="payment_submit"
      >
        <p class="text-sm text-gray-700">Payment form placeholder content.</p>

        <.continue_button id="payment-continue">Continue to review</.continue_button>
      </.form>
    </div>
    """
  end

  attr :form, :any, default: nil

  defp review_step(assigns) do
    assigns = assign_new(assigns, :form, fn -> to_form(%{}) end)

    ~H"""
    <div>
      <.form
        for={@form}
        id="review-form"
        class="space-y-4"
        phx-submit="review_submit"
      >
        <p class="text-sm text-gray-700">Order review placeholder content.</p>

        <.continue_button id="review-continue">Place order</.continue_button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{cart: nil}} = socket) do
    {:ok,
     socket
     |> put_flash(:info, "No cart found.")
     |> push_navigate(to: ~p"/products")}
  end

  def mount(_params, _session, %{assigns: assigns} = socket) do
    %{current_scope: current_scope, cart: cart} = assigns
    session = Checkout.find_or_create_active_session(current_scope, cart)
    pricing = Checkout.build_pricing(session)
    steps = Checkout.checkout_steps(current_scope, session, pricing)
    session = Checkout.ensure_valid_current_step!(current_scope, session, steps)
    contact_form = contact_form(current_scope)

    {:ok,
     assign(socket,
       current_scope: current_scope,
       cart: cart,
       session: session,
       pricing: pricing,
       steps: steps,
       contact_form: contact_form
     )}
  end

  @impl true
  def handle_event("put_step", %{"step" => step_param}, socket) do
    next_step = Enum.find(socket.assigns.steps, &(Atom.to_string(&1) == step_param))

    {:noreply, put_current_step(socket, next_step)}
  end

  def handle_event("contact_submit", %{"customer" => customer_params}, socket) do
    scope = socket.assigns.current_scope

    case Customers.save_customer_profile(scope, customer_params) do
      {:ok, customer} ->
        scope = %{scope | customer: customer}

        {:noreply,
         socket
         |> assign(:current_scope, scope)
         |> assign(:contact_form, contact_form(scope))
         |> put_next_step(:contact)}

      {:error, changeset} ->
        {:noreply, assign(socket, :contact_form, to_form(changeset))}
    end
  end

  def handle_event("shipping_submit", _params, socket) do
    {:noreply, put_next_step(socket, :shipping)}
  end

  def handle_event("delivery_submit", _params, socket) do
    {:noreply, put_next_step(socket, :delivery)}
  end

  def handle_event("payment_submit", _params, socket) do
    {:noreply, put_next_step(socket, :payment)}
  end

  def handle_event("review_submit", _params, socket) do
    {:noreply, socket}
  end

  defp step_status(steps, current_step, target_step) do
    current_idx = Enum.find_index(steps, &(&1 == current_step))
    target_idx = Enum.find_index(steps, &(&1 == target_step))

    cond do
      target_idx == current_idx -> :current
      target_idx < current_idx -> :complete
      true -> :upcoming
    end
  end

  defp put_next_step(socket, step) do
    case next_step_for(socket.assigns.steps, step) do
      nil -> socket
      next_step -> put_current_step(socket, next_step)
    end
  end

  defp next_step_for(steps, current_step) do
    idx = Enum.find_index(steps, &(&1 == current_step))
    Enum.at(steps, idx + 1)
  end

  defp put_current_step(socket, nil), do: socket

  defp put_current_step(%{assigns: %{steps: steps}} = socket, step) do
    if step in steps do
      persist_current_step(socket, step)
    else
      socket
    end
  end

  defp persist_current_step(socket, step) do
    %{current_scope: scope, session: session} = socket.assigns

    case Checkout.update_session(scope, session, %{current_step: step}) do
      {:ok, updated_session} -> assign(socket, session: updated_session)
      {:error, _changeset} -> socket
    end
  end

  defp contact_form(%Scope{} = scope) do
    customer = scope.customer || %Customer{}

    customer
    |> Customer.changeset(%{}, scope)
    |> to_form()
  end
end
