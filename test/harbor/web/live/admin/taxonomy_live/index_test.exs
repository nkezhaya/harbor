defmodule Harbor.Web.Admin.TaxonomyLive.IndexTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.Catalog

  setup :register_and_log_in_admin

  test "lists taxonomies", %{conn: conn} do
    taxonomy = taxonomy_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies")

    assert has_element?(view, "#taxonomies-#{taxonomy.id}", taxonomy.name)
    refute has_element?(view, "#taxonomies-empty")

    assert has_element?(
             view,
             "#view-taxonomy-#{taxonomy.id}[href='/admin/taxonomies/#{taxonomy.id}']"
           )
  end

  test "creates a taxonomy from the empty state", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/taxonomies")
    assert has_element?(view, "#taxonomies-empty", "No taxonomies")
    refute has_element?(view, "#taxonomies")

    assert {:ok, form_view, _html} =
             view
             |> element("#taxonomies-empty #new-taxonomy")
             |> render_click()
             |> follow_redirect(conn, "/admin/taxonomies/new")

    form_view
    |> form("#taxonomy-form", taxonomy: %{name: ""})
    |> render_change()

    assert has_element?(form_view, "#taxonomy-form", "can't be blank")

    assert {:ok, view, _html} =
             form_view
             |> form("#taxonomy-form", taxonomy: %{name: "Categories", position: 1})
             |> render_submit()
             |> follow_redirect(conn, "/admin/taxonomies")

    assert [taxonomy] = Catalog.list_taxonomies()
    assert taxonomy.slug == "categories"
    assert has_element?(view, "#taxonomies-#{taxonomy.id}", "Categories")
    refute has_element?(view, "#taxonomies-empty")
  end

  test "updates a taxonomy", %{conn: conn} do
    taxonomy = taxonomy_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies")

    assert {:ok, form_view, _html} =
             view
             |> element("#edit-taxonomy-#{taxonomy.id}")
             |> render_click()
             |> follow_redirect(conn, "/admin/taxonomies/#{taxonomy.id}/edit")

    form_view
    |> form("#taxonomy-form", taxonomy: %{name: ""})
    |> render_change()

    assert has_element?(form_view, "#taxonomy-form", "can't be blank")

    assert {:ok, view, _html} =
             form_view
             |> form("#taxonomy-form", taxonomy: %{name: "Collections", position: 2})
             |> render_submit()
             |> follow_redirect(conn, "/admin/taxonomies")

    assert has_element?(view, "#taxonomies-#{taxonomy.id}", "Collections")
    assert Catalog.get_taxonomy!(taxonomy.id).position == 2
  end

  test "displays a duplicate-name error", %{conn: conn} do
    taxonomy = taxonomy_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies/new")

    view
    |> form("#taxonomy-form", taxonomy: %{name: taxonomy.name})
    |> render_submit()

    assert has_element?(view, "#taxonomy-form", "has already been taken")
  end

  test "deletes an empty taxonomy", %{conn: conn} do
    taxonomy = taxonomy_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies")

    view |> element("#delete-taxonomy-#{taxonomy.id}") |> render_click()

    refute has_element?(view, "#taxonomies")
    assert has_element?(view, "#taxonomies-empty", "No taxonomies")
    assert has_element?(view, "#taxonomies-empty #new-taxonomy[href='/admin/taxonomies/new']")
  end

  test "keeps remaining taxonomies visible after deletion", %{conn: conn} do
    taxonomy = taxonomy_fixture()
    remaining = taxonomy_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies")

    view |> element("#delete-taxonomy-#{taxonomy.id}") |> render_click()

    refute has_element?(view, "#taxonomies-#{taxonomy.id}")
    assert has_element?(view, "#taxonomies-#{remaining.id}", remaining.name)
    refute has_element?(view, "#taxonomies-empty")
  end

  test "keeps a nonempty taxonomy visible when deletion fails", %{conn: conn} do
    taxon = taxon_fixture()
    {:ok, view, _html} = live(conn, "/admin/taxonomies")

    view |> element("#delete-taxonomy-#{taxon.taxonomy_id}") |> render_click()

    assert has_element?(view, "#taxonomies-#{taxon.taxonomy_id}")
    assert has_element?(view, "#flash-error", "Delete this taxonomy's taxons")
  end

  test "requires an admin", %{conn: conn} do
    user = Harbor.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/admin/taxonomies")
  end

  test "requires authentication", %{conn: conn} do
    conn = Plug.Conn.clear_session(conn)

    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, "/admin/taxonomies")
  end
end
