defmodule PlausibleWeb.LayoutView do
  use PlausibleWeb, :view

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def base_domain do
    PlausibleWeb.Endpoint.host()
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def trial_notificaton(_user), do: "Trial ends tomorrow"

  def on_grace_period?(nil), do: false

  def on_grace_period?(user) do
    user.grace_period &&
      Timex.diff(user.grace_period.end_date, Timex.today(), :days) >= 0
  end

  def grace_period_over?(nil), do: false

  def grace_period_over?(user) do
    user.grace_period &&
      Timex.diff(user.grace_period.end_date, Timex.today(), :days) < 0
  end

  def grace_period_end(user) do
    end_date = user.grace_period.end_date

    case Timex.diff(end_date, Timex.today(), :days) do
      0 -> "today"
      1 -> "tomorrow"
      n -> "within #{n} days"
    end
  end

  @doc "http://blog.plataformatec.com.br/2018/05/nested-layouts-with-phoenix/"
  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end

  def is_current_tab(conn, tab) do
    List.last(conn.path_info) == tab
  end
end
