defmodule PlausibleWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use PlausibleWeb, :html

  embed_templates "error_html/*"

  @doc """
  Renders error pages with custom messages.
  """
  def render(template, assigns) do
    status = status_from_template(template)
    message = message_from_status(status)

    assigns =
      assigns
      |> Map.put(:status, status)
      |> Map.put(:message, message)

    error(assigns)
  end

  defp status_from_template(template) do
    template
    |> String.trim_trailing(".html")
    |> String.to_integer()
  rescue
    _ -> 500
  end

  defp message_from_status(404), do: "Oops! There's nothing here"
  defp message_from_status(500), do: "Oops! Looks like we're having server issues"

  defp message_from_status(status),
    do: Phoenix.Controller.status_message_from_template("#{status}.html")
end
