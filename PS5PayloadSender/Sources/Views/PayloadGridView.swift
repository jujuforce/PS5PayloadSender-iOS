import SwiftUI

struct PayloadGridView: View {
    @EnvironmentObject private var store: PayloadStore
    @Binding var selectedPayload: Payload?
    @Binding var portString: String
    @Binding var showFolderPicker: Bool

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
                .foregroundColor(.cyanCompat)

            Text("folder.select.title")
                .font(.headline)

            Text("folder.select.description")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showFolderPicker = true
            } label: {
                Text("folder.select.browse")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .primaryButtonStyle(color: .blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .glassCard()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            SpinnerView()
            Text("payloads.loading")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("folder.select.another") {
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
                .foregroundColor(.secondary)
            Text("payloads.empty.title")
                .font(.headline)
            Text("payloads.empty.description")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("payloads.refresh") {
                store.loadPayloads()
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .glassCard()
    }

    // "cpu.fill" requires SF Symbols 3 (iOS 15+); fall back to "cpu" on earlier versions.
    private var cpuFillIcon: String {
        if #available(iOS 15, *) { return "cpu.fill" }
        return "cpu"
    }

    // MARK: - Grid

    @ViewBuilder
    private var gridView: some View {
        if #available(iOS 14, *) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(store.payloads) { payloadCell($0) }
            }
        } else {
            legacyGridView
        }
    }

    /// Manual 2-column grid for iOS 13 (no LazyVGrid).
    private var legacyGridView: some View {
        VStack(spacing: 10) {
            ForEach(Array(stride(from: 0, to: store.payloads.count, by: 2)), id: \.self) { i in
                HStack(spacing: 10) {
                    payloadCell(store.payloads[i])
                    if i + 1 < store.payloads.count {
                        payloadCell(store.payloads[i + 1])
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func payloadCell(_ payload: Payload) -> some View {
        let isSelected = selectedPayload?.id == payload.id
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPayload = payload
                portString = "\(payload.defaultPort)"
            }
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                Image(systemName: payload.fileExtension == "lua" ? "scroll.fill" : cpuFillIcon)
                    .font(.title3Compat)
                    .foregroundColor(payload.fileExtension == "lua" ? .orange : Color.cyanCompat)

                Spacer(minLength: 6)

                Text(payload.fullFilename)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Color.white.opacity(0.2)
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                Spacer(minLength: 6)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .secondary)
                    .font(.subheadline)

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .glassCard(tint: isSelected ? .blue.opacity(0.2) : nil)
    }
}

#if DEBUG
#Preview {
    PayloadGridView(
        selectedPayload: .constant(Payload.preview[0]),
        portString: .constant("9021"),
        showFolderPicker: .constant(false)
    )
    .padding()
    .environmentObject(PayloadStore(preview: Payload.preview))
}
#endif
