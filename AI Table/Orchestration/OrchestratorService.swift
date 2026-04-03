import Foundation

protocol TaskRouter: Sendable {
    func decompose(_ request: TaskRequest) -> [Subtask]
}

struct DefaultTaskRouter: TaskRouter {
    func decompose(_ request: TaskRequest) -> [Subtask] {
        if !request.autoDecompose {
            return [
                Subtask(
                    subtaskId: UUID().uuidString,
                    taskId: request.taskId,
                    title: request.title,
                    description: request.prompt,
                    agentId: "writer",
                    provider: "OpenAI",
                    status: .queued,
                    dependencies: [],
                    resultRef: nil
                )
            ]
        }

        return [
            Subtask(
                subtaskId: UUID().uuidString,
                taskId: request.taskId,
                title: "Plan",
                description: "Break down goals, constraints, and delivery plan",
                agentId: "planner",
                provider: "OpenAI",
                status: .queued,
                dependencies: [],
                resultRef: nil
            ),
            Subtask(
                subtaskId: UUID().uuidString,
                taskId: request.taskId,
                title: "Design",
                description: "Define architecture trade-offs and execution approach",
                agentId: "architect",
                provider: "Claude",
                status: .queued,
                dependencies: [],
                resultRef: nil
            ),
            Subtask(
                subtaskId: UUID().uuidString,
                taskId: request.taskId,
                title: "Review",
                description: "Perform quality/security validation pass",
                agentId: "reviewer",
                provider: "OpenAI",
                status: .queued,
                dependencies: [],
                resultRef: nil
            )
        ]
    }
}

struct ContextManager: Sendable {
    func packet(for request: TaskRequest, subtasks: [Subtask], historySummary: String = "") -> ContextPacket {
        ContextPacket(
            taskHeader: "\(request.title): \(request.prompt)",
            constraints: compactConstraints(from: request.constraints),
            inputs: request.attachments.map { $0.uri },
            stateSnapshot: "subtasks=\(subtasks.count); output=\(request.outputFormat.rawValue)",
            evidence: historySummary.isEmpty ? [] : [historySummary]
        )
    }

    private func compactConstraints(from constraints: TaskRequest.Constraints) -> [String] {
        var values: [String] = []
        if let deadline = constraints.deadline {
            values.append("deadline=\(ISO8601DateFormatter().string(from: deadline))")
        }
        if let budget = constraints.budget {
            values.append("budget=\(budget)")
        }
        if let privacyLevel = constraints.privacyLevel {
            values.append("privacy=\(privacyLevel.rawValue)")
        }
        return values
    }
}

actor AgentRegistry {
    private let store: OrchestrationStore
    private var cache: [String: AgentRecord] = [:]

    init(store: OrchestrationStore) {
        self.store = store
    }

    func load() async throws {
        let agents = try await store.fetchAgents()
        cache = Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0) })
    }

    func agent(for id: String) -> AgentRecord? {
        cache[id]
    }
}

actor OrchestratorService {
    private let store: OrchestrationStore
    private let router: TaskRouter
    private let contextManager: ContextManager
    private let agentRegistry: AgentRegistry

    init(
        store: OrchestrationStore,
        router: TaskRouter = DefaultTaskRouter(),
        contextManager: ContextManager = ContextManager(),
        agentRegistry: AgentRegistry
    ) {
        self.store = store
        self.router = router
        self.contextManager = contextManager
        self.agentRegistry = agentRegistry
    }

    func bootstrap() async throws {
        try await store.bootstrap()
        try await agentRegistry.load()
    }

    func submit(_ request: TaskRequest) async throws -> OrchestrationRunSnapshot {
        let task = try await store.upsertTask(from: request, status: .running)
        let run = try await store.createRun(taskID: request.taskId)

        let subtasks = router.decompose(request)
        _ = contextManager.packet(for: request, subtasks: subtasks)

        try await store.saveSubtasks(subtasks, for: request.taskId)

        for subtask in subtasks {
            try await store.updateSubtaskStatus(subtaskID: subtask.subtaskId, status: .running)
            let output = try await store.addOutput(
                subtaskID: subtask.subtaskId,
                content: "Skeleton execution complete for \(subtask.title). Provider integration is pending.",
                artifacts: []
            )
            try await store.updateSubtaskStatus(subtaskID: subtask.subtaskId, status: .done, resultRef: output.id)
        }

        try await store.finishRun(
            runID: run.id,
            taskID: request.taskId,
            state: .complete,
            costUSD: 0,
            tokensIn: 0,
            tokensOut: 0
        )
        try await store.updateTaskStatus(taskID: request.taskId, status: .done)

        let updatedTask = try await store.fetchTask(id: request.taskId) ?? task
        let savedSubtasks = try await store.fetchSubtasks(taskID: request.taskId)
        let runs = try await store.fetchRuns(taskID: request.taskId)

        return OrchestrationRunSnapshot(
            run: runs.first ?? run,
            task: updatedTask,
            subtasks: savedSubtasks
        )
    }

    func listTasks(limit: Int = 50) async throws -> [TaskRecord] {
        try await store.fetchTasks(limit: limit)
    }

    func listRuns(taskID: String) async throws -> [RunRecord] {
        try await store.fetchRuns(taskID: taskID)
    }

    func subtasks(taskID: String) async throws -> [SubtaskRecord] {
        try await store.fetchSubtasks(taskID: taskID)
    }
}
