import { Controller } from "@hotwired/stimulus"
import { throttle } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item" ]

  itemTargetConnected(target) {
    this.#throttledSort()
  }

  updateItem({ detail: { targetId }}) {
    const itemTargetForUpdate = this.itemTargets.find(itemTarget => itemTarget.id == targetId)

    if (itemTargetForUpdate) {
      if (itemTargetForUpdate.dataset.sortedListNumber) {
        itemTargetForUpdate.dataset.sortedListNumber = new Date().getTime()
      }

      this.sort()
    }
  }

  sort() {
    const sortedItemTargets = this.itemTargets.sort((a, b) => {
      if (a.dataset.sortedListNumber) {
        return b.dataset.sortedListNumber - a.dataset.sortedListNumber
      } else {
        return a.dataset.sortedListName.toLowerCase().localeCompare(b.dataset.sortedListName.toLowerCase())
      }
    })

    sortedItemTargets.forEach(item => this.element.appendChild(item))
  }

  #throttledSort = throttle(this.sort.bind(this))
}
