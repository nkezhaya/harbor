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
      onEnd: _ => {
        const nodes = this.el.querySelectorAll('[data-sortable_id]')
        const elements = [...nodes]
        const ids = elements.map(el => el.dataset.sortable_id)

        this.pushEventTo(this.el, "sortable:reposition", { ids })
      }
    })
  }
}

export { hooks }
