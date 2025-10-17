defmodule Mix.Tasks.Harbor.ImportTaxCodes do
  @shortdoc "Import tax codes from the configured tax provider"
  @moduledoc "Import tax codes from the configured tax provider"

  use Mix.Task

  alias Harbor.{Config, Repo}
  alias Harbor.Tax.{TaxCode, TaxProvider}

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_) do
    provider = Config.tax_provider()
    {:ok, tax_codes} = TaxProvider.list_tax_codes()

    for tc <- tax_codes do
      Repo.insert!(Ecto.Changeset.change(%TaxCode{provider: provider}, tc))
    end
  end
end
