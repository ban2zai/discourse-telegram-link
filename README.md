# discourse-telegram-link

Discourse-плагин для привязки Telegram-аккаунта к аккаунту на форуме через одноразовый opaque token.

## Как работает

1. n8n вызывает notification-service endpoint `/telegram/link-token`.

2. notification-service создаёт одноразовый token и возвращает ссылку:
   ```
   https://forum.example.com/link-telegram?token=OPAQUE_ONE_TIME_TOKEN
   ```

3. Пользователь открывает ссылку на форуме. Если пользователь не авторизован, Discourse отправляет его на login и возвращает обратно после входа.

4. Плагин показывает страницу подтверждения и не делает привязку на GET-запросе.

5. После подтверждения плагин отправляет данные на notification-service endpoint `/telegram/account-link`, указанный в `telegram_link_webhook_url`:
   ```json
   {
     "token": "OPAQUE_ONE_TIME_TOKEN",
     "discourse_user_id": 123,
     "discourse_username": "username",
     "email": "user@example.com",
     "linked_at": "2026-05-22T00:00:00Z"
   }
   ```

6. Пользователь видит страницу с результатом привязки.

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
| `telegram_link_hmac_secret` | Больше не используется. Оставлен только для совместимости со старыми установками |
| `telegram_link_webhook_url` | URL notification-service endpoint `/telegram/account-link` |
| `telegram_link_webhook_token` | Bearer токен для авторизации в notification-service |
| `telegram_link_success_button_label` | Текст кнопки на странице успеха (по умолчанию: "Инструкция для уведомлений") |
| `telegram_link_success_button_url` | Ссылка для кнопки на странице успеха (если пусто — кнопка "На главную") |

## Важно про старую HMAC-схему

Параметры `chat_id` и `sig` больше не являются актуальным способом привязки. Плагин не проверяет HMAC, не принимает `chat_id` и не выполняет привязку на GET-запросе. Настройка `telegram_link_hmac_secret` больше не используется и оставлена только для совместимости.
