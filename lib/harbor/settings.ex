defmodule Harbor.Settings do
  @moduledoc """
  Persisted feature toggles for the Harbor store.

  `Harbor.Settings` is a singleton row that lives in the `settings` table. The
  public API exposes convenience accessors that read through `Harbor.Cache` so
  hot-path lookups never hit the database.
  """

  use Harbor.Schema

  alias Harbor.{Cache, Repo}

  @type t() :: %__MODULE__{}

  @primary_key {:id, :boolean, autogenerate: false}

  schema "settings" do
    field :payments_enabled, :boolean, default: true
    field :delivery_enabled, :boolean, default: true
    field :tax_enabled, :boolean, default: true
  end

  def changeset(%__MODULE__{} = settings, attrs) do
    cast(settings, attrs, fields())
  end

  @doc """
  Returns the cached `%Settings{}`. Falls back to the database on cache miss,
  and returns a default struct when no row exists yet.
  """
  @spec get() :: t()
  def get do
    case Cache.get(:settings) do
      nil ->
        settings = Repo.get(__MODULE__, true) || %__MODULE__{id: true}
        Cache.put(:settings, settings)
        settings

      settings ->
        settings
    end
  end

  @doc """
  Upserts the singleton settings row and invalidates the cache.
  """
  @spec update(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def update(attrs) do
    result =
      %__MODULE__{id: true}
      |> changeset(attrs)
      |> Repo.insert(
        on_conflict: {:replace, fields()},
        conflict_target: [:id],
        returning: true
      )

    case result do
      {:ok, settings} ->
        Cache.delete(:settings)
        {:ok, settings}

      error ->
        error
    end
  end

  @doc "Whether payments are enabled."
  @spec payments_enabled?() :: boolean()
  def payments_enabled?, do: get().payments_enabled

  @doc "Whether delivery / shipping methods are enabled."
  @spec delivery_enabled?() :: boolean()
  def delivery_enabled?, do: get().delivery_enabled

  @doc "Whether tax calculation is enabled."
  @spec tax_enabled?() :: boolean()
  def tax_enabled?, do: get().tax_enabled

  defp fields, do: __MODULE__.__schema__(:fields) -- [:id]
end
