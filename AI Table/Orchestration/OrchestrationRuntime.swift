import Foundation

@MainActor
final class OrchestrationRuntime {
    static let shared = OrchestrationRuntime()

    let orchestrator: OrchestratorService

    private init() {
        do {
            let store = try OrchestrationStore.live()
            let registry = AgentRegistry(store: store)
            orchestrator = OrchestratorService(store: store, agentRegistry: registry)
        } catch {
            fatalError("Failed to initialize orchestration runtime: \(error)")
        }
    }

    func bootstrapIfNeeded() {
        Task {
            do {
                try await orchestrator.bootstrap()
            } catch {
                NSLog("Orchestration bootstrap failed: \(error.localizedDescription)")
            }
        }
    }
}
