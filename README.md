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
| `document_chunks` | Чанки документов с эмбеддингами (vector 1024) |
| `rag_queries` | История RAG-запросов |

### Представления

- `v_active_tenders` — активные тендеры с количеством связанных писем
- `v_unlinked_tender_emails` — тендерные письма без связи с тендерами

## 🚀 Быстрый старт

### 1. Клонирование репозитория

    git clone https://github.com/ВАШ_ЛОГИН/tender-crm-database.git
    cd tender-crm-database

### 2. Настройка переменных окружения

    cp .env.example .env

Отредактируйте `.env` и замените пароли на свои:

    POSTGRES_USER=tender_user
    POSTGRES_PASSWORD=your_secure_password
    POSTGRES_DB=tender_crm
    POSTGRES_PORT=5432

    PGADMIN_DEFAULT_EMAIL=admin@tender-crm.local
    PGADMIN_DEFAULT_PASSWORD=your_secure_password
    PGADMIN_PORT=5050

> ⚠️ **Важно**: используйте надёжные пароли!

### 3. Запуск контейнеров

    docker compose up -d

При первом запуске:
- Скачаются образы (~800 MB)
- Выполнится `init.sql` — создадутся все таблицы
- Создастся начальный пользователь `admin`

### 4. Проверка

    docker compose ps
    docker exec -it tender_crm_db psql -U tender_user -d tender_crm

В psql:

    \dt    -- список таблиц
    \dx    -- список расширений
    \q     -- выход

## 🌐 Доступ

### PostgreSQL

| Параметр | Значение |
|----------|----------|
| Хост | `localhost` |
| Порт | `5432` |
| Пользователь | из `.env` (POSTGRES_USER) |
| Пароль | из `.env` (POSTGRES_PASSWORD) |
| База данных | из `.env` (POSTGRES_DB) |

### pgAdmin

| Параметр | Значение |
|----------|----------|
| URL | `http://localhost:5050` |
| Email | из `.env` (PGADMIN_DEFAULT_EMAIL) |
| Пароль | из `.env` (PGADMIN_DEFAULT_PASSWORD) |

Для подключения к серверу в pgAdmin:
- Host: `postgres` (имя контейнера)
- Port: `5432`
- Username: из `.env` (POSTGRES_USER)
- Password: из `.env` (POSTGRES_PASSWORD)

## 📊 Полезные SQL-запросы

### Статистика по письмам

    SELECT category, COUNT(*) 
    FROM emails 
    GROUP BY category 
    ORDER BY COUNT(*) DESC;

### Тендеры с количеством писем

    SELECT t.id, t.purchase_name, COUNT(etl.email_id) as emails_count
    FROM tenders t
    LEFT JOIN email_tender_links etl ON t.id = etl.tender_id
    GROUP BY t.id, t.purchase_name
    ORDER BY emails_count DESC;

### Проверка RAG-данных

    SELECT 
        d.id, d.title, d.doc_type, 
        d.is_indexed, d.chunks_count
    FROM documents d
    ORDER BY d.created_at DESC;

### Поиск ближайших чанков (RAG)

    SELECT 
        dc.content,
        d.title,
        1 - (dc.embedding <=> '[0.1, 0.2, ...]') as similarity
    FROM document_chunks dc
    JOIN documents d ON dc.document_id = d.id
    ORDER BY dc.embedding <=> '[0.1, 0.2, ...]'
    LIMIT 5;

## 🔧 Управление контейнерами

### Остановка

    docker compose down

### Перезапуск

    docker compose restart

### Полное удаление (с данными!)

    docker compose down -v

> ⚠️ **Внимание**: это удалит все данные!

### Пересоздание БД с нуля

    docker compose down
    docker volume rm tender-crm-database_postgres_data
    docker compose up -d

### Просмотр логов

    docker logs tender_crm_db
    docker logs tender_crm_pgadmin

### Подключение к psql

    docker exec -it tender_crm_db psql -U tender_user -d tender_crm

### Бэкап базы данных

    docker exec tender_crm_db pg_dump -U tender_user tender_crm > backup.sql

### Восстановление из бэкапа

    cat backup.sql | docker exec -i tender_crm_db psql -U tender_user -d tender_crm

## 🛠 Технологии

| Компонент | Версия |
|-----------|--------|
| PostgreSQL | 16 |
| pgvector | 0.8.3 |
| pgAdmin | latest |
| Docker Compose | 3.8+ |

## 📁 Структура проекта

    tender-crm-database/
    ├── docker-compose.yml    # Конфигурация контейнеров
    ├── init.sql              # Схема БД (13 таблиц, индексы, триггеры)
    ├── .env.example          # Шаблон переменных окружения
    ├── .env                  # Реальные значения (в .gitignore)
    ├── .gitignore            # Правила исключения файлов
    └── README.md             # Этот файл

## 🔗 Связанные проекты

- [Backend](https://github.com/ВАШ_ЛОГИН/tender-crm-backend) — FastAPI + LLM + RAG
- [Desktop](https://github.com/ВАШ_ЛОГИН/tender-crm-desktop) — Qt 6 / C++ клиент

## 📄 Лицензия

MIT