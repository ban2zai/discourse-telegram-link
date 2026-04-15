# frozen_string_literal: true

# name: discourse-telegram-link
# about: Links Discourse accounts to Telegram via HMAC-verified deeplink
# version: 0.1.0
# authors: ban2zai

Discourse::Application.routes.prepend do
  get "/link-telegram" => "telegram_link#show"
end
