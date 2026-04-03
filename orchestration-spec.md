# AI_Table 오케스트레이션 스펙 (JSON Schema / DB 설계 / 에이전트 템플릿)

> 전제: DB는 **로컬 macOS 환경**에서 동작 (오프라인/로컬 우선).

---

## 1) JSON Schema

### 1.1 TaskRequest
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "TaskRequest",
  "type": "object",
  "required": ["taskId", "title", "prompt", "constraints", "outputFormat"],
  "properties": {
    "taskId": {"type": "string"},
    "title": {"type": "string"},
    "prompt": {"type": "string"},
    "attachments": {
      "type": "array",
      "items": {"$ref": "#/definitions/Attachment"}
    },
    "constraints": {
      "type": "object",
      "properties": {
        "deadline": {"type": "string", "format": "date-time"},
        "budget": {"type": "number"},
        "privacyLevel": {"type": "string", "enum": ["local", "external-ok"]}
      }
    },
    "outputFormat": {"type": "string", "enum": ["summary", "report", "code", "files"]},
    "autoDecompose": {"type": "boolean"}
  },
  "definitions": {
    "Attachment": {
      "type": "object",
      "required": ["type", "uri"],
      "properties": {
        "type": {"type": "string", "enum": ["file", "url"]},
        "uri": {"type": "string"},
        "label": {"type": "string"}
      }
    }
  }
}
```

### 1.2 Subtask
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Subtask",
  "type": "object",
  "required": ["subtaskId", "taskId", "title", "status"],
  "properties": {
    "subtaskId": {"type": "string"},
    "taskId": {"type": "string"},
    "title": {"type": "string"},
    "description": {"type": "string"},
    "agentId": {"type": "string"},
    "provider": {"type": "string"},
    "status": {"type": "string", "enum": ["queued", "running", "blocked", "done", "failed"]},
    "dependencies": {"type": "array", "items": {"type": "string"}},
    "resultRef": {"type": "string"}
  }
}
```

### 1.3 AgentTemplate
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "AgentTemplate",
  "type": "object",
  "required": ["agentId", "name", "role", "systemPrompt"],
  "properties": {
    "agentId": {"type": "string"},
    "name": {"type": "string"},
    "role": {"type": "string", "enum": ["planner", "architect", "writer", "researcher", "coder", "reviewer"]},
    "capabilities": {"type": "array", "items": {"type": "string"}},
    "systemPrompt": {"type": "string"},
    "toolPolicy": {
      "type": "object",
      "properties": {
        "allow": {"type": "array", "items": {"type": "string"}},
        "deny": {"type": "array", "items": {"type": "string"}}
      }
    },
    "tokenBudget": {"type": "integer"},
    "defaultProvider": {"type": "string"}
  }
}
```

### 1.4 ContextPacket (Sub‑agent 전달용)
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "ContextPacket",
  "type": "object",
  "required": ["taskHeader", "constraints", "inputs", "stateSnapshot"],
  "properties": {
    "taskHeader": {"type": "string"},
    "constraints": {"type": "array", "items": {"type": "string"}},
    "inputs": {"type": "array", "items": {"type": "string"}},
    "stateSnapshot": {"type": "string"},
    "evidence": {"type": "array", "items": {"type": "string"}}
  }
}
```

---

## 2) DB 설계 (macOS 로컬)

### 선택안
- **SQLite (권장)**: GRDB 또는 CoreData
- 로컬 동작 + 오프라인 우선

### 테이블 설계

#### tasks
| column | type | note |
|---|---|---|
| id | TEXT (PK) | taskId |
| title | TEXT | |
| prompt | TEXT | 원문 입력 |
| constraints | TEXT | JSON |
| output_format | TEXT | summary/report/code/files |
| status | TEXT | queued/running/done/failed |
| created_at | DATETIME | |
| updated_at | DATETIME | |

#### subtasks
| column | type | note |
|---|---|---|
| id | TEXT (PK) | subtaskId |
| task_id | TEXT (FK) | tasks.id |
| title | TEXT | |
| description | TEXT | |
| agent_id | TEXT | |
| provider | TEXT | |
| status | TEXT | queued/running/done/failed |
| dependencies | TEXT | JSON array |
| result_ref | TEXT | output id |
| created_at | DATETIME | |

#### runs
| column | type | note |
|---|---|---|
| id | TEXT (PK) | runId |
| task_id | TEXT | |
| state | TEXT | running/paused/complete |
| cost_usd | REAL | |
| tokens_in | INTEGER | |
| tokens_out | INTEGER | |
| started_at | DATETIME | |
| ended_at | DATETIME | |

#### outputs
| column | type | note |
|---|---|---|
| id | TEXT (PK) | outputId |
| subtask_id | TEXT | |
| content | TEXT | 최종 텍스트 |
| artifacts | TEXT | JSON |
| created_at | DATETIME | |

#### agents
| column | type | note |
|---|---|---|
| id | TEXT (PK) | agentId |
| name | TEXT | |
| role | TEXT | |
| system_prompt | TEXT | |
| capabilities | TEXT | JSON |
| tool_policy | TEXT | JSON |
| default_provider | TEXT | |

---

## 3) 에이전트 템플릿 (예시)

### Planner
```yaml
id: planner
name: Planner
role: planner
capabilities:
  - task_breakdown
  - risk_analysis
system_prompt: |
  You are a planning specialist. Produce phased implementation plans with risks and testing.
```

### Architect
```yaml
id: architect
name: Architect
role: architect
capabilities:
  - system_design
  - tradeoff_analysis
system_prompt: |
  You are a software architect. Propose scalable, secure system designs with trade-off analysis.
```

### Reviewer
```yaml
id: reviewer
name: Security Reviewer
role: reviewer
capabilities:
  - security_audit
  - vulnerability_scan
system_prompt: |
  You are a security reviewer. Check for OWASP risks and sensitive data handling issues.
```

### Writer
```yaml
id: writer
name: Writer
role: writer
capabilities:
  - summarization
  - report_writing
system_prompt: |
  You are a writer agent. Produce clear summaries and structured reports.
```

---

## 다음 단계
- 위 스키마/DB/에이전트 템플릿을 기준으로 **Swift 코드 스켈레톤** 생성 가능
- 필요하면 **GRDB 기반 SQLite 모델/마이그레이션** 설계 추가
