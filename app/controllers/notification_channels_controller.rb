class NotificationChannelsController < ApplicationController
  before_action :set_channel, only: %i[edit update destroy toggle_active test]

  def index
    @channels = NotificationChannel.order(created_at: :desc)
  end

  def new
    @channel = NotificationChannel.new
  end

  def create
    @channel = NotificationChannel.new(channel_params)

    if @channel.save
      redirect_to notification_channels_path, notice: "Канал уведомлений успешно создан."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @channel.update(channel_params)
      redirect_to notification_channels_path, notice: "Канал уведомлений успешно обновлен."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @channel.destroy
    redirect_to notification_channels_path, notice: "Канал уведомлений удален."
  end

  def toggle_active
    @channel.update(active: !@channel.active)
    redirect_to notification_channels_path, notice: "Статус канала изменен."
  end

  def test
    begin
      test_alert = Alert.new(
        symbol: "BTCUSDT",
        threshold_price: 50000,
        direction: "up",
        triggered_at: Time.current
      )

      @channel.send_notification(test_alert, 50001)
      redirect_to notification_channels_path, notice: "Тестовое уведомление отправлено."
    rescue => e
      redirect_to notification_channels_path, alert: "Ошибка отправки: #{e.message}"
    end
  end

  private

  def set_channel
    @channel = NotificationChannel.find(params[:id])
  end

  def channel_params
    params.require(:notification_channel).permit(:name, :channel_type, :active, config: {})
  end
end
