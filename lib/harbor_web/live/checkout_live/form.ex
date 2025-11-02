defmodule HarborWeb.CheckoutLive.Form do
  @moduledoc """
  Placeholder view for the checkout page.
  """
  use HarborWeb, :live_view
  import HarborWeb.CheckoutComponents

  alias Harbor.Checkout

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

        <.main_form />
      </section>
    </Layouts.checkout>
    """
  end

  @doc """
  Renders the placeholder markup for the checkout form workflow.

  The template currently reflects the visual shell while the interactive
  payment, shipping, and review steps are implemented.
  """
  def main_form(assigns) do
    ~H"""
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

      <form class="mt-6">
        <h2 class="text-lg font-medium text-gray-900">Contact information</h2>

        <div class="mt-6">
          <label for="email-address" class="block text-sm/6 font-medium text-gray-700">
            Email address
          </label>
          <div class="mt-2">
            <input
              id="email-address"
              type="email"
              name="email-address"
              autocomplete="email"
              class="block w-full rounded-md bg-white px-3 py-2 text-base text-gray-900 outline-1 -outline-offset-1 outline-gray-300 placeholder:text-gray-400 focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600 sm:text-sm/6"
            />
          </div>
        </div>

        <div class="mt-6">
          <label for="phone" class="block text-sm/6 font-medium text-gray-700">Phone number</label>
          <div class="mt-2">
            <input
              id="phone"
              type="text"
              name="phone"
              autocomplete="tel"
              class="block w-full rounded-md bg-white px-3 py-2 text-base text-gray-900 outline-1 -outline-offset-1 outline-gray-300 placeholder:text-gray-400 focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600 sm:text-sm/6"
            />
          </div>
        </div>

        <button
          type="submit"
          disabled
          class="mt-6 w-full rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-xs hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-hidden disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500"
        >
          Continue
        </button>
      </form>

      <div class="mt-10 divide-y divide-gray-200 border-t border-b border-gray-200">
        <.tab_button>Shipping address</.tab_button>
        <.tab_button>Delivery</.tab_button>
        <.tab_button>Payment details</.tab_button>
        <.tab_button>Review</.tab_button>
      </div>
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

    {:ok, assign(socket, session: session, pricing: pricing)}
  end
end
