import Foundation
import GRDB

actor OrchestrationStore {
    private let dbQueue: DatabaseQueue
    private var taskCache: [String: TaskRecord] = [:]
    private var subtaskCacheByTask: [String: [SubtaskRecord]] = [:]
    private var runCacheByTask: [String: [RunRecord]] = [:]

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    static func live() throws -> OrchestrationStore {
        let dbURL = try Self.defaultDatabaseURL()
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        return OrchestrationStore(dbQueue: dbQueue)
    }

    func bootstrap() throws {
        try OrchestrationMigrations.migrator().migrate(dbQueue)
    }

    func upsertTask(from request: TaskRequest, status: OrchestrationTaskStatus = .queued) throws -> TaskRecord {
        let now = Date()
        let constraintsData = try JSONEncoder().encode(request.constraints)
        let constraintsString = String(data: constraintsData, encoding: .utf8) ?? "{}"

        let record = TaskRecord(
            id: request.taskId,
            title: request.title,
            prompt: request.prompt,
            constraints: constraintsString,
            outputFormat: request.outputFormat.rawValue,
            status: status.rawValue,
            createdAt: now,
            updatedAt: now
        )

        try dbQueue.write { db in
            try record.save(db)
        }

        taskCache[record.id] = record
        return record
    }

    func updateTaskStatus(taskID: String, status: OrchestrationTaskStatus) throws {
        let now = Date()
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?",
                arguments: [status.rawValue, now, taskID]
            )
        }

        if var cached = taskCache[taskID] {
            cached.status = status.rawValue
            cached.updatedAt = now
            taskCache[taskID] = cached
        }
    }

    func fetchTask(id: String) throws -> TaskRecord? {
        if let cached = taskCache[id] {
            return cached
        }

        let record = try dbQueue.read { db in
            try TaskRecord.fetchOne(db, key: id)
        }

        if let record {
            taskCache[id] = record
        }
        return record
    }

    func fetchTasks(limit: Int = 50) throws -> [TaskRecord] {
        let records = try dbQueue.read { db in
            try TaskRecord
                .order(sql: "created_at DESC")
                .limit(limit)
                .fetchAll(db)
        }

        for task in records {
            taskCache[task.id] = task
        }
        return records
    }

    func saveSubtasks(_ subtasks: [Subtask], for taskID: String) throws {
        guard !subtasks.isEmpty else { return }
        let now = Date()
        let rows = subtasks.map {
            SubtaskRecord(
                id: $0.subtaskId,
                taskId: taskID,
                title: $0.title,
                subtaskDescription: $0.description,
                agentId: $0.agentId,
                provider: $0.provider,
                status: $0.status.rawValue,
                dependencies: Self.encodeStringArray($0.dependencies),
                resultRef: $0.resultRef,
                createdAt: now
            )
        }

        try dbQueue.write { db in
            for row in rows {
                try row.save(db)
            }
        }

        subtaskCacheByTask[taskID] = rows
    }

    func updateSubtaskStatus(subtaskID: String, status: Subtask.Status, resultRef: String? = nil) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE subtasks SET status = ?, result_ref = COALESCE(?, result_ref) WHERE id = ?",
                arguments: [status.rawValue, resultRef, subtaskID]
            )
        }

        for (taskID, rows) in subtaskCacheByTask {
            if let index = rows.firstIndex(where: { $0.id == subtaskID }) {
                var updatedRows = rows
                updatedRows[index].status = status.rawValue
                if let resultRef {
                    updatedRows[index].resultRef = resultRef
                }
                subtaskCacheByTask[taskID] = updatedRows
                break
            }
        }
    }

    func fetchSubtasks(taskID: String) throws -> [SubtaskRecord] {
        if let cached = subtaskCacheByTask[taskID] {
            return cached
        }

        let rows = try dbQueue.read { db in
            try SubtaskRecord
                .filter(SubtaskRecord.Columns.taskId == taskID)
                .order(SubtaskRecord.Columns.createdAt.asc)
                .fetchAll(db)
        }

        subtaskCacheByTask[taskID] = rows
        return rows
    }

    func createRun(taskID: String, state: OrchestrationRunState = .running) throws -> RunRecord {
        let run = RunRecord(
            id: UUID().uuidString,
            taskId: taskID,
            state: state.rawValue,
            costUSD: 0,
            tokensIn: 0,
            tokensOut: 0,
            startedAt: Date(),
            endedAt: nil
        )

        try dbQueue.write { db in
            try run.insert(db)
        }

        var runs = runCacheByTask[taskID] ?? []
        runs.insert(run, at: 0)
        runCacheByTask[taskID] = runs
        return run
    }

    func finishRun(
        runID: String,
        taskID: String,
        state: OrchestrationRunState,
        costUSD: Double,
        tokensIn: Int,
        tokensOut: Int
    ) throws {
        let endedAt = Date()
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE runs SET state = ?, cost_usd = ?, tokens_in = ?, tokens_out = ?, ended_at = ? WHERE id = ?",
                arguments: [state.rawValue, costUSD, tokensIn, tokensOut, endedAt, runID]
            )
        }

        if var cachedRuns = runCacheByTask[taskID],
           let index = cachedRuns.firstIndex(where: { $0.id == runID }) {
            cachedRuns[index].state = state.rawValue
            cachedRuns[index].costUSD = costUSD
            cachedRuns[index].tokensIn = tokensIn
            cachedRuns[index].tokensOut = tokensOut
            cachedRuns[index].endedAt = endedAt
            runCacheByTask[taskID] = cachedRuns
        }
    }

    func fetchRuns(taskID: String) throws -> [RunRecord] {
        if let cached = runCacheByTask[taskID] {
            return cached
        }

        let rows = try dbQueue.read { db in
            try RunRecord
                .filter(RunRecord.Columns.taskId == taskID)
                .order(RunRecord.Columns.startedAt.desc)
                .fetchAll(db)
        }

        runCacheByTask[taskID] = rows
        return rows
    }

    func addOutput(subtaskID: String, content: String, artifacts: [String] = []) throws -> OutputRecord {
        let output = OutputRecord(
            id: UUID().uuidString,
            subtaskId: subtaskID,
            content: content,
            artifacts: Self.encodeStringArray(artifacts),
            createdAt: Date()
        )

        try dbQueue.write { db in
            try output.insert(db)
        }

        return output
    }

    func fetchAgents() throws -> [AgentRecord] {
        try dbQueue.read { db in
            try AgentRecord.fetchAll(db)
        }
    }

    private static func defaultDatabaseURL() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = appSupport.appendingPathComponent("AI_Table", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("orchestration.sqlite")
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
