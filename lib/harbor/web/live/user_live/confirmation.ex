defmodule Harbor.Web.UserLive.Confirmation do
  @moduledoc """
  LiveView to confirm login via magic link and proceed to sign-in.
  """
  use Harbor.Web, :live_view

  alias Harbor.Auth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-8">
        <div class="text-center">
          <.header>Welcome {@user.email}</.header>
        </div>

        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action="/users/log-in?_action=confirmed"
          phx-trigger-action={@trigger_submit}
          class="space-y-4"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.button
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Confirming..."
            class="w-full justify-center"
            variant="primary"
          >
            Confirm and stay logged in
          </.button>
          <.button phx-disable-with="Confirming..." class="w-full justify-center">
            Confirm and log in only this time
          </.button>
        </.form>

        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action="/users/log-in"
          phx-trigger-action={@trigger_submit}
          class="space-y-4"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <%= if @current_scope.authenticated? do %>
            <.button phx-disable-with="Logging in..." class="w-full justify-center" variant="primary">
              Log in
            </.button>
          <% else %>
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Logging in..."
              class="w-full justify-center"
              variant="primary"
            >
              Keep me logged in on this device
            </.button>
            <.button phx-disable-with="Logging in..." class="w-full justify-center">
              Log me in only this time
            </.button>
          <% end %>
        </.form>

        <div
          :if={!@user.confirmed_at}
          class="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-700 dark:border-white/10 dark:bg-white/5 dark:text-gray-300"
        >
          Tip: If you prefer passwords, you can enable them in the user settings.
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Auth.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: "/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
