import SwiftUI

struct PayloadGridView: View {
    @Environment(PayloadStore.self) private var store
    @Binding var selectedPayload: Payload?
    @Binding var portString: String
    @Binding var showFolderPicker: Bool

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        Group {
            if !store.hasFolder {
                noFolderView
            } else if store.isLoading {
                loadingView
            } else if let error = store.error {
                errorView(error)
            } else if store.payloads.isEmpty {
                emptyView
            } else {
                gridView
            }
        }
    }

    // MARK: - States

    private var noFolderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.cyan)

            Text("folder.select.title")
                .font(.headline)

            Text("folder.select.description")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showFolderPicker = true
            } label: {
                Text("folder.select.browse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .glassCard(tint: .blue, interactive: true, shape: .capsule)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .glassCard()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("payloads.loading")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "folder.select.another")) {
                showFolderPicker = true
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .glassCard()
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("payloads.empty.title")
                .font(.headline)
            Text("payloads.empty.description")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "payloads.refresh")) {
                store.loadPayloads()
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .glassCard()
    }

    // MARK: - Grid

    private var gridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(store.payloads) { payload in
                let isSelected = selectedPayload?.id == payload.id
                Button {
                    withAnimation(.smooth) {
                        selectedPayload = payload
                        portString = "\(payload.defaultPort)"
                    }
                } label: {
                    VStack(spacing: 0) {
                        Spacer(minLength: 8)

                        Image(systemName: payload.fileExtension == "lua" ? "scroll.fill" : "cpu.fill")
                            .font(.title3)
                            .foregroundStyle(payload.fileExtension == "lua" ? .orange : .cyan)

                        Spacer(minLength: 6)

                        Text(payload.fullFilename)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Divider()
                            .padding(.horizontal, 16)

                        Spacer(minLength: 6)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .green : .secondary)
                            .font(.subheadline)

                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassCard(tint: isSelected ? .blue.opacity(0.2) : nil)
            }
        }
    }
}

#Preview {
    PayloadGridView(
        selectedPayload: .constant(Payload.preview[0]),
        portString: .constant("9021"),
        showFolderPicker: .constant(false)
    )
    .padding()
    .environment(PayloadStore(preview: Payload.preview))
}
