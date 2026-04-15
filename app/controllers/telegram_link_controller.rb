# frozen_string_literal: true

class TelegramLinkController < ApplicationController
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
      render :show, status: :bad_request and return
    end

    secret = SiteSetting.telegram_link_hmac_secret
    expected_sig = OpenSSL::HMAC.hexdigest("SHA256", secret, chat_id)

    unless Rack::Utils.secure_compare(expected_sig, sig)
      @error_message = "Неверная подпись ссылки"
      render :show, status: :forbidden and return
    end

    payload = {
      discourse_user_id: current_user.id,
      discourse_username: current_user.username,
      email: current_user.email,
      chat_id: chat_id.to_i
    }

    begin
      uri = URI.parse(SiteSetting.telegram_link_webhook_url)
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
        @error_message = "Ошибка отправки данных (webhook вернул #{response.code})"
        render :show, status: :bad_gateway and return
      end
    rescue => e
      Rails.logger.error("[discourse-telegram-link] Webhook exception: #{e.message}")
      @error_message = "Ошибка соединения с webhook: #{e.message}"
      render :show, status: :internal_server_error and return
    end

    @success = true
    render :show
  end
end
