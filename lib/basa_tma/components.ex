defmodule BasaTma.Components do
  @moduledoc "Function components for pages that run inside Telegram."
  use Phoenix.Component

  @doc """
  Telegram's Mini App script. Put it in the root layout's `<head>`:

      <BasaTma.Components.script :if={assigns[:telegram_webapp]} />
  """
  def script(assigns) do
    ~H"""
    <script src="https://telegram.org/js/telegram-web-app.js">
    </script>
    """
  end

  @doc """
  The Mini App's entry page: posts Telegram's signed `initData` to
  `sign_in_path` (JSON `{init_data, to}` with the CSRF token), then opens the
  path the server answers with (`{"ok": true, "to": path}`).

  The inner block is shown while signing in (a logo, a spinner).
  """
  attr :to, :string, required: true
  attr :sign_in_path, :string, default: "/auth/telegram/webapp"
  attr :signing_in, :string, default: "Signing you in…"
  attr :outside, :string, default: "Open this page from the bot in Telegram."
  attr :failed, :string, default: "Sign-in failed. Close and reopen the app."
  slot :inner_block

  def entry(assigns) do
    ~H"""
    <main
      id="tma-entry"
      class="min-h-screen flex flex-col items-center justify-center gap-3 p-6 text-center"
      data-to={@to}
      data-sign-in-path={@sign_in_path}
      data-outside={@outside}
      data-failed={@failed}
    >
      {render_slot(@inner_block)}
      <p id="tma-status" class="text-sm opacity-70">{@signing_in}</p>
    </main>
    <script>
      (() => {
        const tg = window.Telegram && window.Telegram.WebApp
        const main = document.getElementById("tma-entry")
        const status = document.getElementById("tma-status")
        if (!tg || !tg.initData) {
          status.textContent = main.dataset.outside
          return
        }
        tg.ready(); tg.expand()
        const csrf = document.querySelector("meta[name='csrf-token']").content
        fetch(main.dataset.signInPath, {
          method: "POST",
          headers: {"content-type": "application/json", "x-csrf-token": csrf},
          body: JSON.stringify({init_data: tg.initData, to: main.dataset.to})
        })
          .then(r => r.ok ? r.json() : Promise.reject(r))
          .then(res => { window.location.replace(res.to) })
          .catch(() => { status.textContent = main.dataset.failed })
      })()
    </script>
    """
  end

  @doc """
  A start screen of large tiles. Each tile is a map with `:id`, `:label`,
  `:path`; the inner block renders a tile's icon.

      <BasaTma.Components.tiles :let={tile} tiles={@tiles}>
        <.icon name={tile.icon} class="size-7" />
      </BasaTma.Components.tiles>
  """
  attr :tiles, :list, required: true
  attr :id, :string, default: "app-home"
  slot :inner_block

  def tiles(assigns) do
    ~H"""
    <nav id={@id} class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <.link
        :for={tile <- @tiles}
        navigate={tile.path}
        id={"tile-#{tile.id}"}
        class="tma-tile flex flex-col items-center justify-center gap-2 rounded-2xl border border-zinc-200 bg-white p-3 py-4 text-center text-sm font-medium shadow-sm transition dark:border-zinc-800 dark:bg-zinc-900"
      >
        <span class="tma-tile-icon flex size-12 items-center justify-center rounded-full bg-zinc-100 dark:bg-zinc-800">
          {render_slot(@inner_block, tile)}
        </span>
        {tile.label}
      </.link>
    </nav>
    """
  end
end
