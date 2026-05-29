import Foundation
import Observation

@MainActor
@Observable
final class OrchestrationViewModel {
    private let runtime: OrchestrationRuntime

    var tasks: [TaskRecord] = []
    var selectedTaskID: String?
    var selectedTaskDetail: OrchestrationTaskDetail?
    var isLoading = false
    var lastRunID: String?
    var lastError: String?
    var logSearchQuery = ""

    init(runtime: OrchestrationRuntime = .shared) {
        self.runtime = runtime
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await runtime.orchestrator.bootstrap()
            tasks = try await runtime.orchestrator.listTasks(limit: 20)
            if selectedTaskID == nil {
                selectedTaskID = tasks.first?.id
            }
            await refreshSelectedTaskDetail()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func runSampleTask() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await runtime.orchestrator.bootstrap()
            let request = TaskRequest(
                title: "MVP Orchestration Skeleton",
                prompt: "Create a minimal orchestration run and persist subtasks/results.",
                outputFormat: .report,
                autoDecompose: true
            )

            let snapshot = try await runtime.orchestrator.submit(request)
            lastRunID = snapshot.run.id
            tasks = try await runtime.orchestrator.listTasks(limit: 20)
            selectedTaskID = snapshot.task.id
            await refreshSelectedTaskDetail()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func selectTask(_ taskID: String?) async {
        selectedTaskID = taskID
        await refreshSelectedTaskDetail()
    }

    func refreshSelectedTaskDetail() async {
        guard let selectedTaskID else {
            selectedTaskDetail = nil
            return
        }

        do {
            selectedTaskDetail = try await runtime.orchestrator.taskDetail(taskID: selectedTaskID)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateTaskStatus(_ status: OrchestrationTaskStatus) async {
        guard let taskID = selectedTaskID else { return }
        await runMutation { [self] in
            try await self.runtime.orchestrator.updateTaskStatus(taskID: taskID, status: status)
        }
    }

    func updateSubtaskStatus(subtaskID: String, status: Subtask.Status, clearResultRef: Bool = false) async {
        guard let taskID = selectedTaskID else { return }
        await runMutation { [self] in
            try await self.runtime.orchestrator.updateSubtaskStatus(
                taskID: taskID,
                subtaskID: subtaskID,
                status: status,
                clearResultRef: clearResultRef
            )
        }
    }

    func retrySubtask(subtaskID: String) async {
        await updateSubtaskStatus(subtaskID: subtaskID, status: .queued, clearResultRef: true)
    }

    func rerunSelectedTask() async {
        guard let taskID = selectedTaskID else { return }
        await runMutation { [self] in
            let run = try await self.runtime.orchestrator.rerun(taskID: taskID)
            self.lastRunID = run.id
        }
    }

    func runPendingSubtasks() async {
        guard let taskID = selectedTaskID else { return }
        await runMutation { [self] in
            try await self.runtime.orchestrator.runPendingSubtasks(taskID: taskID)
        }
    }

    var filteredEvents: [EventRecord] {
        guard let detail = selectedTaskDetail else { return [] }
        let query = logSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return detail.events }

        let lowered = query.lowercased()
        return detail.events.filter { event in
            event.message.lowercased().contains(lowered)
            || event.level.lowercased().contains(lowered)
            || (event.subtaskId?.lowercased().contains(lowered) ?? false)
            || (event.runId?.lowercased().contains(lowered) ?? false)
        }
    }

    private func runMutation(_ work: @escaping () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await work()
            tasks = try await runtime.orchestrator.listTasks(limit: 20)
            await refreshSelectedTaskDetail()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
