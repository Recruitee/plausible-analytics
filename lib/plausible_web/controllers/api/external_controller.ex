defmodule PlausibleWeb.Api.ExternalController do
  @moduledoc """
  Controller for handling external API requests, primarily event tracking.

  This controller serves as the entry point for external tracking requests.
  The actual event creation logic has been extracted to `Plausible.Tracking.Actions.Event`.
  """

  use PlausibleWeb, :controller

  alias Plausible.Tracking.Actions.Event

  @doc """
  Handles incoming event tracking requests.

  Parses the request body and delegates to Event for processing.

  ## Response Codes

    * 202 - Event accepted successfully
    * 400 - Invalid request (malformed JSON, missing fields, validation errors)
  """
  def event(conn, _params) do
    with {:ok, params} <- parse_body(conn),
         :ok <- Event.create(conn, params) do
      conn |> put_status(202) |> text("ok")
    else
      _ ->
        conn
        |> put_status(400)
        |> json(%{errors: %{request: "Unable to process request"}})
    end
  end

  @doc """
  Parses the request body, handling both pre-parsed and raw body content.

  When Content-Type is not application/json, the body may come as raw text
  that needs to be JSON-decoded.
  """
  @spec parse_body(Plug.Conn.t()) :: {:ok, map()} | {:error, :invalid_json}
  def parse_body(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)

        case Jason.decode(body) do
          {:ok, params} -> {:ok, params}
          _ -> {:error, :invalid_json}
        end

      params ->
        {:ok, params}
    end
  end
end
