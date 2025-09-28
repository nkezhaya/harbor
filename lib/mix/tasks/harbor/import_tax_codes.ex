defmodule Mix.Tasks.Harbor.ImportTaxCodes do
  @moduledoc "Import tax codes from the configured tax provider"
  @requirements ["app.start"]

  use Mix.Task

  alias Harbor.Config
  alias Harbor.Tax.TaxProvider

  @shortdoc "Import tax codes from the configured tax provider"
  def run(_) do
    provider = Config.tax_provider()
    {:ok, tax_codes} = TaxProvider.list_tax_codes()

    for tc <- tax_codes do
      Harbor.Repo.insert!(Ecto.Changeset.change(%Harbor.Tax.TaxCode{provider: provider}, tc))
    end
  end
end
