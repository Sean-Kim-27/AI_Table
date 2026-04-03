import Foundation
import Observation

@MainActor
@Observable
final class OrchestrationViewModel {
    private let runtime: OrchestrationRuntime

    var tasks: [TaskRecord] = []
    var isLoading = false
    var lastRunID: String?
    var lastError: String?

    init(runtime: OrchestrationRuntime = .shared) {
        self.runtime = runtime
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await runtime.orchestrator.bootstrap()
            tasks = try await runtime.orchestrator.listTasks(limit: 20)
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
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
