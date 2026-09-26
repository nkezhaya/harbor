defmodule Harbor.Web.Admin.TaxonLive.ShowTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.TaxonomiesFixtures

  setup :register_and_log_in_admin

  setup do
    %{taxon: taxon_fixture()}
  end

  test "displays a taxon inside its taxonomy", %{conn: conn, taxon: taxon} do
    {:ok, view, _html} = live(conn, "/admin/taxonomies/#{taxon.taxonomy_id}/taxons/#{taxon.id}")

    assert has_element?(view, "#taxon-name", taxon.name)
    assert has_element?(view, "#back-to-taxonomy[href='/admin/taxonomies/#{taxon.taxonomy_id}']")
  end

  test "updates a taxon and returns to its details", %{conn: conn, taxon: taxon} do
    path = "/admin/taxonomies/#{taxon.taxonomy_id}/taxons/#{taxon.id}"
    {:ok, view, _html} = live(conn, path)

    assert {:ok, form_view, _html} =
             view
             |> element("#edit-taxon")
             |> render_click()
             |> follow_redirect(conn, "#{path}/edit?return_to=show")

    form_view |> form("#taxon-form", taxon: %{name: ""}) |> render_change()
    assert has_element?(form_view, "#taxon-form", "can't be blank")

    assert {:ok, view, _html} =
             form_view
             |> form("#taxon-form", taxon: %{name: "Renamed Taxon"})
             |> render_submit()
             |> follow_redirect(conn, path)

    assert has_element?(view, "#taxon-name", "Renamed Taxon")
  end

  test "does not display or edit a taxon through another taxonomy", %{conn: conn, taxon: taxon} do
    other = taxonomy_fixture()
    path = "/admin/taxonomies/#{other.id}/taxons/#{taxon.id}"

    assert_raise Ecto.NoResultsError, fn -> live(conn, path) end
    assert_raise Ecto.NoResultsError, fn -> live(conn, "#{path}/edit") end
  end
end
