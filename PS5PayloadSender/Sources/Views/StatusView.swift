import SwiftUI

enum SendStatus: Equatable {
    case idle
    case sending
    case success(Int)
    case error(String)
}

struct SendButtonView: View {
    let status: SendStatus
    let isEnabled: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    private var tintColor: Color {
        switch status {
        case .idle: .appBlue
        case .sending: .orange
        case .success: .green
        case .error: .red
        }
    }

    var body: some View {
        Button(action: status == .sending ? onCancel : onSend) {
            HStack(spacing: 8) {
                switch status {
                case .idle:
                    Image(systemName: "paperplane.fill")
                    Text("send.idle").font(.headline)
                case .sending:
                    SpinnerView().accentColor(.white)
                    Text("send.sending").font(.headline)
                case .success(let bytes):
                    Image(systemName: "checkmark.circle.fill")
                    Text("send.success \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))").font(.headline)
                case .error(let msg):
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(msg).font(.headline).lineLimit(1)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .disabled(!isEnabled && status == .idle)
        .primaryButtonStyle(color: tintColor)
        .opacity(!isEnabled && status == .idle ? 0.5 : 1.0)
    }
}

#Preview {
    VStack(spacing: 12) {
        SendButtonView(status: .idle, isEnabled: true, onSend: {}, onCancel: {})
        SendButtonView(status: .idle, isEnabled: false, onSend: {}, onCancel: {})
        SendButtonView(status: .sending, isEnabled: true, onSend: {}, onCancel: {})
        SendButtonView(status: .success(1543912), isEnabled: true, onSend: {}, onCancel: {})
        SendButtonView(status: .error("Connection refused"), isEnabled: true, onSend: {}, onCancel: {})
    }
    .padding()
}
