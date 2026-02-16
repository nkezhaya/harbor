defmodule Harbor.Web.UserLive.Login do
  @moduledoc """
  LiveView for user login via magic link or password.
  """
  use Harbor.Web, :live_view

  alias Harbor.{Accounts, Auth}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-8">
        <div class="space-y-3 text-center">
          <.header>
            <p>Log in</p>
            <:subtitle>
              <%= if @current_scope.authenticated? do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                Don't have an account? <.link
                  navigate="/users/register"
                  class="font-semibold text-indigo-600 underline-offset-4 hover:text-indigo-500 hover:underline dark:text-indigo-400 dark:hover:text-indigo-300"
                  phx-no-format
                >Sign up</.link> for an account now.
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action="/users/log-in"
          phx-submit="submit_magic"
          class="space-y-5"
        >
          <.input
            readonly={@current_scope.authenticated?}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="w-full justify-center" variant="primary">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="flex items-center gap-4 text-sm font-medium text-gray-500 dark:text-gray-400">
          <div class="flex-1 border-t border-gray-200 dark:border-white/10" />
          <span>or</span>
          <div class="flex-1 border-t border-gray-200 dark:border-white/10" />
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action="/users/log-in"
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
          class="space-y-5"
        >
          <.input
            readonly={@current_scope.authenticated?}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
          />
          <.button
            class="w-full justify-center"
            name={@form[:remember_me].name}
            value="true"
            variant="primary"
          >
            Log in and stay logged in <span aria-hidden="true">→</span>
          </.button>
          <.button class="w-full justify-center">
            Log in only this time
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Auth.deliver_login_instructions(
        user,
        &url(socket, "/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: "/users/log-in")}
  end
end
