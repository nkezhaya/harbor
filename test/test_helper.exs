Mox.defmock(Harbor.Tax.TaxProviderMock, for: Harbor.Tax.TaxProvider)
Application.put_env(:harbor, :tax_provider, {:mock, Harbor.Tax.TaxProviderMock})

Harbor.Seeds.run()

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Harbor.Repo, :manual)
