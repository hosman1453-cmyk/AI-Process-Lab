# AI Process Lab

## Project Overview

AI Process Lab is an AI-supported business process automation laboratory built with n8n, local LLMs, Docker and PostgreSQL.

The repository demonstrates a working workflow pattern for analyzing operational records, converting AI output into structured JSON, applying business decision logic, routing records for follow-up, and writing an auditable process log to PostgreSQL.

## Business Problem

Warehouse receiving teams often work with incomplete or inconsistent records. A receiving record may be missing supplier, material or quantity information, which creates manual review work before the record can move forward in the process.

This project uses a warehouse receiving scenario to show how an AI-assisted workflow can:

- inspect incoming record data
- detect missing required fields
- classify the record as ready or requiring review
- preserve the decision in a database audit log

The current input is simulated warehouse receiving test data inside the n8n workflow. It is not yet connected to CSV, PDF, email, API or ERP sources.

## What Is Implemented

- n8n workflow export
- local Ollama-based AI analysis
- structured JSON output parsing
- normalized workflow fields
- business decision logic
- manual review / ready-for-processing routing
- metadata generation
- PostgreSQL audit logging
- reproducible SQL migrations
- Dockerized n8n and PostgreSQL services
- environment-based secret management with `.env` and `.env.example`

## Architecture

```text
Simulated Input
      |
      v
AI Analysis (Ollama)
      |
      v
Structured Output
      |
      v
Normalize
      |
      v
Business Decision
   /       \
Review     Ready
   \       /
      v
Metadata
      |
      v
PostgreSQL Audit Log
```

## Workflow 01 - AI Document Analyzer

The workflow export is stored at:

```text
workflows/01 - AI Document Analyzer.json
```

Despite the workflow name, the current demo scenario analyzes a simulated warehouse receiving record. The workflow contains these main steps:

- `Manual Trigger`: starts the workflow manually from n8n.
- `Test Data Simulator`: provides sample warehouse receiving data.
- `AI Agent`: analyzes supplier, material and quantity information.
- `Ollama Chat Model`: provides the local LLM used by the AI Agent.
- `Structured Output Parser`: enforces the expected JSON fields.
- `Normalize Output node`: converts AI output into flat workflow fields.
- `If`: checks whether manual review is required.
- `Review Queue`: marks incomplete records for manual review.
- `Ready For Processing`: marks complete records as ready.
- `Merge`: brings both routing paths back together.
- `Generate Record Metadata`: adds record and workflow metadata.
- `Execute a SQL query`: writes the audit record to PostgreSQL.

## Decision Logic

The workflow expects the AI output to include a `status` field:

- `OK`: all required fields are present.
- `REVIEW_REQUIRED`: at least one required field is missing.

Required fields in the current scenario:

- `supplier`
- `material`
- `quantity`

If any required field is missing, the workflow routes the record to manual review and stores the missing field names in `missing_fields`.

## PostgreSQL Audit Logging

The workflow writes process results into the `ai_process_log` table.

Main audit fields:

- `record_id`
- `supplier`
- `material`
- `quantity`
- `status`
- `missing_fields`
- `process_step`
- `created_at`
- `workflow_name`
- `workflow_version`

The database structure is defined by these migration files:

```text
database/migrations/V1__create_ai_process_log.sql
database/migrations/V2__add_unique_record_id.sql
```

`V1` creates the `ai_process_log` table. `V2` adds a unique constraint for `record_id`.

## Local AI with Ollama

The workflow uses a local Ollama chat model for AI analysis. This keeps the demo suitable for local experimentation and avoids requiring an external AI API for the workflow logic.

Benefits of this approach:

- local AI experimentation
- no external AI API requirement for the current workflow
- improved data privacy for local test runs

Ollama is not included in `docker-compose.yml`. It must be installed and running separately, and the Ollama credential must be configured inside n8n.

## Security & Privacy

The repository uses environment-based configuration for local secrets:

