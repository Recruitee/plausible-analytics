defmodule Plausible.TestUtils do
  use Plausible.Repo

  def get_buffer_size do
    Keyword.fetch!(Application.get_env(:plausible, :ingestion), :buffer_size)
  end

  def get_flush_interval_ms do
    Keyword.fetch!(Application.get_env(:plausible, :ingestion), :flush_interval_ms)
  end
end
