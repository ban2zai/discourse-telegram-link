# frozen_string_literal: true

class TelegramLinkController < ApplicationController
  prepend_view_path File.expand_path("../../views", __FILE__)
  skip_before_action :check_xhr

  GENERIC_FAILURE_MESSAGE = "Не удалось завершить привязку. Попробуйте позже или обратитесь к администратору."

  def show
    ensure_enabled!
    redirect_to_login and return unless current_user

    token = token_param

    if token.blank?
      render_error("Неверная ссылка: отсутствует token", :bad_request)
      return
    end

    @confirmation = true
    @token = token
    @username = current_user.username
    @logo_url = logo_url

    render :show, layout: false
  end

  def confirm
    ensure_enabled!
    redirect_to_login and return unless current_user

    token = token_param

    if token.blank?
      render_error("Неверная ссылка: отсутствует token", :bad_request)
      return
    end

    begin
      response = post_account_link(token)
      status_code = response.code.to_i

      case status_code
      when 200..299
        render_success
      when 409
        log_webhook_error(status_code, response.body, token)
        render_error("Этот Telegram или аккаунт форума уже привязан к другой учётной записи.", :conflict)
      when 410
        log_webhook_error(status_code, response.body, token)
        render_error("Ссылка устарела. Откройте /settings в Telegram и попробуйте снова.", :gone)
      else
        log_webhook_error(status_code, response.body, token)
        render_error(GENERIC_FAILURE_MESSAGE, :bad_gateway)
      end
    rescue => e
      Rails.logger.error("[discourse-telegram-link] Webhook exception: #{e.class}: #{e.message}")
      render_error(GENERIC_FAILURE_MESSAGE, :internal_server_error)
    end
  end

  private

  def ensure_enabled!
    raise Discourse::NotFound unless SiteSetting.telegram_link_enabled
  end

  def redirect_to_login
    redirect_to "/login?return_path=#{CGI.escape(request.fullpath)}"
  end

  def token_param
    params[:token].to_s.strip
  end

  def post_account_link(token)
    uri = URI.parse(SiteSetting.telegram_link_webhook_url)

    unless uri.scheme.in?(%w[http https])
      raise URI::InvalidURIError, "Invalid webhook URL scheme: #{uri.scheme}"
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 10

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{SiteSetting.telegram_link_webhook_token}"
    req.body = {
      token: token,
      discourse_user_id: current_user.id,
      discourse_username: current_user.username,
      email: current_user.email,
      linked_at: Time.now.utc.iso8601
    }.to_json

    http.request(req)
  end

  def render_success
    @username = current_user.username
    @logo_url = logo_url
    @success_button_label = SiteSetting.telegram_link_success_button_label
    @success_button_url = SiteSetting.telegram_link_success_button_url

    @confirmation = false
    @success = true
    render :show, layout: false
  end

  def render_error(message, status)
    @logo_url = logo_url
    @confirmation = false
    @success = false
    @error_message = message
    render :show, layout: false, status: status
  end

  def logo_url
    logo = SiteSetting.logo
    logo.present? ? logo.url : nil
  rescue
    nil
  end

  def log_webhook_error(status_code, body, token)
    Rails.logger.error(
      "[discourse-telegram-link] Webhook error: status=#{status_code} body=#{safe_body_preview(body, token)}"
    )
  end

  def safe_body_preview(body, token)
    preview = body.to_s[0, 200]
    preview = preview.gsub(token, "[FILTERED_TOKEN]") if token.present?
    preview = preview.gsub(current_user.email.to_s, "[FILTERED_EMAIL]") if current_user&.email.present?
    preview.gsub(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i, "[FILTERED_EMAIL]")
  end
end
