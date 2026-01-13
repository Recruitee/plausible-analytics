defmodule Plausible.Sites do
  use Plausible.Repo

  def has_stats?(_site), do: true

  def get_for_user!(user_id, domain, roles \\ [:owner, :admin, :viewer]),
    do: Repo.one!(get_for_user_q(user_id, domain, roles))

  def get_for_user(user_id, domain, roles \\ [:owner, :admin, :viewer]),
    do: Repo.one(get_for_user_q(user_id, domain, roles))

  defp get_for_user_q(user_id, domain, roles) do
    from(s in Plausible.Site,
      join: sm in Plausible.Site.Membership,
      on: sm.site_id == s.id,
      where: sm.user_id == ^user_id,
      where: sm.role in ^roles,
      where: s.domain == ^domain,
      select: s
    )
  end

  def is_member?(user_id, site) do
    role(user_id, site) !== nil
  end

  def has_admin_access?(user_id, site) do
    role(user_id, site) in [:admin, :owner]
  end

  def role(user_id, site) do
    Repo.one(
      from sm in Plausible.Site.Membership,
        where: sm.user_id == ^user_id and sm.site_id == ^site.id,
        select: sm.role
    )
  end

  def owned_by(user) do
    Repo.all(
      from s in Plausible.Site,
        join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        where: sm.role == :owner,
        where: sm.user_id == ^user.id
    )
  end

  def count_owned_by(user) do
    Repo.one(
      from s in Plausible.Site,
        join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        where: sm.role == :owner,
        where: sm.user_id == ^user.id,
        select: count(sm)
    )
  end

  def owner_for(site) do
    Repo.one(
      from u in Plausible.Auth.User,
        join: sm in Plausible.Site.Membership,
        on: sm.user_id == u.id,
        where: sm.site_id == ^site.id,
        where: sm.role == :owner
    )
  end
end
