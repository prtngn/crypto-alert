import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener('input', (e) => {
      const cursorPosition = e.target.selectionStart
      e.target.value = e.target.value.toUpperCase()
      e.target.setSelectionRange(cursorPosition, cursorPosition)
    })
  }
}
