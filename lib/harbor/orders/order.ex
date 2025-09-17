defmodule Harbor.Orders.Order do
  @moduledoc """
  Ecto schema for orders with status and totals.
  """
  use Harbor.Schema

  alias Harbor.Accounts.User
  alias Harbor.Orders.OrderItem

  @type t() :: %__MODULE__{}

  schema "orders" do
    field :status, Ecto.Enum,
      values: [:pending, :paid, :shipped, :delivered, :canceled],
      default: :pending

    field :number, :string
    field :email, :string

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

    belongs_to :user, User
    has_many :items, OrderItem

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :status,
      :number,
      :email,
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
    |> validate_required([
      :status,
      :email,
      :delivery_method_name,
      :subtotal,
      :tax,
      :shipping_price
    ])
    |> cast_assoc(:items)
    |> put_new_order_number()
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

  defp put_new_order_number(changeset) do
    case get_field(changeset, :number) do
      nil ->
        # TODO: Just trusting for now that collisions won't occur, but this will
        # need to be reworked to ensure uniqueness.
        digits = 9

        n =
          :crypto.strong_rand_bytes(16)
          |> :binary.decode_unsigned()
          |> rem(10 ** digits)

        number = :io_lib.format("R~9..0B", [n]) |> IO.iodata_to_binary()

        put_change(changeset, :number, number)

      _ ->
        changeset
    end
  end
end
