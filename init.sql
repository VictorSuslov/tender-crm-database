-- ============================================================
-- Tender CRM Database Schema
-- Версия: 1.0
-- Дата: 2026-07-07
-- 
-- Автоматически применяется при первом запуске контейнера БД
-- ============================================================

-- ============================================================
-- 1. РАСШИРЕНИЯ
-- ============================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ============================================================
-- 2. ФУНКЦИИ
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ============================================================
-- 3. ТАБЛИЦЫ (в порядке, учитывающем внешние ключи)
-- ============================================================

-- Пользователи (базовая таблица)
CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(100) NOT NULL,
    full_name character varying(200),
    email character varying(200),
    telegram_chat_id character varying(100),
    notify_telegram boolean DEFAULT true,
    notify_email boolean DEFAULT false,
    notify_desktop boolean DEFAULT true,
    role character varying(50) DEFAULT 'USER',
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    last_login timestamp without time zone
);

-- Тендеры
CREATE TABLE public.tenders (
    id integer NOT NULL,
    notice_number character varying(100),
    lot_number character varying(100),
    purchase_name text NOT NULL,
    customer_name character varying(500),
    etp_url text,
    nmck numeric(18,2),
    currency character varying(10) DEFAULT 'RUB',
    publication_date date,
    application_deadline timestamp without time zone,
    auction_date timestamp without time zone,
    contract_deadline date,
    status character varying(50) DEFAULT 'NEW',
    result character varying(50),
    responsible_user_id integer,
    created_by integer,
    notes text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);

-- Письма
CREATE TABLE public.emails (
    id integer NOT NULL,
    uid character varying(100) NOT NULL,
    message_id character varying(500),
    folder character varying(100) DEFAULT 'INBOX',
    from_email character varying(500),
    from_name character varying(500),
    to_emails text,
    subject text,
    body_text text,
    category character varying(50) NOT NULL,
    summary text,
    llm_model_used character varying(100),
    tender_details jsonb,
    attachments_info jsonb,
    processing_status character varying(50) DEFAULT 'NEW',
    is_important boolean DEFAULT false,
    is_notified boolean DEFAULT false,
    email_date timestamp without time zone,
    received_at timestamp without time zone DEFAULT now(),
    processed_at timestamp without time zone,
    thread_id integer,
    body_html text
);

-- Треды писем
CREATE TABLE public.email_threads (
    id integer NOT NULL,
    tender_id integer,
    subject_template text,
    participants text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);

-- Связи писем и тендеров
CREATE TABLE public.email_tender_links (
    id integer NOT NULL,
    email_id integer,
    tender_id integer,
    link_type character varying(50) NOT NULL,
    confidence numeric(3,2),
    created_at timestamp without time zone DEFAULT now()
);

-- Вложения писем
CREATE TABLE public.email_attachments (
    id integer NOT NULL,
    email_id integer,
    filename character varying(500),
    content_type character varying(200),
    size_bytes integer,
    file_path text NOT NULL,
    extracted_text text,
    created_at timestamp without time zone DEFAULT now()
);

-- Документы тендеров
CREATE TABLE public.documents (
    id integer NOT NULL,
    tender_id integer,
    email_id integer,
    doc_type character varying(50) NOT NULL,
    title character varying(500) NOT NULL,
    content text NOT NULL,
    source_path text,
    metadata jsonb,
    is_indexed boolean DEFAULT false,
    indexed_at timestamp without time zone,
    chunks_count integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);

-- Чанки документов (для RAG)
CREATE TABLE public.document_chunks (
    id integer NOT NULL,
    document_id integer,
    tender_id integer,
    chunk_index integer NOT NULL,
    content text NOT NULL,
    embedding public.vector(1024),
    metadata jsonb,
    created_at timestamp without time zone DEFAULT now()
);

-- Настройки системы
CREATE TABLE public.system_settings (
    key character varying(100) NOT NULL,
    value text NOT NULL,
    description text,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by integer
);

-- Каналы уведомлений
CREATE TABLE public.notification_channels (
    id integer NOT NULL,
    user_id integer,
    channel_type character varying(50) NOT NULL,
    is_enabled boolean DEFAULT true,
    config jsonb NOT NULL,
    notify_on_new_email boolean DEFAULT true,
    notify_on_deadline boolean DEFAULT true,
    notify_on_status_change boolean DEFAULT true,
    notify_on_manual_link boolean DEFAULT true,
    deadline_days_before integer DEFAULT 3,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);

