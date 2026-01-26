defmodule Plausible.Event do
  use Ecto.Schema

  import Ecto.Changeset

  alias Plausible.ValueHelpers

  @primary_key false
  schema "events" do
    field :company_id, Ch, type: "UInt64"
    field :name, Ch, type: "String"
    field :domain, Ch, type: "String"
    field :user_id, Ch, type: "UInt64"
    field :session_id, Ch, type: "UInt64"
    field :hostname, Ch, type: "String"
    field :pathname, Ch, type: "String"
    field :referrer, Ch, type: "String", default: ""
    field :referrer_source, Ch, type: "String", default: ""
    field :country_code, Ch, type: "LowCardinality(FixedString(2))", default: ""
    field :screen_size, Ch, type: "LowCardinality(String)", default: ""
    field :operating_system, Ch, type: "LowCardinality(String)", default: ""
    field :browser, Ch, type: "LowCardinality(String)", default: ""
    field :timestamp, Ch, type: "DateTime"
    field :utm_medium, Ch, type: "String", default: ""
    field :utm_source, Ch, type: "String", default: ""
    field :utm_campaign, Ch, type: "String", default: ""
    field :"meta.key", Ch, type: "Array(String)", default: []
    field :"meta.value", Ch, type: "Array(String)", default: []
    field :browser_version, Ch, type: "LowCardinality(String)", default: ""
    field :operating_system_version, Ch, type: "LowCardinality(String)", default: ""
    field :subdivision1_code, Ch, type: "LowCardinality(String)", default: ""
    field :subdivision2_code, Ch, type: "LowCardinality(String)", default: ""
    field :city_geoname_id, Ch, type: "UInt32", default: 0
    field :utm_content, Ch, type: "String", default: ""
    field :utm_term, Ch, type: "String", default: ""
    field :job_id, Ch, type: "UInt64"
    field :page_id, Ch, type: "UInt64"
    field :site_id, Ch, type: "UInt64"
    field :event_id, Ch, type: "UInt64"
    field :careers_application_form_uuid, Ch, type: "String", default: ""
    field :campaign_id, Ch, type: "String", default: ""
    field :product_id, Ch, type: "String", default: ""
  end

  def random_event_id() do
    :crypto.strong_rand_bytes(8) |> :binary.decode_unsigned()
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :name,
        :domain,
        :hostname,
        :pathname,
        :user_id,
        :event_id,
        :company_id,
        :site_id,
        :page_id,
        :job_id,
        :campaign_id,
        :product_id,
        :timestamp,
        :operating_system,
        :operating_system_version,
        :browser,
        :browser_version,
        :referrer,
        :referrer_source,
        :utm_medium,
        :utm_source,
        :utm_campaign,
        :utm_content,
        :utm_term,
        :country_code,
        :subdivision1_code,
        :subdivision2_code,
        :city_geoname_id,
        :screen_size,
        :careers_application_form_uuid,
        :"meta.key",
        :"meta.value"
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([:name, :domain, :hostname, :pathname, :event_id, :user_id, :timestamp])
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
