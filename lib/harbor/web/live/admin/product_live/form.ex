defmodule Harbor.Web.Admin.ProductLive.Form do
  @moduledoc """
  Admin LiveView for creating and editing products.
  """
  use Harbor.Web, :live_view

  import Phoenix.HTML.Form, only: [input_name: 2]

  alias Ecto.Changeset
  alias Harbor.{Catalog, Config, Tax, Util}
  alias Harbor.Catalog.Forms.MediaUpload
  alias Harbor.Catalog.{Product, ProductOptionValue}

  @impl true
  def render(assigns) do
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
        <:subtitle>Use this form to manage product records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="product-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <div class="grid gap-6 lg:grid-cols-2">
          <.input field={@form[:name]} type="text" label="Name" />
          <.input
            field={@form[:status]}
            type="select"
            label="Status"
            prompt="Choose a value"
            options={Ecto.Enum.values(Product, :status)}
          />
        </div>

        <.input field={@form[:description]} type="textarea" label="Description" />

        <div class="grid gap-6 lg:grid-cols-2">
          <.input
            field={@form[:taxon_ids]}
            type="select"
            label="Taxons"
            options={@taxon_options}
            multiple
          />

          <.input
            field={@form[:primary_taxon_id]}
            type="select"
            label="Primary Taxon"
            prompt="Choose a primary taxon"
            options={@primary_taxon_options}
          />

          <.input
            field={@form[:product_type_id]}
            type="select"
            label="Product Type"
            prompt="Choose a product type"
            options={@product_type_options}
          />

          <.input
            field={@form[:tax_code_id]}
            type="select"
            label="Tax Override"
            prompt="Choose a tax code"
            options={@tax_code_options}
          />

          <.inputs_for :let={master_variant_form} field={@form[:master_variant]}>
            <.input
              field={master_variant_form[:price]}
              type="text"
              label="Price"
              placeholder="0.00"
            />
          </.inputs_for>
        </div>

        <div class="col-span-full">
          <label class="block text-sm/6 font-medium text-gray-900 dark:text-white">
            Media
          </label>
          <div
            class="mt-2 flex justify-center rounded-lg border border-dashed border-gray-900/25 px-6 py-10 dark:border-white/25"
            phx-drop-target={@uploads.media_asset.ref}
          >
            <div class="text-center">
              <.icon
                name="hero-photo-solid"
                class="mx-auto size-12 text-gray-300 dark:text-gray-500"
              />
              <div class="mt-4 flex text-sm/6 text-gray-600 dark:text-gray-400">
                <label
                  for={@uploads.media_asset.ref}
                  class="relative cursor-pointer rounded-md font-semibold text-indigo-600 focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-indigo-600 hover:text-indigo-500 dark:bg-transparent dark:text-indigo-400 dark:focus-within:outline-indigo-500 dark:hover:text-indigo-400"
                >
                  <span>Upload a file</span>
                  <.live_file_input upload={@uploads.media_asset} class="sr-only" />
                </label>
                <p class="pl-1">or drag and drop</p>
              </div>
              <p class="text-xs/5 text-gray-600 dark:text-gray-400">PNG or JPG up to 10MB</p>
            </div>
          </div>
        </div>

        <ul
          id="media-uploads"
          role="list"
          class="divide-y divide-gray-100 dark:divide-white/5 space-y-4"
          phx-hook="Sortable"
          data-list_id="media-uploads"
          data-push_event="sortable:reposition"
        >
          <.media_upload_item :for={media_upload <- @media_uploads} media_upload={media_upload} />
        </ul>

        <.options_card form={@form} product={@product} />

        <.card>
          <:title>Variants</:title>
          <:body>
            <div class="space-y-4">
              <div class="rounded-lg bg-gray-50 p-4 text-sm text-gray-600">
                Create, edit, and remove additional variants on the variants page.
              </div>

              <%= if @product.id do %>
                <div class="flex flex-wrap items-center gap-3">
                  <.button
                    variant="primary"
                    navigate={admin_path(@socket, "/products/#{@product.id}/variants")}
                  >
                    Edit Variants
                  </.button>
                  <p class="text-sm text-gray-600">
                    {ngettext(
                      "%{count} additional variant configured.",
                      "%{count} additional variants configured.",
                      length(@product.variants)
                    )}
                  </p>
                </div>
              <% else %>
                <div class="text-sm text-gray-600">
                  Save this product first. Then you can add variants here if this product needs them.
                </div>
              <% end %>
            </div>
          </:body>
        </.card>

        <footer class="flex flex-wrap items-center gap-3 pt-4">
          <.button phx-disable-with="Saving..." variant="primary">Save Product</.button>
          <.button navigate={return_path(@socket, @return_to, @product)}>Cancel</.button>
        </footer>
      </.form>
    </AdminLayouts.app>
    """
  end

  defp media_upload_item(assigns) do
    ~H"""
    <li
      class={[
        "flex items-center justify-between gap-x-6 rounded-lg border border-dashed border-gray-900/25 px-4 py-4 dark:border-white/25",
        "drag-item:focus-within:ring-0 drag-item:focus-within:ring-offset-0",
        "drag-ghost:border-0 drag-ghost:bg-zinc-300 drag-ghost:ring-0",
        @media_upload.delete && "hidden"
      ]}
      data-sortable_id={@media_upload.id}
    >
      <div class="flex items-center gap-3 overflow-hidden">
        <div class="cursor-grab drag-handle">
          <.icon name="grip-vertical" class="size-5 text-gray-950 dark:gray-200" />
        </div>

        <%= case @media_upload.status do %>
          <% :pending -> %>
            <div class="aspect-square shrink-0 rounded flex">
              <span class="inline-block size-8 border-[3px] border-gray-200 border-b-indigo-600 rounded-full box-border animate-spin">
                <span class="sr-only">Loading...</span>
              </span>
            </div>
          <% :complete -> %>
            <div class="aspect-square shrink-0 rounded">
              <img
                src={ImageHelpers.media_upload_url(@media_upload)}
                alt=""
                class="size-10 rounded-[inherit] object-cover"
              />
            </div>
        <% end %>
        <div class="flex min-w-0 flex-col gap-0.5">
          <p class="truncate text-sm font-medium">{@media_upload.file_name}</p>
          <p class="text-muted-foreground text-xs">
            {Util.format_bytes(@media_upload.file_size)}
          </p>
        </div>
      </div>

      <.button
        type="button"
        variant="link"
        size="custom"
        phx-click="remove_media_upload"
        phx-value-id={@media_upload.id}
        data-slot="button"
        class="justify-center whitespace-nowrap outline-none -me-2 size-8"
        aria-label="Remove file"
      >
        <.icon
          name="hero-x-mark"
          class="mx-auto size-6 text-gray-950 dark:text-gray-500"
        />
      </.button>
    </li>
    """
  end

  defp options_card(assigns) do
    assigns = assign(assigns, :has_variants?, assigns.product.variants != [])

    ~H"""
    <.card>
      <:title>Options</:title>
      <:action :if={not @has_variants?}>
        <.button
          type="button"
          variant="primary"
          name={input_name(@form, :product_options_sort) <> "[]"}
          value="new"
          phx-click={JS.dispatch("change")}
        >
          <.icon name="hero-plus-circle" class="size-5" /> Add Product Option
        </.button>
      </:action>
      <:body>
        <div class="space-y-6">
          <.error :for={error <- @form[:product_options].errors}>{translate_error(error)}</.error>

          <%= if @has_variants? do %>
            <div class="rounded-lg bg-gray-50 p-4 text-sm text-gray-600">
              Product options are locked once variants exist. Edit variants on the separate variant page, or remove variants before changing the option structure.
            </div>

            <div class="space-y-4">
              <div
                :for={product_option <- @product.product_options}
                class="rounded-xl border border-gray-200 p-5 dark:border-white/10"
              >
                <h4 class="text-sm font-medium text-gray-900 dark:text-white">
                  {product_option.name}
                </h4>

                <div class="mt-3 flex flex-wrap gap-2">
                  <span
                    :for={value <- product_option.values}
                    class="inline-flex items-center rounded-md bg-gray-100 px-2 py-1 text-sm text-gray-700 dark:bg-white/10 dark:text-gray-200"
                  >
                    {value.name}
                  </span>
                </div>
              </div>
            </div>
          <% else %>
            <input type="hidden" name={input_name(@form, :product_options_drop) <> "[]"} />

            <div
              :if={@form[:product_options].value == []}
              class="rounded-lg bg-gray-50 p-4 text-sm text-gray-600"
            >
              Add product options like Size or Color here. Each named option must include at least one value.
            </div>

            <.inputs_for :let={product_option_form} field={@form[:product_options]}>
              <div class="rounded-xl border border-gray-200 p-5 dark:border-white/10">
                <input
                  type="hidden"
                  name={product_option_form[:id].name}
                  value={product_option_form[:id].value}
                />
                <input
                  type="hidden"
                  name={input_name(@form, :product_options_sort) <> "[]"}
                  value={product_option_form.index}
                />

                <div class="flex items-start justify-between gap-4">
                  <div class="flex-1">
                    <.input field={product_option_form[:name]} label="Option Name" placeholder="Size" />
                  </div>

                  <.button
                    type="button"
                    variant="link"
                    name={input_name(@form, :product_options_drop) <> "[]"}
                    value={product_option_form.index}
                    phx-click={JS.dispatch("change")}
                    class="mt-8"
                  >
                    <.icon name="hero-trash" class="size-5" />
                  </.button>
                </div>

                <div class="mt-4">
                  <div class="flex items-center justify-between">
                    <h4 class="text-sm font-medium text-gray-900 dark:text-white">Values</h4>

                    <.button
                      type="button"
                      variant="link"
                      name={input_name(product_option_form, :values_sort) <> "[]"}
                      value="new"
                      phx-click={JS.dispatch("change")}
                    >
                      <.icon name="hero-plus-circle" class="size-4" /> Add Value
                    </.button>
                  </div>

                  <input
                    type="hidden"
                    name={input_name(product_option_form, :values_drop) <> "[]"}
                  />

                  <div class="mt-3 space-y-3">
                    <.inputs_for
                      :let={value_form}
                      field={product_option_form[:values]}
                      append={[%ProductOptionValue{}]}
                    >
                      <div class="flex items-start gap-3">
                        <input
                          type="hidden"
                          name={value_form[:id].name}
                          value={value_form[:id].value}
                        />
                        <input
                          type="hidden"
                          name={input_name(product_option_form, :values_sort) <> "[]"}
                          value={value_form.index}
                        />
                        <div class="flex-1">
                          <.input field={value_form[:name]} type="text" placeholder="Small" />
                        </div>

                        <.button
                          type="button"
                          variant="link"
                          name={input_name(product_option_form, :values_drop) <> "[]"}
                          value={value_form.index}
                          phx-click={JS.dispatch("change")}
                          class="mt-2"
                        >
                          <.icon name="hero-trash" class="size-5" />
                        </.button>
                      </div>
                    </.inputs_for>
                    <.error :for={error <- product_option_form[:values].errors}>
                      {translate_error(error)}
                    </.error>
                  </div>
                </div>
              </div>
            </.inputs_for>
          <% end %>
        </div>
      </:body>
    </.card>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(:tax_code_options, tax_code_options())
     |> assign(:taxon_options, taxon_options())
     |> assign(:product_type_options, product_type_options())
     |> allow_upload(:media_asset,
       accept: ~w(.jpg .jpeg .png .mp4),
       auto_upload: true,
       external: &prepare_upload/2,
       max_entries: 8,
       progress: &handle_progress/3
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp prepare_upload(entry, socket) do
    attrs = %{
      id: entry.uuid,
      file_name: entry.client_name,
      file_size: entry.client_size,
      file_type: entry.client_type
    }

    %MediaUpload{}
    |> MediaUpload.changeset(attrs)
    |> Changeset.apply_action(:insert)
    |> case do
      {:ok, media_upload} ->
        socket = update(socket, :media_uploads, &(&1 ++ [media_upload]))
        url = presigned_url(media_upload)
        meta = %{uploader: "S3", key: media_upload.key, url: url}
        {:ok, meta, socket}

      {:error, _changeset} ->
        {:error, %{}, socket}
    end
  end

  defp presigned_url(media_upload) do
    config = ExAws.Config.new(:s3)
    bucket = Config.s3_bucket()

    {:ok, url} =
      ExAws.S3.presigned_url(config, :put, bucket, media_upload.key,
        expires_in: 3600,
        query_params: [
          {"Content-Type", media_upload.file_type},
          {"Cache-Control", "max-age=31536000,public"}
        ]
      )

    url
  end

  defp handle_progress(:media_asset, %{done?: true, uuid: id}, socket) do
    media_uploads =
      Enum.map(socket.assigns.media_uploads, fn
        %{id: ^id} = media_upload -> %{media_upload | status: :complete}
        media_upload -> media_upload
      end)

    {:noreply, assign(socket, :media_uploads, media_uploads)}
  end

  defp handle_progress(:media_asset, _entry, socket) do
    {:noreply, socket}
  end

  defp tax_code_options do
    for tax_code <- Tax.list_tax_codes() do
      {tax_code.name, tax_code.id}
    end
  end

  defp taxon_options do
    for taxon <- Catalog.list_taxons() do
      {taxon.name, taxon.id}
    end
  end

  defp product_type_options do
    for product_type <- Catalog.list_product_types() do
      {product_type.name, product_type.id}
    end
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    product = Catalog.get_product!(id)

    socket
    |> assign(:page_title, "Edit Product")
    |> assign(:product, product)
    |> assign(:media_uploads, Enum.map(product.images, &MediaUpload.from_product_image/1))
    |> assign_form(Catalog.change_product(product))
  end

  defp apply_action(socket, :new, _params) do
    product = %Product{images: [], product_options: [], variants: [], product_taxons: []}

    socket
    |> assign(:page_title, "New Product")
    |> assign(:product, product)
    |> assign(:media_uploads, [])
    |> assign_form(Catalog.change_product(product))
  end

  @impl true
  def handle_event("sortable:reposition", %{"ids" => ids}, socket) do
    media_uploads =
      socket.assigns.media_uploads
      |> Enum.sort_by(fn media_upload -> Enum.find_index(ids, &(&1 == media_upload.id)) end)
      |> Enum.with_index(fn media_upload, position ->
        %{media_upload | position: position}
      end)

    {:noreply, assign(socket, :media_uploads, media_uploads)}
  end

  def handle_event("remove_media_upload", %{"id" => id}, socket) do
    media_uploads =
      Enum.map(socket.assigns.media_uploads, fn
        %{id: ^id} = media_upload -> %{media_upload | delete: true}
        media_upload -> media_upload
      end)

    {:noreply, assign(socket, :media_uploads, media_uploads)}
  end

  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.product
      |> Catalog.change_product(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    save_product(socket, socket.assigns.live_action, product_params)
  end

  defp save_product(socket, live_action, product_params) do
    %{product: product, media_uploads: media_uploads} = socket.assigns

    case Catalog.save_product_with_media(product, product_params, media_uploads) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_success_flash(live_action)
         |> push_navigate(to: return_path(socket, socket.assigns.return_to, product))}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp put_success_flash(socket, :new),
    do: put_flash(socket, :info, "Product created successfully")

  defp put_success_flash(socket, :edit),
    do: put_flash(socket, :info, "Product updated successfully")

  defp assign_form(socket, changeset) do
    primary_taxon_options =
      case Changeset.get_field(changeset, :taxon_ids) do
        [] ->
          socket.assigns.taxon_options

        taxon_ids ->
          Enum.filter(socket.assigns.taxon_options, fn {_name, taxon_id} ->
            taxon_id in taxon_ids
          end)
      end

    socket
    |> assign(:primary_taxon_options, primary_taxon_options)
    |> assign(:form, to_form(changeset, as: :product))
  end

  defp return_path(socket, "index", _product), do: admin_path(socket, "/products")
  defp return_path(socket, "show", product), do: admin_path(socket, "/products/#{product.id}")
end
