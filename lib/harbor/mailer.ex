defmodule Harbor.Mailer do
  @moduledoc """
  Swoosh mailer configuration for delivering emails.
  """
  use Swoosh.Mailer, otp_app: :harbor
end
