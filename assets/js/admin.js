import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks} from "./hooks"
import Uploaders from "./uploaders"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks,
  uploaders: Uploaders,
})

liveSocket.connect()
window.liveSocket = liveSocket

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()

    let keyDown

    window.addEventListener("keydown", event => keyDown = event.key)
    window.addEventListener("keyup", _event => keyDown = null)
    window.addEventListener("click", event => {
      if (keyDown === "c") {
        event.preventDefault()
        event.stopImmediatePropagation()
        reloader.openEditorAtCaller(event.target)
      } else if (keyDown === "d") {
        event.preventDefault()
        event.stopImmediatePropagation()
        reloader.openEditorAtDef(event.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
