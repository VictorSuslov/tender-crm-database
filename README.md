# Tender CRM Database

Docker-контейнер с PostgreSQL 16 + pgvector для системы Tender CRM.

## 📦 Что внутри

- **PostgreSQL 16** с расширением **pgvector** для векторного поиска
- **pgAdmin 4** — веб-интерфейс для управления БД
- **13 таблиц** для хранения тендеров, писем, документов и RAG-данных
- **Векторные индексы** для семантического поиска (RAG)
- **Начальные данные** — администратор и системные настройки

## 🗂 Структура базы данных

### Основные таблицы

| Таблица | Описание |
|---------|----------|
| `users` | Пользователи системы |
| `tenders` | Тендеры (закупки) |
| `emails` | Обработанные письма |
| `email_attachments` | Вложения писем |
| `email_threads` | Треды писем |
| `email_tender_links` | Связи писем с тендерами |
| `tender_history` | История изменений тендеров |
| `system_settings` | Системные настройки |
| `notification_channels` | Каналы уведомлений |
| `notifications` | Уведомления |

### RAG-таблицы

| Таблица | Описание |
|---------|----------|
| `documents` | Документы тендеров (заявки, доп. соглашения) |
| `document_chunks` | Чанки документов с эмбеддингами (vector(1024)) |
| `rag_queries` | История RAG-запросов |

### Представления

- `v_active_tenders` — активные тендеры с количеством связанных писем
- `v_unlinked_tender_emails` — тендерные письма без связи с тендерами

## 🚀 Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/ВАШ_ЛОГИН/tender-crm-database.git
cd tender-crm-database

2. Настройка переменных окружения
cp .env.example .env
Отредактируйте .env и замените пароли на свои

POSTGRES_USER=tender_user
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=tender_crm
POSTGRES_PORT=5432

PGADMIN_DEFAULT_EMAIL=admin@tender-crm.local
PGADMIN_DEFAULT_PASSWORD=your_secure_password
PGADMIN_PORT=5050

⚠️ Важно: используйте надёжные пароли!

3. Запуск контейнеров
docker compose up -d