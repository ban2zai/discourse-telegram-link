# discourse-telegram-link

Discourse-плагин для привязки Telegram-аккаунта к аккаунту на форуме через HMAC-верифицированную deeplink.

## Как работает

1. Telegram-бот формирует ссылку:
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

В разделе `/admin/site_settings` выставить:

| Настройка | Описание |
|---|---|
| `telegram_link_enabled` | Включить плагин |
| `telegram_link_hmac_secret` | Секрет для проверки HMAC подписи (должен совпадать с секретом в боте) |
| `telegram_link_webhook_url` | URL n8n webhook |
| `telegram_link_webhook_token` | Bearer токен для авторизации на webhook |
