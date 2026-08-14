CREATE TABLE ai_process_log (
    id SERIAL PRIMARY KEY,
    record_id VARCHAR(50) NOT NULL,
    supplier VARCHAR(255),
    material VARCHAR(255),
    quantity INTEGER,
    status VARCHAR(50),
    missing_fields JSONB,
    process_step VARCHAR(100),
    created_at TIMESTAMP,
    workflow_name VARCHAR(100),
    workflow_version VARCHAR(20)
);
