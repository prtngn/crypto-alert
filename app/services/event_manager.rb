require "singleton"

class EventManager
  include Singleton

  def initialize
    @running = false
    @thread = nil
  end

  def start
    @running = true
    Rails.logger.info "🚀 Запуск EventManager ..."

    @thread = Thread.new do
      EM.run do
        Rails.logger.info "✅ EventMachine запущен"
      end
    end
  end

  def stop
    return unless @running

    @running = false
    EM.stop if EM.reactor_running?
    @thread&.join(5)
    @thread = nil
    Rails.logger.info "🛑 EventManager остановлен"
  end
end
