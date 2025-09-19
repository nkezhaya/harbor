defmodule Harbor.TaxFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Tax`
  context.
  """

  alias Harbor.Tax

  def get_general_tax_code! do
    [tax_code | _] = Tax.list_tax_codes()
    tax_code
  end

  def tax_code_fixture(attrs \\ %{}) do
    {:ok, tax_code} =
      attrs
      |> Enum.into(%{
        provider_ref: unique_provider_ref(),
        name: "General - Tangible Goods",
        description:
          "A physical good that can be moved or touched. Also known as tangible personal property."
      })
      |> Tax.create_tax_code()

    tax_code
  end

  defp unique_provider_ref, do: "ref-#{System.unique_integer([:positive])}"
end
