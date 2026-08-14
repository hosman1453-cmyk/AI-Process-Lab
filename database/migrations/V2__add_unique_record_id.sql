ALTER TABLE ai_process_log
    ADD CONSTRAINT uq_ai_process_record_id UNIQUE (record_id);
