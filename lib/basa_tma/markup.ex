defmodule BasaTma.Markup do
  @moduledoc "Bot keyboards and Mini App buttons, as ExGram structs."

  alias ExGram.Model

  @doc """
  A keyboard under the message field. `rows` is a list of rows of buttons;
  a button is a label or `{label, :request_contact}`.
  """
  def reply_keyboard(rows, opts \\ []) do
    keyboard =
      for row <- rows do
        for button <- row do
          case button do
            {text, :request_contact} -> %{text: text, request_contact: true}
            text when is_binary(text) -> %{text: text}
          end
        end
      end

    cast(
      %{
        keyboard: keyboard,
        resize_keyboard: Keyword.get(opts, :resize, true),
        is_persistent: Keyword.get(opts, :persistent, true)
      },
      Model.ReplyKeyboardMarkup
    )
  end

  @doc """
  Buttons under a message, one per row, that open pages of the host
  application. `entries` are `{label, path}`.

  With `web_app: true` (Telegram requires HTTPS for it) a button opens the
  page as a Mini App through the entry page; otherwise it is a plain link.
  """
  def open_buttons(entries, base_url, opts \\ []) do
    web_app? = Keyword.get(opts, :web_app, String.starts_with?(base_url, "https://"))
    entry = Keyword.get(opts, :entry, "/tg")

    rows =
      for {text, path} <- entries do
        if web_app?,
          do: [%{text: text, web_app: %{url: BasaTma.app_url(base_url, path, entry)}}],
          else: [%{text: text, url: base_url <> path}]
      end

    cast(%{inline_keyboard: rows}, Model.InlineKeyboardMarkup)
  end

  @doc "The chat's menu button that opens `url` as a Mini App."
  def menu_button(text, url) do
    cast(%{type: "web_app", text: text, web_app: %{url: url}}, Model.MenuButtonWebApp)
  end

  defp cast(map, type) do
    {:ok, struct} = ExGram.Cast.cast(map, type)
    struct
  end
end
