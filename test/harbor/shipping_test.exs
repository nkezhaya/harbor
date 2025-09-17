defmodule Harbor.ShippingTest do
  use Harbor.DataCase

  alias Harbor.Shipping

  # Address management moved to Accounts context

  alias Harbor.Shipping.DeliveryMethod

  import Harbor.ShippingFixtures

  describe "list_delivery_methods/0" do
    test "returns all delivery_methods" do
      delivery_method = delivery_method_fixture()
      assert Shipping.list_delivery_methods() == [delivery_method]
    end
  end

  describe "get_delivery_method!/1" do
    test "returns the delivery_method with given id" do
      delivery_method = delivery_method_fixture()
      assert Shipping.get_delivery_method!(delivery_method.id) == delivery_method
    end
  end

  describe "create_delivery_method/1" do
    test "with valid data creates a delivery_method" do
      valid_attrs = %{name: "some name", price: 42}

      assert {:ok, %DeliveryMethod{} = delivery_method} =
               Shipping.create_delivery_method(valid_attrs)

      assert delivery_method.name == "some name"
      assert delivery_method.price == 42
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Shipping.create_delivery_method(%{name: nil, price: nil})
    end
  end

  describe "update_delivery_method/2" do
    test "with valid data updates the delivery_method" do
      delivery_method = delivery_method_fixture()
      update_attrs = %{name: "some updated name", price: 43}

      assert {:ok, %DeliveryMethod{} = delivery_method} =
               Shipping.update_delivery_method(delivery_method, update_attrs)

      assert delivery_method.name == "some updated name"
      assert delivery_method.price == 43
    end

    test "with invalid data returns error changeset" do
      delivery_method = delivery_method_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Shipping.update_delivery_method(delivery_method, %{name: nil, price: nil})

      assert delivery_method == Shipping.get_delivery_method!(delivery_method.id)
    end
  end

  describe "delete_delivery_method/1" do
    test "deletes the delivery_method" do
      delivery_method = delivery_method_fixture()
      assert {:ok, %DeliveryMethod{}} = Shipping.delete_delivery_method(delivery_method)

      assert_raise Ecto.NoResultsError, fn ->
        Shipping.get_delivery_method!(delivery_method.id)
      end
    end
  end

  describe "change_delivery_method/1" do
    test "returns a delivery_method changeset" do
      delivery_method = delivery_method_fixture()
      assert %Ecto.Changeset{} = Shipping.change_delivery_method(delivery_method)
    end
  end
end
