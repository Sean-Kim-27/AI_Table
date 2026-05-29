import SwiftUI

struct OrchestrationSettingsPanel: View {
    @State private var viewModel = OrchestrationViewModel()

    var body: some View {
        VStack(spacing: 10) {
            header
            Divider()
            HSplitView {
                taskListPane
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                detailPane
                    .frame(minWidth: 500)
            }
        }
        .padding(12)
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("오케스트레이션")
                .font(.headline)
            Text("작업: \(viewModel.tasks.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if let lastRunID = viewModel.lastRunID {
                Text("최근 실행: \(lastRunID)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 260, alignment: .trailing)
            }

            Button("새로고침") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)

            Button("샘플 실행") {
                Task { await viewModel.runSampleTask() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
    }

    private var taskListPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("작업 목록")
                .font(.subheadline.weight(.semibold))

            List(selection: taskSelectionBinding) {
                ForEach(viewModel.tasks, id: \.id) { task in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(task.status)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(Self.dateFormatter.string(from: task.updatedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(task.id)
                }
            }
            .listStyle(.inset)

            if let lastError = viewModel.lastError {
                Text("오류: \(lastError)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
    }

    private var detailPane: some View {
        ScrollView {
            if let detail = viewModel.selectedTaskDetail {
                VStack(alignment: .leading, spacing: 14) {
                    taskSection(detail)
                    runSection(detail)
                    subtaskSection(detail)
                    historySection(detail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("작업을 선택하면 실행/서브태스크/출력/히스토리를 볼 수 있습니다.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func taskSection(_ detail: OrchestrationTaskDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("작업")
                .font(.subheadline.weight(.semibold))
            Text(detail.task.title)
                .font(.headline)
            Text(detail.task.prompt)
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Text("상태: \(detail.task.status)")
                    .font(.caption)
                statusButtons(
                    currentStatus: detail.task.status,
                    values: OrchestrationTaskStatus.allCases.map(\.rawValue)
                ) { raw in
                    guard let status = OrchestrationTaskStatus(rawValue: raw) else { return }
                    Task { await viewModel.updateTaskStatus(status) }
                }
            }
        }
    }

    private func runSection(_ detail: OrchestrationTaskDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("실행")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("재실행") {
                    Task { await viewModel.rerunSelectedTask() }
                }
                .buttonStyle(.bordered)

                Button("대기 작업 실행(스텁)") {
                    Task { await viewModel.runPendingSubtasks() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }

            if detail.runs.isEmpty {
                Text("실행 기록 없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(detail.runs, id: \.id) { run in
                    HStack(spacing: 8) {
                        Text(run.id)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(run.state)
                            .font(.caption)
                        Text(Self.dateFormatter.string(from: run.startedAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func subtaskSection(_ detail: OrchestrationTaskDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("서브태스크")
                .font(.subheadline.weight(.semibold))

            if detail.subtasks.isEmpty {
                Text("서브태스크 없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(detail.subtasks, id: \.id) { subtask in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(subtask.title)
                                .font(.subheadline)
                            Text(subtask.status)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("재시도") {
                                Task { await viewModel.retrySubtask(subtaskID: subtask.id) }
                            }
                            .buttonStyle(.bordered)

                            Button("차단") {
                                Task { await viewModel.updateSubtaskStatus(subtaskID: subtask.id, status: .blocked) }
                            }
                            .buttonStyle(.bordered)

                            Button("실패") {
                                Task { await viewModel.updateSubtaskStatus(subtaskID: subtask.id, status: .failed) }
                            }
                            .buttonStyle(.bordered)

                            Button("완료") {
                                Task { await viewModel.updateSubtaskStatus(subtaskID: subtask.id, status: .done) }
                            }
                            .buttonStyle(.bordered)
                        }

                        if let output = detail.latestOutputBySubtaskID[subtask.id] {
                            Text(output.content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(3)
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }

    private func historySection(_ detail: OrchestrationTaskDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("로그 / 히스토리")
                .font(.subheadline.weight(.semibold))

            TextField("로그 검색", text: $viewModel.logSearchQuery)
                .textFieldStyle(.roundedBorder)

            if detail.events.isEmpty {
                Text("기록 없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                if viewModel.filteredEvents.isEmpty {
                    Text("검색 결과 없음")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.filteredEvents, id: \.id) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(event.level.uppercased())
                                    .font(.caption2)
                                    .foregroundColor(event.level == OrchestrationEventLevel.error.rawValue ? .red : .secondary)
                                Text(Self.dateFormatter.string(from: event.createdAt))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(event.message)
                                .font(.caption)
                            if let subtaskID = event.subtaskId {
                                Text("서브태스크: \(subtaskID)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    private func statusButtons(
        currentStatus: String,
        values: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(values, id: \.self) { status in
                Button(status) { onSelect(status) }
                    .buttonStyle(.bordered)
                    .foregroundColor(currentStatus == status ? .accentColor : .primary)
            }
        }
    }

    private var taskSelectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedTaskID },
            set: { selected in
                Task { await viewModel.selectTask(selected) }
            }
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
