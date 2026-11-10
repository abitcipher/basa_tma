defmodule BasaTmaTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  alias BasaTma.Markup

  test "only same-site paths are safe" do
    assert BasaTma.safe_path("/lots/1") == "/lots/1"
    assert BasaTma.safe_path("//evil.example") == "/"
    assert BasaTma.safe_path("/\\evil.example") == "/"
    assert BasaTma.safe_path("https://evil.example") == "/"
    assert BasaTma.safe_path(nil) == "/"
  end

  test "the Mini App URL of a page" do
    assert BasaTma.app_url("https://example.test", "/my/items") ==
             "https://example.test/tg?to=%2Fmy%2Fitems"
  end

  test "a reply keyboard" do
    keyboard = Markup.reply_keyboard([[{"Phone", :request_contact}], ["A", "B"]])
    assert keyboard.is_persistent and keyboard.resize_keyboard

    assert [[%{text: "Phone", request_contact: true}], [%{text: "A"}, %{text: "B"}]] =
             keyboard.keyboard
  end

  test "open buttons are Mini App buttons over HTTPS and links otherwise" do
    assert %{inline_keyboard: [[%{text: "Open", web_app: %{url: url}}]]} =
             Markup.open_buttons([{"Open", "/page"}], "https://example.test")

    assert url == "https://example.test/tg?to=%2Fpage"

    assert %{
             inline_keyboard: [[%{text: "Open", url: "http://localhost:4000/page", web_app: nil}]]
           } =
             Markup.open_buttons([{"Open", "/page"}], "http://localhost:4000")

    assert %{inline_keyboard: [[%{web_app: %{}}]]} =
             Markup.open_buttons([{"Open", "/page"}], "http://localhost:4000", web_app: true)
  end

  test "the menu button" do
    assert %{type: "web_app", text: "App", web_app: %{url: "https://example.test/tg"}} =
             Markup.menu_button("App", "https://example.test/tg")
  end

  test "the entry page carries where to go and its texts" do
    html =
      render_component(&BasaTma.Components.entry/1,
        to: "/bookings",
        signing_in: "One moment",
        inner_block: []
      )

    assert html =~ ~s(data-to="/bookings")
    assert html =~ ~s(data-sign-in-path="/auth/telegram/webapp")
    assert html =~ "One moment"
  end

  test "tiles link to their pages" do
    html =
      render_component(&BasaTma.Components.tiles/1,
        tiles: [
          %{id: "find", label: "Find", path: "/"},
          %{id: "help", label: "Help", path: "/help"}
        ],
        inner_block: []
      )

    assert html =~ ~s(id="tile-find")
    assert html =~ ~s(href="/help")
  end
end
