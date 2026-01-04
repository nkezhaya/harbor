defmodule Harbor.Orders.Order do
  @moduledoc """
  Ecto schema for orders with status and totals.
  """
  use Harbor.Schema

  alias Harbor.Accounts.Scope
  alias Harbor.Checkout.Cart
  alias Harbor.Customers.Address
  alias Harbor.Customers.Customer
  alias Harbor.Orders.OrderItem
  alias Harbor.Shipping.DeliveryMethod

  @type t() :: %__MODULE__{}

  schema "orders" do
    field :status, Ecto.Enum,
      values: [:draft, :pending, :paid, :shipped, :delivered, :canceled],
      default: :draft

    field :number, :string
    field :email, :string

    belongs_to :billing_address, Address
    belongs_to :shipping_address, Address
    belongs_to :delivery_method, DeliveryMethod
    # Snapshotted address fields
    field :address_name, :string
    field :address_line1, :string
    field :address_line2, :string
    field :address_city, :string
    field :address_region, :string
    field :address_postal_code, :string
    field :address_country, :string
    field :address_phone, :string

    field :delivery_method_name, :string

    field :subtotal, :integer, default: 0
    field :tax, :integer, default: 0
    field :shipping_price, :integer, default: 0
    field :total_price, :integer, read_after_writes: true

    belongs_to :cart, Cart
    belongs_to :customer, Customer
    has_many :items, OrderItem

    timestamps()
  end

  @doc false
  def changeset(order, attrs, scope) do
    order
    |> cast(attrs, [
      :customer_id,
      :cart_id,
      :status,
      :number,
      :email,
      :shipping_address_id,
      :delivery_method_id,
      :address_name,
      :address_line1,
      :address_line2,
      :address_city,
      :address_region,
      :address_postal_code,
      :address_country,
      :address_phone,
      :delivery_method_name,
      :subtotal,
      :tax,
      :shipping_price
    ])
    |> validate_required([:status, :subtotal, :tax, :shipping_price])
    |> cast_assoc(:items)
    |> put_new_order_number()
    |> apply_scope(scope)
    |> check_constraint(:subtotal,
      name: :subtotal_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> check_constraint(:tax, name: :tax_gte_zero, message: "must be greater than or equal to 0")
    |> check_constraint(:shipping_price,
      name: :shipping_price_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:number)
  end

  @doc false
  def submit_changeset(order, attrs, scope) do
    order
    |> changeset(attrs, scope)
    |> validate_required([:email, :delivery_method_id])
    |> require_shipping_address()
    |> denormalize_delivery_method()
    |> denormalize_shipping_address()
  end

  defp denormalize_delivery_method(changeset) do
    case get_assoc(changeset, :delivery_method, :struct) do
      %DeliveryMethod{name: name} -> put_change(changeset, :delivery_method_name, name)
      _ -> changeset
    end
  end

  defp require_shipping_address(changeset) do
    case get_assoc(changeset, :delivery_method, :struct) do
      %DeliveryMethod{fulfillment_type: :ship} ->
        validate_required(changeset, [:shipping_address_id])

      _ ->
        changeset
    end
  end

  defp denormalize_shipping_address(changeset) do
    case get_assoc(changeset, :shipping_address, :struct) do
      %Address{} = address ->
        change(changeset, %{
          address_name: address.name,
          address_line1: address.line1,
          address_line2: address.line2,
          address_city: address.city,
          address_region: address.region,
          address_postal_code: address.postal_code,
          address_country: address.country,
          address_phone: address.phone
        })

      _ ->
        changeset
    end
  end

  @admin_roles [:superadmin, :system]
  defp apply_scope(changeset, %Scope{role: role}) when role in @admin_roles, do: changeset

  defp apply_scope(changeset, %Scope{customer: %Customer{id: customer_id}}) do
    change(changeset, %{customer_id: customer_id})
  end

  defp apply_scope(_changeset, %Scope{}) do
    raise Harbor.UnauthorizedError
  end

  defp put_new_order_number(changeset) do
    case get_field(changeset, :number) do
      nil -> put_change(changeset, :number, random_order_number())
      _ -> changeset
    end
  end

  defp random_order_number do
    digits = 9

    n =
      :crypto.strong_rand_bytes(16)
      |> :binary.decode_unsigned()
      |> rem(10 ** digits)

    :io_lib.format("R~9..0B", [n]) |> IO.iodata_to_binary()
  end
end
