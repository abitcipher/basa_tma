defmodule BasaTma.Emulator.File do
  @moduledoc """
  Serves photos sent in the emulator. Route it with an `:id` parameter:

      get "/telegram/file/:id", BasaTma.Emulator.File, :show
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case BasaTma.Emulator.file(conn.path_params["id"]) do
      {:ok, bin, mime} -> conn |> put_resp_content_type(mime, nil) |> send_resp(200, bin)
      _ -> send_resp(conn, 404, "Not found")
    end
  end
end
