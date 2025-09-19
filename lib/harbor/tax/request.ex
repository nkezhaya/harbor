defmodule Harbor.Tax.Request do
  @moduledoc """
  Defines the normalized representation of data required by external tax
  providers. The struct captures shipping, customer, and line item details so
  adapters can work without depending on checkout-specific structs.
  """

  defstruct [:shipping_price, :customer_details, :line_items]

  @type line_item() :: %{
          price: non_neg_integer(),
          quantity: non_neg_integer(),
          reference: String.t(),
          tax_code_ref: String.t()
        }

  @type address() :: %{
          region: String.t(),
          postal_code: String.t(),
          country: String.t()
        }

  @type t() :: %__MODULE__{
          shipping_price: non_neg_integer(),
          customer_details: %{address: address(), address_source: String.t()},
          line_items: [line_item()]
        }
end
