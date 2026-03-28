defmodule Harbor.Web.Admin.ProductLive.VariantForm do
  @moduledoc """
  Admin LiveView for editing a persisted product's variants.
  """
  use Harbor.Web, :live_view
  import Phoenix.HTML.Form, only: [input_id: 2, input_name: 2, input_value: 2]

  alias Ecto.Changeset
  alias Harbor.{Catalog, Tax}
  alias Harbor.Catalog.{Variant, VariantOptionValue}

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:has_variants?, Changeset.get_assoc(assigns.form.source, :variants) != [])
      |> assign(:product_options_by_id, Map.new(assigns.product.product_options, &{&1.id, &1}))

    ~H"""
    <AdminLayouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      current_path={@current_path}
      socket={@socket}
    >
      <.header>
        {@page_title}
        <:subtitle>Manage variants for {@product.name}.</:subtitle>
        <:actions>
          <.button navigate={admin_path(@socket, "/products/#{@product.id}")}>
            <.icon name="hero-arrow-left" /> Back to product
          </.button>
        </:actions>
      </.header>

      <.form
        for={@form}
        id="product-variants-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <.card>
          <:title>Variants</:title>
          <:action>
            <.button
              type="button"
              variant="primary"
              name={input_name(@form, :variants_sort) <> "[]"}
              value="new"
              phx-click={JS.dispatch("change")}
            >
              <.icon name="hero-plus-circle" class="size-5" /> Add Variant
            </.button>
          </:action>
          <:body>
            <div class="space-y-6">
              <div class="rounded-lg bg-gray-50 p-4 text-sm text-gray-600">
                Product options are managed on the product editor. This page only manages persisted variants.
              </div>

              <.error :for={error <- @form[:status].errors}>{translate_error(error)}</.error>
              <.error :for={error <- @form[:variants].errors}>{translate_error(error)}</.error>

              <input type="hidden" name={input_name(@form, :variants_drop) <> "[]"} />

              <.inputs_for
                :let={variant_form}
                field={@form[:variants]}
                append={if @has_variants?, do: [], else: [blank_variant()]}
              >
                <.variant_fields
                  form={@form}
                  variant_form={variant_form}
                  product_options={@product.product_options}
                  tax_code_options={@tax_code_options}
                  product_options_by_id={@product_options_by_id}
                />
              </.inputs_for>
            </div>
          </:body>
        </.card>

        <footer class="flex flex-wrap items-center gap-3 pt-4">
          <.button phx-disable-with="Saving..." variant="primary">Save Variants</.button>
          <.button navigate={admin_path(@socket, "/products/#{@product.id}")}>Cancel</.button>
        </footer>
      </.form>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    product = Catalog.get_product!(id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Variants")
     |> assign(:product, product)
     |> assign(:tax_code_options, tax_code_options())
     |> assign_form(Catalog.change_product_variants(product))}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.product
      |> Catalog.change_product_variants(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    case Catalog.update_product_variants(socket.assigns.product, product_params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Variants updated successfully")
         |> push_navigate(to: admin_path(socket, "/products/#{product.id}"))}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp tax_code_options do
    for tax_code <- Tax.list_tax_codes() do
      {tax_code.name, tax_code.id}
    end
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :product))
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :variant_form, Phoenix.HTML.Form, required: true
  attr :product_options, :list, required: true
  attr :product_options_by_id, :map, required: true
  attr :tax_code_options, :list, required: true

  defp variant_fields(assigns) do
    ~H"""
    <div class="rounded-xl border border-gray-200 p-5 dark:border-white/10">
      <input type="hidden" name={@variant_form[:id].name} value={@variant_form[:id].value} />
      <input
        type="hidden"
        name={input_name(@form, :variants_sort) <> "[]"}
        value={@variant_form.index}
      />

      <div class="flex items-start justify-between gap-4">
        <div class="grid flex-1 gap-4 md:grid-cols-2">
          <.input field={@variant_form[:sku]} type="text" label="SKU" />

          <.input
            field={@variant_form[:price]}
            type="text"
            label="Price"
            placeholder="0.00"
            value={format_money_input(input_value(@variant_form, :price))}
          />

          <.input
            field={@variant_form[:quantity_available]}
            type="number"
            label="Quantity Available"
          />

          <.input
            field={@variant_form[:inventory_policy]}
            type="select"
            label="Inventory Policy"
            options={Ecto.Enum.values(Variant, :inventory_policy)}
          />

          <div class="md:col-span-2">
            <.input field={@variant_form[:enabled]} type="checkbox" label="Enabled" />
          </div>

          <.input
            field={@variant_form[:tax_code_id]}
            type="select"
            label="Tax Override"
            prompt="Use product or product type tax"
            options={@tax_code_options}
          />
        </div>

        <.button
          type="button"
          variant="link"
          name={input_name(@form, :variants_drop) <> "[]"}
          value={@variant_form.index}
          phx-click={JS.dispatch("change")}
        >
          <.icon name="hero-trash" class="size-5" />
        </.button>
      </div>

      <div
        :if={@product_options != []}
        class="mt-6 border-t border-gray-200 pt-5 dark:border-white/10"
      >
        <h4 class="text-sm font-medium text-gray-900 dark:text-white">Option Values</h4>

        <div class="mt-4 grid gap-4 md:grid-cols-2">
          <.inputs_for
            :let={variant_option_value_form}
            field={@variant_form[:variant_option_values]}
            append={
              if Changeset.get_assoc(@variant_form.source, :variant_option_values) == [] do
                blank_variant_option_values(@product_options)
              else
                []
              end
            }
          >
            <.variant_option_value_fields
              form={variant_option_value_form}
              product_options_by_id={@product_options_by_id}
            />
          </.inputs_for>
        </div>

        <div id={input_id(@variant_form, :variant_option_values) <> "_errors"} class="mt-3">
          <.error :for={error <- @variant_form[:variant_option_values].errors}>
            {translate_error(error)}
          </.error>
        </div>
      </div>
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :product_options_by_id, :map, required: true

  defp variant_option_value_fields(assigns) do
    assigns =
      assign(
        assigns,
        :product_option,
        Map.fetch!(assigns.product_options_by_id, input_value(assigns.form, :product_option_id))
      )

    ~H"""
    <div>
      <input
        :if={input_value(@form, :id)}
        type="hidden"
        name={@form[:id].name}
        value={input_value(@form, :id)}
      />
      <input
        type="hidden"
        name={@form[:product_option_id].name}
        value={input_value(@form, :product_option_id)}
      />
      <.input
        field={@form[:product_option_value_id]}
        type="select"
        label={@product_option.name}
        prompt="Choose a value"
        options={option_value_options(@product_option)}
      />
    </div>
    """
  end

  defp option_value_options(product_option) do
    Enum.map(product_option.values, fn value ->
      {value.name, value.id}
    end)
  end

  defp blank_variant do
    %Variant{enabled: true, inventory_policy: :not_tracked, variant_option_values: []}
  end

  defp blank_variant_option_values(product_options) do
    Enum.map(product_options, fn product_option ->
      %VariantOptionValue{product_option_id: product_option.id}
    end)
  end

  defp format_money_input(%Money{} = money) do
    money
    |> Money.to_decimal()
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  defp format_money_input(value) when is_binary(value), do: value
  defp format_money_input(_), do: nil
end
