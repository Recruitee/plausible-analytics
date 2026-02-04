defmodule PlausibleWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  @doc """
  Renders a JSON error response.

  The default is to render a JSON object with the status and message.
  """
  def render(template, _assigns) do
    status = status_from_template(template)

    %{
      status: status,
      message: message_from_status(status)
    }
  end

  defp status_from_template(template) do
    template
    |> String.trim_trailing(".json")
    |> String.to_integer()
  rescue
    _ -> 500
  end

  defp message_from_status(500), do: "Server error"
  defp message_from_status(404), do: "Not found"
  defp message_from_status(400), do: "Bad request"
  defp message_from_status(401), do: "Unauthorized"
  defp message_from_status(403), do: "Forbidden"
  defp message_from_status(_), do: "Error"
end
