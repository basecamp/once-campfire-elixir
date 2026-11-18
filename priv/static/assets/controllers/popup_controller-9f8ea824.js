import { Controller } from "@hotwired/stimulus"

const BOTTOM_THRESHOLD = 90

export default class extends Controller {
  static targets = [ "menu" ]
  static classes = [ "orientationTop" ]

  close() {
    this.element.open = false
  }

  toggle() {
    this.#orient()
  }

  closeOnClickOutside({ target }) {
    if (!this.element.contains(target)) this.close()
  }

  #orient() {
    this.element.classList.toggle(this.orientationTopClass, this.#distanceToBottom < BOTTOM_THRESHOLD)
    this.menuTarget.style.setProperty("--max-width", this.#maxWidth + "px")
  }

  get #distanceToBottom() {
    return window.innerHeight - this.#boundingClientRect.bottom
  }

  get #maxWidth() {
    return window.innerWidth - this.#boundingClientRect.left
  }

  get #boundingClientRect() {
    return this.menuTarget.getBoundingClientRect()
  }
}
