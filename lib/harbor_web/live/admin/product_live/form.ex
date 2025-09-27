defmodule HarborWeb.Admin.ProductLive.Form do
  @moduledoc """
  Admin LiveView for creating and editing products.
  """
  use HarborWeb, :live_view

  alias Ecto.Changeset
  alias Harbor.{Catalog, Config, Tax}
  alias Harbor.Catalog.Forms.ProductForm
  alias Harbor.Catalog.Product

  @impl true
  def render(assigns) do
    ~H"""
    <AdminLayouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      live_action={@live_action}
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
        <.inputs_for :let={product_form} field={@form[:product]}>
          <.input field={product_form[:name]} type="text" label="Name" />
          <.input field={product_form[:slug]} type="text" label="Slug" />
          <.input field={product_form[:description]} type="textarea" label="Description" />
          <.input
            field={product_form[:status]}
            type="select"
            label="Status"
            prompt="Choose a value"
            options={Ecto.Enum.values(Product, :status)}
          />
          <.input
            field={product_form[:tax_code_id]}
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

          <ul role="list" class="divide-y divide-gray-100 dark:divide-white/5">
            <li
              :for={media_upload <- @product_form.media_uploads ++ [1]}
              class="flex justify-between gap-x-6 py-4 px-4 border border-dashed border-gray-900/25 dark:border-white/25 rounded-lg"
            >
              <div class="flex items-center gap-3 overflow-hidden">
                <div class="bg-accent aspect-square shrink-0 rounded">
                  <img
                    src="https://picsum.photos/1000/800?grayscale&amp;random=1"
                    alt="image-01.jpg"
                    class="size-10 rounded-[inherit] object-cover"
                  />
                </div>
                <div class="flex min-w-0 flex-col gap-0.5">
                  <p class="truncate text-sm font-medium">image-01.jpg</p>
                  <p class="text-muted-foreground text-xs">1.46MB</p>
                </div>
              </div>

              <button
                data-slot="button"
                class="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-[color,box-shadow] disabled:pointer-events-none disabled:opacity-50 [&amp;_svg]:pointer-events-none [&amp;_svg:not([class*='size-'])]:size-4 [&amp;_svg]:shrink-0 outline-none focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] text-muted-foreground/80 hover:text-foreground -me-2 size-8 hover:bg-transparent"
                aria-label="Remove file"
              >
                <.icon
                  name="hero-x-mark"
                  class="mx-auto size-6 text-gray-950 dark:text-gray-500"
                />
              </button>
            </li>
          </ul>
        </.inputs_for>
        <footer class="flex flex-wrap items-center gap-3 pt-4">
          <.button phx-disable-with="Saving..." variant="primary">Save Product</.button>
          <.button navigate={return_path(@return_to, @product_form.product)}>Cancel</.button>
        </footer>
      </.form>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(:tax_code_options, tax_code_options())
     |> assign(:uploaded_assets, [])
     |> allow_upload(:media_asset,
       accept: ~w(.jpg .jpeg .png .mp4),
       auto_upload: true,
       external: &prepare_upload/2,
       progress: &handle_progress/3
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp prepare_upload(entry, socket) do
    product_form = socket.assigns.product_form

    case ProductForm.insert_new_media_upload(product_form, entry.client_name, entry.client_type) do
      {:ok, product_form, media_upload} ->
        url = presigned_url(media_upload)
        meta = %{uploader: "S3", key: media_upload.key, url: url}
        {:ok, meta, assign(socket, product_form: product_form)}

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
      {:noreply, put_flash(socket, :info, "file uploaded")}
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
    product = Catalog.get_product!(id)
    product_form = ProductForm.build(product)

    socket
    |> assign(:page_title, "Edit Product")
    |> assign(:product_form, product_form)
    |> assign_form(ProductForm.changeset(product_form))
  end

  defp apply_action(socket, :new, _params) do
    product_form = ProductForm.build(%Product{})

    socket
    |> assign(:page_title, "New Product")
    |> assign(:product_form, product_form)
    |> assign_form(ProductForm.changeset(product_form))
  end

  @impl true
  def handle_event("validate", %{"product_form" => product_params}, socket) do
    changeset =
      socket.assigns.product_form
      |> ProductForm.changeset(product_params)
      |> then(&%{&1 | action: :validate})

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"product_form" => product_params}, socket) do
    save_product(socket, socket.assigns.live_action, product_params)
  end

  defp save_product(socket, :edit, product_params) do
    case ProductForm.update_product(socket.assigns.product_form, product_params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, product))}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_product(socket, :new, product_params) do
    case ProductForm.create_product(socket.assigns.product_form, product_params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, product))}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    socket
    |> assign(:product_form, Changeset.apply_changes(changeset))
    |> assign(:form, to_form(changeset, as: :product_form))
  end

  defp return_path("index", _product), do: ~p"/admin/products"
  defp return_path("show", product), do: ~p"/admin/products/#{product}"
end
