defmodule Harbor.Web.Admin.TaxonLive.ShowTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  setup :register_and_log_in_admin

  setup do
    taxon = taxon_fixture(%{})

    %{taxon: taxon}
  end

  test "displays taxon", %{conn: conn, taxon: taxon} do
    {:ok, _show_live, html} = live(conn, "/admin/taxons/#{taxon.id}")

    assert html =~ "Show Taxon"
    assert html =~ taxon.name
  end

  test "updates taxon and returns to show", %{conn: conn, taxon: taxon} do
    {:ok, show_live, _html} = live(conn, "/admin/taxons/#{taxon.id}")

    assert {:ok, form_live, _} =
             show_live
             |> element("a", "Edit")
             |> render_click()
             |> follow_redirect(conn, "/admin/taxons/#{taxon.id}/edit?return_to=show")

    assert render(form_live) =~ "Edit Taxon"

    assert form_live
           |> form("#taxon-form", taxon: %{name: nil})
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, show_live, _html} =
             form_live
             |> form("#taxon-form", taxon: %{name: "Renamed Taxon"})
             |> render_submit()
             |> follow_redirect(conn, "/admin/taxons/#{taxon.id}")

    html = render(show_live)
    assert html =~ "Taxon updated successfully"
    assert html =~ "Renamed Taxon"
  end
end
