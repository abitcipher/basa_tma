defmodule BasaTma do
  @moduledoc """
  Telegram Mini App toolkit for Phoenix applications.

  * `BasaTma.Auth` verifies Telegram's signatures (Mini App `initData`,
    Login Widget).
  * `BasaTma.Plug` and `BasaTma.Components` make pages run inside Telegram.
  * `BasaTma.Markup` builds bot keyboards and Mini App buttons.
  * `BasaTma.Emulator` is a local stand-in for Telegram for development.
  """

  @doc """
  The URL that opens `path` of the host application as a Mini App: the entry
  page signs the person in and then goes to `path`.

      iex> BasaTma.app_url("https://example.com", "/bookings")
      "https://example.com/tg?to=%2Fbookings"
  """
  def app_url(base_url, path, entry \\ "/tg") do
    "#{base_url}#{entry}?to=#{URI.encode_www_form(path)}"
  end

  @doc """
  `path` when it is a path of this site, otherwise `"/"`. Use it for every
  redirect target that comes from a request.
  """
  def safe_path("/" <> rest = path) do
    if String.starts_with?(rest, ["/", "\\"]), do: "/", else: path
  end

  def safe_path(_), do: "/"
end
