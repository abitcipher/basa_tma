defmodule BasaTma.Test.Bot do
  use ExGram.Bot, name: :tma_test_bot

  command("start", description: "Start")

  def handle({:command, :start, _msg}, context) do
    answer(context, "Welcome",
      reply_markup: BasaTma.Markup.reply_keyboard([["One", "Two"], [{"Phone", :request_contact}]])
    )
  end

  def handle({:text, text, _msg}, context) do
    answer(context, "You said: #{text}",
      reply_markup: BasaTma.Markup.open_buttons([{"Open", "/page"}], "https://example.test")
    )
  end

  def handle(_update, context), do: context
end

defmodule BasaTma.Test.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_query_params
    plug BasaTma.Plug
  end

  scope "/" do
    pipe_through :browser
    live "/telegram", BasaTma.Emulator.Live
    get "/telegram/file/:id", BasaTma.Emulator.File, :show
  end
end

defmodule BasaTma.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :basa_tma

  @session [store: :cookie, key: "_tma_test", signing_salt: "tma-test"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session]]
  plug Plug.Session, @session
  plug BasaTma.Test.Router
end