-- Уведомления
CREATE TABLE public.notifications (
    id integer NOT NULL,
    tender_id integer,
    email_id integer,
    user_id integer,
    channel_id integer,
    notification_type character varying(50) NOT NULL,
    priority character varying(20) DEFAULT 'NORMAL',
    title character varying(500),
    message text,
    data jsonb,
    status character varying(50) DEFAULT 'PENDING',
    sent_at timestamp without time zone,
    delivered_at timestamp without time zone,
    read_at timestamp without time zone,
    error_message text,
    created_at timestamp without time zone DEFAULT now()
);

-- История запросов RAG
CREATE TABLE public.rag_queries (
    id integer NOT NULL,
    user_id integer,
    tender_id integer,
    query text NOT NULL,
    answer text,
    sources_count integer DEFAULT 0,
    sources jsonb,
    processing_time_ms integer,
    created_at timestamp without time zone DEFAULT now()
);

-- История изменений тендеров
CREATE TABLE public.tender_history (
    id integer NOT NULL,
    tender_id integer,
    user_id integer,
    action character varying(100) NOT NULL,
    field_name character varying(100),
    old_value text,
    new_value text,
    comment text,
    created_at timestamp without time zone DEFAULT now()
);

-- ============================================================
-- 4. SEQUENCES (автоинкремент)
-- ============================================================

CREATE SEQUENCE public.users_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;

CREATE SEQUENCE public.tenders_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.tenders_id_seq OWNED BY public.tenders.id;

CREATE SEQUENCE public.emails_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.emails_id_seq OWNED BY public.emails.id;

CREATE SEQUENCE public.email_threads_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.email_threads_id_seq OWNED BY public.email_threads.id;

CREATE SEQUENCE public.email_tender_links_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.email_tender_links_id_seq OWNED BY public.email_tender_links.id;

CREATE SEQUENCE public.email_attachments_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.email_attachments_id_seq OWNED BY public.email_attachments.id;

CREATE SEQUENCE public.documents_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;

CREATE SEQUENCE public.document_chunks_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.document_chunks_id_seq OWNED BY public.document_chunks.id;

CREATE SEQUENCE public.notification_channels_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.notification_channels_id_seq OWNED BY public.notification_channels.id;

CREATE SEQUENCE public.notifications_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;

CREATE SEQUENCE public.rag_queries_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.rag_queries_id_seq OWNED BY public.rag_queries.id;

CREATE SEQUENCE public.tender_history_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.tender_history_id_seq OWNED BY public.tender_history.id;

-- ============================================================
-- 5. DEFAULT VALUES (привязка sequences к колонкам)
-- ============================================================

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq');
ALTER TABLE ONLY public.tenders ALTER COLUMN id SET DEFAULT nextval('public.tenders_id_seq');
ALTER TABLE ONLY public.emails ALTER COLUMN id SET DEFAULT nextval('public.emails_id_seq');
ALTER TABLE ONLY public.email_threads ALTER COLUMN id SET DEFAULT nextval('public.email_threads_id_seq');
ALTER TABLE ONLY public.email_tender_links ALTER COLUMN id SET DEFAULT nextval('public.email_tender_links_id_seq');
ALTER TABLE ONLY public.email_attachments ALTER COLUMN id SET DEFAULT nextval('public.email_attachments_id_seq');
ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq');
ALTER TABLE ONLY public.document_chunks ALTER COLUMN id SET DEFAULT nextval('public.document_chunks_id_seq');
ALTER TABLE ONLY public.notification_channels ALTER COLUMN id SET DEFAULT nextval('public.notification_channels_id_seq');
ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq');
ALTER TABLE ONLY public.rag_queries ALTER COLUMN id SET DEFAULT nextval('public.rag_queries_id_seq');
ALTER TABLE ONLY public.tender_history ALTER COLUMN id SET DEFAULT nextval('public.tender_history_id_seq');

-- ============================================================
-- 6. PRIMARY KEYS и UNIQUE CONSTRAINTS
-- ============================================================

ALTER TABLE ONLY public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.users ADD CONSTRAINT users_username_key UNIQUE (username);

ALTER TABLE ONLY public.tenders ADD CONSTRAINT tenders_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.tenders ADD CONSTRAINT tenders_notice_number_key UNIQUE (notice_number);

ALTER TABLE ONLY public.emails ADD CONSTRAINT emails_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.emails ADD CONSTRAINT emails_uid_key UNIQUE (uid);

ALTER TABLE ONLY public.email_threads ADD CONSTRAINT email_threads_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.email_tender_links ADD CONSTRAINT email_tender_links_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.email_tender_links ADD CONSTRAINT email_tender_links_email_id_tender_id_key UNIQUE (email_id, tender_id);
ALTER TABLE ONLY public.email_attachments ADD CONSTRAINT email_attachments_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.documents ADD CONSTRAINT documents_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.document_chunks ADD CONSTRAINT document_chunks_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.system_settings ADD CONSTRAINT system_settings_pkey PRIMARY KEY (key);

