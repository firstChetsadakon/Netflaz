import Foundation

/// Lightweight NTP-style clock synchronisation against the sync server.
///
/// Every client measures its clock offset to the server using ping/pong round
/// trips. That lets all clients express media-playback timestamps on one
/// shared clock (the server's), so a position sampled on the host can be
/// compared on a viewer *and compensated for the time the message spent in
/// flight* — the key to tight sync.
///
/// Offset math (symmetric-delay assumption, same as NTP):
///   t0 = client send time        (local clock)
///   t1 = server time at handling (server clock)
///   t3 = client receive time     (local clock)
///   rtt    = t3 - t0
///   offset = t1 - (t0 + rtt/2)    // serverClock - localClock
@MainActor
final class ClockSync {
    private(set) var offsetMillis: Double = 0
    private(set) var rttMillis: Double = 0
    private(set) var isSynced = false

    private var bestRtt = Double.greatestFiniteMagnitude

    func nowMillis() -> Double { Date().timeIntervalSince1970 * 1000 }

    /// "Now" on the shared (server) clock, in milliseconds.
    func serverNowMillis() -> Double { nowMillis() + offsetMillis }

    /// Feed a pong back in. `clientSend` is the local-clock value we stamped on
    /// the ping; `serverTime` is the server-clock value the server reported.
    func handlePong(clientSend: Double, serverTime: Double) {
        let recv = nowMillis()
        let rtt = max(0, recv - clientSend)
        let newOffset = serverTime - (clientSend + rtt / 2)

        if !isSynced || rtt <= bestRtt {
            // A lower-latency sample is a better estimate — trust it fully.
            bestRtt = rtt
            offsetMillis = newOffset
        } else {
            // Otherwise ease toward it so transient spikes don't jerk us.
            offsetMillis = offsetMillis * 0.8 + newOffset * 0.2
        }

        // Let the "best" bar rise slowly so a better sample can win later even
        // after one unusually fast round trip.
        bestRtt *= 1.05
        rttMillis = rtt
        isSynced = true
    }
}
