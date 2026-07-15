//
//  ConnectivityService.swift
//  IosDevelopersGuide
//
//  Observable network connectivity. The iOS counterpart to Android's
//  `broadcastreceivers/NetworkConnectivityReceiver` and Flutter's
//  `core/connectivity/connectivity_service.dart`.
//
//  Exposes a boolean online stream so the app can surface offline state or
//  gate network calls. Wraps `NWPathMonitor` from the `Network` framework.
//

import Foundation
import Network

final class ConnectivityService: @unchecked Sendable {

    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private let lock = NSLock()
    private var listeners: [UUID: @Sendable (Bool) -> Void] = [:]

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        self.monitorQueue = DispatchQueue(label: "com.iosdevelopersguide.connectivity")
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    /// Snapshot of the current connectivity state.
    var currentlyOnline: Bool {
        monitor.currentPath.status == .satisfied
    }

    /// Stream of online/offline state, starting with the current value.
    func isOnline() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            // Seed with the current state.
            continuation.yield(self.currentlyOnline)

            let id = UUID()
            let listener: @Sendable (Bool) -> Void = { online in
                continuation.yield(online)
            }
            self.addListener(id, listener)

            continuation.onTermination = { @Sendable [weak self] _ in
                self?.removeListener(id)
            }
        }
    }

    // MARK: - Private

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let online = path.status == .satisfied
            self.broadcast(online)
        }
        monitor.start(queue: monitorQueue)
    }

    private func addListener(_ id: UUID, _ listener: @escaping @Sendable (Bool) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        listeners[id] = listener
    }

    private func removeListener(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        listeners.removeValue(forKey: id)
    }

    private func broadcast(_ online: Bool) {
        lock.lock()
        let snapshot = Array(listeners.values)
        lock.unlock()
        for listener in snapshot {
            listener(online)
        }
    }
}
