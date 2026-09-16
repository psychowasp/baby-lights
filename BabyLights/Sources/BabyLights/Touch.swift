//
//  Touch.swift
//  BabyLights
//
//  The touches on the lights screen. Every press and every move adds a
//  glow — as the Kivy version did — so a dragged finger leaves a trail,
//  and each glow fades out on its own over `TouchManager.glowSeconds`.
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
    /// Glows alive at once; the oldest goes when a new one would exceed it.
    nonisolated static let maxGlows = 200
    nonisolated static let glowSeconds: TimeInterval = 10
    /// How long both corners must be held before the exit dialog shows.
    nonisolated static let exitHoldSeconds: TimeInterval = 0.5

    private(set) var touches: [TouchData] = []
    /// The lights view's size in points, from the last pointer event — what
    /// a glow's fractions are turned back into a frame with.
    private(set) var viewSize = Size(width: 0, height: 0)

    /// Set when the exit gesture has been held long enough; the screen shows
    /// its confirmation while this is true.
    var exitRequested = false

    /// Fingers currently down, by pointer id, as fractions of the view
    /// (y-down). The exit gesture is checked over these.
    private var active: [Int: Point] = [:]
    private var exitTimer: Timer?
    private var fadeTimer: Timer?
    private var nextID = 0

    nonisolated init() {}

    // MARK: - Pointer

    /// A press or a move: the finger is here now.
    func pointer(id: Int, at point: Point, in bounds: Size) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let fx = min(1, max(0, point.x / bounds.width))
        let fy = min(1, max(0, point.y / bounds.height))
        viewSize = bounds
        active[id] = Point(x: fx, y: fy)
        addGlow(x: fx, y: fy)
        checkExitGesture()
    }

    func released(id: Int) {
        active[id] = nil
        checkExitGesture()
    }

    /// Everything gone, as when the screen is left.
    func clear() {
        touches.removeAll()
        active.removeAll()
        exitRequested = false
        resetExitTimer()
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    // MARK: - Glows

    private func addGlow(x: Double, y: Double) {
        if touches.count >= Self.maxGlows {
            touches.removeFirst()
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
        touches.removeAll { now - $0.startedAt >= Self.glowSeconds }
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
