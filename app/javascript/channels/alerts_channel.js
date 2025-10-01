import consumer from "channels/consumer"

consumer.subscriptions.create("AlertsChannel", {
  connected() {
    console.log("✅ Подключено к AlertsChannel")
    this.showNotification("info", "WebSocket подключен")
  },

  disconnected() {
    console.log("❌ Отключено от AlertsChannel")
  },

  received(data) {
    console.log("📨 Получено сообщение:", data)

    // Обновление алерта
    if (data.type === "price_update") {
      this.updateAlertPrice(data.alert_id, data.current_price, data.exchange)
      // Также обновляем общую цену для символа
      this.updatePrice(data.symbol, data.current_price, data.exchange)
    }

    // Срабатывание алерта
    if (data.type === "triggered") {
      this.handleAlertTriggered(data)
    }
  },

  formatPrice(price) {
    // Форматируем с 8 знаками после запятой, убирая незначащие нули
    return price.toFixed(8).replace(/\.?0+$/, '')
  },

  updatePrice(symbol, price, exchange) {
    // Обновляем цену в UI если есть элемент с data-symbol
    const priceElements = document.querySelectorAll(`[data-symbol="${symbol}"]`)
    priceElements.forEach(element => {
      const priceEl = element.querySelector('[data-price]')
      if (priceEl) {
        const exchangeBadge = exchange ? ` [${exchange.toUpperCase()}]` : ''
        priceEl.textContent = `$${this.formatPrice(price)}${exchangeBadge}`
        // Анимация изменения
        priceEl.classList.add('text-green-600')
        setTimeout(() => priceEl.classList.remove('text-green-600'), 500)
      }
    })
  },

  updateAlertPrice(alertId, price, exchange) {
    // Обновляем last_price для алерта
    const alertRow = document.querySelector(`[data-alert-id="${alertId}"]`)
    if (alertRow) {
      const lastPriceEl = alertRow.querySelector('[data-last-price]')
      if (lastPriceEl) {
        const exchangeBadge = exchange ? ` [${exchange.toUpperCase()}]` : ''
        lastPriceEl.textContent = `$${this.formatPrice(price)}${exchangeBadge}`
        // Анимация изменения
        lastPriceEl.classList.add('text-green-600')
        setTimeout(() => lastPriceEl.classList.remove('text-green-600'), 500)
      }
    }
  },

  handleAlertTriggered(data) {
    console.log("🔔 Алерт сработал!", data)

    // Показываем уведомление
    this.showNotification("alert", `Алерт ${data.symbol} сработал при цене $${this.formatPrice(data.current_price)}!`)

    // Перезагружаем страницу через 2 секунды чтобы показать обновленный статус
    setTimeout(() => {
      if (window.location.pathname === '/alerts' || window.location.pathname === '/') {
        window.location.reload()
      }
    }, 2000)
  },

  showNotification(type, message) {
    // Создаем уведомление в UI
    const notification = document.createElement('div')
    notification.className = `fixed bottom-4 right-4 p-4 rounded-lg shadow-lg z-50 ${type === 'alert' ? 'bg-red-500' : 'bg-blue-500'
      } text-white`
    notification.textContent = message

    document.body.appendChild(notification)

    // Удаляем через 5 секунд
    setTimeout(() => {
      notification.style.opacity = '0'
      notification.style.transition = 'opacity 0.5s'
      setTimeout(() => notification.remove(), 500)
    }, 5000)
  }
});
