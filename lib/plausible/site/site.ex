defmodule Plausible.Site do
  use Ecto.Schema
  alias Plausible.Auth.User

  @derive {Jason.Encoder, only: [:domain, :timezone]}
  schema "sites" do
    field :domain, :string
    field :timezone, :string, default: "Etc/UTC"
    field :public, :boolean
    field :locked, :boolean
    field :has_stats, :boolean

    many_to_many :members, User, join_through: Plausible.Site.Membership
    has_many :memberships, Plausible.Site.Membership

    timestamps()
  end
end