ALTER TABLE ONLY public.notification_channels ADD CONSTRAINT notification_channels_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.rag_queries ADD CONSTRAINT rag_queries_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.tender_history ADD CONSTRAINT tender_history_pkey PRIMARY KEY (id);

-- ============================================================
-- 7. ИНДЕКСЫ (кроме ivfflat — он создаётся отдельно)
-- ============================================================

-- Тендеры
CREATE INDEX idx_tenders_notice_number ON public.tenders USING btree (notice_number);
CREATE INDEX idx_tenders_status ON public.tenders USING btree (status);
CREATE INDEX idx_tenders_application_deadline ON public.tenders USING btree (application_deadline);
CREATE INDEX idx_tenders_customer_name_trgm ON public.tenders USING gin (customer_name public.gin_trgm_ops);
CREATE INDEX idx_tenders_purchase_name_trgm ON public.tenders USING gin (purchase_name public.gin_trgm_ops);

-- Письма
CREATE INDEX idx_emails_uid ON public.emails USING btree (uid);
CREATE INDEX idx_emails_category ON public.emails USING btree (category);
CREATE INDEX idx_emails_email_date ON public.emails USING btree (email_date DESC);
CREATE INDEX idx_emails_processing_status ON public.emails USING btree (processing_status);
CREATE INDEX idx_emails_from_email_trgm ON public.emails USING gin (from_email public.gin_trgm_ops);
CREATE INDEX idx_emails_subject_trgm ON public.emails USING gin (subject public.gin_trgm_ops);
CREATE INDEX idx_emails_tender_details ON public.emails USING gin (tender_details);

-- Связи писем и тендеров
CREATE INDEX idx_email_tender_links_email ON public.email_tender_links USING btree (email_id);
CREATE INDEX idx_email_tender_links_tender ON public.email_tender_links USING btree (tender_id);

-- Треды писем
CREATE INDEX idx_email_threads_tender ON public.email_threads USING btree (tender_id);

-- Вложения писем
CREATE INDEX idx_email_attachments_email ON public.email_attachments USING btree (email_id);

-- Документы
CREATE INDEX idx_documents_tender ON public.documents USING btree (tender_id);
CREATE INDEX idx_documents_type ON public.documents USING btree (doc_type);
CREATE INDEX idx_documents_indexed ON public.documents USING btree (is_indexed);

-- Чанки документов (btree индексы)
CREATE INDEX idx_chunks_document ON public.document_chunks USING btree (document_id);
CREATE INDEX idx_chunks_tender ON public.document_chunks USING btree (tender_id);

-- Уведомления
CREATE INDEX idx_notification_channels_user ON public.notification_channels USING btree (user_id);
CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id);
CREATE INDEX idx_notifications_status ON public.notifications USING btree (status);
CREATE INDEX idx_notifications_created ON public.notifications USING btree (created_at);

-- RAG запросы
CREATE INDEX idx_rag_queries_tender ON public.rag_queries USING btree (tender_id);
CREATE INDEX idx_rag_queries_date ON public.rag_queries USING btree (created_at);

-- История тендеров
CREATE INDEX idx_tender_history_tender ON public.tender_history USING btree (tender_id);
CREATE INDEX idx_tender_history_created ON public.tender_history USING btree (created_at);

-- Пользователи
CREATE INDEX idx_users_username ON public.users USING btree (username);
CREATE INDEX idx_users_role ON public.users USING btree (role);

-- ============================================================
-- 8. VIEWS (представления)
-- ============================================================

-- Активные тендеры
CREATE OR REPLACE VIEW public.v_active_tenders AS
 SELECT t.id,
    t.notice_number,
    t.lot_number,
    t.purchase_name,
    t.customer_name,
    t.etp_url,
    t.nmck,
    t.currency,
    t.publication_date,
    t.application_deadline,
    t.auction_date,
    t.contract_deadline,
    t.status,
    t.result,
    t.responsible_user_id,
    t.created_by,
    t.notes,
    t.created_at,
    t.updated_at,
    u.full_name AS responsible_name,
    count(DISTINCT etl.email_id) AS linked_emails_count,
    count(DISTINCT etl.email_id) FILTER (WHERE ((e.category)::text = 'TENDER'::text)) AS tender_emails_count
   FROM (((public.tenders t
     LEFT JOIN public.users u ON ((t.responsible_user_id = u.id)))
     LEFT JOIN public.email_tender_links etl ON ((t.id = etl.tender_id)))
     LEFT JOIN public.emails e ON ((etl.email_id = e.id)))
  WHERE ((t.status)::text <> ALL ((ARRAY['ARCHIVED'::character varying, 'CANCELLED'::character varying])::text[]))
  GROUP BY t.id, u.full_name;

