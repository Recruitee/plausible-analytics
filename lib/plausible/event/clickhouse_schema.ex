defmodule Plausible.ClickhouseEvent do
  use Ecto.Schema

  import Ecto.Changeset

  alias Plausible.ValueHelpers

  @primary_key false
  schema "events" do
    field :event_id, :integer
    field :name, :string
    field :domain, :string
    field :hostname, :string
    field :pathname, :string
    field :user_id, :integer
    field :session_id, :integer
    field :company_id, :integer
    field :site_id, :integer
    field :page_id, :integer
    field :job_id, :integer
    field :timestamp, :naive_datetime

    field :referrer, :string, default: ""
    field :referrer_source, :string, default: ""
    field :utm_medium, :string, default: ""
    field :utm_source, :string, default: ""
    field :utm_campaign, :string, default: ""
    field :utm_content, :string, default: ""
    field :utm_term, :string, default: ""
    field :campaign_id, :string, default: ""
    field :contract_id, :string, default: ""
    field :product_id, :string, default: ""

    field :country_code, :string, default: ""
    field :subdivision1_code, :string, default: ""
    field :subdivision2_code, :string, default: ""
    field :city_geoname_id, :integer, default: 0

    field :screen_size, :string, default: ""
    field :operating_system, :string, default: ""
    field :operating_system_version, :string, default: ""
    field :browser, :string, default: ""
    field :browser_version, :string, default: ""

    field :careers_application_form_uuid, :string, default: ""

    field :"meta.key", {:array, :string}, default: []
    field :"meta.value", {:array, :string}, default: []
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
        :contract_id,
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
    |> validate_contract_id()
    |> validate_product_id()
  end

  def validate_campaign_id(changeset) do
    campaign_id = get_field(changeset, :campaign_id)

    if ValueHelpers.validate(campaign_id, type: :prefixed_id) do
      changeset
    else
      delete_change(changeset, :campaign_id)
    end
  end

  def validate_contract_id(changeset) do
    contract_id = get_field(changeset, :contract_id)

    if ValueHelpers.validate(contract_id, type: :prefixed_id) do
      changeset
    else
      delete_change(changeset, :contract_id)
    end
  end

  def validate_product_id(changeset) do
    product_id = get_field(changeset, :product_id)

    if ValueHelpers.validate(product_id, type: :prefixed_id) do
      changeset
    else
      delete_change(changeset, :product_id)
    end
  end
end
