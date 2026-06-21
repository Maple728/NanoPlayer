import Foundation
import Cmpv

/// Thin Swift wrapper over the libmpv C client API.
/// Owns the mpv handle and provides typed property / command helpers.
///
/// All calls are thread-agnostic at this layer; callers (see `Player`) are
/// responsible for serializing access on a single queue.
final class MPV {
    private(set) var handle: OpaquePointer?
    private var wakeup: (() -> Void)?

    init() {
        handle = mpv_create()
    }

    deinit {
        destroy()
    }

    /// Tear down mpv. Idempotent. Call off the main thread: `mpv_terminate_destroy`
    /// blocks until the video output uninitializes, which needs the main run loop.
    func destroy() {
        guard let h = handle else { return }
        handle = nil
        mpv_set_wakeup_callback(h, nil, nil)
        mpv_terminate_destroy(h)
    }

    // MARK: - Lifecycle

    /// Set an option (only valid before `initialize()`).
    @discardableResult
    func setOption(_ name: String, _ value: String) -> Bool {
        guard let h = handle else { return false }
        return mpv_set_option_string(h, name, value) >= 0
    }

    @discardableResult
    func initialize() -> Bool {
        guard let h = handle else { return false }
        return mpv_initialize(h) >= 0
    }

    // MARK: - Event pump

    /// Register a wakeup callback. libmpv calls it from an arbitrary thread; the
    /// closure should hop to the owning queue and drain events.
    func setWakeup(_ cb: @escaping () -> Void) {
        wakeup = cb
        guard let h = handle else { return }
        mpv_set_wakeup_callback(h, { ctx in
            let me = Unmanaged<MPV>.fromOpaque(ctx!).takeUnretainedValue()
            me.wakeup?()
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    /// Non-blocking next event (returns nil when the queue is empty).
    func nextEvent() -> UnsafeMutablePointer<mpv_event>? {
        guard let h = handle else { return nil }
        let ev = mpv_wait_event(h, 0)
        if ev == nil || ev!.pointee.event_id == MPV_EVENT_NONE { return nil }
        return ev
    }

    func observe(_ name: String, format: mpv_format) {
        guard let h = handle else { return }
        mpv_observe_property(h, 0, name, format)
    }

    // MARK: - Commands

    func command(_ args: [String]) {
        guard let h = handle else { return }
        var cargs: [UnsafePointer<CChar>?] = args.map { UnsafePointer(strdup($0)) }
        cargs.append(nil)
        defer { for p in cargs where p != nil { free(UnsafeMutableRawPointer(mutating: p)) } }
        cargs.withUnsafeMutableBufferPointer { buf in
            _ = mpv_command(h, buf.baseAddress)
        }
    }

    // MARK: - Property setters

    func setString(_ name: String, _ value: String) {
        guard let h = handle else { return }
        _ = mpv_set_property_string(h, name, value)
    }

    func setFlag(_ name: String, _ value: Bool) {
        setString(name, value ? "yes" : "no")
    }

    func setDouble(_ name: String, _ value: Double) {
        guard let h = handle else { return }
        var v = value
        _ = mpv_set_property(h, name, MPV_FORMAT_DOUBLE, &v)
    }

    func setInt(_ name: String, _ value: Int64) {
        guard let h = handle else { return }
        var v = value
        _ = mpv_set_property(h, name, MPV_FORMAT_INT64, &v)
    }

    // MARK: - Property getters

    func getInt(_ name: String) -> Int64? {
        guard let h = handle else { return nil }
        var v: Int64 = 0
        return mpv_get_property(h, name, MPV_FORMAT_INT64, &v) >= 0 ? v : nil
    }

    func getDouble(_ name: String) -> Double? {
        guard let h = handle else { return nil }
        var v: Double = 0
        return mpv_get_property(h, name, MPV_FORMAT_DOUBLE, &v) >= 0 ? v : nil
    }

    func getFlag(_ name: String) -> Bool? {
        guard let h = handle else { return nil }
        var v: Int32 = 0
        return mpv_get_property(h, name, MPV_FORMAT_FLAG, &v) >= 0 ? (v != 0) : nil
    }

    func getString(_ name: String) -> String? {
        guard let h = handle else { return nil }
        guard let c = mpv_get_property_string(h, name) else { return nil }
        defer { mpv_free(c) }
        return String(cString: c)
    }
}
