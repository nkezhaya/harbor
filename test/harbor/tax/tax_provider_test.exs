defmodule Harbor.Tax.TaxProviderTest do
  use Harbor.DataCase
  import Mox

  alias Harbor.Tax.TaxProvider

  describe "list_tax_codes/0" do
    test "returns a list of tax codes" do
      expect(Harbor.Tax.TaxProviderMock, :list_tax_codes, fn ->
        {:ok,
         [
           %{
             provider_ref: "txcd_99999999",
             description:
               "Any tangible or physical good. For jurisdictions that impose a tax, the standard rate is applied.",
             name: "General - Tangible Goods"
           }
         ]}
      end)

      assert {:ok, [_tax_code]} = TaxProvider.list_tax_codes()
    end
  end
end
