defmodule Plausible.Test.GeolocationStub do
  @moduledoc """
  Stub implementation of the Plausible.Geolocation behaviour for tests.

  Provides fake geolocation data for common test IP addresses.
  This module is used with Mox.stub_with/2 to provide default behavior
  in tests without explicit mocking.
  """

  @behaviour Plausible.Geolocation

  @fake_data %{
    {1, 1, 1, 1} => %{"country" => %{"iso_code" => "US", "geoname_id" => 6_252_001}},
    {1, 1, 1, 1, 1, 1, 1, 1} => %{"country" => %{"iso_code" => "US", "geoname_id" => 6_252_001}},
    {8193, 18528, 18528, 0, 0, 0, 0, 34952} => %{
      "country" => %{"iso_code" => "US", "geoname_id" => 6_252_001}
    },
    {0, 0, 0, 0} => %{"country" => %{"iso_code" => "ZZ"}}
  }

  @impl Plausible.Geolocation
  def lookup(ip) when is_binary(ip) do
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, ip_tuple} -> lookup(ip_tuple)
      {:error, _} -> {:error, :not_found}
    end
  end

  def lookup(ip) do
    case Map.get(@fake_data, ip) do
      nil -> {:error, :not_found}
      data -> {:ok, data}
    end
  end
end
