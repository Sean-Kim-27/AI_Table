import Foundation
import GRDB

// MARK: - Spec-level API Models

struct TaskRequest: Codable, Sendable {
    struct Attachment: Codable, Sendable {
        enum Kind: String, Codable, Sendable {
            case file
            case url
        }

        var type: Kind
        var uri: String
        var label: String?
    }

    struct Constraints: Codable, Sendable {
        enum PrivacyLevel: String, Codable, Sendable {
            case local
            case externalOK = "external-ok"
        }

        var deadline: Date?
        var budget: Double?
        var privacyLevel: PrivacyLevel?
    }

    enum OutputFormat: String, Codable, Sendable {
        case summary
        case report
        case code
        case files
    }

    var taskId: String
    var title: String
    var prompt: String
    var attachments: [Attachment]
    var constraints: Constraints
    var outputFormat: OutputFormat
    var autoDecompose: Bool

    init(
        taskId: String = UUID().uuidString,
        title: String,
        prompt: String,
        attachments: [Attachment] = [],
        constraints: Constraints = .init(),
        outputFormat: OutputFormat,
        autoDecompose: Bool = true
    ) {
        self.taskId = taskId
        self.title = title
        self.prompt = prompt
        self.attachments = attachments
        self.constraints = constraints
        self.outputFormat = outputFormat
        self.autoDecompose = autoDecompose
    }
}

struct Subtask: Codable, Identifiable, Sendable {
    enum Status: String, Codable, CaseIterable, Sendable {
        case queued
        case running
        case blocked
        case done
        case failed
    }

    var subtaskId: String
    var taskId: String
    var title: String
    var description: String?
    var agentId: String?
    var provider: String?
    var status: Status
    var dependencies: [String]
    var resultRef: String?

    var id: String { subtaskId }
}

struct AgentTemplate: Codable, Identifiable, Sendable {
    enum Role: String, Codable, CaseIterable, Sendable {
        case planner
        case architect
        case writer
        case researcher
        case coder
        case reviewer
    }

    struct ToolPolicy: Codable, Sendable {
        var allow: [String]
        var deny: [String]

        init(allow: [String] = [], deny: [String] = []) {
            self.allow = allow
            self.deny = deny
        }
    }

    var agentId: String
    var name: String
    var role: Role
    var capabilities: [String]
    var systemPrompt: String
    var toolPolicy: ToolPolicy
    var tokenBudget: Int?
    var defaultProvider: String?

    var id: String { agentId }
}

struct ContextPacket: Codable, Sendable {
    var taskHeader: String
    var constraints: [String]
    var inputs: [String]
    var stateSnapshot: String
    var evidence: [String]
}

// MARK: - Persistence Models

enum OrchestrationTaskStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case done
    case failed
}

enum OrchestrationRunState: String, Codable, Sendable {
    case running
    case paused
    case complete
    case failed
}

enum OrchestrationEventLevel: String, Codable, Sendable {
    case info
    case warning
    case error
}

struct TaskRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    static let databaseTableName = "tasks"

    var id: String
    var title: String
    var prompt: String
    var constraints: String
    var outputFormat: String
    var status: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case prompt
        case constraints
        case outputFormat = "output_format"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SubtaskRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    static let databaseTableName = "subtasks"

    var id: String
    var taskId: String
    var title: String
    var subtaskDescription: String?
    var agentId: String?
    var provider: String?
    var status: String
    var dependencies: String
    var resultRef: String?
    var createdAt: Date

    enum Columns {
        static let id = Column("id")
        static let taskId = Column("task_id")
        static let createdAt = Column("created_at")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case title
        case subtaskDescription = "description"
        case agentId = "agent_id"
        case provider
        case status
        case dependencies
        case resultRef = "result_ref"
        case createdAt = "created_at"
    }
}

struct RunRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    static let databaseTableName = "runs"

    var id: String
    var taskId: String
    var state: String
    var costUSD: Double
    var tokensIn: Int
    var tokensOut: Int
    var startedAt: Date
    var endedAt: Date?

    enum Columns {
        static let id = Column("id")
        static let taskId = Column("task_id")
        static let startedAt = Column("started_at")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case state
        case costUSD = "cost_usd"
        case tokensIn = "tokens_in"
        case tokensOut = "tokens_out"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

struct OutputRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    static let databaseTableName = "outputs"

    var id: String
    var subtaskId: String
    var content: String
    var artifacts: String
    var createdAt: Date

    enum Columns {
        static let subtaskId = Column("subtask_id")
        static let createdAt = Column("created_at")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case subtaskId = "subtask_id"
        case content
        case artifacts
        case createdAt = "created_at"
    }
}

struct EventRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    static let databaseTableName = "events"

    var id: String
    var taskId: String
    var runId: String?
    var subtaskId: String?
    var level: String
    var message: String
    var createdAt: Date

    enum Columns {
        static let taskId = Column("task_id")
        static let createdAt = Column("created_at")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case runId = "run_id"
        case subtaskId = "subtask_id"
        case level
        case message
        case createdAt = "created_at"
    }
}

struct AgentRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    static let databaseTableName = "agents"

    var id: String
    var name: String
    var role: String
    var systemPrompt: String
    var capabilities: String
    var toolPolicy: String
    var defaultProvider: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case systemPrompt = "system_prompt"
        case capabilities
        case toolPolicy = "tool_policy"
        case defaultProvider = "default_provider"
    }
}

struct OrchestrationRunSnapshot: Identifiable, Sendable {
    var run: RunRecord
    var task: TaskRecord
    var subtasks: [SubtaskRecord]

    var id: String { run.id }
}

struct OrchestrationTaskDetail: Sendable {
    var task: TaskRecord
    var runs: [RunRecord]
    var subtasks: [SubtaskRecord]
    var latestOutputBySubtaskID: [String: OutputRecord]
    var events: [EventRecord]
}
