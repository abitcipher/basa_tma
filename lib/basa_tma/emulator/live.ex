defmodule BasaTma.Emulator.Live do
  @moduledoc """
  A Telegram-like chat page for `BasaTma.Emulator`: talk to your real bot as
  any test user, send photos, share a contact, reply to messages, and open
  the Mini App with signed `initData`.

  Tools that Telegram itself doesn't have (switching the test user, quick
  commands, theme, clearing the chat) are in the "Dev" panel.

  Mount it in a development-only scope, without the application layout:

      live "/telegram", BasaTma.Emulator.Live
      get "/telegram/file/:id", BasaTma.Emulator.File, :show

  It needs the `TmaChatScroll` hook from this package's JavaScript.

  Options, under `config :basa_tma, :emulator`:

    * `:title` - the bot's name in the header ("Bot")
    * `:icon` - path of the bot's picture
    * `:menu_path` - what the chat's menu button opens ("/tg?to=%2F")
    * `:file_path` - where `BasaTma.Emulator.File` is routed
      ("/dev/telegram/file/")
    * `:commands` - quick texts in the Dev panel (["/start"])
    * `:users` - test users (maps with `:id`, `:first_name`, `:language_code`)
    * `:home` - where to go when the emulator is off ("/")
  """
  use Phoenix.LiveView

  alias BasaTma.Emulator

  @users [
    %{
      id: 700_001,
      first_name: "Olena",
      last_name: "K",
      username: "olena_studio",
      language_code: "uk"
    },
    %{id: 700_002, first_name: "Max", username: "max_vocals", language_code: "en"},
    %{id: 700_003, first_name: "Hans", username: "hans_berlin", language_code: "de"},
    %{id: 700_004, first_name: "Camille", username: "camille_paris", language_code: "fr"},
    %{id: 700_005, first_name: "Lucía", username: "lucia_madrid", language_code: "es"},
    %{id: 700_006, first_name: "Marco", username: "marco_roma", language_code: "it"},
    %{id: 700_007, first_name: "Kasia", username: "kasia_krakow", language_code: "pl"},
    %{id: 700_008, first_name: "Ioana", username: "ioana_cluj", language_code: "ro"},
    %{id: 700_009, first_name: "Ayşe", username: "ayse_izmir", language_code: "tr"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    config = Emulator.config()
    users = Keyword.get(config, :users, @users)

    if Emulator.enabled?() do
      {:ok,
       socket
       |> assign(
         page_title: "Telegram emulator",
         users: users,
         title: Keyword.get(config, :title, "Bot"),
         icon: config[:icon],
         menu_path: Keyword.get(config, :menu_path, "/tg?to=%2F"),
         file_path: Keyword.get(config, :file_path, "/dev/telegram/file/"),
         commands: Keyword.get(config, :commands, ["/start"]),
         reply_to: nil,
         mini_app: nil,
         tg_theme: "light",
         sent: 0,
         dev_open: false,
         keyboard_open: true
       )
       |> allow_upload(:photo,
         accept: ~w(.jpg .jpeg .png .webp),
         max_entries: 1,
         max_file_size: 12_000_000
       )
       |> switch_user(hd(users))}
    else
      {:ok,
       socket
       |> put_flash(:error, "The Telegram emulator is off.")
       |> push_navigate(to: Keyword.get(config, :home, "/"))}
    end
  end

  defp switch_user(socket, user) do
    if connected?(socket) do
      pubsub = Keyword.fetch!(Emulator.config(), :pubsub)

      if old = socket.assigns[:user],
        do: Phoenix.PubSub.unsubscribe(pubsub, Emulator.topic(old.id))

      Phoenix.PubSub.subscribe(pubsub, Emulator.topic(user.id))
    end

    assign(socket,
      user: user,
      entries: Emulator.transcript(user.id),
      reply_to: nil,
      mini_app: nil
    )
  end

  @impl true
  def handle_event("user", %{"id" => id}, socket) do
    user = Enum.find(socket.assigns.users, &(to_string(&1.id) == id))
    {:noreply, switch_user(socket, user)}
  end

  def handle_event("send", %{"text" => text}, socket) do
    text = String.trim(text)
    if text != "", do: deliver(socket, {:text, text})
    {:noreply, socket |> assign(reply_to: nil) |> update(:sent, &(&1 + 1))}
  end

  def handle_event("command", %{"text" => text}, socket) do
    deliver(socket, {:text, text})
    {:noreply, socket}
  end

  def handle_event("share_contact", _params, socket) do
    phone =
      "+38050#{rem(socket.assigns.user.id, 10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

    deliver(socket, {:contact, phone})
    {:noreply, socket}
  end

  def handle_event("reply", %{"id" => id}, socket),
    do: {:noreply, assign(socket, reply_to: String.to_integer(id))}

  def handle_event("cancel_reply", _, socket), do: {:noreply, assign(socket, reply_to: nil)}

  def handle_event("open", %{"url" => url}, socket) do
    path = relative(url)

    {:noreply,
     assign(socket, mini_app: mini_app_url(path, socket.assigns.user, socket.assigns.tg_theme))}
  end

  def handle_event("close_app", _, socket), do: {:noreply, assign(socket, mini_app: nil)}

  def handle_event("toggle_dev", _, socket),
    do: {:noreply, assign(socket, dev_open: !socket.assigns.dev_open)}

  def handle_event("toggle_keyboard", _, socket),
    do: {:noreply, assign(socket, keyboard_open: !socket.assigns.keyboard_open)}

  def handle_event("tg_theme", _, socket) do
    theme = if socket.assigns.tg_theme == "light", do: "dark", else: "light"
    {:noreply, assign(socket, tg_theme: theme)}
  end

  def handle_event("photo_change", _params, socket), do: {:noreply, socket}

  def handle_event("send_photo", _params, socket) do
    for {bin, mime} <-
          consume_uploaded_entries(socket, :photo, fn %{path: path}, entry ->
            {:ok, {File.read!(path), entry.client_type}}
          end) do
      deliver(socket, {:photo, bin, mime})
    end

    {:noreply, socket}
  end

  def handle_event("reset", _, socket) do
    Emulator.reset(socket.assigns.user.id)
    {:noreply, assign(socket, entries: [])}
  end

  @impl true
  def handle_info({:tma_emulator, entry}, socket) do
    {:noreply, socket |> update(:entries, &(&1 ++ [entry])) |> push_event("chat:scroll", %{})}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp deliver(socket, content) do
    user = socket.assigns.user
    reply_to = socket.assigns.reply_to
    Task.start(fn -> Emulator.user_sends(user, content, reply_to) end)
  end

  defp relative(url) do
    uri = URI.parse(url)
    (uri.path || "/") <> if(uri.query, do: "?" <> uri.query, else: "")
  end

  @themes %{
    "light" => %{
      bg_color: "#ffffff",
      text_color: "#000000",
      hint_color: "#707579",
      link_color: "#3390ec",
      button_color: "#3390ec",
      button_text_color: "#ffffff",
      secondary_bg_color: "#f4f4f5",
      section_separator_color: "#e7e7e7"
    },
    "dark" => %{
      bg_color: "#212121",
      text_color: "#ffffff",
      hint_color: "#aaaaaa",
      link_color: "#8774e1",
      button_color: "#8774e1",
      button_text_color: "#ffffff",
      secondary_bg_color: "#181818",
      section_separator_color: "#0f0f0f"
    }
  }

  defp mini_app_url(path, user, theme) do
    fragment =
      URI.encode_query(%{
        "tgWebAppData" => Emulator.init_data(user),
        "tgWebAppVersion" => "8.0",
        "tgWebAppPlatform" => "android",
        "tgWebAppThemeParams" => Jason.encode!(@themes[theme])
      })

    path <> "#" <> fragment
  end

  defp buttons(%{"inline_keyboard" => rows}), do: {:inline, List.flatten(rows)}
  defp buttons(%{"keyboard" => rows}), do: {:reply, List.flatten(rows)}
  defp buttons(_), do: nil

  defp reply_keyboard(entries) do
    entries
    |> Enum.filter(&(&1.from == :bot and is_map(&1[:reply_markup])))
    |> Enum.reverse()
    |> Enum.find_value([], fn e ->
      cond do
        e.reply_markup["remove_keyboard"] -> :removed
        rows = e.reply_markup["keyboard"] -> rows
        true -> nil
      end
    end)
    |> case do
      :removed -> []
      rows -> rows
    end
  end

  defp reply_text(entries, id) do
    case Enum.find(entries, &(&1.id == id)) do
      %{text: t} when is_binary(t) -> String.slice(t, 0, 60)
      _ -> "message"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto flex h-dvh max-w-md flex-col bg-[#e6ebee] dark:bg-zinc-900">
      <header class="flex items-center gap-3 bg-[#517da2] px-3 py-2 text-white">
        <img :if={@icon} src={@icon} class="size-9 rounded-full" alt="" />
        <div class="flex-1">
          <p class="font-semibold leading-tight">{@title}</p>
          <p class="text-xs opacity-80">@{Emulator.bot_username()} · emulator</p>
        </div>
        <button
          id="tg-dev-toggle"
          phx-click="toggle_dev"
          class="cursor-pointer rounded-full border border-white/50 px-2 py-0.5 text-xs opacity-80"
          title="Developer tools (not part of Telegram)"
        >
          Dev {if @dev_open, do: "▴", else: "▾"}
        </button>
      </header>
      <div
        :if={@dev_open}
        id="tg-dev"
        class="space-y-1.5 border-b-2 border-dashed border-amber-400 bg-amber-50 px-2 py-2 text-xs text-zinc-800 dark:bg-zinc-800 dark:text-zinc-100"
      >
        <div class="flex items-center gap-2">
          <span class="font-semibold">Developer tools</span>
          <button id="tg-theme" phx-click="tg_theme" class="cursor-pointer underline">
            {if @tg_theme == "light", do: "☀ light", else: "☾ dark"}
          </button>
          <button phx-click="reset" class="cursor-pointer underline">clear chat</button>
        </div>
        <div class="flex flex-wrap gap-1">
          <span class="py-1 opacity-60">You are:</span>
          <button
            :for={u <- @users}
            phx-click="user"
            phx-value-id={u.id}
            class={[
              "shrink-0 cursor-pointer rounded-full px-2 py-1",
              if(u.id == @user.id,
                do: "bg-[#517da2] text-white",
                else: "bg-zinc-100 dark:bg-zinc-700"
              )
            ]}
          >
            {u.first_name} ({u.language_code})
          </button>
        </div>
        <div class="flex flex-wrap gap-1">
          <span class="py-1 opacity-60">Type:</span>
          <button
            :for={cmd <- @commands}
            phx-click="command"
            phx-value-text={cmd}
            class="shrink-0 cursor-pointer rounded-full bg-white px-2 py-1 dark:bg-zinc-700"
          >
            {cmd}
          </button>
        </div>
      </div>

      <div id="tg-log" phx-hook="TmaChatScroll" class="flex-1 space-y-2 overflow-y-auto p-3">
        <p :if={@entries == []} class="py-10 text-center text-sm opacity-60">Tap /start to begin.</p>
        <div :for={e <- @entries} class={["flex", e.from == :user && "justify-end"]}>
          <div class={[
            "max-w-[85%] rounded-2xl px-3 py-2 text-sm shadow-sm",
            if(e.from == :user,
              do: "bg-[#effdde] dark:bg-emerald-900",
              else: "bg-white dark:bg-zinc-800"
            )
          ]}>
            <p :if={e[:reply_to]} class="mb-1 border-l-2 border-[#517da2] pl-2 text-xs opacity-70">
              {reply_text(@entries, e.reply_to)}
            </p>
            <img
              :if={e[:photo]}
              src={@file_path <> e.photo}
              class="mb-1 max-h-48 rounded-lg"
              alt=""
            />
            <p :if={e[:text]} class="whitespace-pre-line">{e.text}</p>

            <%= case buttons(e[:reply_markup]) do %>
              <% {:inline, btns} -> %>
                <div class="mt-2 grid gap-1">
                  <button
                    :for={b <- btns}
                    phx-click="open"
                    phx-value-url={(b["web_app"] && b["web_app"]["url"]) || b["url"]}
                    class="cursor-pointer rounded-lg bg-[#517da2]/10 px-2 py-1.5 text-xs font-medium text-[#3a6d99] dark:text-sky-300"
                  >
                    {if b["web_app"], do: "▣ ", else: "↗ "}{b["text"]}
                  </button>
                </div>
              <% _ -> %>
            <% end %>

            <div class="mt-1 flex items-center justify-end gap-2 text-[10px] opacity-50">
              <button
                :if={e.from == :bot}
                phx-click="reply"
                phx-value-id={e.id}
                class="cursor-pointer underline"
              >reply</button>
              <span>{Calendar.strftime(e.at, "%H:%M")}</span>
            </div>
          </div>
        </div>
      </div>

      <div
        :if={@reply_to}
        class="flex items-center justify-between bg-white px-3 py-1 text-xs dark:bg-zinc-800"
      >
        <span class="border-l-2 border-[#517da2] pl-2 opacity-70">Replying to: {reply_text(
          @entries,
          @reply_to
        )}</span>
        <button phx-click="cancel_reply" class="cursor-pointer">✕</button>
      </div>

      <div class="flex items-end gap-2 bg-white p-2 dark:bg-zinc-800">
        <button
          id="tg-menu-button"
          phx-click="open"
          phx-value-url={@menu_path}
          class="mb-0.5 cursor-pointer rounded-full bg-[#517da2] px-3 py-1.5 text-xs font-semibold text-white"
        >
          ☰ {@title}
        </button>
        <form
          id="tg-photo"
          phx-change="photo_change"
          phx-submit="send_photo"
          class="flex items-center"
        >
          <label class="cursor-pointer p-1" title="Send a photo">
            <span class="text-xl opacity-60">📎</span>
            <.live_file_input upload={@uploads.photo} class="hidden" />
          </label>
          <button
            :if={@uploads.photo.entries != []}
            type="submit"
            class="cursor-pointer rounded bg-[#517da2] px-2 py-1 text-xs text-white"
          >
            send photo
          </button>
        </form>
        <form id={"tg-send-#{@sent}"} phx-submit="send" class="flex flex-1 items-end gap-2">
          <input
            name="text"
            autocomplete="off"
            placeholder="Message"
            class="flex-1 rounded-full bg-zinc-100 px-4 py-2 text-sm outline-none dark:bg-zinc-700"
            autofocus
          />
          <button
            :if={reply_keyboard(@entries) != []}
            type="button"
            id="tg-keyboard-toggle"
            phx-click="toggle_keyboard"
            class="cursor-pointer p-1"
            aria-label="Menu keyboard"
          >
            <span class="text-xl opacity-60">⌨</span>
          </button>
          <button type="submit" class="cursor-pointer p-1" aria-label="Send">
            <span class="text-xl text-[#517da2]">➤</span>
          </button>
        </form>
      </div>
      <div
        :if={@keyboard_open and reply_keyboard(@entries) != []}
        id="tg-keyboard"
        class="grid gap-1.5 bg-[#e6ebee] p-2 dark:bg-zinc-900"
      >
        <div :for={row <- reply_keyboard(@entries)} class="flex gap-1.5">
          <button
            :for={b <- row}
            phx-click={if b["request_contact"], do: "share_contact", else: "command"}
            phx-value-text={b["text"]}
            class="flex-1 cursor-pointer rounded-lg bg-white px-2 py-2.5 text-sm shadow-sm dark:bg-zinc-800"
          >
            {b["text"]}
          </button>
        </div>
      </div>

      <div
        :if={@mini_app}
        class="fixed inset-0 z-50 mx-auto flex max-w-md flex-col bg-white dark:bg-zinc-900"
      >
        <div class="flex items-center gap-2 bg-[#517da2] px-3 py-2 text-white">
          <button phx-click="close_app" class="cursor-pointer text-sm">✕ Close</button>
          <span class="flex-1 text-center text-sm font-semibold">{@title}</span>
          <span class="w-14 text-right text-xs opacity-80">{@tg_theme}</span>
        </div>
        <iframe id="mini-app" src={@mini_app} class="w-full flex-1 border-0"></iframe>
      </div>
    </div>
    """
  end
end
