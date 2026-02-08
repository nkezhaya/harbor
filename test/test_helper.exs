Mox.defmock(Harbor.Tax.TaxProviderMock, for: Harbor.Tax.TaxProvider)
Application.put_env(:harbor, :tax_provider, {:mock, Harbor.Tax.TaxProviderMock})

Mox.defmock(Harbor.Billing.PaymentProviderMock, for: Harbor.Billing.PaymentProvider)
Application.put_env(:harbor, :payment_provider, {:mock, Harbor.Billing.PaymentProviderMock})

Harbor.Seeds.run()

{:ok, _} = Harbor.Web.TestEndpoint.start_link()

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Harbor.Repo, :manual)
