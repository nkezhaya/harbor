defmodule Harbor.Tax do
  @moduledoc """
  Exposes the public API for tax-related data and provider integrations. The
  context handles persistence concerns such as listing and creating tax codes
  while delegating provider-specific work through behaviours.
  """

  import Ecto.Query
  import Harbor.QueryMacros

  alias Harbor.{Config, Repo}
  alias Harbor.Tax.{Calculation, CalculationLineItem, TaxCode}

  ## Tax Codes

  def list_tax_codes do
    provider = Atom.to_string(Config.tax_provider())

    TaxCode
    |> order_by(:position)
    |> where([tc], tc.provider == ^provider)
    |> where([tc], is_nil(tc.effective_at) or now() >= tc.effective_at)
    |> where([tc], is_nil(tc.ended_at) or now() <= tc.ended_at)
    |> Repo.all()
  end

  def create_tax_code(attrs) do
    %TaxCode{}
    |> TaxCode.changeset(attrs)
    |> Repo.insert()
  end

  def create_calculation(attrs) do
    %Calculation{}
    |> Calculation.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:checkout_session_id, :hash])
    |> case do
      {:ok, calculation} ->
        calculation =
          Repo.get_by!(Calculation,
            checkout_session_id: calculation.checkout_session_id,
            hash: calculation.hash
          )

        {:ok, calculation}

      error ->
        error
    end
  end

  def upsert_calculation_line_items(line_items) do
    Repo.insert_all(CalculationLineItem, line_items,
      on_conflict: :nothing,
      conflict_target: :provider_ref
    )

    :ok
  end
end
