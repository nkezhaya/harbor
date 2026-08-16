defmodule Harbor.Web.CheckoutLive.Form do
  @moduledoc """
  Settings-driven checkout form for contact, fulfillment, payment, and review steps.
  """
  use Harbor.Web, :live_view
  import Harbor.Web.CheckoutComponents

  alias Harbor.{Checkout, Customers, Settings, Shipping}
  alias Harbor.Checkout.Pricing
  alias Harbor.Customers.{Address, Customer}
  alias Harbor.Orders.Order
  alias Localize.Territory

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.checkout flash={@flash}>
      <.order_summary
        order={@order}
        pricing={@pricing}
        tax_enabled={@tax_enabled}
        delivery_enabled={:delivery in @steps}
      />

      <section
        aria-labelledby="payment-heading"
        class="flex-auto overflow-y-auto px-4 pt-12 pb-16 sm:px-6 sm:pt-16 lg:px-8 lg:pb-24"
      >
        <h2 id="payment-heading" class="sr-only">Checkout details</h2>

        <div class="mx-auto w-full max-w-lg">
          <div :if={:payment in @steps} id="express-checkout"></div>

          <div class="divide-y divide-gray-200 border-b border-gray-200">
            <.step
              :if={:contact in @steps}
              id="contact"
              label="Contact information"
              status={step_status(@steps, @session.current_step, :contact)}
            >
              <:summary>
                <%= if @session.order.customer do %>
                  {@session.order.customer.email}
                <% end %>
              </:summary>
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
              <:summary>
                <.address_summary
                  :if={@session.order.shipping_address}
                  address={@session.order.shipping_address}
                />
              </:summary>
              <:body>
                <.shipping_step form={@shipping_form} />
              </:body>
            </.step>
            <.step
              :if={:delivery in @steps}
              id="delivery"
              label="Delivery"
              status={step_status(@steps, @session.current_step, :delivery)}
            >
              <:summary>
                <div :if={@session.order.delivery_method} id="checkout-delivery-summary">
                  <span class="block font-medium text-gray-700">
                    {@session.order.delivery_method.name}
                  </span>
                  <span class="block">{@session.order.delivery_method.price}</span>
                </div>
              </:summary>
              <:body>
                <.delivery_step
                  form={@delivery_form}
                  delivery_methods={@delivery_methods}
                />
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
                <.review_step
                  order={@order}
                  pricing={@pricing}
                  steps={@steps}
                  tax_enabled={@tax_enabled}
                />
              </:body>
            </.step>
          </div>
        </div>
      </section>
    </Layouts.checkout>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true

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

  attr :form, Phoenix.HTML.Form, required: true

  defp shipping_step(assigns) do
    countries =
      AddressInput.countries()
      |> Enum.map(fn country ->
        {Territory.display_name!(country.id, locale: :en), country.id}
      end)
      |> Enum.sort_by(fn {display_name, _id} -> display_name end)

    country = AddressInput.get_country(assigns.form[:country].value)

    subregions =
      for subregion <- country.subregions do
        {subregion.name, subregion.id}
      end

    address_fields = AddressInput.format_fields(country.address_format)

    locality_fields =
      Enum.filter(
        [:sublocality, :region, :postal_code],
        &(&1 in address_fields)
      )

    assigns =
      assigns
      |> assign(:country, country)
      |> assign(:countries, countries)
      |> assign(:subregions, subregions)
      |> assign(:address_fields, address_fields)
      |> assign(:locality_fields, locality_fields)

    ~H"""
    <div>
      <.form
        for={@form}
        id="shipping-form"
        class="space-y-4"
        phx-change="shipping_change"
        phx-submit="shipping_submit"
      >
        <div class="mt-4 grid grid-cols-1 gap-y-6 sm:grid-cols-2 sm:gap-x-4">
          <div>
            <.input
              field={@form[:first_name]}
              type="text"
              label="First name"
              autocomplete="given-name"
            />
          </div>

          <div>
            <.input
              field={@form[:last_name]}
              type="text"
              label="Last name"
              autocomplete="family-name"
            />
          </div>

          <div class="sm:col-span-2">
            <.input field={@form[:company]} type="text" label="Company" />
          </div>

          <div class="sm:col-span-2">
            <.input
              field={@form[:country]}
              type="select"
              label="Country / Region"
              options={@countries}
              autocomplete="country"
            />
          </div>

          <%= if :address in @address_fields do %>
            <div class="sm:col-span-2">
              <.input
                field={@form[:line1]}
                type="text"
                label="Address"
                autocomplete="street-address"
              />
            </div>

            <div class="sm:col-span-2">
              <.input
                field={@form[:line2]}
                type="text"
                label="Apartment, suite, etc."
              />
            </div>
          <% end %>

          <div
            :if={@locality_fields != []}
            class="grid grid-cols-1 gap-x-4 gap-y-6 sm:col-span-2 sm:grid-cols-[repeat(auto-fit,minmax(8rem,1fr))]"
          >
            <div :if={:sublocality in @locality_fields}>
              <.input
                field={@form[:city]}
                type="text"
                label={address_field_label(@country.sublocality_type)}
                autocomplete="address-level2"
              />
            </div>

            <div :if={:region in @locality_fields}>
              <.input
                field={@form[:region]}
                type="select"
                label={address_field_label(@country.subregion_type)}
                options={@subregions}
                autocomplete="address-level1"
              />
            </div>

            <div :if={:postal_code in @locality_fields}>
              <.input
                field={@form[:postal_code]}
                type="text"
                label={address_field_label(@country.postal_code_type)}
                autocomplete="postal-code"
              />
            </div>
          </div>

          <div class="sm:col-span-2">
            <.input field={@form[:phone]} type="text" label="Phone" autocomplete="tel" />
          </div>
        </div>

        <.continue_button id="shipping-continue">Continue to delivery</.continue_button>
      </.form>
    </div>
    """
  end

  defp address_field_label("zip"), do: "ZIP code"
  defp address_field_label("pin"), do: "PIN code"
  defp address_field_label("eircode"), do: "Eircode"
  defp address_field_label(type), do: humanize(type)

  attr :form, Phoenix.HTML.Form, required: true
  attr :delivery_methods, :list, required: true

  defp delivery_step(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="delivery-form"
        class="space-y-4"
        phx-submit="delivery_submit"
      >
        <fieldset
          :if={@delivery_methods != []}
          id="delivery-methods"
          aria-describedby="delivery-method-errors"
        >
          <legend class="sr-only">Delivery method</legend>

          <div class="space-y-4">
            <label
              :for={delivery_method <- @delivery_methods}
              class="relative block rounded-lg border border-gray-300 bg-white px-6 py-4 transition-colors has-checked:outline-2 has-checked:-outline-offset-2 has-checked:outline-indigo-600 has-focus-visible:outline-3 has-focus-visible:-outline-offset-1 hover:not-has-checked:border-gray-400 hover:not-has-checked:bg-gray-50"
            >
              <input
                type="radio"
                id={"delivery-method-#{delivery_method.id}"}
                name={@form[:delivery_method_id].name}
                value={delivery_method.id}
                checked={@form[:delivery_method_id].value == delivery_method.id}
                class="absolute inset-0 cursor-pointer appearance-none focus:outline-none"
              />
              <span class="flex items-center justify-between gap-4">
                <span class="text-sm font-medium text-gray-900">{delivery_method.name}</span>
                <span class="text-sm font-medium text-gray-900">{delivery_method.price}</span>
              </span>
            </label>
          </div>
        </fieldset>

        <div id="delivery-method-errors" class="space-y-2">
          <.error :for={error <- translate_errors(@form.source.errors, :base)}>{error}</.error>
          <.error :for={error <- @form[:delivery_method_id].errors}>
            {translate_error(error)}
          </.error>
        </div>

        <.continue_button id="delivery-continue" disabled={@delivery_methods == []}>
          Continue
        </.continue_button>
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
  attr :order, Order, required: true
  attr :pricing, Pricing, required: true
  attr :steps, :list, required: true
  attr :tax_enabled, :boolean, required: true

  defp review_step(assigns) do
    assigns = assign_new(assigns, :form, fn -> to_form(%{}) end)

    ~H"""
    <div id="checkout-review" class="space-y-6">
      <div>
        <h3 class="text-base font-semibold text-gray-900">Review your order</h3>
        <p class="mt-1 text-sm text-gray-600">
          Confirm your details before submitting.
        </p>
      </div>

      <div class="space-y-6 lg:hidden">
        <section aria-labelledby="review-items-heading">
          <h3 id="review-items-heading" class="font-medium text-gray-900">Items</h3>
          <ul id="review-items" class="mt-2 divide-y divide-gray-200 border-y border-gray-200">
            <li
              :for={item <- @order.items}
              id={"review-item-#{item.id}"}
              class="flex justify-between gap-4 py-3 text-sm"
            >
              <div>
                <p class="font-medium text-gray-900">{item.variant.product.name}</p>
                <p class="text-gray-500">Quantity: {item.quantity}</p>
              </div>
              <p class="font-medium text-gray-900">
                {Money.mult!(item.price, item.quantity)}
              </p>
            </li>
          </ul>
        </section>

        <dl id="review-totals" class="space-y-3 text-sm">
          <div class="flex justify-between">
            <dt class="text-gray-600">Subtotal</dt>
            <dd class="font-medium text-gray-900">{@pricing.subtotal}</dd>
          </div>
          <div :if={@tax_enabled} id="review-tax" class="flex justify-between">
            <dt class="text-gray-600">Taxes</dt>
            <dd class="font-medium text-gray-900">{@pricing.tax || Money.zero(:USD)}</dd>
          </div>
          <div :if={:delivery in @steps} id="review-shipping-price" class="flex justify-between">
            <dt class="text-gray-600">Shipping</dt>
            <dd class="font-medium text-gray-900">{@pricing.shipping_price}</dd>
          </div>
          <div class="flex justify-between border-t border-gray-200 pt-3">
            <dt class="font-semibold text-gray-900">Total</dt>
            <dd class="font-semibold text-gray-900">{@pricing.total_price}</dd>
          </div>
        </dl>
      </div>

      <.form for={@form} id="review-form" phx-submit="review_submit">
        <.continue_button id="review-submit">Submit order</.continue_button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: current_scope}} = socket) do
    case Checkout.get_session(current_scope, id) do
      {:ok, session} ->
        pricing = Checkout.build_pricing(session.order)
        steps = Checkout.checkout_steps(current_scope, session.order, pricing)
        session = Checkout.ensure_valid_current_step!(current_scope, session, steps)

        {:ok,
         assign(socket,
           session: session,
           order: session.order,
           current_scope: current_scope,
           pricing: pricing,
           steps: steps,
           tax_enabled: Settings.tax_enabled?(),
           delivery_methods: Shipping.list_delivery_methods(),
           contact_form: contact_form(current_scope),
           shipping_form: shipping_form(current_scope, session.order),
           delivery_form: delivery_form(session.order)
         )}

      {:error, error} ->
        {:ok, redirect_with_error(socket, error)}
    end
  end

  defp redirect_with_error(socket, error) do
    message =
      case error do
        :not_found -> "Checkout session not found."
        :session_expired -> "Checkout session has expired."
        _ -> "Unable to load checkout session."
      end

    socket
    |> put_flash(:error, message)
    |> push_navigate(to: "/cart")
  end

  @impl true
  def handle_event("put_step", %{"step" => step_param}, socket) do
    next_step = Enum.find(socket.assigns.steps, &(Atom.to_string(&1) == step_param))

    {:noreply, put_current_step(socket, next_step)}
  end

  def handle_event("contact_submit", %{"customer" => customer_params}, socket) do
    scope = socket.assigns.current_scope

    case Checkout.complete_contact_step(scope, socket.assigns.session, customer_params) do
      {:ok, session, scope} ->
        {:noreply,
         socket
         |> assign(
           session: session,
           order: session.order,
           current_scope: scope,
           contact_form: contact_form(scope)
         )
         |> put_next_step(:contact)}

      {:error, changeset} ->
        {:noreply, assign(socket, :contact_form, to_form(changeset))}
    end
  end

  def handle_event("shipping_change", %{"address" => address_params}, socket) do
    %{current_scope: scope, order: order} = socket.assigns

    {:noreply, assign(socket, :shipping_form, shipping_form(scope, order, address_params))}
  end

  def handle_event("shipping_submit", %{"address" => address_params}, socket) do
    scope = socket.assigns.current_scope

    case Checkout.complete_shipping_step(scope, socket.assigns.session, address_params) do
      {:ok, session} ->
        {:noreply,
         socket
         |> assign(:session, session)
         |> assign(:order, session.order)
         |> put_next_step(:shipping)}

      {:error, changeset} ->
        {:noreply, assign(socket, :shipping_form, to_form(changeset))}
    end
  end

  def handle_event("delivery_submit", params, socket) do
    delivery_params = Map.get(params, "delivery", %{})
    scope = socket.assigns.current_scope

    case Checkout.complete_delivery_step(scope, socket.assigns.session, delivery_params) do
      {:ok, session} ->
        pricing = Checkout.build_pricing(session.order)
        steps = Checkout.checkout_steps(scope, session.order, pricing)

        {:noreply,
         socket
         |> assign(
           session: session,
           order: session.order,
           pricing: pricing,
           steps: steps,
           delivery_form: delivery_form(session.order)
         )
         |> put_next_step(:delivery)}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :delivery_form, to_form(%{changeset | action: :validate}, as: :delivery))}
    end
  end

  def handle_event("payment_submit", _params, socket) do
    {:noreply, put_next_step(socket, :payment)}
  end

  def handle_event("review_submit", _params, socket) do
    case Checkout.submit_checkout(socket.assigns.current_scope, socket.assigns.session) do
      {:ok, _order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order placed successfully.")
         |> push_navigate(to: "/checkout/#{socket.assigns.session.id}/receipt")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         put_flash(socket, :error, "We couldn't place your order. Please review the details.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "We couldn't place your order. Please try again.")}
    end
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

  defp contact_form(scope) do
    customer = scope.customer || %Customer{}

    scope
    |> Customers.change_customer(customer, %{})
    |> to_form()
  end

  defp shipping_form(scope, order, params \\ %{}) do
    address =
      if order.shipping_address do
        order.shipping_address
      else
        case Customers.list_addresses(scope) do
          [] -> %Address{country: "US"}
          [address | _] -> address
        end
      end

    scope
    |> Customers.change_address(address, params)
    |> to_form()
  end

  defp delivery_form(order) do
    order
    |> Ecto.Changeset.change()
    |> to_form(as: :delivery)
  end
end
