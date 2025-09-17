defmodule HarborWeb.PageController do
  @moduledoc """
  Handles public pages like the home page.
  """
  use HarborWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
