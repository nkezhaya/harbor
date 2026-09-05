defmodule Harbor.SettingsTest do
  use Harbor.DataCase, async: true

  alias Harbor.Accounts.Scope
  alias Harbor.Settings

  describe "get/0" do
    test "returns the persisted singleton settings" do
      settings = Settings.get()
      assert settings.address_enabled == true
      assert settings.payments_enabled == true
      assert settings.delivery_enabled == true
      assert settings.tax_enabled == true
    end
  end

  describe "update/2" do
    test "updates and returns the settings" do
      assert {:ok, settings} =
               Settings.update(Scope.for_system(), %{payments_enabled: false})

      assert settings.address_enabled == true
      assert settings.payments_enabled == false
      assert settings.delivery_enabled == true
    end

    test "preserves settings omitted from subsequent updates" do
      Settings.update(Scope.for_system(), %{payments_enabled: false})
      assert {:ok, settings} = Settings.update(Scope.for_system(), %{tax_enabled: false})

      refute settings.payments_enabled
      refute settings.tax_enabled
      assert settings.address_enabled
      assert settings.delivery_enabled
    end

    test "rejects unauthorized scopes" do
      assert_raise Harbor.UnauthorizedError, fn ->
        Settings.update(Scope.for_guest(), %{payments_enabled: false})
      end
    end

    test "subsequent get/0 reflects the change" do
      Settings.update(Scope.for_system(), %{delivery_enabled: false})
      refute Settings.get().delivery_enabled
    end
  end

  describe "address_enabled?/0" do
    test "reflects current state" do
      Settings.update(Scope.for_system(), %{address_enabled: false})
      refute Settings.address_enabled?()
    end
  end

  describe "payments_enabled?/0" do
    test "reflects current state" do
      Settings.update(Scope.for_system(), %{payments_enabled: false})
      refute Settings.payments_enabled?()
    end
  end

  describe "delivery_enabled?/0" do
    test "reflects current state" do
      Settings.update(Scope.for_system(), %{delivery_enabled: false})
      refute Settings.delivery_enabled?()
    end
  end

  describe "tax_enabled?/0" do
    test "reflects current state" do
      Settings.update(Scope.for_system(), %{tax_enabled: false})
      refute Settings.tax_enabled?()
    end
  end
end
