-- ============================================================================
-- Tender CRM Database Schema
-- ============================================================================
-- Полный скрипт инициализации базы данных с поддержкой RAG
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Расширения PostgreSQL
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;      -- Триграммный поиск (нечеткий поиск)
CREATE EXTENSION IF NOT EXISTS btree_gin;    -- GIN индексы
CREATE EXTENSION IF NOT EXISTS unaccent;     -- Удаление акцентов для поиска
CREATE EXTENSION IF NOT EXISTS vector;       -- pgvector для векторного поиска (RAG)

-- ============================================================================
-- 1. Пользователи системы
-- ============================================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(200),
    email VARCHAR(200),
    telegram_chat_id VARCHAR(100),
    
    notify_telegram BOOLEAN DEFAULT TRUE,
    notify_email BOOLEAN DEFAULT FALSE,
    notify_desktop BOOLEAN DEFAULT TRUE,
    
    role VARCHAR(50) DEFAULT 'USER',
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);

-- ============================================================================
-- 2. Тендеры
-- ============================================================================
CREATE TABLE tenders (
    id SERIAL PRIMARY KEY,
    
    notice_number VARCHAR(100) UNIQUE,
    lot_number VARCHAR(100),
    purchase_name TEXT NOT NULL,
    customer_name VARCHAR(500),
    etp_url TEXT,
    
    nmck NUMERIC(18, 2),
    currency VARCHAR(10) DEFAULT 'RUB',
    
    publication_date DATE,
    application_deadline TIMESTAMP,
    auction_date TIMESTAMP,
    contract_deadline DATE,
    
    status VARCHAR(50) DEFAULT 'NEW',
    result VARCHAR(50),
    
    responsible_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tenders_status ON tenders(status);
CREATE INDEX idx_tenders_notice_number ON tenders(notice_number);
CREATE INDEX idx_tenders_purchase_name_trgm ON tenders USING gin (purchase_name gin_trgm_ops);
CREATE INDEX idx_tenders_customer_name_trgm ON tenders USING gin (customer_name gin_trgm_ops);
CREATE INDEX idx_tenders_application_deadline ON tenders(application_deadline);

-- ============================================================================
-- 3. Письма
-- ============================================================================
CREATE TABLE emails (
    id SERIAL PRIMARY KEY,
    
    uid VARCHAR(100) UNIQUE NOT NULL,
    message_id VARCHAR(500),
    folder VARCHAR(100) DEFAULT 'INBOX',
    
    from_email VARCHAR(500),
    from_name VARCHAR(500),
    to_emails TEXT,
    
    subject TEXT,
    body_text TEXT,
    
    category VARCHAR(50) NOT NULL,
    summary TEXT,
    llm_model_used VARCHAR(100),
    
    tender_details JSONB,
    
    attachments_info JSONB,
    
    processing_status VARCHAR(50) DEFAULT 'NEW',
    is_important BOOLEAN DEFAULT FALSE,
    is_notified BOOLEAN DEFAULT FALSE,
    
    email_date TIMESTAMP,
    received_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    
    thread_id INTEGER
);

CREATE INDEX idx_emails_uid ON emails(uid);
CREATE INDEX idx_emails_category ON emails(category);
CREATE INDEX idx_emails_processing_status ON emails(processing_status);
CREATE INDEX idx_emails_email_date ON emails(email_date DESC);
CREATE INDEX idx_emails_subject_trgm ON emails USING gin (subject gin_trgm_ops);
CREATE INDEX idx_emails_from_email_trgm ON emails USING gin (from_email gin_trgm_ops);
CREATE INDEX idx_emails_tender_details ON emails USING gin (tender_details);

-- ============================================================================
-- 4. Вложения писем
-- ============================================================================
CREATE TABLE email_attachments (
    id SERIAL PRIMARY KEY,
    email_id INTEGER REFERENCES emails(id) ON DELETE CASCADE,
    
    filename VARCHAR(500),
    content_type VARCHAR(200),
    size_bytes INTEGER,
    file_path TEXT NOT NULL,
    extracted_text TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_email_attachments_email ON email_attachments(email_id);

-- ============================================================================
-- 5. Треды писем
-- ============================================================================
CREATE TABLE email_threads (
    id SERIAL PRIMARY KEY,
    tender_id INTEGER REFERENCES tenders(id) ON DELETE CASCADE,
    
    subject_template TEXT,
    participants TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_email_threads_tender ON email_threads(tender_id);

ALTER TABLE emails ADD CONSTRAINT fk_emails_thread
    FOREIGN KEY (thread_id) REFERENCES email_threads(id) ON DELETE SET NULL;

-- ============================================================================
-- 6. Связи писем с тендерами
-- ============================================================================
CREATE TABLE email_tender_links (
    id SERIAL PRIMARY KEY,
    email_id INTEGER REFERENCES emails(id) ON DELETE CASCADE,
    tender_id INTEGER REFERENCES tenders(id) ON DELETE CASCADE,
    
    link_type VARCHAR(50) NOT NULL,
    confidence NUMERIC(3, 2),
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(email_id, tender_id)
);

CREATE INDEX idx_email_tender_links_email ON email_tender_links(email_id);
CREATE INDEX idx_email_tender_links_tender ON email_tender_links(tender_id);

-- ============================================================================
-- 7. История изменений тендеров
-- ============================================================================
CREATE TABLE tender_history (
    id SERIAL PRIMARY KEY,
    tender_id INTEGER REFERENCES tenders(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    
    action VARCHAR(100) NOT NULL,
    field_name VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    comment TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tender_history_tender ON tender_history(tender_id);
CREATE INDEX idx_tender_history_created ON tender_history(created_at DESC);

-- ============================================================================
-- 8. Системные настройки
-- ============================================================================
CREATE TABLE system_settings (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT NOW(),
    updated_by INTEGER REFERENCES users(id)
);

-- ============================================================================
-- 9. Каналы уведомлений
-- ============================================================================
CREATE TABLE notification_channels (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    
    channel_type VARCHAR(50) NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    
    config JSONB NOT NULL,
    
    notify_on_new_email BOOLEAN DEFAULT TRUE,
    notify_on_deadline BOOLEAN DEFAULT TRUE,
    notify_on_status_change BOOLEAN DEFAULT TRUE,
    notify_on_manual_link BOOLEAN DEFAULT TRUE,
    deadline_days_before INTEGER DEFAULT 3,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notification_channels_user ON notification_channels(user_id);

-- ============================================================================
-- 10. Уведомления
-- ============================================================================
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    
    tender_id INTEGER REFERENCES tenders(id) ON DELETE SET NULL,
    email_id INTEGER REFERENCES emails(id) ON DELETE SET NULL,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    channel_id INTEGER REFERENCES notification_channels(id) ON DELETE SET NULL,
    
    notification_type VARCHAR(50) NOT NULL,
    priority VARCHAR(20) DEFAULT 'NORMAL',
    title VARCHAR(500),
    message TEXT,
    data JSONB,
    
    status VARCHAR(50) DEFAULT 'PENDING',
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- ============================================================================
-- 11. RAG: Документы тендеров
-- ============================================================================
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    tender_id INTEGER REFERENCES tenders(id) ON DELETE CASCADE,
    email_id INTEGER REFERENCES emails(id) ON DELETE SET NULL,
    
    doc_type VARCHAR(50) NOT NULL,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    source_path TEXT,
    
    metadata JSONB,
    
    is_indexed BOOLEAN DEFAULT FALSE,
    indexed_at TIMESTAMP,
    chunks_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_documents_tender ON documents(tender_id);
CREATE INDEX idx_documents_type ON documents(doc_type);
CREATE INDEX idx_documents_indexed ON documents(is_indexed);

-- ============================================================================
-- 12. RAG: Чанки документов с эмбеддингами
-- ============================================================================
CREATE TABLE document_chunks (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    tender_id INTEGER REFERENCES tenders(id) ON DELETE CASCADE,
    
    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1024),
    
    metadata JSONB,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_chunks_tender ON document_chunks(tender_id);
CREATE INDEX idx_chunks_document ON document_chunks(document_id);

CREATE INDEX idx_chunks_embedding ON document_chunks 
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================================================
-- 13. RAG: История запросов
-- ============================================================================
CREATE TABLE rag_queries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    tender_id INTEGER REFERENCES tenders(id) ON DELETE SET NULL,
    
    query TEXT NOT NULL,
    answer TEXT,
    sources_count INTEGER DEFAULT 0,
    sources JSONB,
    
    processing_time_ms INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_rag_queries_tender ON rag_queries(tender_id);
CREATE INDEX idx_rag_queries_date ON rag_queries(created_at DESC);

-- ============================================================================
-- ПРЕДСТАВЛЕНИЯ
-- ============================================================================

CREATE OR REPLACE VIEW v_active_tenders AS
SELECT 
    t.*,
    u.full_name AS responsible_name,
    COUNT(DISTINCT etl.email_id) AS linked_emails_count,
    COUNT(DISTINCT etl.email_id) FILTER (WHERE e.category = 'TENDER') AS tender_emails_count
FROM tenders t
LEFT JOIN users u ON t.responsible_user_id = u.id
LEFT JOIN email_tender_links etl ON t.id = etl.tender_id
LEFT JOIN emails e ON etl.email_id = e.id
WHERE t.status NOT IN ('ARCHIVED', 'CANCELLED')
GROUP BY t.id, u.full_name;

CREATE OR REPLACE VIEW v_unlinked_tender_emails AS
SELECT 
    e.*,
    COUNT(etl.id) AS links_count
FROM emails e
LEFT JOIN email_tender_links etl ON e.id = etl.email_id
WHERE e.category = 'TENDER' 
  AND e.processing_status = 'PROCESSED'
GROUP BY e.id
HAVING COUNT(etl.id) = 0;

-- ============================================================================
-- НАЧАЛЬНЫЕ ДАННЫЕ
-- ============================================================================

INSERT INTO users (username, full_name, email, role, is_active)
VALUES (
    'admin',
    'Администратор системы',
    'admin@tender-crm.local',
    'ADMIN',
    TRUE
);

INSERT INTO system_settings (key, value, description) VALUES
('imap_check_interval_minutes', '5', 'Интервал проверки почты в минутах'),
('llm_model_name', 'qwen2.5:7b', 'Модель LLM для анализа'),
('llm_api_url', 'http://localhost:11434/api/generate', 'URL API Ollama'),
('max_attachment_size_mb', '10', 'Максимальный размер вложения для обработки'),
('auto_link_confidence_threshold', '0.6', 'Порог уверенности для авто-связи'),
('deadline_warning_days', '3', 'За сколько дней предупреждать о дедлайне'),
('embedding_model_name', 'jeffh/intfloat-multilingual-e5-large-instruct:q8_0', 'Модель для создания эмбеддингов (RAG)'),
('embedding_dimensions', '1024', 'Размерность вектора эмбеддинга'),
('rag_chunk_size', '500', 'Размер чанка для RAG (в символах)'),
('rag_chunk_overlap', '50', 'Перекрытие между чанками (в символах)'),
('rag_top_k', '5', 'Количество релевантных чанков для RAG');

-- ============================================================================
-- ФУНКЦИИ И ТРИГГЕРЫ
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_tenders_updated_at BEFORE UPDATE ON tenders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_channels_updated_at BEFORE UPDATE ON notification_channels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();