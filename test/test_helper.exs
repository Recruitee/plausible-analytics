{:ok, _} = Application.ensure_all_started(:ex_machina)
{:ok, _} = Application.ensure_all_started(:plausible)
ExUnit.start()
Application.ensure_all_started(:double)
Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)

Mox.defmock(Plausible.Geolocation.Mock, for: Plausible.Geolocation)
