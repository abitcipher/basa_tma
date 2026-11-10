defmodule BasaTma.EmulatorTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias BasaTma.Emulator

  @endpoint BasaTma.Test.Endpoint
  @user %{id: 900_001, first_name: "Max", username: "max", language_code: "en"}

  setup do
    Emulator.reset(@user.id)
    :ok
  end

  defp bot_entries, do: Emulator.transcript(@user.id) |> Enum.filter(&(&1.from == :bot))

  test "the bot answers through the emulator, keyboards included" do
    Emulator.user_sends(@user, {:text, "/start"})

    assert [%{text: "Welcome", reply_markup: %{"keyboard" => [[%{"text" => "One"}, _], [phone]]}}] =
             bot_entries()

    assert phone["request_contact"]

    Emulator.user_sends(@user, {:text, "hello"})

    assert %{text: "You said: hello", reply_markup: %{"inline_keyboard" => [[button]]}} =
             List.last(bot_entries())

    assert button["web_app"]["url"] == "https://example.test/tg?to=%2Fpage"
  end

  test "photos the user sends can be read back" do
    Emulator.user_sends(@user, {:photo, "bytes", "image/png"})
    [%{photo: file_id}] = Emulator.transcript(@user.id)
    assert {:ok, "bytes", "image/png"} = Emulator.file(file_id)

    conn = get(build_conn(), "/telegram/file/#{file_id}")
    assert response(conn, 200) == "bytes"
    assert response(get(build_conn(), "/telegram/file/nope"), 404)
  end

  test "initData is signed with the emulator's token" do
    assert {:ok, %{"id" => 900_001}} =
             BasaTma.Auth.verify_init_data(Emulator.init_data(@user), Emulator.token())
  end

  test "the chat page: send a message, use the keyboard, open the Mini App" do
    {:ok, view, html} = live(build_conn(), "/telegram")
    assert html =~ "Test bot"
    refute has_element?(view, "#tg-dev")

    view |> element("#tg-dev-toggle") |> render_click()
    assert has_element?(view, "#tg-dev")

    view |> element("#tg-dev button", "/start") |> render_click()
    assert_eventually(fn -> has_element?(view, "#tg-keyboard button", "One") end)

    view |> element("#tg-keyboard button", "One") |> render_click()
    assert_eventually(fn -> render(view) =~ "You said: One" end)

    view |> element("#tg-menu-button") |> render_click()
    assert has_element?(view, "iframe#mini-app[src*='tgWebAppData']")
  end

  defp assert_eventually(fun, tries \\ 40) do
    cond do
      fun.() -> :ok
      tries == 0 -> flunk("condition not met")
      true -> Process.sleep(25) && assert_eventually(fun, tries - 1)
    end
  end
end