-- Непривязанные тендерные письма
CREATE OR REPLACE VIEW public.v_unlinked_tender_emails AS
 SELECT e.id,
    e.uid,
    e.message_id,
    e.folder,
    e.from_email,
    e.from_name,
    e.to_emails,
    e.subject,
    e.body_text,
    e.category,
    e.summary,
    e.llm_model_used,
    e.tender_details,
    e.attachments_info,
    e.processing_status,
    e.is_important,
    e.is_notified,
    e.email_date,
    e.received_at,
    e.processed_at,
    e.thread_id,
    count(etl.id) AS links_count
   FROM (public.emails e
     LEFT JOIN public.email_tender_links etl ON ((e.id = etl.email_id)))
  WHERE (((e.category)::text = 'TENDER'::text) AND ((e.processing_status)::text = 'PROCESSED'::text))
  GROUP BY e.id
 HAVING (count(etl.id) = 0);

-- ============================================================
-- 9. TRIGGERS (автоматическое обновление updated_at)
-- ============================================================

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_tenders_updated_at BEFORE UPDATE ON public.tenders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_notification_channels_updated_at BEFORE UPDATE ON public.notification_channels FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- 10. FOREIGN KEYS (внешние ключи)
-- ============================================================

-- Тендеры
ALTER TABLE ONLY public.tenders ADD CONSTRAINT tenders_responsible_user_id_fkey FOREIGN KEY (responsible_user_id) REFERENCES public.users(id);
ALTER TABLE ONLY public.tenders ADD CONSTRAINT tenders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);

-- Письма
ALTER TABLE ONLY public.emails ADD CONSTRAINT fk_emails_thread FOREIGN KEY (thread_id) REFERENCES public.email_threads(id);

-- Треды писем
ALTER TABLE ONLY public.email_threads ADD CONSTRAINT email_threads_tender_id_fkey FOREIGN KEY (tender_id) REFERENCES public.tenders(id);

-- Связи писем и тендеров
ALTER TABLE ONLY public.email_tender_links ADD CONSTRAINT email_tender_links_email_id_fkey FOREIGN KEY (email_id) REFERENCES public.emails(id);
ALTER TABLE ONLY public.email_tender_links ADD CONSTRAINT email_tender_links_tender_id_fkey FOREIGN KEY (tender_id) REFERENCES public.tenders(id);

-- Вложения писем
ALTER TABLE ONLY public.email_attachments ADD CONSTRAINT email_attachments_email_id_fkey FOREIGN KEY (email_id) REFERENCES public.emails(id);

-- Документы
ALTER TABLE ONLY public.documents ADD CONSTRAINT documents_tender_id_fkey FOREIGN KEY (tender_id) REFERENCES public.tenders(id);
ALTER TABLE ONLY public.documents ADD CONSTRAINT documents_email_id_fkey FOREIGN KEY (email_id) REFERENCES public.emails(id);

-- Чанки документов
ALTER TABLE ONLY public.document_chunks ADD CONSTRAINT document_chunks_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);
ALTER TABLE ONLY public.document_chunks ADD CONSTRAINT document_chunks_tender_id_fkey FOREIGN KEY (tender_id) REFERENCES public.tenders(id);

-- Настройки
ALTER TABLE ONLY public.system_settings ADD CONSTRAINT system_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);

-- Уведомления
ALTER TABLE ONLY public.notification_channels ADD CONSTRAINT notification_channels_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_tender_id_fkey FOREIGN KEY (tender_id) REFERENCES public.tenders(id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_email_id_fkey FOREIGN KEY (email_id) REFERENCES public.emails(id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.notification_channels(id);

-- RAG запросы
ALTER TABLE ONLY public.rag_queries ADD CONSTRAINT rag_queries_tender_id_fkey FOREIGN KEY (tender_id) REFERENCES public.tenders(id);
ALTER TABLE ONLY public.rag_queries ADD CONSTRAINT rag_queries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);

-- История тендеров
ALTER TABLE ONLY public.tender_history ADD CONSTRAINT tender_history_tender_id_fkey FOREIGN KEY (tender_id) REFERENCES public.tenders(id);
ALTER TABLE ONLY public.tender_history ADD CONSTRAINT tender_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);

-- ============================================================
-- 11. НАЧАЛЬНЫЕ ДАННЫЕ
-- ============================================================

-- Настройки по умолчанию (необходимы для работы приложения)
INSERT INTO public.system_settings (key, value, description) VALUES
    ('imap_check_interval_minutes', '5', 'Интервал проверки IMAP в минутах')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- КОНЕЦ СХЕМЫ
-- ============================================================