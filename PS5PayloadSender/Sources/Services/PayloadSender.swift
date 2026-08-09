import Foundation
import Network
import os

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "PS5PayloadSender", category: "PayloadSender")

enum SendError: LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case emptyPayload
    case cancelled
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return String(format: NSLocalizedString("error.connection.failed", comment: ""), msg)
        case .sendFailed(let msg): return String(format: NSLocalizedString("error.send.failed", comment: ""), msg)
        case .emptyPayload: return NSLocalizedString("error.payload.empty", comment: "")
        case .cancelled: return NSLocalizedString("error.cancelled", comment: "")
        case .timeout: return NSLocalizedString("error.timeout", comment: "")
        }
    }
}

/// Thread-safe one-shot continuation wrapper.
private final class ContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int, any Error>?

    init(_ continuation: CheckedContinuation<Int, any Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Int, any Error>) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(with: result)
    }
}

/// Cancellable, re-armable deadline.
///
/// The old code armed a bare `asyncAfter` at `connection.start()` that fired no matter
/// what the connection was doing. Two ways that bites: the system can deny a local-network
/// operation *before* the user answers the permission alert (TN3179) and leaves the
/// connection in `.waiting` until they do — nobody accepts an alert in 5s — and a payload
/// still transferring at 5s got cancelled mid-send.
private final class TimeoutBox: @unchecked Sendable {
    private let lock = NSLock()
    private var item: DispatchWorkItem?

    func arm(after seconds: TimeInterval, _ body: @escaping () -> Void) {
        let new = DispatchWorkItem(block: body)
        lock.lock()
        item?.cancel()
        item = new
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: new)
    }

    func cancel() {
        lock.lock()
        item?.cancel()
        item = nil
        lock.unlock()
    }
}

final class PayloadSender {

    static func send(data: Data, to host: String, port: UInt16) async throws -> Int {
        guard !data.isEmpty else { throw SendError.emptyPayload }

        os_log("Connecting to %{public}@:%d (%d bytes)", log: log, type: .info, host, Int(port), data.count)

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let box = ContinuationBox(continuation)
                let timeout = TimeoutBox()

                let fireTimeout: @Sendable () -> Void = {
                    os_log("Connection timed out", log: log, type: .error)
                    connection.cancel()
                    box.resume(with: .failure(SendError.timeout))
                }

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .setup:
                        os_log("Connection state: setup", log: log, type: .debug)
                    case .preparing:
                        os_log("Connection state: preparing", log: log, type: .debug)
                    case .ready:
                        // Connected: the transfer sets its own pace, so stop the clock.
                        timeout.cancel()
                        os_log("Connected to %{public}@:%d, sending %d bytes...", log: log, type: .info, host, Int(port), data.count)
                        connection.send(content: data, isComplete: true, completion: .contentProcessed { error in
                            if let error {
                                os_log("Send failed: %{public}@", log: log, type: .error, error.localizedDescription)
                                connection.cancel()
                                box.resume(with: .failure(SendError.sendFailed(error.localizedDescription)))
                            } else {
                                os_log("Successfully sent %d bytes to %{public}@:%d", log: log, type: .info, data.count, host, Int(port))
                                connection.cancel()
                                box.resume(with: .success(data.count))
                            }
                        })
                    case .failed(let error):
                        os_log("Connection failed: %{public}@", log: log, type: .error, error.localizedDescription)
                        connection.cancel()
                        box.resume(with: .failure(SendError.connectionFailed(error.localizedDescription)))
                    case .cancelled:
                        os_log("Connection cancelled", log: log, type: .info)
                        box.resume(with: .failure(SendError.cancelled))
                    case .waiting(let error):
                        // Usually the local-network alert is on screen. Give the user
                        // room to actually read and accept it before giving up.
                        os_log("Connection waiting: %{public}@", log: log, type: .default, error.localizedDescription)
                        timeout.arm(after: 30, fireTimeout)
                    @unknown default:
                        break
                    }
                }
                connection.start(queue: .global(qos: .userInitiated))
                timeout.arm(after: 5, fireTimeout)
            }
        } onCancel: {
            os_log("Task cancelled, closing connection", log: log, type: .info)
            connection.cancel()
        }
    }
}
