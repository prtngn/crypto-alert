import consumer from "channels/consumer"

consumer.subscriptions.create("BrowserNotificationsChannel", {
  connected() {
    console.log("🔔 Подключено к BrowserNotificationsChannel")
    this.requestNotificationPermission()
  },

  disconnected() {
    console.log("❌ Отключено от BrowserNotificationsChannel")
  },

  received(data) {
    console.log("📨 Получено браузерное уведомление:", data)

    if (data.type === "alert_triggered") {
      this.showNotification(data)
    }
  },

  requestNotificationPermission() {
    if (!("Notification" in window)) {
      console.log("⚠️ Браузер не поддерживает уведомления")
      return
    }

    if (Notification.permission === "default") {
      Notification.requestPermission().then(permission => {
        if (permission === "granted") {
          console.log("✅ Разрешение на уведомления получено")
        }
      })
    }
  },

  showNotification(data) {
    if (!("Notification" in window)) {
      console.log("⚠️ Браузер не поддерживает уведомления")
      return
    }

    if (Notification.permission !== "granted") {
      console.log("⚠️ Нет разрешения на уведомления")
      return
    }

    const direction = data.data.direction === "up" ? "↑" : "↓"
    const notification = new Notification(data.title || "🚨 Crypto Alert", {
      body: data.body || `${data.data.symbol} ${direction} $${data.data.price}`,
      icon: "/icon.png",
      badge: "/icon.png",
      tag: `alert-${data.data.alert_id}`,
      requireInteraction: true,
      data: data.data
    })

    notification.onclick = function () {
      window.focus()
      window.location.href = "/alerts"
      notification.close()
    }

    // Автоматически закрываем через 10 секунд
    setTimeout(() => notification.close(), 10000)
  }
});
