//
//  SettingsScreen.swift
//  BabyLights
//
//  Pushed over the start screen: the three knobs on `TouchManager`, each a
//  row of `−  value  +`. Changes apply at once and last for the session.
//

import NucleantSwiftUI

/// One adjustable value: a title, the value as text, and a button either side.
@View
struct SettingRow {
    let title: String
    let detail: String
    let value: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.title)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(Theme.subtitle)
            HStack(spacing: 12) {
                BabyButton(title: "−", theme: .secondary, height: 36, fontSize: 18, action: decrement)
                    .frame(width: 84)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.title)
                    .frame(maxWidth: .infinity)
                BabyButton(title: "+", theme: .baby, height: 36, fontSize: 18, action: increment)
                    .frame(width: 84)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
    }
}

@View
struct SettingsScreen {
    @Environment(\.touchManager) private var touchManager

    var body: some View {
        VStack(spacing: 16) {
            SettingRow(
                title: "Max glows",
                detail: "How many glows can be on screen at once; the oldest makes room.",
                value: "\(touchManager.maxGlows)",
                decrement: { touchManager.maxGlows = max(10, touchManager.maxGlows - 10) },
                increment: { touchManager.maxGlows = min(1000, touchManager.maxGlows + 10) }
            )
            SettingRow(
                title: "Duration",
                detail: "How long a glow takes to fade out.",
                value: "\(Int(touchManager.glowSeconds)) s",
                decrement: { touchManager.glowSeconds = max(1, touchManager.glowSeconds - 1) },
                increment: { touchManager.glowSeconds = min(60, touchManager.glowSeconds + 1) }
            )
            SettingRow(
                title: "Drag interval",
                detail: "The least time between two glows from a moving finger; 0 glows on every move.",
                value: "\(Int((touchManager.dragInterval * 1000).rounded())) ms",
                decrement: { touchManager.dragInterval = max(0, touchManager.dragInterval - 0.005) },
                increment: { touchManager.dragInterval = min(0.5, touchManager.dragInterval + 0.005) }
            )
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
