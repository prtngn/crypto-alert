import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status"]

  connect() {
    this.updateStatus()
  }

  requestPermission() {
    if (!("Notification" in window)) {
      alert("Ваш браузер не поддерживает уведомления")
      return
    }

    Notification.requestPermission().then(permission => {
      this.updateStatus()

      if (permission === "granted") {
        // Показываем тестовое уведомление
        new Notification("✅ Уведомления включены!", {
          body: "Теперь вы будете получать уведомления о срабатывании алертов",
          icon: "/icon.png"
        })
      }
    })
  }

  updateStatus() {
    if (!("Notification" in window)) {
      if (this.hasStatusTarget) {
        this.statusTarget.innerHTML = '<span class="text-gray-500">Не поддерживается</span>'
      }
      return
    }

    const permission = Notification.permission

    if (this.hasButtonTarget) {
      if (permission === "granted") {
        this.buttonTarget.classList.add("hidden")
      } else {
        this.buttonTarget.classList.remove("hidden")
      }
    }

    if (this.hasStatusTarget) {
      if (permission === "granted") {
        this.statusTarget.innerHTML = '<span class="text-green-600">✓ Включены</span>'
      } else if (permission === "denied") {
        this.statusTarget.innerHTML = '<span class="text-red-600">✗ Заблокированы</span>'
      } else {
        this.statusTarget.innerHTML = '<span class="text-yellow-600">⚠ Требуется разрешение</span>'
      }
    }
  }
}
