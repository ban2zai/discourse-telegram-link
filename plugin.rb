# frozen_string_literal: true

# name: discourse-telegram-link
# about: Links Discourse accounts to Telegram via HMAC-verified deeplink
# version: 0.1.0
# authors: ban2zai

after_initialize do
  require File.expand_path("../app/controllers/telegram_link_controller", __FILE__)
end

Discourse::Application.routes.prepend do
  get "/link-telegram" => "telegram_link#show"
end
