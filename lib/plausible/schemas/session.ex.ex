defmodule Plausible.Session do
  use Ecto.Schema

  import Ecto.Changeset

  alias Plausible.ValueHelpers

  @primary_key false
  schema "sessions" do
    field :company_id, Ch, type: "UInt64"
    field :session_id, Ch, type: "UInt64"
    field :sign, Ch, type: "Int8"
    field :domain, Ch, type: "String"
    field :user_id, Ch, type: "UInt64"
    field :hostname, Ch, type: "String"
    field :is_bounce, Ch, type: "UInt8"
    field :entry_page, Ch, type: "String"
    field :exit_page, Ch, type: "String"
    field :pageviews, Ch, type: "Int32"
    field :events, Ch, type: "Int32"
    field :duration, Ch, type: "UInt32"
    field :referrer, Ch, type: "String"
    field :referrer_source, Ch, type: "String"
    field :country_code, Ch, type: "LowCardinality(FixedString(2))", default: ""
    field :screen_size, Ch, type: "LowCardinality(String)"
    field :operating_system, Ch, type: "LowCardinality(String)"
    field :browser, Ch, type: "LowCardinality(String)"
    field :start, Ch, type: "DateTime"
    field :timestamp, Ch, type: "DateTime"
    field :utm_medium, Ch, type: "String"
    field :utm_source, Ch, type: "String"
    field :utm_campaign, Ch, type: "String"
    field :browser_version, Ch, type: "LowCardinality(String)"
    field :operating_system_version, Ch, type: "LowCardinality(String)"
    field :subdivision1_code, Ch, type: "LowCardinality(String)", default: ""
    field :subdivision2_code, Ch, type: "LowCardinality(String)", default: ""
    field :city_geoname_id, Ch, type: "UInt32", default: 0
    field :utm_content, Ch, type: "String"
    field :utm_term, Ch, type: "String"
    field :site_id, Ch, type: "UInt64"
    field :campaign_id, Ch, type: "String"
    field :product_id, Ch, type: "String"
  end

  def random_uint64() do
    :crypto.strong_rand_bytes(8) |> :binary.decode_unsigned()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :hostname,
      :domain,
      :entry_page,
      :exit_page,
      :fingerprint,
      :start,
      :length,
      :is_bounce,
      :operating_system,
      :operating_system_version,
      :browser_version,
      :referrer,
      :referrer_source,
      :utm_medium,
      :utm_source,
      :utm_campaign,
      :utm_content,
      :utm_term,
      :country_code,
      :country_geoname_id,
      :company_id,
      :site_id,
      :campaign_id,
      :product_id,
      :subdivision1_code,
      :subdivision2_code,
      :city_geoname_id,
      :screen_size
    ])
    |> validate_required([:hostname, :domain, :fingerprint, :is_bounce, :start])
    |> validate_campaign_id()
    |> validate_product_id()
  end

  defp validate_campaign_id(changeset) do
    campaign_id = get_field(changeset, :campaign_id)

    if ValueHelpers.validate(campaign_id, type: :prefixed_id) do
      changeset
    else
      delete_change(changeset, :campaign_id)
    end
  end

  defp validate_product_id(changeset) do
    product_id = get_field(changeset, :product_id)

    if ValueHelpers.validate(product_id, type: :prefixed_id) do
      changeset
    else
      delete_change(changeset, :product_id)
    end
  end
end
