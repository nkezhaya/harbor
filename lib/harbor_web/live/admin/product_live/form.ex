defmodule HarborWeb.Admin.ProductLive.Form do
  @moduledoc """
  Admin LiveView for creating and editing products.
  """
  use HarborWeb, :live_view
  import Phoenix.HTML.Form, only: [input_name: 2, normalize_value: 2]

  alias Ecto.Changeset
  alias Harbor.{Catalog, Config, Tax, Util}
  alias Harbor.Catalog.Forms.MediaUpload
  alias Harbor.Catalog.{OptionType, OptionValue, Product}
  alias Harbor.Repo

  @impl true
  def render(assigns) do
    ~H"""
    <AdminLayouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      current_path={@current_path}
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
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          prompt="Choose a value"
          options={Ecto.Enum.values(Product, :status)}
        />
        <.input
          field={@form[:tax_code_id]}
          type="select"
          label="Tax Code"
          prompt="Choose a value"
          options={@tax_code_options}
        />

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
                  class="relative cursor-pointer rounded-md bg-white font-semibold text-indigo-600 focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-indigo-600 hover:text-indigo-500 dark:bg-transparent dark:text-indigo-400 dark:focus-within:outline-indigo-500 dark:hover:text-indigo-400"
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

        <.variants_card form={@form} />
        <footer class="flex flex-wrap items-center gap-3 pt-4">
          <.button phx-disable-with="Saving..." variant="primary">Save Product</.button>
          <.button navigate={return_path(@return_to, @product)}>Cancel</.button>
        </footer>
      </.form>
    </AdminLayouts.app>
    """
  end

  defp media_upload_item(assigns) do
    class = [
      "flex justify-between items-center gap-x-6 py-4 px-4 border border-dashed border-gray-900/25 dark:border-white/25 rounded-lg",
      "drag-item:focus-within:ring-0 drag-item:focus-within:ring-offset-0",
      "drag-ghost:bg-zinc-300 drag-ghost:border-0 drag-ghost:ring-0"
    ]

    class =
      if assigns.media_upload.delete do
        class ++ ["hidden"]
      else
        class
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <li class={@class} data-sortable_id={@media_upload.id}>
      <div class="flex items-center gap-3 overflow-hidden">
        <div class="cursor-grab drag-handle">
          <.icon name="hero-bars-3" class="size-5 text-gray-400 dark:gray-200" />
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

  defp variants_card(assigns) do
    ~H"""
    <.card hide_body={@form[:option_types].value == []}>
      <:title>Variants</:title>
      <:action>
        <.button type="button" variant="primary">
          <.icon name="hero-plus-circle" class="size-5" /> Add Option Type
          <input type="checkbox" name={input_name(@form, :option_types_sort) <> "[]"} />
        </.button>
      </:action>
      <:body>
        <div id="variants-card" phx-hook="Sortable" data-list_id="option_types">
          <.inputs_for :let={option_types_form} field={@form[:option_types]}>
            <div class="pt-2 pb-4 drag-item" data-sortable_id={option_types_form.id}>
              <div class="cursor-grab drag-handle">
                <.icon name="hero-bars-3" class="size-5 text-gray-400 dark:gray-200" />
              </div>

              <input
                type="hidden"
                name={input_name(@form, :option_types_sort) <> "[]"}
                value={option_types_form.index}
              />

              <.input
                field={option_types_form[:name]}
                type="text"
                label="Option Name"
                placeholder="Size"
              />

              <h6 class="block text-sm/6 font-medium text-gray-900 dark:text-white pt-2">
                Option Types
              </h6>
              <.inputs_for
                :let={values_form}
                field={option_types_form[:values]}
                append={[%OptionValue{}]}
              >
                <div :if={not normalize_value("checkbox", values_form[:delete].value)} class="flex">
                  <div class="grow">
                    <.input field={values_form[:name]} type="text" placeholder="Small" />
                  </div>

                  <label>
                    <div
                      class="justify-center whitespace-nowrap outline-none -me-2 size-8"
                      aria-label="Remove option type"
                    >
                      <.icon
                        name="hero-x-mark"
                        class="mx-auto size-6 text-gray-950 dark:text-gray-500"
                      />
                    </div>
                    <.input
                      field={values_form[:delete]}
                      type="checkbox"
                      class="hidden"
                    />
                  </label>
                </div>
              </.inputs_for>
            </div>
          </.inputs_for>
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
        media_uploads = socket.assigns.media_uploads ++ [media_upload]
        url = presigned_url(media_upload)
        meta = %{uploader: "S3", key: media_upload.key, url: url}
        {:ok, meta, assign(socket, media_uploads: media_uploads)}

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
        query_params: [{"Content-Type", media_upload.file_type}]
      )

    url
  end

  defp handle_progress(:media_asset, entry, socket) do
    if entry.done? do
      id = entry.uuid

      media_uploads =
        Enum.map(socket.assigns.media_uploads, fn
          %{id: ^id} = media_upload -> %{media_upload | status: :complete}
          media_upload -> media_upload
        end)

      {:noreply, assign(socket, media_uploads: media_uploads)}
    else
      {:noreply, socket}
    end
  end

  defp tax_code_options do
    for tax_code <- Tax.list_tax_codes() do
      {tax_code.name, tax_code.id}
    end
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    product =
      id
      |> Catalog.get_product!()
      |> Repo.preload([:images, option_types: [:values]])

    media_uploads = Enum.map(product.images, &MediaUpload.from_product_image/1)

    socket
    |> assign(:page_title, "Edit Product")
    |> assign(:product, product)
    |> assign(:media_uploads, media_uploads)
    |> assign_form(Catalog.change_product(product))
  end

  defp apply_action(socket, :new, _params) do
    product = %Product{option_types: [], images: []}

    socket
    |> assign(:page_title, "New Product")
    |> assign(:product, product)
    |> assign(:media_uploads, [])
    |> assign_form(Catalog.change_product(product))
  end

  @impl true
  def handle_event("sortable:reposition", %{"ids" => ids}, socket) do
    media_uploads =
      Enum.sort_by(socket.assigns.media_uploads, fn media_upload ->
        Enum.find_index(ids, &(&1 == media_upload.id))
      end)

    {:noreply, assign(socket, media_uploads: media_uploads)}
  end

  def handle_event("remove_media_upload", %{"id" => id}, socket) do
    media_uploads =
      Enum.map(socket.assigns.media_uploads, fn
        %{id: ^id} = media_upload -> %{media_upload | delete: true}
        media_upload -> media_upload
      end)

    {:noreply, assign(socket, media_uploads: media_uploads)}
  end

  def handle_event("add_option_type", _params, socket) do
    socket =
      update(socket, :form, fn %{source: changeset} ->
        option_types = Changeset.get_assoc(changeset, :option_types)

        new_option_type = %OptionType{
          position: length(option_types),
          values: []
        }

        changeset
        |> Changeset.put_assoc(:option_types, option_types ++ [new_option_type])
        |> to_form()
      end)

    {:noreply, socket}
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
         |> push_navigate(to: return_path(socket.assigns.return_to, product))}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp put_success_flash(socket, :new),
    do: put_flash(socket, :info, "Product created successfully")

  defp put_success_flash(socket, :edit),
    do: put_flash(socket, :info, "Product updated successfully")

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :product))
  end

  defp return_path("index", _product), do: ~p"/admin/products"
  defp return_path("show", product), do: ~p"/admin/products/#{product}"
end
