defmodule Harbor.CatalogFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Catalog` context.
  """
  alias Harbor.AccountsFixtures
  alias Harbor.Catalog
  alias Harbor.TaxFixtures

  def product_fixture(attrs \\ %{}) do
    taxon = taxon_fixture()
    product_type = product_type_fixture()

    attrs =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        status: :active,
        primary_taxon_id: taxon.id,
        product_type_id: product_type.id
      })
      |> put_master_variant()

    final_status = Map.fetch!(attrs, :status)
    create_status = if final_status == :active, do: :draft, else: final_status

    create_attrs =
      attrs
      |> Map.drop([:variants, :status])
      |> Map.put(:status, create_status)

    {:ok, product} = Catalog.create_product(create_attrs)
    product = maybe_update_status(product, create_status, final_status)

    Catalog.get_product!(product.id)
  end

  defp put_master_variant(%{variants: [master_variant | _]} = attrs) do
    Map.put_new(attrs, :master_variant, master_variant)
  end

  defp put_master_variant(%{variants: []} = attrs), do: attrs

  defp put_master_variant(attrs) do
    Map.put_new(attrs, :master_variant, %{
      sku: "sku-#{System.unique_integer([:positive])}",
      price: Money.new(:USD, 40),
      inventory_policy: :track_strict,
      quantity_available: 10,
      enabled: true
    })
  end

  def product_with_options_fixture(option_specs, product_attrs \\ %{}) do
    taxon = if Map.has_key?(product_attrs, :primary_taxon_id), do: nil, else: taxon_fixture()

    product_type =
      if Map.has_key?(product_attrs, :product_type_id), do: nil, else: product_type_fixture()

    final_status = Map.get(product_attrs, :status, :active)

    create_attrs =
      product_attrs
      |> Map.drop([:status])
      |> Enum.into(%{
        description: "some description",
        name: "some name #{System.unique_integer([:positive])}",
        status: :draft,
        primary_taxon_id: taxon && taxon.id,
        product_type_id: product_type && product_type.id,
        product_options: build_product_options(option_specs)
      })

    {:ok, product} = Catalog.create_product(create_attrs)
    product = Catalog.get_product!(product.id)

    {:ok, product} =
      Catalog.update_product_variants(product, %{
        variants: build_variants(product.product_options)
      })

    product = maybe_update_status(product, :draft, final_status)

    Catalog.get_product!(product.id)
  end

  def variant_fixture(attrs \\ %{}) do
    product = product_fixture(attrs)
    Harbor.Repo.preload(product.master_variant, [:option_values, :product])
  end

  def product_image_fixture(attrs \\ %{}) do
    {:ok, image} =
      attrs
      |> Enum.into(%{
        image_path: "files/id/original.jpg",
        temp_upload_path: "media_uploads/id/original.jpg",
        position: 0,
        file_name: "original.jpg",
        file_type: "image/jpeg",
        file_size: 100_000
      })
      |> Catalog.create_image()

    image
  end

  def taxon_fixture(attrs \\ %{}) do
    scope = AccountsFixtures.admin_scope_fixture()

    attrs =
      Enum.into(attrs, %{
        name: "some name-#{System.unique_integer([:positive])}",
        parent_ids: []
      })

    {:ok, taxon} = Catalog.create_taxon(scope, attrs)

    taxon
  end

  def product_type_fixture(attrs \\ %{}) do
    tax_code = TaxFixtures.get_general_tax_code!()

    attrs =
      Enum.into(attrs, %{
        name: "Default Product Type #{System.unique_integer([:positive])}",
        tax_code_id: tax_code.id
      })

    {:ok, product_type} = Catalog.create_product_type(attrs)
    product_type
  end

  defp maybe_update_status(product, status, status), do: product

  defp maybe_update_status(product, _current_status, final_status) do
    {:ok, product} = Catalog.update_product(product, %{status: final_status})
    product
  end

  defp build_product_options(option_specs) do
    Enum.with_index(option_specs, fn {option_name, value_names}, option_position ->
      %{
        name: option_name,
        position: option_position,
        values:
          Enum.with_index(value_names, fn value_name, value_position ->
            %{
              name: value_name,
              position: value_position
            }
          end)
      }
    end)
  end

  defp build_variants(product_options) do
    product_options
    |> Enum.map(& &1.values)
    |> cartesian_product()
    |> Enum.with_index(fn product_option_values, index ->
      %{
        sku: "sku-#{System.unique_integer([:positive])}-#{index}",
        price: Money.new(:USD, 40),
        inventory_policy: :track_strict,
        quantity_available: 10,
        enabled: true,
        variant_option_values:
          Enum.map(product_option_values, fn product_option_value ->
            %{
              product_option_id: product_option_value.product_option_id,
              product_option_value_id: product_option_value.id
            }
          end)
      }
    end)
  end

  defp cartesian_product([]), do: [[]]

  defp cartesian_product([head | tail]) do
    for value <- head, rest <- cartesian_product(tail) do
      [value | rest]
    end
  end
end
