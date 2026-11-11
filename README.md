# BASA TMA - Telegram Mini App for [BASA](https://github.com/abitcipher/basa)

Telegram Mini App toolkit for Phoenix applications. It was built for
[BASA](https://github.com/abitcipher/basa) and knows nothing about BASA's data, so it works in any Phoenix + LiveView application with an [ExGram](https://github.com/rockneurotiko/ex_gram) bot.

What is inside:

| Module | What it does |
|---|---|
| `BasaTma.Auth` | Verifies Telegram's signatures: Mini App `initData` and the Login Widget |
| `BasaTma.Plug` | Marks requests that run inside Telegram |
| `BasaTma.Components` | Telegram's script tag, the Mini App entry page, a start screen of tiles |
| `BasaTma.Markup` | Bot keyboards, Mini App buttons, the chat's menu button |
| `BasaTma.Emulator` | A local stand-in for Telegram, with a Telegram-like chat page |
| `assets/js` | Theme, Back button, haptics inside Telegram; the chat page's hook |
| `assets/css` | Telegram's theme colours for the page |

## Install

```elixir
{:basa_tma, github: "abitcipher/basa_tma", tag: "v0.1.0"}
```

## A Mini App in five steps

1. **Router.** Add the plug to the browser pipeline and three routes:

   ```elixir
   plug BasaTma.Plug

   get "/tg", TelegramController, :app
   post "/auth/telegram/webapp", TelegramController, :webapp_sign_in
   ```

2. **Controller.** Render the entry page, verify `initData`, start the
   session:

   ```elixir
   def app(conn, params) do
     render(conn, :app, to: BasaTma.safe_path(params["to"]))
   end

   def webapp_sign_in(conn, %{"init_data" => init_data} = params) do
     with {:ok, tg_user} <- BasaTma.Auth.verify_init_data(init_data, bot_token()),
          {:ok, user} <- MyApp.Accounts.sign_in(BasaTma.Auth.user_attrs(tg_user)) do
       conn
       |> log_in(user)
       |> BasaTma.Plug.enter()
       |> json(%{ok: true, to: BasaTma.safe_path(params["to"])})
     else
       _ -> conn |> put_status(401) |> json(%{ok: false})
     end
   end
   ```

   ```heex
   <BasaTma.Components.entry to={@to}>
     <img src={~p"/images/logo.png"} class="size-20" />
   </BasaTma.Components.entry>
   ```

3. **Root layout.** Load Telegram's script inside Telegram:

   ```heex
   <BasaTma.Components.script :if={assigns[:telegram_webapp]} />
   ```

4. **JavaScript and CSS.** With Phoenix's default esbuild and Tailwind
   setup (`NODE_PATH` includes `deps`):

   ```js
   import { startTelegram, TmaChatScroll } from "basa_tma"

   const liveSocket = new LiveSocket("/live", Socket, { hooks: { TmaChatScroll } })
   startTelegram(liveSocket, { home: "/" })
   ```

   ```css
   @import "../../deps/basa_tma/assets/css/telegram.css";
   @source "../../deps/basa_tma/lib";
   ```

5. **Bot.** Send buttons that open your pages as the Mini App:

   ```elixir
   answer(context, "Welcome",
     reply_markup: BasaTma.Markup.open_buttons([{"Open", "/app"}], MyAppWeb.Endpoint.url())
   )
   ```

## The emulator

Develop without a bot token or a public HTTPS server. Your real bot runs
unchanged; a chat page plays Telegram.

```elixir
# config/dev.exs
config :basa_tma, :emulator, pubsub: MyApp.PubSub, bot: :my_bot, title: "My bot"
config :ex_gram, adapter: BasaTma.Emulator.Adapter

# application.ex (development)
ExGram,
BasaTma.Emulator,
{MyApp.Bot, [method: :test, token: BasaTma.Emulator.token(), handler_mode: :sync]}

# router.ex (development only)
live "/dev/telegram", BasaTma.Emulator.Live
get "/dev/telegram/file/:id", BasaTma.Emulator.File, :show
```

Verify `initData` with `BasaTma.Emulator.token()` while the emulator runs.
In tests, `BasaTma.Emulator.user_sends/3` and `transcript/1` drive the bot
and read its answers.

## Develop

```sh
mix deps.get
mix test
```
