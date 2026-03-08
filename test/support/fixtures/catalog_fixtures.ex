defmodule Harbor.CatalogFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Catalog` context.
  """
  alias Harbor.AccountsFixtures
  alias Harbor.Catalog

  alias Harbor.Catalog.{
    OptionType,
    OptionValue,
    ProductOptionType,
    ProductOptionValue,
    ProductTypeOptionType,
    Variant,
    VariantOptionValue
  }

  alias Harbor.Repo
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
      |> put_default_variants()

    {:ok, product} = Catalog.create_product(attrs)
    Catalog.get_product!(product.id)
  end

  defp put_default_variants(%{variants: _} = attrs), do: attrs

  defp put_default_variants(attrs) do
    Map.put_new(attrs, :variants, [
      %{
        sku: "sku-#{System.unique_integer([:positive])}",
        price: Money.new(:USD, 40),
        inventory_policy: :track_strict,
        quantity_available: 10,
        enabled: true
      }
    ])
  end

  @doc """
  Creates a product with reusable option types, allowed values, and explicit
  variants.

  Returns the product with option types and variants preloaded.
  """
  def product_with_options_fixture(option_specs, product_attrs \\ %{}) do
    product = product_fixture(Map.put(product_attrs, :variants, []))

    option_types =
      Enum.with_index(option_specs, fn {type_name, value_names}, type_pos ->
        option_type =
          option_type_fixture(%{
            name: "#{type_name} #{System.unique_integer([:positive])}",
            slug: Harbor.Slug.to_slug(type_name),
            position: type_pos
          })

        option_values =
          Enum.with_index(value_names, fn value_name, value_pos ->
            option_value_fixture(option_type,
              name: value_name,
              slug: Harbor.Slug.to_slug(value_name),
              position: value_pos
            )
          end)

        %ProductTypeOptionType{}
        |> ProductTypeOptionType.changeset(%{
          product_type_id: product.product_type_id,
          option_type_id: option_type.id,
          position: type_pos
        })
        |> Repo.insert!()

        %ProductOptionType{}
        |> ProductOptionType.changeset(%{
          product_id: product.id,
          option_type_id: option_type.id,
          product_type_id: product.product_type_id,
          position: type_pos
        })
        |> Repo.insert!()

        Enum.each(option_values, fn option_value ->
          %ProductOptionValue{}
          |> ProductOptionValue.changeset(%{
            product_id: product.id,
            option_type_id: option_type.id,
            option_value_id: option_value.id
          })
          |> Repo.insert!()
        end)

        %{option_type: option_type, option_values: option_values}
      end)

    variants =
      option_types
      |> Enum.map(& &1.option_values)
      |> cartesian_product()
      |> Enum.with_index(fn option_values, index ->
        variant =
          %Variant{product_id: product.id}
          |> Variant.changeset(%{
            sku: "sku-#{product.id}-#{index}",
            price: Money.new(:USD, 40),
            inventory_policy: :track_strict,
            quantity_available: 10,
            enabled: true
          })
          |> Repo.insert!()

        Enum.each(option_values, fn option_value ->
          %VariantOptionValue{}
          |> VariantOptionValue.changeset(%{
            variant_id: variant.id,
            option_value_id: option_value.id,
            option_type_id: option_value.option_type_id
          })
          |> Repo.insert!()
        end)

        variant
      end)

    default_variant = List.first(variants)
    {:ok, _product} = Catalog.update_product(product, %{default_variant_id: default_variant.id})

    Catalog.get_product!(product.id)
  end

  def variant_fixture(attrs \\ %{}) do
    %{variants: [variant | _]} = product_fixture(attrs)
    Repo.preload(variant, [:option_values, :product])
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

  def option_type_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Option Type #{System.unique_integer([:positive])}",
        position: 0
      })

    %OptionType{}
    |> OptionType.changeset(attrs)
    |> Repo.insert!()
  end

  def option_value_fixture(%OptionType{} = option_type, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Option Value #{System.unique_integer([:positive])}",
        option_type_id: option_type.id,
        position: 0
      })

    %OptionValue{}
    |> OptionValue.changeset(attrs)
    |> Repo.insert!()
  end

  defp cartesian_product([]), do: [[]]

  defp cartesian_product([head | tail]) do
    for value <- head, rest <- cartesian_product(tail) do
      [value | rest]
    end
  end
end
