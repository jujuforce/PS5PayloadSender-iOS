import Foundation
import Network
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PS5PayloadSender", category: "PayloadSender")

enum SendError: LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case emptyPayload
    case cancelled
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return String(localized: "error.connection.failed \(msg)")
        case .sendFailed(let msg): return String(localized: "error.send.failed \(msg)")
        case .emptyPayload: return String(localized: "error.payload.empty")
        case .cancelled: return String(localized: "error.cancelled")
        case .timeout: return String(localized: "error.timeout")
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

final class PayloadSender {

    static func send(data: Data, to host: String, port: UInt16) async throws -> Int {
        guard !data.isEmpty else { throw SendError.emptyPayload }

        log.info("Connecting to \(host):\(port) (\(data.count) bytes)")

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let box = ContinuationBox(continuation)

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .setup:
                        log.debug("Connection state: setup")
                    case .preparing:
                        log.debug("Connection state: preparing")
                    case .ready:
                        log.info("Connected to \(host):\(port), sending \(data.count) bytes...")
                        connection.send(content: data, isComplete: true, completion: .contentProcessed { error in
                            if let error {
                                log.error("Send failed: \(error.localizedDescription)")
                                connection.cancel()
                                box.resume(with: .failure(SendError.sendFailed(error.localizedDescription)))
                            } else {
                                log.info("Successfully sent \(data.count) bytes to \(host):\(port)")
                                connection.cancel()
                                box.resume(with: .success(data.count))
                            }
                        })
                    case .failed(let error):
                        log.error("Connection failed: \(error.localizedDescription)")
                        connection.cancel()
                        box.resume(with: .failure(SendError.connectionFailed(error.localizedDescription)))
                    case .cancelled:
                        log.info("Connection cancelled")
                        box.resume(with: .failure(SendError.cancelled))
                    case .waiting(let error):
                        log.warning("Connection waiting: \(error.localizedDescription)")
                    @unknown default:
                        break
                    }
                }
                connection.start(queue: .global(qos: .userInitiated))

                // Timeout after 5 seconds if not connected
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                    log.error("Connection timed out after 5s")
                    connection.cancel()
                    box.resume(with: .failure(SendError.timeout))
                }
            }
        } onCancel: {
            log.info("Task cancelled, closing connection")
            connection.cancel()
        }
    }
}
