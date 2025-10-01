import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("🔔 Browser notifications controller connected")
    this.requestPermission()
  }

  requestPermission() {
    if (!("Notification" in window)) {
      console.log("Браузер не поддерживает Notifications API")
      return
    }

    if (Notification.permission === "granted") {
      console.log("✅ Разрешение на уведомления уже получено")
      return
    }

    if (Notification.permission !== "denied") {
      Notification.requestPermission().then(permission => {
        if (permission === "granted") {
          console.log("✅ Разрешение на уведомления получено")
          this.showTestNotification()
        }
      })
    }
  }

  showTestNotification() {
    new Notification("Crypto Alert", {
      body: "Браузерные уведомления включены!",
      icon: "/icon.png"
    })
  }
}
