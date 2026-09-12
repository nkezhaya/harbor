defmodule Harbor.Auth.UserNotifierTest do
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  alias Harbor.Accounts.User
  alias Harbor.Auth.UserNotifier

  describe "deliver_update_email_instructions/2" do
    test "uses the configured sender for email-change instructions" do
      user = %User{email: "customer@example.com"}
      url = "https://store.example/users/settings/confirm-email/token"

      assert {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)
      assert email.from == {"Test Store", "support@store.example"}
      assert email.to == [{"", user.email}]
      assert email.subject == "Update email instructions"
      assert email.text_body =~ url
      assert_email_sent(email)
    end
  end

  describe "deliver_login_instructions/2" do
    test "uses the configured sender for account confirmation" do
      user = %User{email: "customer@example.com"}
      url = "https://store.example/users/log-in/token"

      assert {:ok, email} = UserNotifier.deliver_login_instructions(user, url)
      assert email.from == {"Test Store", "support@store.example"}
      assert email.to == [{"", user.email}]
      assert email.subject == "Confirmation instructions"
      assert email.text_body =~ url
      assert_email_sent(email)
    end

    test "uses the configured sender for magic-link login" do
      user = %User{email: "customer@example.com", confirmed_at: DateTime.utc_now()}
      url = "https://store.example/users/log-in/token"

      assert {:ok, email} = UserNotifier.deliver_login_instructions(user, url)
      assert email.from == {"Test Store", "support@store.example"}
      assert email.to == [{"", user.email}]
      assert email.subject == "Log in instructions"
      assert email.text_body =~ url
      assert_email_sent(email)
    end
  end
end
