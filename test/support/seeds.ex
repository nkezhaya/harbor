defmodule Harbor.Seeds do
  @moduledoc false

  alias Harbor.{Config, Repo}
  alias Harbor.Tax.TaxCode

  def run do
    tax_codes =
      [
        {
          "txcd_99999999",
          "A physical good that can be moved or touched. Also known as tangible personal property.",
          "General - Tangible Goods"
        },
        {
          "txcd_20030000",
          "General category for services. It should be used only when there is no more specific services category. In the European Union, the default rule for business-to-consumer sales (B2C) is the location of the seller, whereas for business-to-business sales (B2B) - the location of the buyer.",
          "General - Services"
        },
        {
          "txcd_10000000",
          "A digital service provided mainly through the internet with minimal human involvement, relying on information technology. Consider more specific categories like software, digital goods, cloud services, or website services for your product (especially if you sell in the US). If you stay with this category, taxes will be similar to those for a generic digital item like downloaded music.",
          "General - Electronically Supplied Services"
        },
        {
          "txcd_00000000",
          "Any nontaxable good or service which can be used to ensure no tax is applied, even for jurisdictions that impose a tax.",
          "Nontaxable"
        }
      ]

    now = DateTime.utc_now()

    entries =
      for {provider_ref, description, name} <- tax_codes do
        %{
          provider: Atom.to_string(Config.tax_provider()),
          provider_ref: provider_ref,
          description: description,
          name: name,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(TaxCode, entries,
      on_conflict: :nothing,
      conflict_target: [:provider, :provider_ref]
    )
  end
end