- Real secrets belong in `.env`.
- `.env` is ignored by Git.
- `.env.example` is tracked as a public configuration template.
- PostgreSQL host port `5432` is intentionally not exposed.
- n8n communicates with PostgreSQL through the Docker internal network at `postgres:5432`.
- The workflow export contains n8n credential references, not actual credential secret values.

## Quick Start

1. Clone the repository.

2. Copy the public environment template to a local `.env` file.

   Windows PowerShell:

   ```powershell
   Copy-Item .env.example .env
   ```

   macOS/Linux:

   ```bash
   cp .env.example .env
   ```

3. Set a strong local `POSTGRES_PASSWORD` in `.env`.

4. Start the Docker services:

   ```powershell
   docker compose up -d
   ```

5. Apply the PostgreSQL migrations before running the workflow.

   These commands pipe the SQL files into `psql` inside the PostgreSQL container and do not require PostgreSQL host port `5432` to be exposed.

   Windows PowerShell:

   ```powershell
   Get-Content -Raw .\database\migrations\V1__create_ai_process_log.sql | docker exec -i ai-process-postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
   Get-Content -Raw .\database\migrations\V2__add_unique_record_id.sql | docker exec -i ai-process-postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
   ```

6. Ensure Ollama is installed and running locally.

   If Ollama runs on the Windows host and n8n runs inside Docker, configure the n8n Ollama credential with:

   ```text
   Base URL: http://host.docker.internal:11434
   Model: llama3.1
   ```

   This host-to-container connection has been verified in the current project environment. Other operating systems or Docker setups may require a different host address.

7. Import the workflow into n8n:

   ```text
   workflows/01 - AI Document Analyzer.json
   ```

8. Configure the PostgreSQL credential inside n8n:

   ```text
   Host: postgres
   Port: 5432
   Database: value of POSTGRES_DB from .env
   User: value of POSTGRES_USER from .env
   Password: value of POSTGRES_PASSWORD from .env
   ```

9. Connect the configured Ollama and PostgreSQL credentials to the imported workflow nodes.

10. Run the workflow manually from n8n.

The imported `Test Data Simulator` currently uses `quantity: null`, so the first run is expected to demonstrate the `REVIEW_REQUIRED` path. To test the `OK` path, change the simulated quantity to `100`.

## Example Input / Output

Example ready record:

```json
{
  "supplier": "HT Solar",
  "material": "Solar panel 450W",
  "quantity": 100
}
```

Expected structured output:

```json
{
  "supplier": "HT Solar",
  "material": "Solar panel 450W",
  "quantity": 100,
  "status": "OK",
  "missing_fields": []
}
```

Example manual review record:

```json
{
  "supplier": "HT Solar",
  "material": "Solar panel 450W",
  "quantity": null
}
```

Expected structured output:

```json
{
  "supplier": "HT Solar",
  "material": "Solar panel 450W",
  "quantity": null,
  "status": "REVIEW_REQUIRED",
  "missing_fields": ["quantity"]
}
```

## Repository Structure

```text
AI-Process-Lab/
|-- .env.example
|-- .gitignore
|-- README.md
|-- docker-compose.yml
|-- database/
|   `-- migrations/
|       |-- V1__create_ai_process_log.sql
|       `-- V2__add_unique_record_id.sql
|-- docs/
|-- examples/
|-- prompts/
`-- workflows/
    `-- 01 - AI Document Analyzer.json
```

`docs/`, `examples/` and `prompts/` are reserved for future documentation, sample data and prompt assets.

## Current Limitations

- Input is currently simulated inside the n8n workflow.
- CSV, PDF, email, API and ERP ingestion are not implemented yet.
- Ollama is an external local prerequisite.
- n8n credentials are configured manually inside n8n.
- The workflow is a focused portfolio demo, not a production deployment template.

## Roadmap

- CSV ingestion
- PDF/document ingestion
- email and API integration
- ERP/database connectors
- monitoring and KPI dashboard
- stronger error handling
