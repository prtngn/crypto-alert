class AlertsController < ApplicationController
  before_action :set_alert, only: %i[edit update destroy reset toggle_active]

  def index
    @alerts = Alert.includes(:notification_channels).order(created_at: :desc)
    @active_alerts = @alerts.active.count
    @triggered_alerts = @alerts.triggered.count
  end

  def new
    @alert = Alert.new
    @notification_channels = NotificationChannel.active
  end

  def create
    @alert = Alert.new(alert_params)

    if @alert.save
      if params[:alert][:notification_channel_ids].present?
        params[:alert][:notification_channel_ids].reject(&:blank?).each do |channel_id|
          @alert.alert_notification_channels.find_or_create_by(notification_channel_id: channel_id)
        end
      end

      redirect_to alerts_path, notice: "Алерт успешно создан."
    else
      @notification_channels = NotificationChannel.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @notification_channels = NotificationChannel.active
  end

  def update
    if @alert.update(alert_params)
      new_channel_ids = params[:alert][:notification_channel_ids]&.reject(&:blank?)&.map(&:to_i) || []
      current_channel_ids = @alert.notification_channel_ids
      channels_to_remove = current_channel_ids - new_channel_ids
      @alert.alert_notification_channels.where(notification_channel_id: channels_to_remove).destroy_all
      new_channel_ids.each do |channel_id|
        @alert.alert_notification_channels.find_or_create_by(notification_channel_id: channel_id)
      end

      redirect_to alerts_path, notice: "Алерт успешно обновлен."
    else
      @notification_channels = NotificationChannel.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @alert.destroy
    redirect_to alerts_path, notice: "Алерт удален."
  end

  def reset
    @alert.reset!
    redirect_to alerts_path, notice: "Алерт сброшен и активирован."
  end

  def toggle_active
    @alert.update(active: !@alert.active)
    redirect_to alerts_path, notice: "Статус алерта изменен."
  end

  private

  def set_alert
    @alert = Alert.find(params[:id])
  end

  def alert_params
    params.require(:alert).permit(:symbol, :threshold_price, :direction, :active, notification_channel_ids: [])
  end
end
