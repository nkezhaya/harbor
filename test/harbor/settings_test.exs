defmodule Harbor.SettingsTest do
  use Harbor.DataCase, async: true

  alias Harbor.Settings

  describe "get/0" do
    test "returns default settings when no row exists" do
      settings = Settings.get()
      assert settings.payments_enabled == true
      assert settings.delivery_enabled == true
      assert settings.tax_enabled == true
    end
  end

  describe "update/1" do
    test "upserts and returns updated settings" do
      assert {:ok, settings} = Settings.update(%{payments_enabled: false})
      assert settings.payments_enabled == false
      assert settings.delivery_enabled == true
    end

    test "subsequent get/0 reflects the change" do
      {:ok, _} = Settings.update(%{delivery_enabled: false})
      assert Settings.get().delivery_enabled == false
    end
  end

  describe "payments_enabled?/0" do
    test "reflects current state" do
      {:ok, _} = Settings.update(%{payments_enabled: false})
      refute Settings.payments_enabled?()
    end
  end

  describe "delivery_enabled?/0" do
    test "reflects current state" do
      {:ok, _} = Settings.update(%{delivery_enabled: false})
      refute Settings.delivery_enabled?()
    end
  end

  describe "tax_enabled?/0" do
    test "reflects current state" do
      {:ok, _} = Settings.update(%{tax_enabled: false})
      refute Settings.tax_enabled?()
    end
  end
end
