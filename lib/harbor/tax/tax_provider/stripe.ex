defmodule Harbor.Tax.TaxProvider.Stripe do
  @moduledoc false

  alias Harbor.Tax.{Request, TaxProvider}

  @behaviour TaxProvider

  @impl true
  def list_tax_codes do
    case do_list_tax_codes() do
      tax_codes when is_list(tax_codes) ->
        tax_codes = Enum.map(tax_codes, &normalize_tax_code/1)
        {:ok, tax_codes}

      {:error, _} = error ->
        error
    end
  end

  defp do_list_tax_codes(starting_after \\ nil) do
    params = %{limit: 100}

    params =
      if starting_after do
        Map.put(params, :starting_after, starting_after)
      else
        params
      end

    case Stripe.TaxCode.list(params) do
      {:ok, %{data: tax_codes, has_more: has_more}} ->
        if has_more do
          tax_codes ++ do_list_tax_codes(List.last(tax_codes).id)
        else
          tax_codes
        end

      {:error, _} = error ->
        error
    end
  end

  defp normalize_tax_code(%Stripe.TaxCode{} = tax_code) do
    %{name: tax_code.name, description: tax_code.description, provider_ref: tax_code.id}
  end

  @impl true
  def calculate_taxes(%Request{line_items: line_items} = request, idempotency_key) do
    line_items =
      for item <- line_items do
        %{
          amount: item.price,
          quantity: item.quantity,
          reference: item.reference,
          tax_code: item.tax_code_ref
        }
      end

    address = request.customer_details.address

    customer_details = %{
      address_source: request.customer_details.address_source,
      address: %{
        state: address.region,
        postal_code: address.postal_code,
        country: address.country
      }
    }

    params = %{
      currency: "usd",
      expand: ["line_items"],
      line_items: line_items,
      shipping_cost: %{amount: request.shipping_price},
      customer_details: customer_details
    }

    case Stripe.Tax.Calculation.create(params, idempotency_key: idempotency_key) do
      {:ok, calculation} ->
        line_items =
          for line_item <- calculation.line_items.data do
            %{id: line_item.id, amount: line_item.amount_tax, reference: line_item.reference}
          end

        {:ok,
         %{id: calculation.id, amount: calculation.tax_amount_exclusive, line_items: line_items}}

      error ->
        error
    end
  end

  @impl true
  def record_transaction(params) do
    params = Map.put(params, :expand, ["line_items"])

    case Stripe.Tax.Transaction.create_from_calculation(params) do
      {:ok, transaction} ->
        line_items =
          for line_item <- transaction.line_items.data do
            %{id: line_item.id, amount: line_item.amount_tax, reference: line_item.reference}
          end

        {:ok, %{id: transaction.id, line_items: line_items}}

      error ->
        error
    end
  end

  @impl true
  def refund_transaction(params) do
    Stripe.Tax.Transaction.create_reversal(params)
  end
end
