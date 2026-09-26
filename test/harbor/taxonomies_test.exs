defmodule Harbor.TaxonomiesTest do
  use Harbor.DataCase, async: true

  import Harbor.CatalogFixtures, only: [product_fixture: 0]
  import Harbor.TaxonomiesFixtures

  alias Harbor.Accounts.Scope
  alias Harbor.AccountsFixtures
  alias Harbor.Taxonomies
  alias Harbor.Taxonomies.{Taxon, Taxonomy}

  describe "list_taxonomies/0" do
    test "orders taxonomies by position and name" do
      last = taxonomy_fixture(%{name: "Last", position: 1})
      second = taxonomy_fixture(%{name: "Departments"})
      first = taxonomy_fixture(%{name: "Categories"})

      assert Taxonomies.list_taxonomies() == [first, second, last]
    end
  end

  describe "get_taxonomy!/1" do
    test "returns a taxonomy" do
      taxonomy = taxonomy_fixture()
      assert Taxonomies.get_taxonomy!(taxonomy.id) == taxonomy
    end
  end

  describe "create_taxonomy/2" do
    test "creates a taxonomy and derives its slug" do
      assert {:ok, taxonomy} =
               Taxonomies.create_taxonomy(Scope.for_system(), %{
                 name: "Product Categories",
                 position: 2
               })

      assert taxonomy.name == "Product Categories"
      assert taxonomy.slug == "product-categories"
      assert taxonomy.position == 2
    end

    test "validates required fields" do
      assert {:error, changeset} =
               Taxonomies.create_taxonomy(Scope.for_system(), %{name: "", position: nil})

      assert errors_on(changeset).name == ["can't be blank"]
      assert errors_on(changeset).position == ["can't be blank"]
    end

    test "rejects duplicate names" do
      taxonomy = taxonomy_fixture()

      assert {:error, changeset} =
               Taxonomies.create_taxonomy(Scope.for_system(), %{name: taxonomy.name})

      assert errors_on(changeset).name == ["has already been taken"]
    end

    test "rejects negative positions" do
      assert {:error, changeset} =
               Taxonomies.create_taxonomy(Scope.for_system(), %{name: "Categories", position: -1})

      assert errors_on(changeset).position == ["must be greater than or equal to 0"]
    end

    test "requires an admin scope" do
      scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Taxonomies.create_taxonomy(scope, %{name: "Categories"})
      end
    end
  end

  describe "update_taxonomy/3" do
    test "updates taxonomy metadata without changing taxon ownership" do
      taxonomy = taxonomy_fixture()
      taxon = taxon_fixture(%{taxonomy_id: taxonomy.id})

      assert {:ok, updated} =
               Taxonomies.update_taxonomy(Scope.for_system(), taxonomy, %{
                 name: "Collections",
                 slug: "curated-collections",
                 position: 3
               })

      assert updated.name == "Collections"
      assert updated.slug == "curated-collections"
      assert updated.position == 3
      assert Taxonomies.get_taxon!(taxon.id).taxonomy_id == taxonomy.id
    end

    test "does not persist invalid changes" do
      taxonomy = taxonomy_fixture()

      assert {:error, changeset} =
               Taxonomies.update_taxonomy(Scope.for_system(), taxonomy, %{name: ""})

      assert errors_on(changeset).name == ["can't be blank"]
      assert Taxonomies.get_taxonomy!(taxonomy.id) == taxonomy
    end

    test "requires an admin scope" do
      taxonomy = taxonomy_fixture()
      scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Taxonomies.update_taxonomy(scope, taxonomy, %{name: "Collections"})
      end
    end
  end

  describe "delete_taxonomy/2" do
    test "deletes an empty taxonomy" do
      taxonomy = taxonomy_fixture()
      assert {:ok, %Taxonomy{}} = Taxonomies.delete_taxonomy(Scope.for_system(), taxonomy)
      refute Repo.get(Taxonomy, taxonomy.id)
    end

    test "does not delete a taxonomy containing taxons" do
      taxonomy = taxonomy_fixture()
      taxon = taxon_fixture(%{taxonomy_id: taxonomy.id})

      assert {:error, changeset} = Taxonomies.delete_taxonomy(Scope.for_system(), taxonomy)
      assert errors_on(changeset).taxons == ["must be empty before it can be deleted"]
      assert Repo.get(Taxonomy, taxonomy.id)
      assert Repo.get(Taxon, taxon.id)
    end

    test "requires an admin scope" do
      taxonomy = taxonomy_fixture()
      scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Taxonomies.delete_taxonomy(scope, taxonomy)
      end
    end
  end

  describe "change_taxonomy/3" do
    test "returns a changeset" do
      taxonomy = taxonomy_fixture()

      assert %Ecto.Changeset{} =
               Taxonomies.change_taxonomy(Scope.for_system(), taxonomy, %{name: "Collections"})
    end

    test "requires an admin scope" do
      taxonomy = taxonomy_fixture()
      scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Taxonomies.change_taxonomy(scope, taxonomy)
      end
    end
  end

  describe "list_root_taxons/0" do
    test "lists roots across all taxonomies" do
      first = taxon_fixture(%{position: 0})
      second = taxon_fixture(%{position: 1})
      _child = taxon_fixture(%{taxonomy_id: first.taxonomy_id, parent_id: first.id})

      assert Enum.map(Taxonomies.list_root_taxons(), & &1.id) == [first.id, second.id]
    end
  end

  describe "list_taxons/0" do
    test "returns all taxons" do
      taxon = taxon_fixture(%{})

      assert Taxonomies.list_taxons() == [taxon]
    end
  end

  describe "list_taxons/1" do
    test "only returns taxons belonging to the taxonomy, ordered by position" do
      taxonomy = taxonomy_fixture()
      last = taxon_fixture(%{taxonomy_id: taxonomy.id, position: 1})
      first = taxon_fixture(%{taxonomy_id: taxonomy.id})
      _other = taxon_fixture()

      assert Taxonomies.list_taxons(taxonomy.id) == [first, last]
    end
  end

  describe "get_taxon!/1" do
    test "returns the taxon with given id" do
      taxon = taxon_fixture(%{})
      assert Taxonomies.get_taxon!(taxon.id) == taxon
    end
  end

  describe "get_taxon!/2" do
    test "only retrieves a taxon inside its owning taxonomy" do
      taxonomy = taxonomy_fixture()
      taxon = taxon_fixture(%{taxonomy_id: taxonomy.id})
      other = taxon_fixture()

      assert Taxonomies.get_taxon!(taxonomy.id, taxon.id) == taxon

      assert_raise Ecto.NoResultsError, fn ->
        Taxonomies.get_taxon!(taxonomy.id, other.id)
      end
    end
  end

  describe "create_taxon/2" do
    test "preloads its taxonomy" do
      taxonomy = taxonomy_fixture()

      assert {:ok, taxon} =
               Taxonomies.create_taxon(Scope.for_system(), %{
                 name: "Shirts",
                 taxonomy_id: taxonomy.id
               })

      assert taxon.taxonomy == taxonomy
    end

    test "requires a taxonomy ID" do
      assert {:error, changeset} = Taxonomies.create_taxon(Scope.for_system(), %{name: "Shirts"})

      assert errors_on(changeset).taxonomy_id == ["can't be blank"]
    end

    test "rejects a nonexistent taxonomy ID" do
      taxonomy = taxonomy_fixture()
      {:ok, _taxonomy} = Taxonomies.delete_taxonomy(Scope.for_system(), taxonomy)

      assert {:error, changeset} =
               Taxonomies.create_taxon(Scope.for_system(), %{
                 name: "Shirts",
                 taxonomy_id: taxonomy.id
               })

      assert errors_on(changeset).taxonomy == ["does not exist"]
    end

    test "allows a parent from the same taxonomy" do
      parent = taxon_fixture()

      assert {:ok, child} =
               Taxonomies.create_taxon(Scope.for_system(), %{
                 name: "Shirts",
                 taxonomy_id: parent.taxonomy_id,
                 parent_id: parent.id,
                 parent_ids: [parent.id]
               })

      assert child.parent_id == parent.id
      assert child.taxonomy_id == parent.taxonomy_id
    end

    test "rejects a parent from another taxonomy" do
      parent = taxon_fixture()
      taxonomy = taxonomy_fixture()

      assert {:error, changeset} =
               Taxonomies.create_taxon(Scope.for_system(), %{
                 name: "Shirts",
                 taxonomy_id: taxonomy.id,
                 parent_id: parent.id
               })

      assert errors_on(changeset).parent_id == ["must belong to the same taxonomy"]
    end

    test "allows matching root names and positions in separate taxonomies but keeps slugs global" do
      first = taxon_fixture(%{name: "Clothing"})
      second = taxon_fixture(%{name: "Clothing"})

      assert first.position == second.position
      refute first.taxonomy_id == second.taxonomy_id
      refute first.slug == second.slug
    end

    test "rejects matching root names within a taxonomy" do
      taxon = taxon_fixture(%{name: "Clothing"})

      assert {:error, changeset} =
               Taxonomies.create_taxon(Scope.for_system(), %{
                 name: "Clothing",
                 taxonomy_id: taxon.taxonomy_id,
                 position: 1
               })

      assert errors_on(changeset).name == ["has already been taken"]
    end

    test "with valid data creates a taxon" do
      admin_scope = AccountsFixtures.admin_scope_fixture()

      valid_attrs = %{
        name: "some name",
        position: 42,
        slug: "some slug",
        taxonomy_id: taxonomy_fixture().id
      }

      assert {:ok, taxon} = Taxonomies.create_taxon(admin_scope, valid_attrs)
      assert taxon.name == "some name"
      assert taxon.position == 42
      assert taxon.slug == "some-slug"
      assert taxon.taxonomy_id == valid_attrs.taxonomy_id
    end

    test "with invalid data returns error changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Taxonomies.create_taxon(admin_scope, %{
                 name: nil,
                 position: nil,
                 slug: nil,
                 taxonomy_id: taxonomy_fixture().id
               })
    end

    test "raises for non-admin scopes" do
      user_scope = AccountsFixtures.user_scope_fixture()
      taxonomy = taxonomy_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Taxonomies.create_taxon(user_scope, %{name: "foo", taxonomy_id: taxonomy.id})
      end
    end
  end

  describe "update_taxon/3" do
    test "does not accept changes to taxonomy ownership" do
      taxon = taxon_fixture()
      other = taxonomy_fixture()

      assert {:ok, updated} =
               Taxonomies.update_taxon(Scope.for_system(), taxon, %{taxonomy_id: other.id})

      assert updated.taxonomy_id == taxon.taxonomy_id
    end

    test "rejects reparenting into a different taxonomy" do
      taxon = taxon_fixture()
      other_parent = taxon_fixture()

      assert {:error, changeset} =
               Taxonomies.update_taxon(Scope.for_system(), taxon, %{parent_id: other_parent.id})

      assert errors_on(changeset).parent_id == ["must belong to the same taxonomy"]
      refute Taxonomies.get_taxon!(taxon.id).parent_id
    end

    test "with valid data updates the taxon" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})
      update_attrs = %{name: "some updated name", position: 43, slug: "some updated slug"}

      assert {:ok, taxon} = Taxonomies.update_taxon(admin_scope, taxon, update_attrs)
      assert taxon.name == "some updated name"
      assert taxon.position == 43
      assert taxon.slug == "some-updated-slug"
    end

    test "with invalid data returns error changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})

      assert {:error, %Ecto.Changeset{}} =
               Taxonomies.update_taxon(admin_scope, taxon, %{
                 name: nil,
                 position: nil,
                 slug: nil
               })

      assert taxon == Taxonomies.get_taxon!(taxon.id)
    end

    test "raises for non-admin scopes" do
      taxon = taxon_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Taxonomies.update_taxon(user_scope, taxon, %{name: "updated"})
      end
    end
  end

  describe "delete_taxon/2" do
    test "does not delete a taxon with children" do
      parent = taxon_fixture()
      child = taxon_fixture(%{taxonomy_id: parent.taxonomy_id, parent_id: parent.id})

      assert {:error, changeset} = Taxonomies.delete_taxon(Scope.for_system(), parent)
      assert errors_on(changeset).children == ["are still associated with this entry"]
      assert Repo.get(Taxon, child.id)
    end

    test "does not delete a product's primary taxon" do
      product = product_fixture()
      taxon = Taxonomies.get_taxon!(product.primary_taxon_id)

      assert {:error, %Ecto.Changeset{}} = Taxonomies.delete_taxon(Scope.for_system(), taxon)
      assert Repo.get(Taxon, taxon.id)
    end

    test "deletes the taxon" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})
      assert {:ok, %Taxon{}} = Taxonomies.delete_taxon(admin_scope, taxon)

      assert_raise Ecto.NoResultsError, fn ->
        Taxonomies.get_taxon!(taxon.id)
      end
    end

    test "raises for non-admin scopes" do
      taxon = taxon_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Taxonomies.delete_taxon(user_scope, taxon)
      end
    end
  end

  describe "change_taxon/3" do
    test "returns a taxon changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})
      assert %Ecto.Changeset{} = Taxonomies.change_taxon(admin_scope, taxon)
    end

    test "raises for non-admin scopes" do
      taxon = taxon_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Taxonomies.change_taxon(user_scope, taxon)
      end
    end
  end
end
