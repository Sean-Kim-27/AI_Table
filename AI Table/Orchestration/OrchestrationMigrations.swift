import Foundation
import GRDB

enum OrchestrationMigrations {
    private static let schemaV1 = "orchestration.schema.v1"
    private static let schemaV2Events = "orchestration.schema.v2.events"
    private static let seedAgentsV1 = "orchestration.data.seed-agents.v1"

    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = false
#endif
        registerSchemaMigrations(into: &migrator)
        registerDataMigrations(into: &migrator)
        return migrator
    }

    private static func registerSchemaMigrations(into migrator: inout DatabaseMigrator) {
        migrator.registerMigration(schemaV1) { db in
            try db.create(table: "tasks") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("prompt", .text).notNull()
                t.column("constraints", .text).notNull().defaults(to: "{}")
                t.column("output_format", .text).notNull()
                t.column("status", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "subtasks") { t in
                t.column("id", .text).primaryKey()
                t.column("task_id", .text).notNull().indexed().references("tasks", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("agent_id", .text)
                t.column("provider", .text)
                t.column("status", .text).notNull()
                t.column("dependencies", .text).notNull().defaults(to: "[]")
                t.column("result_ref", .text)
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "runs") { t in
                t.column("id", .text).primaryKey()
                t.column("task_id", .text).notNull().indexed().references("tasks", onDelete: .cascade)
                t.column("state", .text).notNull()
                t.column("cost_usd", .double).notNull().defaults(to: 0)
                t.column("tokens_in", .integer).notNull().defaults(to: 0)
                t.column("tokens_out", .integer).notNull().defaults(to: 0)
                t.column("started_at", .datetime).notNull()
                t.column("ended_at", .datetime)
            }

            try db.create(table: "outputs") { t in
                t.column("id", .text).primaryKey()
                t.column("subtask_id", .text).notNull().indexed().references("subtasks", onDelete: .cascade)
                t.column("content", .text).notNull()
                t.column("artifacts", .text).notNull().defaults(to: "[]")
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "agents") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("role", .text).notNull()
                t.column("system_prompt", .text).notNull()
                t.column("capabilities", .text).notNull().defaults(to: "[]")
                t.column("tool_policy", .text).notNull().defaults(to: "{}")
                t.column("default_provider", .text)
            }
        }

        migrator.registerMigration(schemaV2Events) { db in
            try db.create(table: "events") { t in
                t.column("id", .text).primaryKey()
                t.column("task_id", .text).notNull().indexed().references("tasks", onDelete: .cascade)
                t.column("run_id", .text).references("runs", onDelete: .setNull)
                t.column("subtask_id", .text).references("subtasks", onDelete: .setNull)
                t.column("level", .text).notNull()
                t.column("message", .text).notNull()
                t.column("created_at", .datetime).notNull().indexed()
            }
        }
    }

    private static func registerDataMigrations(into migrator: inout DatabaseMigrator) {
        migrator.registerMigration(seedAgentsV1) { db in
            let encoder = JSONEncoder()
            let toolPolicyJSON = String(data: try encoder.encode(AgentTemplate.ToolPolicy()), encoding: .utf8) ?? "{}"

            let seeds: [AgentRecord] = [
                AgentRecord(
                    id: "planner",
                    name: "Planner",
                    role: "planner",
                    systemPrompt: "You are a planning specialist. Produce phased implementation plans with risks and testing.",
                    capabilities: "[\"task_breakdown\",\"risk_analysis\"]",
                    toolPolicy: toolPolicyJSON,
                    defaultProvider: "OpenAI"
                ),
                AgentRecord(
                    id: "architect",
                    name: "Architect",
                    role: "architect",
                    systemPrompt: "You are a software architect. Propose scalable, secure system designs with trade-off analysis.",
                    capabilities: "[\"system_design\",\"tradeoff_analysis\"]",
                    toolPolicy: toolPolicyJSON,
                    defaultProvider: "Claude"
                ),
                AgentRecord(
                    id: "reviewer",
                    name: "Security Reviewer",
                    role: "reviewer",
                    systemPrompt: "You are a security reviewer. Check for OWASP risks and sensitive data handling issues.",
                    capabilities: "[\"security_audit\",\"vulnerability_scan\"]",
                    toolPolicy: toolPolicyJSON,
                    defaultProvider: "OpenAI"
                ),
                AgentRecord(
                    id: "writer",
                    name: "Writer",
                    role: "writer",
                    systemPrompt: "You are a writer agent. Produce clear summaries and structured reports.",
                    capabilities: "[\"summarization\",\"report_writing\"]",
                    toolPolicy: toolPolicyJSON,
                    defaultProvider: "Claude"
                )
            ]

            for agent in seeds {
                if try AgentRecord.fetchOne(db, key: agent.id) == nil {
                    try agent.insert(db)
                }
            }
        }
    }
}
