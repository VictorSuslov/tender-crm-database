-- ============================================================
-- Создание ivfflat индекса для эмбеддингов
-- 
-- ВАЖНО: Запускать только после добавления данных в document_chunks!
-- Требуется минимум ~1000 строк для корректной работы ivfflat.
-- 
-- Запуск:
--   docker exec -i tender_crm_db psql -U tender_user -d tender_crm < database/create_indexes.sql
-- ============================================================

-- Удаляем индекс, если он уже есть
DROP INDEX IF EXISTS public.idx_chunks_embedding;

-- Создаём ivfflat индекс для cosine distance
-- lists=100 — оптимально для 1000-10000 строк
CREATE INDEX idx_chunks_embedding 
    ON public.document_chunks 
    USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100);

-- Альтернатива: для L2 distance (евклидово расстояние)
-- CREATE INDEX idx_chunks_embedding_l2 
--     ON public.document_chunks 
--     USING ivfflat (embedding vector_l2_ops) 
--     WITH (lists = 100);