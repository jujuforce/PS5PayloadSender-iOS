import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: PayloadStore
    @AppStorage("ps5_ip") private var ipAddress = ""
    @State private var selectedPayload: Payload?
    @State private var portString = "9021"
    @State private var status: SendStatus = .idle
    @State private var isSending = false
    @State private var sendTask: Task<Void, Never>?
    @State private var showFolderPicker = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case ip, port }

    var body: some View {
        navigationContainer
    }

    @ViewBuilder
    private var navigationContainer: some View {
        if #available(iOS 16, *) {
            NavigationStack { mainContent }
        } else {
            NavigationView { mainContent }
                .navigationViewStyle(.stack)
        }
    }

    private var mainContent: some View {
            VStack(spacing: 0) {
                // Fixed top: connection fields
                connectionSection
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Scrollable middle: payload grid
                ScrollView {
                    PayloadGridView(
                        selectedPayload: $selectedPayload,
                        portString: $portString,
                        showFolderPicker: $showFolderPicker
                    )
                    .padding(.horizontal)
                }
                .scrollBounceBasedOnSize()

                // Fixed bottom: send button
                if store.hasFolder {
                    SendButtonView(
                        status: status,
                        isEnabled: !ipAddress.isEmpty && selectedPayload != nil,
                        onSend: sendPayload,
                        onCancel: cancelSend
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .background { AppBackground() }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { focusedField = nil } label: {
                        Text(String(localized: "connection.keyboard.ok"))
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if store.hasFolder {
                        Button { store.loadPayloads() } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        folderMenu
                    }
                }
            }
            .scrollDismissesKeyboardCompat()
            .simultaneousGesture(TapGesture().onEnded { focusedField = nil })
            .navigationTitle(String(localized: "app.title"))
            #if targetEnvironment(macCatalyst)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [UTType.folder]) { result in
                if case .success(let url) = result { store.setFolder(url) }
            }
            .onChange(of: store.payloads) { newPayloads in
                if selectedPayload == nil || !newPayloads.contains(where: { $0.id == selectedPayload?.id }) {
                    selectedPayload = newPayloads.first
                    portString = "\(selectedPayload?.defaultPort ?? 9021)"
                }
            }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "network").foregroundStyle(.secondary)
                TextField(String(localized: "connection.ip.placeholder"), text: $ipAddress)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .ip)
            }
            .padding()
            .glassCard(shape: .capsule)

            HStack {
                Image(systemName: "number").foregroundStyle(.secondary)
                TextField(String(localized: "connection.port.placeholder"), text: $portString)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .port)
            }
            .padding()
            .glassCard(shape: .capsule)
        }
    }

    // MARK: - Folder Menu

    private var folderMenu: some View {
        Menu {
            Button { showFolderPicker = true } label: {
                Label(String(localized: "folder.menu.change"), systemImage: "folder")
            }
            Button(role: .destructive) { store.clearFolder() } label: {
                Label(String(localized: "folder.menu.disconnect"), systemImage: "folder.badge.minus")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Actions

    private func sendPayload() {
        guard let selectedPayload else {
            status = .error(String(localized: "send.error.noPayload")); return
        }
        guard let port = UInt16(portString) else {
            status = .error(String(localized: "send.error.invalidPort")); return
        }
        guard let data = selectedPayload.data else {
            status = .error(String(localized: "send.error.loadFailed")); return
        }

        isSending = true
        status = .sending

        sendTask = Task {
            do {
                let bytesSent = try await PayloadSender.send(data: data, to: ipAddress, port: port)
                await MainActor.run { status = .success(bytesSent); isSending = false }
                // Reset to idle after showing success briefly
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    if case .success = status { status = .idle }
                }
            } catch is CancellationError {
                await MainActor.run { status = .idle; isSending = false }
            } catch {
                await MainActor.run {
                    let msg = error.localizedDescription
                    status = msg == "Cancelled" ? .idle : .error(msg)
                    isSending = false
                }
                // Reset to idle after showing error briefly
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    if case .error = status { status = .idle }
                }
            }
        }
    }

    private func cancelSend() {
        sendTask?.cancel()
        sendTask = nil
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(PayloadStore(preview: Payload.preview))
}
#endif
