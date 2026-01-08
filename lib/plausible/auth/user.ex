defmodule Plausible.Auth.User do
  use Ecto.Schema

  schema "users" do
    field :email, :string
    field :password_hash
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :name, :string
    field :last_seen, :naive_datetime
    field :trial_expiry_date, :date
    field :theme, :string
    field :email_verified, :boolean

    has_many :site_memberships, Plausible.Site.Membership
    has_many :sites, through: [:site_memberships, :site]

    timestamps()
  end
end
