defmodule Harbor.Web.Admin.TaxonLive.IndexTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  setup :register_and_log_in_admin

  setup do
    taxon = taxon_fixture(%{})

    %{taxon: taxon}
  end

  test "lists all taxons", %{conn: conn, taxon: taxon} do
    {:ok, _index_live, html} = live(conn, "/admin/taxons")

    assert html =~ "Listing Taxons"
    assert html =~ taxon.name
  end

  test "saves new taxon", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, "/admin/taxons")

    assert {:ok, form_live, _} =
             index_live
             |> element("a", "New Taxon")
             |> render_click()
             |> follow_redirect(conn, "/admin/taxons/new")

    assert render(form_live) =~ "New Taxon"

    assert form_live
           |> form("#taxon-form", taxon: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#taxon-form", taxon: create_attrs())
             |> render_submit()
             |> follow_redirect(conn, "/admin/taxons")

    html = render(index_live)
    assert html =~ "Taxon created successfully"
    assert html =~ "New Taxon"
  end

  test "updates taxon in listing", %{conn: conn, taxon: taxon} do
    {:ok, index_live, _html} = live(conn, "/admin/taxons")

    assert {:ok, form_live, _html} =
             index_live
             |> element("#taxons-#{taxon.id} a", "Edit")
             |> render_click()
             |> follow_redirect(conn, "/admin/taxons/#{taxon.id}/edit")

    assert render(form_live) =~ "Edit Taxon"

    assert form_live
           |> form("#taxon-form", taxon: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#taxon-form", taxon: update_attrs())
             |> render_submit()
             |> follow_redirect(conn, "/admin/taxons")

    html = render(index_live)
    assert html =~ "Taxon updated successfully"
    assert html =~ "Updated Taxon"
  end

  test "deletes taxon in listing", %{conn: conn, taxon: taxon} do
    {:ok, index_live, _html} = live(conn, "/admin/taxons")

    assert index_live |> element("#taxons-#{taxon.id} a", "Delete") |> render_click()
    refute has_element?(index_live, "#taxons-#{taxon.id}")
  end

  defp create_attrs do
    %{
      name: "New Taxon",
      slug: "new-taxon",
      position: "1"
    }
  end

  defp update_attrs do
    %{
      name: "Updated Taxon",
      slug: "updated-taxon",
      position: "2"
    }
  end

  defp invalid_attrs do
    %{
      name: nil,
      slug: nil,
      position: nil
    }
  end
end
