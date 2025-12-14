defmodule Harbor.Tax do
  @moduledoc """
  Exposes the public API for tax-related data and provider integrations. The
  context handles persistence concerns such as listing and creating tax codes
  while delegating provider-specific work through behaviours.
  """

  import Ecto.Query
  import Harbor.QueryMacros

  alias Harbor.{Config, Repo}
  alias Harbor.Tax.{Calculation, CalculationLineItem, Request, TaxCode, TaxProvider}

  @doc """
  Fetches a tax calculation from the configured provider using the supplied
  idempotency key to avoid duplicate requests.
  """
  @spec calculate_taxes(Request.t(), String.t()) ::
          TaxProvider.result(%{
            id: String.t(),
            amount: non_neg_integer(),
            line_items: [TaxProvider.line_item()]
          })
  def calculate_taxes(%Request{} = request, idempotency_key) do
    TaxProvider.calculate_taxes(request, idempotency_key)
  end

  ## Tax Codes

  def list_tax_codes do
    provider = Config.tax_provider()

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
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:order_id, :hash])
    |> case do
      {:ok, %Calculation{id: nil} = calculation} ->
        calculation =
          Repo.get_by!(Calculation,
            order_id: calculation.order_id,
            hash: calculation.hash
          )

        {:ok, calculation}

      result ->
        result
    end
  end

  @doc false
  def upsert_calculation_line_items(line_items) do
    Repo.insert_all(CalculationLineItem, line_items,
      on_conflict: :nothing,
      conflict_target: :provider_ref
    )

    :ok
  end
end
