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

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
                .navigationViewStyle(.stack)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            connectionSection
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)

            ScrollView {
                PayloadGridView(
                    selectedPayload: $selectedPayload,
                    portString: $portString,
                    showFolderPicker: $showFolderPicker
                )
                .padding(.horizontal)
            }
            .scrollBounceBasedOnSize()

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
        .background(AppBackground())
        .scrollDismissesKeyboardCompat()
        .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
        .navigationTitle("app.title")
        #if targetEnvironment(macCatalyst)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.hasFolder {
                    Button { store.loadPayloads() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    folderMenu
                }
            }
        }
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

    private var connectionSection: some View {
        ConnectionSection(ipAddress: $ipAddress, portString: $portString)
    }

    private var folderMenu: some View {
        Menu {
            Button { showFolderPicker = true } label: {
                Label("folder.menu.change", systemImage: "folder")
            }
            disconnectButton
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var disconnectButton: some View {
        if #available(iOS 15, *) {
            Button(role: .destructive) { store.clearFolder() } label: {
                Label("folder.menu.disconnect", systemImage: "folder.badge.minus")
            }
        } else {
            Button { store.clearFolder() } label: {
                Label("folder.menu.disconnect", systemImage: "folder.badge.minus")
                    .foregroundColor(.red)
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func sendPayload() {
        guard let selectedPayload else {
            status = .error(NSLocalizedString("send.error.noPayload", comment: "")); return
        }
        guard let port = UInt16(portString) else {
            status = .error(NSLocalizedString("send.error.invalidPort", comment: "")); return
        }
        guard let data = selectedPayload.data else {
            status = .error(NSLocalizedString("send.error.loadFailed", comment: "")); return
        }
        isSending = true
        status = .sending
        sendTask = Task {
            do {
                let bytesSent = try await PayloadSender.send(data: data, to: ipAddress, port: port)
                await MainActor.run { status = .success(bytesSent); isSending = false }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { if case .success = status { status = .idle } }
            } catch is CancellationError {
                await MainActor.run { status = .idle; isSending = false }
            } catch {
                await MainActor.run {
                    let msg = error.localizedDescription
                    status = msg == "Cancelled" ? .idle : .error(msg)
                    isSending = false
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { if case .error = status { status = .idle } }
            }
        }
    }

    private func cancelSend() {
        sendTask?.cancel()
        sendTask = nil
    }
}

// MARK: - Connection fields

private struct ConnectionSection: View {
    @Binding var ipAddress: String
    @Binding var portString: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "network").foregroundColor(.secondary)
                TextField("connection.ip.placeholder", text: $ipAddress)
                    .keyboardType(.decimalPad)
                    .disableAutocorrection(true)
                    .onChange(of: ipAddress) { ipAddress = $0.replacingOccurrences(of: ",", with: ".") }
            }
            .padding()
            .glassCard(shape: .capsule)

            HStack {
                Image(systemName: "number").foregroundColor(.secondary)
                TextField("connection.port.placeholder", text: $portString)
                    .keyboardType(.numberPad)
            }
            .padding()
            .glassCard(shape: .capsule)
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(PayloadStore(preview: Payload.preview))
}
#endif
