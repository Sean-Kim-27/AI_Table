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
        try await store.addEvent(
            taskID: request.taskId,
            runID: run.id,
            subtaskID: nil,
            level: .info,
            message: "Run started for task '\(request.title)'."
        )

        let subtasks = router.decompose(request)
        _ = contextManager.packet(for: request, subtasks: subtasks)

        try await store.saveSubtasks(subtasks, for: request.taskId)
        try await store.addEvent(
            taskID: request.taskId,
            runID: run.id,
            subtaskID: nil,
            level: .info,
            message: "Generated \(subtasks.count) subtasks."
        )

        try await executeStubPipeline(taskID: request.taskId, runID: run.id)

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

    func taskDetail(taskID: String) async throws -> OrchestrationTaskDetail? {
        try await store.fetchTaskDetail(taskID: taskID)
    }

    func listRuns(taskID: String) async throws -> [RunRecord] {
        try await store.fetchRuns(taskID: taskID)
    }

    func subtasks(taskID: String) async throws -> [SubtaskRecord] {
        try await store.fetchSubtasks(taskID: taskID)
    }

    func updateTaskStatus(taskID: String, status: OrchestrationTaskStatus) async throws {
        try await store.updateTaskStatus(taskID: taskID, status: status)
        try await store.addEvent(
            taskID: taskID,
            runID: nil,
            subtaskID: nil,
            level: .info,
            message: "Task status changed to \(status.rawValue)."
        )
    }

    func updateSubtaskStatus(
        taskID: String,
        subtaskID: String,
        status: Subtask.Status,
        clearResultRef: Bool = false
    ) async throws {
        try await store.updateSubtaskStatus(
            subtaskID: subtaskID,
            status: status,
            resultRef: nil,
            clearResultRef: clearResultRef
        )

        try await store.addEvent(
            taskID: taskID,
            runID: nil,
            subtaskID: subtaskID,
            level: status == .failed ? .error : .info,
            message: "Subtask status changed to \(status.rawValue)."
        )
    }

    func rerun(taskID: String) async throws -> RunRecord {
        let run = try await store.createRun(taskID: taskID, state: .running)
        try await store.updateTaskStatus(taskID: taskID, status: .running)
        try await store.addEvent(
            taskID: taskID,
            runID: run.id,
            subtaskID: nil,
            level: .info,
            message: "Rerun created."
        )
        return run
    }

    func runPendingSubtasks(taskID: String, runID: String? = nil) async throws {
        let activeRunID = try await resolveRunID(taskID: taskID, runID: runID)
        try await executeStubPipeline(taskID: taskID, runID: activeRunID)
    }

    private func resolveRunID(taskID: String, runID: String?) async throws -> String {
        if let runID {
            return runID
        }
        if let latestRunID = try await store.fetchRuns(taskID: taskID).first?.id {
            return latestRunID
        }
        return try await rerun(taskID: taskID).id
    }

    // Minimal local execution stub: marks pending subtasks running/done and writes placeholder outputs.
    private func executeStubPipeline(taskID: String, runID: String) async throws {
        try await store.updateTaskStatus(taskID: taskID, status: .running)
        try await store.updateRunState(runID: runID, taskID: taskID, state: .running)
        try await store.addEvent(
            taskID: taskID,
            runID: runID,
            subtaskID: nil,
            level: .info,
            message: "Stub execution pipeline started."
        )

        let allSubtasks = try await store.fetchSubtasks(taskID: taskID)
        let pending = allSubtasks.filter { row in
            row.status == Subtask.Status.queued.rawValue ||
            row.status == Subtask.Status.running.rawValue ||
            row.status == Subtask.Status.failed.rawValue ||
            row.status == Subtask.Status.blocked.rawValue
        }

        for row in pending {
            try await store.updateSubtaskStatus(subtaskID: row.id, status: .running, clearResultRef: false)
            try await store.addEvent(
                taskID: taskID,
                runID: runID,
                subtaskID: row.id,
                level: .info,
                message: "Started subtask '\(row.title)'."
            )

            let output = try await store.addOutput(
                subtaskID: row.id,
                content: "Stub execution completed for '\(row.title)'. External provider hookup is not integrated yet.",
                artifacts: []
            )
            try await store.updateSubtaskStatus(
                subtaskID: row.id,
                status: .done,
                resultRef: output.id,
                clearResultRef: false
            )
            try await store.addEvent(
                taskID: taskID,
                runID: runID,
                subtaskID: row.id,
                level: .info,
                message: "Completed subtask '\(row.title)'."
            )
        }

        try await store.finishRun(
            runID: runID,
            taskID: taskID,
            state: .complete,
            costUSD: 0,
            tokensIn: 0,
            tokensOut: 0
        )
        try await store.updateTaskStatus(taskID: taskID, status: .done)
        try await store.addEvent(
            taskID: taskID,
            runID: runID,
            subtaskID: nil,
            level: .info,
            message: "Run completed with \(pending.count) processed subtasks."
        )
    }
}
