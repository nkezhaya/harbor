defmodule Harbor.Web.DateHelpers do
  @moduledoc """
  Template helpers for formatting dates and times.
  """

  @doc """
  Formats a date or datetime as a short human-readable string.

  ## Examples

      iex> DateHelpers.format_date(~U[2021-07-06 14:30:00Z])
      "Jul 6, 2021"

  """
  def format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end

  @doc """
  Formats a datetime with time included.

  ## Examples

      iex> DateHelpers.format_datetime(~U[2021-07-06 14:30:00Z])
      "Jul 6, 2021 02:30 PM"

  """
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %-d, %Y %I:%M %p")
  end

  @doc """
  Formats a date as an ISO 8601 date string, suitable for `<time>` datetime attributes.

  ## Examples

      iex> DateHelpers.format_iso_date(~U[2021-07-06 14:30:00Z])
      "2021-07-06"

  """
  def format_iso_date(date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end
end
