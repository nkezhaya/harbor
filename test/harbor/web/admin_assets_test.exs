defmodule Harbor.Web.AdminAssetsTest do
  use Harbor.ConnCase, async: true

  alias Harbor.Web.AdminAssets

  setup :register_and_log_in_admin

  test "admin layout references self-served assets", %{conn: conn} do
    conn = get(conn, "/admin")
    html = html_response(conn, 200)

    assert html =~ "/admin/assets/admin-css-#{AdminAssets.current_hash(:css)}"
    assert html =~ "/admin/assets/admin-js-#{AdminAssets.current_hash(:js)}"
  end

  test "serves admin css and js assets", %{conn: conn, user: user} do
    css_conn = get(conn, "/admin/assets/admin-css-#{AdminAssets.current_hash(:css)}")

    assert response(css_conn, 200)
    assert List.first(get_resp_header(css_conn, "content-type")) == "text/css"

    js_conn =
      Phoenix.ConnTest.build_conn()
      |> log_in_user(user)
      |> get("/admin/assets/admin-js-#{AdminAssets.current_hash(:js)}")

    assert response(js_conn, 200)
    assert List.first(get_resp_header(js_conn, "content-type")) == "text/javascript"
  end
end
