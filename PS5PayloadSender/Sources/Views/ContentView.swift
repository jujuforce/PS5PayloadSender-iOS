import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var store: PayloadStore
    @State private var ipAddress: String = UserDefaults.standard.string(forKey: "ps5_ip") ?? ""
    @State private var selectedPayload: Payload?
    @State private var portString = "9021"
    @State private var status: SendStatus = .idle
    @State private var isSending = false
    @State private var sendTask: Task<Void, Never>?
    @State private var showFolderPicker = false
    @State private var showFolderActions = false

    /// Binding that normalises comma → dot and persists the value to UserDefaults.
    private var ipBinding: Binding<String> {
        Binding(
            get: { ipAddress },
            set: { new in
                ipAddress = new.replacingOccurrences(of: ",", with: ".")
                UserDefaults.standard.set(ipAddress, forKey: "ps5_ip")
            }
        )
    }

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack { mainContent }
        } else {
            NavigationView { mainContent }
                .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ConnectionSection(ipAddress: ipBinding, portString: $portString)
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
        .navigationTitleCompat("app.title")
        .inlineTitleOnMac()
        .navFolderToolbar(store: store, showFolderPicker: $showFolderPicker, showFolderActions: $showFolderActions)
        .folderImporter(isPresented: $showFolderPicker) { store.setFolder($0) }
        .actionSheet(isPresented: $showFolderActions, content: folderActionSheet)
        .onReceive(store.$payloads, perform: syncSelection)
    }

    // Folder action sheet shown on iOS 13 (replaces the Menu on that version)
    private func folderActionSheet() -> ActionSheet {
        ActionSheet(
            title: Text(""),
            buttons: [
                .default(Text(NSLocalizedString("folder.menu.change", comment: ""))) {
                    showFolderPicker = true
                },
                .destructive(Text(NSLocalizedString("folder.menu.disconnect", comment: ""))) {
                    store.clearFolder()
                },
                .cancel()
            ]
        )
    }

    private func syncSelection(_ newPayloads: [Payload]) {
        if selectedPayload == nil || !newPayloads.contains(where: { $0.id == selectedPayload?.id }) {
            selectedPayload = newPayloads.first
            portString = "\(selectedPayload?.defaultPort ?? 9021)"
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
