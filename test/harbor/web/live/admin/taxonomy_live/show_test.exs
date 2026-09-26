defmodule Harbor.Web.Admin.TaxonomyLive.ShowTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures
  import Harbor.TaxonomiesFixtures

  alias Harbor.Taxonomies

  setup :register_and_log_in_admin

  test "lists only this taxonomy's taxons", %{conn: conn} do
    taxon = taxon_fixture()
    other = taxon_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies/#{taxon.taxonomy_id}")

    assert has_element?(view, "#taxonomy-name", taxon.taxonomy.name)
    assert has_element?(view, "#taxons-#{taxon.id}", taxon.name)
    refute has_element?(view, "#taxons-#{other.id}")
    refute has_element?(view, "#taxons-empty")
  end

  test "updates a taxonomy and returns to its taxons", %{conn: conn} do
    taxonomy = taxonomy_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies/#{taxonomy.id}")

    assert {:ok, form_view, _html} =
             view
             |> element("#edit-taxonomy")
             |> render_click()
             |> follow_redirect(conn, "/admin/taxonomies/#{taxonomy.id}/edit?return_to=show")

    assert {:ok, view, _html} =
             form_view
             |> form("#taxonomy-form", taxonomy: %{name: "Departments"})
             |> render_submit()
             |> follow_redirect(conn, "/admin/taxonomies/#{taxonomy.id}")

    assert has_element?(view, "#taxonomy-name", "Departments")
  end

  test "creates a taxon inside the selected taxonomy", %{conn: conn} do
    taxonomy = taxonomy_fixture()
    other = taxonomy_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies/#{taxonomy.id}")
    assert has_element?(view, "#taxons-empty", "No taxons")
    refute has_element?(view, "#taxons")

    assert {:ok, form_view, _html} =
             view
             |> element("#taxons-empty #new-taxon")
             |> render_click()
             |> follow_redirect(conn, "/admin/taxonomies/#{taxonomy.id}/taxons/new")

    refute has_element?(form_view, "#taxon_taxonomy_id")

    form_view |> form("#taxon-form", taxon: %{name: ""}) |> render_change()
    assert has_element?(form_view, "#taxon-form", "can't be blank")

    assert {:ok, view, _html} =
             form_view
             |> form("#taxon-form", taxon: %{name: "Shirts", slug: "shirts", position: 0})
             |> render_submit(%{"taxon" => %{"taxonomy_id" => other.id}})
             |> follow_redirect(conn, "/admin/taxonomies/#{taxonomy.id}")

    assert [taxon] = Taxonomies.list_taxons(taxonomy.id)
    assert taxon.name == "Shirts"
    assert Taxonomies.list_taxons(other.id) == []
    assert has_element?(view, "#taxons-#{taxon.id}", "Shirts")
    refute has_element?(view, "#taxons-empty")
  end

  test "updates a taxon and returns to its taxonomy", %{conn: conn} do
    taxon = taxon_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies/#{taxon.taxonomy_id}")

    assert {:ok, form_view, _html} =
             view
             |> element("#edit-taxon-#{taxon.id}")
             |> render_click()
             |> follow_redirect(
               conn,
               "/admin/taxonomies/#{taxon.taxonomy_id}/taxons/#{taxon.id}/edit"
             )

    form_view |> form("#taxon-form", taxon: %{name: ""}) |> render_change()
    assert has_element?(form_view, "#taxon-form", "can't be blank")

    assert {:ok, view, _html} =
             form_view
             |> form("#taxon-form", taxon: %{name: "Updated Taxon", position: 2})
             |> render_submit()
             |> follow_redirect(conn, "/admin/taxonomies/#{taxon.taxonomy_id}")

    assert has_element?(view, "#taxons-#{taxon.id}", "Updated Taxon")
  end

  test "deletes an unused taxon", %{conn: conn} do
    taxon = taxon_fixture()
    _other = taxon_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies/#{taxon.taxonomy_id}")

    view |> element("#delete-taxon-#{taxon.id}") |> render_click()

    refute has_element?(view, "#taxons")
    assert has_element?(view, "#taxons-empty", "No taxons")

    assert has_element?(
             view,
             "#taxons-empty #new-taxon[href='/admin/taxonomies/#{taxon.taxonomy_id}/taxons/new']"
           )

    assert Taxonomies.get_taxonomy!(taxon.taxonomy_id)
  end

  test "keeps remaining taxons visible after deletion", %{conn: conn} do
    taxon = taxon_fixture()
    remaining = taxon_fixture(%{taxonomy_id: taxon.taxonomy_id, position: 1})
    {:ok, view, _html} = live(conn, "/admin/taxonomies/#{taxon.taxonomy_id}")

    view |> element("#delete-taxon-#{taxon.id}") |> render_click()

    refute has_element?(view, "#taxons-#{taxon.id}")
    assert has_element?(view, "#taxons-#{remaining.id}", remaining.name)
    refute has_element?(view, "#taxons-empty")
  end

  test "does not hide a taxon when deletion is blocked", %{conn: conn} do
    product = product_fixture()
    taxon = Taxonomies.get_taxon!(product.primary_taxon_id)
    {:ok, view, _html} = live(conn, "/admin/taxonomies/#{taxon.taxonomy_id}")

    view |> element("#delete-taxon-#{taxon.id}") |> render_click()

    assert has_element?(view, "#taxons-#{taxon.id}")
    assert has_element?(view, "#flash-error", "cannot be deleted")
  end
end
