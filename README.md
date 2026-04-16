# discourse-telegram-link

Discourse-плагин для привязки Telegram-аккаунта к аккаунту на форуме через HMAC-верифицированную deeplink.

## Как работает

1. Telegram-бот генерирует ссылку:
   ```
   https://forum.example.com/link-telegram?chat_id=641388037&sig=HMAC_ПОДПИСЬ
   ```
   где `sig` = `HMAC-SHA256(chat_id, telegram_link_hmac_secret)`

2. Пользователь открывает ссылку в браузере (должен быть авторизован на форуме)

3. Плагин валидирует подпись и отправляет данные на n8n webhook:
   ```json
   {
     "discourse_user_id": 123,
     "discourse_username": "username",
     "email": "user@example.com",
     "chat_id": 641388037
   }
   ```

4. Пользователь видит страницу с результатом привязки.

## Установка

Добавить в `app.yml` в секцию `hooks.web.run`:

```yaml
- exec:
    cd: $home/plugins
    cmd:
      - git clone https://github.com/ban2zai/discourse-telegram-link.git
```

Затем пересобрать контейнер:

```bash
./launcher rebuild app
```

## Настройки

В разделе `/admin/site_settings` → плагин **Telegram link**:

| Настройка | Описание |
|---|---|
| `telegram_link_enabled` | Включить плагин (по умолчанию выключен) |
| `telegram_link_hmac_secret` | Секрет для проверки HMAC подписи — должен совпадать с секретом в боте |
| `telegram_link_webhook_url` | URL n8n webhook |
| `telegram_link_webhook_token` | Bearer токен для авторизации на webhook |
| `telegram_link_success_button_label` | Текст кнопки на странице успеха (по умолчанию: "Инструкция для уведомлений") |
| `telegram_link_success_button_url` | Ссылка для кнопки на странице успеха (если пусто — кнопка "На главную") |

## Генерация подписи (для бота)

```python
import hmac, hashlib
sig = hmac.new(SECRET.encode(), str(chat_id).encode(), hashlib.sha256).hexdigest()
```

```ruby
sig = OpenSSL::HMAC.hexdigest("SHA256", SECRET, chat_id.to_s)
```
