defmodule PlausibleWeb.StatsHTML do
  @moduledoc """
  This module contains pages rendered by StatsController.
  """
  use PlausibleWeb, :html

  embed_templates "stats_html/*"
end
