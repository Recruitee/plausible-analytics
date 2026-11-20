defmodule Plausible.EventTest do
  use ExUnit.Case, async: true

  @max_uint64 18_446_744_073_709_551_615

  @attrs %{
    name: "pageview",
    domain: "careers.example.com",
    hostname: "careers.example.com",
    pathname: "/jobs",
    event_id: 1,
    user_id: 2,
    timestamp: ~N[2026-11-20 12:00:00]
  }

  describe "new/1 browser-supplied ids" do
    for field <- [:company_id, :site_id, :page_id, :job_id] do
      test "accepts #{field} within UInt64" do
        assert %{valid?: true} = Plausible.Event.new(Map.put(@attrs, unquote(field), "123"))

        assert %{valid?: true} =
                 Plausible.Event.new(Map.put(@attrs, unquote(field), to_string(@max_uint64)))
      end

      test "rejects a negative #{field}" do
        changeset = Plausible.Event.new(Map.put(@attrs, unquote(field), "-1"))

        refute changeset.valid?
        assert [{unquote(field), _}] = changeset.errors
      end

      test "rejects #{field} above UInt64" do
        changeset =
          Plausible.Event.new(Map.put(@attrs, unquote(field), to_string(@max_uint64 + 1)))

        refute changeset.valid?
        assert [{unquote(field), _}] = changeset.errors
      end

      test "allows #{field} to be missing" do
        assert %{valid?: true} = Plausible.Event.new(Map.delete(@attrs, unquote(field)))
      end
    end
  end
end
