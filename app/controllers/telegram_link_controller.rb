# frozen_string_literal: true

class TelegramLinkController < ApplicationController
  prepend_view_path File.expand_path("../../views", __FILE__)
  skip_before_action :check_xhr

  def show
    unless SiteSetting.telegram_link_enabled
      raise Discourse::NotFound
    end

    unless current_user
      redirect_to "/login?return_path=#{CGI.escape(request.fullpath)}"
      return
    end

    chat_id = params[:chat_id].to_s
    sig     = params[:sig].to_s

    if chat_id.blank? || sig.blank?
      @error_message = "Неверная ссылка: отсутствуют параметры"
      render :show, layout: false, status: :bad_request and return
    end

    unless chat_id.match?(/\A-?\d+\z/)
      @error_message = "Неверная ссылка: некорректный chat_id"
      render :show, layout: false, status: :bad_request and return
    end

    secret = SiteSetting.telegram_link_hmac_secret

    if secret.blank?
      Rails.logger.error("[discourse-telegram-link] HMAC secret is not configured")
      @error_message = "Плагин не настроен: обратитесь к администратору"
      render :show, layout: false, status: :service_unavailable and return
    end

    expected_sig = OpenSSL::HMAC.hexdigest("SHA256", secret, chat_id)

    unless Rack::Utils.secure_compare(expected_sig, sig)
      @error_message = "Неверная подпись ссылки"
      render :show, layout: false, status: :forbidden and return
    end

    payload = {
      discourse_user_id: current_user.id,
      discourse_username: current_user.username,
      email: current_user.email,
      chat_id: chat_id.to_i,
      linked_at: Time.now.utc.iso8601
    }

    begin
      uri = URI.parse(SiteSetting.telegram_link_webhook_url)

      unless uri.scheme.in?(%w[http https])
        Rails.logger.error("[discourse-telegram-link] Invalid webhook URL scheme: #{uri.scheme}")
        @error_message = "Не удалось завершить привязку. Обратитесь к администратору."
        render :show, layout: false, status: :internal_server_error and return
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 10

      req = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"] = "application/json"
      req["Authorization"] = "Bearer #{SiteSetting.telegram_link_webhook_token}"
      req.body = payload.to_json

      response = http.request(req)

      unless response.code.to_i.between?(200, 299)
        Rails.logger.error("[discourse-telegram-link] Webhook error: #{response.code} #{response.body}")
        @error_message = "Не удалось завершить привязку. Попробуйте позже или обратитесь к администратору."
        render :show, layout: false, status: :bad_gateway and return
      end
    rescue => e
      Rails.logger.error("[discourse-telegram-link] Webhook exception: #{e.message}")
      @error_message = "Не удалось завершить привязку. Попробуйте позже или обратитесь к администратору."
      render :show, layout: false, status: :internal_server_error and return
    end

    @username = current_user.username
    @logo_url = begin
      logo = SiteSetting.logo
      logo.present? ? logo.url : nil
    rescue
      nil
    end
    @success_button_label = SiteSetting.telegram_link_success_button_label
    @success_button_url   = SiteSetting.telegram_link_success_button_url

    @success = true
    render :show, layout: false
  end
end
