defmodule Plausible.Repo.Migrations.DropAllTablesExceptSalts do
  use Ecto.Migration

  def up do
    # Drop tables that depend on sites first
    drop_if_exists table(:site_memberships)
    drop_if_exists table(:goals)
    drop_if_exists table(:shared_links)
    drop_if_exists table(:spike_notifications)
    drop_if_exists table(:google_auth)
    drop_if_exists table(:invitations)
    drop_if_exists table(:custom_domains)
    drop_if_exists table(:email_settings)
    drop_if_exists table(:sent_email_reports)
    drop_if_exists table(:setup_help_emails)
    drop_if_exists table(:setup_success_emails)
    drop_if_exists table(:weekly_reports)
    drop_if_exists table(:sent_weekly_reports)
    drop_if_exists table(:monthly_reports)
    drop_if_exists table(:sent_monthly_reports)

    # Drop sites (depends on users)
    drop_if_exists table(:sites)

    # Drop tables that depend on users
    drop_if_exists table(:api_keys)
    drop_if_exists table(:subscriptions)
    drop_if_exists table(:enterprise_plans)
    drop_if_exists table(:sent_renewal_notifications)
    drop_if_exists table(:check_stats_emails)
    drop_if_exists table(:create_site_emails)
    drop_if_exists table(:feedback_emails)
    drop_if_exists table(:intro_emails)
    drop_if_exists table(:email_verification_codes)

    # Drop users
    drop_if_exists table(:users)

    # Drop custom enum types
    execute "DROP TYPE IF EXISTS site_membership_role"
    execute "DROP TYPE IF EXISTS billing_interval"
  end

  def down do
    # Create custom enum types
    execute "CREATE TYPE site_membership_role AS ENUM ('owner', 'admin', 'viewer')"
    execute "CREATE TYPE billing_interval AS ENUM ('monthly', 'yearly')"

    # Create users table
    create table(:users) do
      add :email, :citext, null: false
      add :name, :string
      add :last_seen, :naive_datetime, default: fragment("now()")
      add :password_hash, :string
      add :trial_expiry_date, :date
      add :email_verified, :boolean, null: false, default: false
      add :theme, :string, default: "system"
      add :grace_period, :map

      timestamps()
    end

    create unique_index(:users, :email)

    # Create sites table
    create table(:sites) do
      add :domain, :string, null: false
      add :timezone, :string, null: false
      add :public, :boolean, null: false, default: false
      add :locked, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index(:sites, :domain)

    # Create site_memberships table
    create table(:site_memberships) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :user_id, references(:users), null: false
      add :role, :site_membership_role, null: false, default: "owner"

      timestamps()
    end

    create unique_index(:site_memberships, [:site_id, :user_id])

    # Create goals table
    create table(:goals) do
      add :domain, :text, null: false
      add :event_name, :text
      add :page_path, :text

      timestamps()
    end

    create unique_index(:goals, [:domain, :event_name], where: "event_name IS NOT NULL")
    create unique_index(:goals, [:domain, :page_path], where: "page_path IS NOT NULL")

    # Create shared_links table
    create table(:shared_links) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :password_hash, :string
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:shared_links, [:site_id, :name])

    # Create spike_notifications table
    create table(:spike_notifications) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :threshold, :integer, null: false
      add :last_sent, :naive_datetime
      add :recipients, {:array, :citext}, null: false, default: []

      timestamps()
    end

    create unique_index(:spike_notifications, :site_id)

    # Create google_auth table
    create table(:google_auth) do
      add :user_id, references(:users), null: false
      add :email, :string, null: false
      add :refresh_token, :string, null: false
      add :access_token, :string, null: false
      add :expires, :naive_datetime, null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :property, :text

      timestamps()
    end

    create unique_index(:google_auth, :site_id)

    # Create invitations table
    create table(:invitations) do
      add :email, :citext, null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :inviter_id, references(:users), null: false
      add :role, :site_membership_role, null: false
      add :invitation_id, :string

      timestamps()
    end

    create unique_index(:invitations, [:site_id, :email])
    create unique_index(:invitations, :invitation_id)

    # Create custom_domains table
    create table(:custom_domains) do
      add :domain, :text, null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :has_ssl_certificate, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index(:custom_domains, :site_id)

    # Create weekly_reports table
    create table(:weekly_reports) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :recipients, {:array, :citext}, null: false, default: []

      timestamps()
    end

    create unique_index(:weekly_reports, :site_id)

    # Create sent_weekly_reports table
    create table(:sent_weekly_reports) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :year, :integer
      add :week, :integer
      add :timestamp, :naive_datetime
    end

    create unique_index(:sent_weekly_reports, [:site_id, :year, :week])

    # Create monthly_reports table
    create table(:monthly_reports) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :recipients, {:array, :citext}, null: false, default: []

      timestamps()
    end

    create unique_index(:monthly_reports, :site_id)

    # Create sent_monthly_reports table
    create table(:sent_monthly_reports) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :year, :integer, null: false
      add :month, :integer, null: false
      add :timestamp, :naive_datetime
    end

    # Create setup_help_emails table
    create table(:setup_help_emails) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :timestamp, :naive_datetime
    end

    # Create setup_success_emails table
    create table(:setup_success_emails) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :timestamp, :naive_datetime
    end

    # Create api_keys table
    create table(:api_keys) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :key_prefix, :string, null: false
      add :key_hash, :string, null: false
      add :scopes, {:array, :text}, null: false
      add :hourly_request_limit, :integer, null: false, default: 1000

      timestamps()
    end

    create index(:api_keys, [:scopes], using: "GIN")

    # Create subscriptions table
    create table(:subscriptions) do
      add :paddle_subscription_id, :string, null: false
      add :paddle_plan_id, :string, null: false
      add :user_id, references(:users), null: false
      add :update_url, :text, null: false
      add :cancel_url, :text, null: false
      add :status, :string, null: false
      add :next_bill_amount, :string, null: false
      add :next_bill_date, :date, null: false
      add :currency_code, :string, null: false
      add :last_bill_date, :date

      timestamps()
    end

    create unique_index(:subscriptions, :paddle_subscription_id)

    # Create enterprise_plans table
    create table(:enterprise_plans) do
      add :user_id, references(:users), null: false
      add :paddle_plan_id, :string, null: false
      add :billing_interval, :billing_interval, null: false
      add :monthly_pageview_limit, :integer, null: false
      add :hourly_api_request_limit, :integer, null: false
      add :site_limit, :integer, null: false

      timestamps()
    end

    create unique_index(:enterprise_plans, :user_id)

    # Create sent_renewal_notifications table
    create table(:sent_renewal_notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :timestamp, :naive_datetime
    end

    # Create check_stats_emails table
    create table(:check_stats_emails) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :timestamp, :naive_datetime
    end

    # Create create_site_emails table
    create table(:create_site_emails) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :timestamp, :naive_datetime
    end

    # Create feedback_emails table
    create table(:feedback_emails) do
      add :user_id, references(:users), null: false
      add :timestamp, :naive_datetime, null: false
    end

    # Create intro_emails table
    create table(:intro_emails) do
      add :user_id, references(:users), null: false
      add :timestamp, :naive_datetime
    end

    # Create email_verification_codes table
    create table(:email_verification_codes, primary_key: false) do
      add :code, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :issued_at, :naive_datetime
    end
  end
end
