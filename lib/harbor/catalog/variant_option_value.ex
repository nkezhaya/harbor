defmodule Harbor.Catalog.VariantOptionValue do
  @moduledoc """
  Join schema between [Variant](`Harbor.Catalog.Variant`)s and
  [OptionValue](`Harbor.Catalog.OptionValue`)s.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{OptionValue, Variant}

  @primary_key false
  schema "variants_option_values" do
    belongs_to :variant, Variant
    belongs_to :option_value, OptionValue
  end
end
