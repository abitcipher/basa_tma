// Inside the Telegram Mini App (telegram-web-app.js must be loaded):
// the page follows Telegram's theme and colours, Telegram's Back button
// goes back through the app's pages, vertical swipes don't close the app,
// and [data-haptic] elements give a light tap. Outside Telegram this does
// nothing.
//
//   import { startTelegram, TmaChatScroll } from "basa_tma"
//   startTelegram(liveSocket, { home: "/" })
export function startTelegram(liveSocket, opts = {}) {
  const home = opts.home || "/"
  const tg = window.Telegram && window.Telegram.WebApp
  if (!tg || !tg.initData) return

  const root = document.documentElement
  root.dataset.telegram = tg.platform || "1"

  const applyTheme = () => {
    root.setAttribute("data-theme", tg.colorScheme === "dark" ? "dark" : "light")
    root.setAttribute("data-theme-source", "telegram")
    const bg = tg.themeParams && tg.themeParams.bg_color
    if (bg) {
      tg.setHeaderColor && tg.setHeaderColor(bg)
      tg.setBackgroundColor && tg.setBackgroundColor(bg)
      tg.setBottomBarColor && tg.setBottomBarColor(bg)
    }
  }

  const updateBack = () => {
    if (!tg.BackButton) return
    window.location.pathname === home ? tg.BackButton.hide() : tg.BackButton.show()
  }

  tg.ready()
  tg.expand()
  tg.disableVerticalSwipes && tg.disableVerticalSwipes()
  applyTheme()
  updateBack()

  tg.onEvent("themeChanged", applyTheme)
  tg.BackButton && tg.BackButton.onClick(() => {
    if (window.history.length > 1) window.history.back()
    else liveSocket.js().navigate(home)
  })

  window.addEventListener("phx:page-loading-stop", updateBack)
  window.addEventListener("popstate", updateBack)

  document.addEventListener("click", (e) => {
    if (e.target.closest("[data-haptic]") && tg.HapticFeedback) tg.HapticFeedback.impactOccurred("light")
  })
}

// LiveView hook of the emulator's chat: keeps the newest message in view.
export const TmaChatScroll = {
  mounted() {
    this.scroll()
    this.handleEvent("chat:scroll", () => setTimeout(() => this.scroll(), 30))
  },
  updated() { this.scroll() },
  scroll() { this.el.scrollTop = this.el.scrollHeight }
}
