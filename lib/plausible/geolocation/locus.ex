defmodule Plausible.Geolocation.Locus do
  @moduledoc """
  Geolocation implementation using the Locus library.

  This module provides geolocation lookups using MaxMind GeoIP databases
  via the `:locus` library.
  """

  @behaviour Plausible.Geolocation

  @impl Plausible.Geolocation
  def lookup(ip) do
    :locus.lookup(:geolocation, ip)
  end
end
