import SwiftUI

struct OrchestrationSettingsPanel: View {
    @State private var viewModel = OrchestrationViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Orchestration")
                .font(.headline)

            Text("Stored tasks: \(viewModel.tasks.count)")
                .font(.subheadline)

            if let lastRunID = viewModel.lastRunID {
                Text("Last run: \(lastRunID)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let lastError = viewModel.lastError {
                Text("Error: \(lastError)")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Refresh") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.bordered)

                Button("Run Sample") {
                    Task { await viewModel.runSampleTask() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }

            Spacer()
        }
        .padding(20)
        .task {
            await viewModel.load()
        }
    }
}
