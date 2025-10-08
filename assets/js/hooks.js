import Sortable from "sortablejs"

const hooks = {}

hooks.Sortable = {
  mounted() {
    this.sorter = new Sortable(this.el, {
      animation: 150,
      handle: ".drag-handle",
      dragClass: "drag-item",
      ghostClass: "drag-ghost",
      forceFallback: true,
      onEnd: _ => this.onEnd()
    })
  },

  onEnd() {
    const nodes = this.el.querySelectorAll("[data-sortable_id]")
    const listId = this.el.dataset.list_id
    const eventName = this.el.dataset.push_event
    const elements = [...nodes]
    const ids = elements.map(el => el.dataset.sortable_id)

    if (eventName) {
      this.pushEventTo(this.el, eventName, { list_id: listId, ids })
    }
  }
}

export { hooks }
