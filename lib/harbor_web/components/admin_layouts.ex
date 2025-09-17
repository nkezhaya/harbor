defmodule HarborWeb.AdminLayouts do
  @moduledoc """
  Admin layout components and helpers for the admin panel.
  """
  use HarborWeb, :html

  embed_templates "admin_layouts/*"

  @doc """
  Renders the admin app layout with a sidebar.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen flex">
      <aside class="w-64 shrink-0 border-r border-base-300 bg-base-200 p-4">
        <div class="mb-6">
          <a href={~p"/admin"} class="font-bold text-lg">Admin</a>
        </div>

        <nav class="menu">
          <ul>
            <li>
              <.link navigate={~p"/admin/products"} class="btn btn-ghost justify-start w-full">
                <.icon name="hero-rectangle-stack" class="size-4 mr-2" /> Products
              </.link>
            </li>
          </ul>
        </nav>
      </aside>

      <section class="flex-1 p-6">
        {render_slot(@inner_block)}
      </section>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end
end
