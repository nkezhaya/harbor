defmodule Harbor.Catalog.ProductQuery do
  @moduledoc """
  Embedded schema that parses raw string-keyed params into typed filter,
  sort, and pagination values for product listings.

  Also responsible for applying those filters to a product queryable via
  `apply/2`.
  """
  use Harbor.Schema

  import Harbor.Authorization

  alias Harbor.Catalog.{OptionType, OptionValue, Variant, VariantOptionValue}

  @primary_key false
  embedded_schema do
    field :search, :string
    field :status, Ecto.Enum, values: [:draft, :active, :archived], default: :active
    field :category, :string
    field :price_min, :integer
    field :price_max, :integer
    field :options, :map, default: %{}

    field :sort, Ecto.Enum,
      values: [:newest, :price_asc, :price_desc, :name_asc, :name_desc],
      default: :newest

    field :page, :integer, default: 1
    field :per_page, :integer, default: 20
  end

  @type t() :: %__MODULE__{}

  @spec new(Scope.t(), map()) :: t()
  def new(%Scope{} = scope, params \\ %{}) do
    %__MODULE__{}
    |> cast(params, __MODULE__.__schema__(:fields))
    |> apply_scope(scope)
    |> apply_changes()
  end

  defp apply_scope(changeset, scope) do
    if admin?(scope) do
      changeset
    else
      put_change(changeset, :status, :active)
    end
  end

  @doc """
  Applies the filters, option constraints, and sort order from a
  `ProductQuery` to the given product queryable.
  """
  @spec apply(Ecto.Queryable.t(), t()) :: Ecto.Query.t()
  def apply(queryable, %__MODULE__{} = query) do
    queryable
    |> filter_by_status(query.status)
    |> filter_by_category(query.category)
    |> filter_by_price_range(query.price_min, query.price_max)
    |> filter_by_options(query.options)
    |> filter_by_search(query.search)
    |> apply_sort(query.sort)
  end

  defp filter_by_status(q, nil), do: q
  defp filter_by_status(q, status), do: where(q, [p], p.status == ^status)

  defp filter_by_category(q, nil), do: q

  defp filter_by_category(q, slug) do
    q
    |> join(:inner, [p], c in assoc(p, :category), as: :category)
    |> where([category: c], c.slug == ^slug)
  end

  defp filter_by_price_range(q, nil, nil), do: q

  defp filter_by_price_range(q, min, max) do
    q
    |> ensure_variant_join()
    |> where_price_min(min)
    |> where_price_max(max)
  end

  defp where_price_min(q, nil), do: q
  defp where_price_min(q, min), do: where(q, [variant: v], v.price >= ^min)

  defp where_price_max(q, nil), do: q
  defp where_price_max(q, max), do: where(q, [variant: v], v.price <= ^max)

  defp filter_by_options(q, options) when options == %{}, do: q

  defp filter_by_options(q, options) do
    q =
      if has_named_binding?(q, :product),
        do: q,
        else: from(p in q, as: :product)

    Enum.reduce(options, q, fn {type_slug, value_slugs}, acc ->
      values = String.split(to_string(value_slugs), ",", trim: true)
      filter_by_option_group(acc, type_slug, values)
    end)
  end

  defp filter_by_option_group(q, type_slug, value_slugs) do
    sub =
      Variant
      |> join(:inner, [v], vov in VariantOptionValue, on: vov.variant_id == v.id, as: :vov)
      |> join(:inner, [vov: vov], ov in OptionValue, on: ov.id == vov.option_value_id, as: :ov)
      |> join(:inner, [ov: ov], ot in OptionType, on: ot.id == ov.option_type_id, as: :ot)
      |> where([ot: ot, ov: ov], ot.slug == ^type_slug and ov.slug in ^value_slugs)
      |> where([v], v.product_id == parent_as(:product).id)
      |> select([], 1)

    where(q, exists(sub))
  end

  defp filter_by_search(q, nil), do: q

  defp filter_by_search(q, search) do
    term = "%#{search}%"

    where(
      q,
      [p],
      fragment("word_similarity(?, ?) > 0.3", p.name, ^search) or ilike(p.description, ^term)
    )
  end

  defp apply_sort(q, :newest), do: order_by(q, [p], desc: p.inserted_at)
  defp apply_sort(q, :name_asc), do: order_by(q, [p], asc: p.name)
  defp apply_sort(q, :name_desc), do: order_by(q, [p], desc: p.name)

  defp apply_sort(q, sort) when sort in [:price_asc, :price_desc] do
    dir = if sort == :price_asc, do: :asc, else: :desc

    q
    |> ensure_variant_join()
    |> order_by([variant: v], [{^dir, v.price}])
  end

  defp ensure_variant_join(q) do
    if has_named_binding?(q, :variant) do
      q
    else
      join(q, :inner, [p], v in assoc(p, :default_variant), as: :variant)
    end
  end
end
