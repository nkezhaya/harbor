defmodule Harbor.Slug do
  @moduledoc """
  Helpers for deriving unique, URL-friendly slugs from human readable fields.

  The module is designed to be used from Ecto schemas via `put_new_slug/3`,
  which will normalise the configured field (defaulting to `:name`), ensure the
  generated slug is present, and enforce uniqueness by appending an incrementing
  suffix when required. `to_slug/1` provides the underlying string conversion
  and can be reused anywhere a slugified representation is needed.
  """
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @spec put_new_slug(Ecto.Changeset.t(), Ecto.Queryable.t(), atom()) :: Ecto.Changeset.t()
  def put_new_slug(changeset, queryable, field \\ :name) do
    prepare_changes(changeset, fn prepared_changeset ->
      repo = prepared_changeset.repo
      id = get_field(prepared_changeset, :id)

      string =
        cond do
          manual_slug_entry = get_change(prepared_changeset, :slug) ->
            manual_slug_entry

          # If a slug has already been set, only check the sluggable field for
          # changes.
          get_field(prepared_changeset, :slug) ->
            get_change(prepared_changeset, field)

          # If a slug hasn't been set yet, just use the field.
          true ->
            get_field(prepared_changeset, field)
        end

      case string do
        string when is_binary(string) ->
          put_change(prepared_changeset, :slug, get_slug(queryable, repo, id, string))

        _ ->
          prepared_changeset
      end
      |> validate_required(:slug)
      |> unique_constraint(:slug)
    end)
  end

  defp get_slug(queryable, repo, id, string, last_slug \\ nil) do
    slug =
      case last_slug do
        nil -> to_slug(string)
        last_slug -> next_slug(last_slug)
      end

    query = from(q in queryable, where: q.slug == ^slug, limit: 1)

    query =
      case id do
        nil -> query
        _ -> from(q in query, where: q.id != ^id)
      end

    if repo.exists?(query) do
      get_slug(queryable, repo, id, string, slug)
    else
      slug
    end
  end

  @doc """
  Turns the term into a sluggified string.

      iex> Harbor.Slug.to_slug("Trending Products")
      "trending-products"
      iex> Harbor.Slug.to_slug(" -Eighty_Six-- Bars ")
      "eighty-six-bars"
      iex> Harbor.Slug.to_slug("Me & You")
      "me-you"
      iex> Harbor.Slug.to_slug("Hermès & Foo")
      "hermes-foo"
  """
  @spec to_slug(term()) :: String.t()
  def to_slug(term) do
    term
    |> to_string()
    |> String.downcase()
    |> String.trim()
    |> String.normalize(:nfd)
    |> String.replace(~r/(\s|-|_)+/, "-")
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.replace(~r/\-{2,}/, "-")
    |> String.replace(~r/^\-/, "")
    |> String.replace(~r/\-$/, "")
  end

  defp next_slug(slug) do
    last_num = ~r/\-(\d+)$/

    case Regex.scan(last_num, slug, capture: :all_but_first) do
      [[number]] ->
        integer = String.to_integer(number)
        String.replace(slug, last_num, "-#{integer + 1}")

      _ ->
        "#{slug}-2"
    end
  end
end
