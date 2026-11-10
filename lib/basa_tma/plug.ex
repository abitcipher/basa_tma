defmodule BasaTma.Plug do
  @moduledoc """
  Marks requests that run inside the Telegram Mini App.

  After a Mini App sign-in, call `enter/1`; from then on this plug assigns
  `:telegram_webapp` (true or false) on every request, so the root layout
  can load Telegram's script (`BasaTma.Components.script/1`). `?telegram=0`
  leaves Telegram mode for the session.
  """
  import Plug.Conn

  @key :telegram_webapp

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.params["telegram"] do
      "0" -> conn |> delete_session(@key) |> assign(@key, false)
      _ -> assign(conn, @key, get_session(conn, @key) == true)
    end
  end

  @doc "Remembers in the session that pages now run inside Telegram."
  def enter(conn), do: conn |> put_session(@key, true) |> assign(@key, true)
end
