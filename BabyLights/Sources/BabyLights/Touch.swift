//
//  Touch.swift
//  BabyLights
//
//  The touches on the lights screen. Every press adds a glow, and a moving
//  finger adds another every `dragInterval` — so a drag leaves a trail, as
//  in the Kivy version, without a glow per pointer event — and each glow
//  fades out on its own over `glowSeconds`. Those, and how many glows may
//  be alive at once, are the settings screen's knobs.
//
//  The glows are drawn by one shader, which is told about all of them at
//  once (`packedTouches`) and fades each on its own clock: the shader's
//  `time` counts from when the lights screen came up, so a glow's start is
//  stored against the same moment (`epoch`).
//

import Foundation
import NucleantSwiftUI
import Observation

/// One glow: where it was placed, as fractions of the lights view (y-down,
/// layout space), and when.
@MainActor
@Observable
final class TouchData: Identifiable {
    let id: Int
    let x: Double
    let y: Double
    /// Offsets the hue cycle so glows don't all start on the same colour.
    let seed: Double
    let startedAt: TimeInterval

    init(id: Int, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.seed = Double.random(in: 0..<100)
        self.startedAt = Date.timeIntervalSinceReferenceDate
    }
}

@MainActor
@Observable
final class TouchManager {
    // MARK: - Settings

    /// Glows alive at once; the oldest goes when a new one would exceed it.
    var maxGlows = 200
    /// How long a glow takes to fade out.
    var glowSeconds: TimeInterval = 10
    /// The least time between two glows from one dragging finger. Zero puts
    /// a glow on every move event.
    var dragInterval: TimeInterval = 0.025

    /// How long both corners must be held before the exit dialog shows.
    nonisolated static let exitHoldSeconds: TimeInterval = 0.5

    private(set) var touches: [TouchData] = []

    /// Set when the exit gesture has been held long enough; the screen shows
    /// its confirmation while this is true.
    var exitRequested = false

    /// When the lights screen came up — the moment the glow shader's clock
    /// started, so `packedTouches` can express each glow's start in the
    /// shader's seconds.
    private var epoch = Date.timeIntervalSinceReferenceDate

    /// The glows as the shader takes them: `x, y, seed, started` per glow,
    /// with `y` flipped to shader space (y-up) and `started` in seconds since
    /// `epoch`.
    var packedTouches: [Float] {
        var packed: [Float] = []
        packed.reserveCapacity(touches.count * 4)
        for touch in touches {
            packed.append(Float(touch.x))
            packed.append(Float(1 - touch.y))
            packed.append(Float(touch.seed))
            packed.append(Float(touch.startedAt - epoch))
        }
        return packed
    }

    /// The lights screen is about to appear: restart the clock the glows
    /// are timed against.
    func start() {
        epoch = Date.timeIntervalSinceReferenceDate
    }

    /// Fingers currently down, by pointer id, as fractions of the view
    /// (y-down). The exit gesture is checked over these.
    private var active: [Int: Point] = [:]
    /// When each finger last left a glow, for the drag throttle.
    private var lastGlowAt: [Int: TimeInterval] = [:]
    private var exitTimer: Timer?
    private var fadeTimer: Timer?
    private var nextID = 0

    nonisolated init() {}

    // MARK: - Pointer

    /// A press or a move: the finger is here now. A press always glows; a
    /// move only once `dragInterval` has passed since that finger's last one.
    func pointer(id: Int, at point: Point, in bounds: Size) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let fx = min(1, max(0, point.x / bounds.width))
        let fy = min(1, max(0, point.y / bounds.height))
        let isPress = active[id] == nil
        active[id] = Point(x: fx, y: fy)
        let now = Date.timeIntervalSinceReferenceDate
        if isPress || now - (lastGlowAt[id] ?? 0) >= dragInterval {
            addGlow(x: fx, y: fy)
            lastGlowAt[id] = now
        }
        checkExitGesture()
    }

    func released(id: Int) {
        active[id] = nil
        lastGlowAt[id] = nil
        checkExitGesture()
    }

    /// Everything gone, as when the screen is left.
    func clear() {
        touches.removeAll()
        active.removeAll()
        lastGlowAt.removeAll()
        exitRequested = false
        resetExitTimer()
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    // MARK: - Glows

    private func addGlow(x: Double, y: Double) {
        if touches.count >= maxGlows {
            touches.removeFirst(touches.count - maxGlows + 1)
        }
        touches.append(TouchData(id: nextID, x: x, y: y))
        nextID += 1
        guard fadeTimer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
            // The main run loop fires this on the main thread.
            MainActor.assumeIsolated { self.prune() }
        }
        RunLoop.main.add(timer, forMode: .common)
        fadeTimer = timer
    }

    private func prune() {
        let now = Date.timeIntervalSinceReferenceDate
        touches.removeAll { now - $0.startedAt >= glowSeconds }
        if touches.isEmpty {
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
    }

    // MARK: - Exit gesture

    /// Top-left and bottom-right corners both held, by at least two
    /// fingers, for `exitHoldSeconds`.
    private func checkExitGesture() {
        var topLeft = false
        var bottomRight = false
        for point in active.values {
            if point.x < 0.15 && point.y < 0.15 { topLeft = true }
            if point.x > 0.85 && point.y > 0.85 { bottomRight = true }
        }
        guard topLeft, bottomRight, active.count >= 2 else {
            resetExitTimer()
            return
        }
        guard exitTimer == nil else { return }
        let timer = Timer(timeInterval: Self.exitHoldSeconds, repeats: false) { _ in
            MainActor.assumeIsolated {
                self.resetExitTimer()
                self.exitRequested = true
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        exitTimer = timer
    }

    private func resetExitTimer() {
        exitTimer?.invalidate()
        exitTimer = nil
    }
}
