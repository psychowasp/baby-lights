//
//  MainScreen.swift
//  BabyLights
//
//  The parent's screen: title, a big START, About — and the dialogs, drawn
//  as a dimmed layer over whatever screen is up.
//

import NucleantSwiftUI

/// The Kivy version's palette.
struct Theme {
    static let background = Color(red: 0.95, green: 0.97, blue: 1)
    static let title = Color(red: 0.2, green: 0.3, blue: 0.6)
    static let subtitle = Color(white: 0.4)
}

enum ButtonTheme {
    case baby, secondary

    var background: Color {
        switch self {
        case .baby:      return Color(red: 1, green: 0.8, blue: 0.9)
        case .secondary: return Color(white: 0.9)
        }
    }

    var foreground: Color {
        switch self {
        case .baby:      return Color(red: 0.4, green: 0.2, blue: 0.4)
        case .secondary: return Color(white: 0.2)
        }
    }
}

/// The face of this app's buttons: a rounded, shadowed label. Worn by
/// `BabyButton`, and by the `NavigationLink` that opens the settings.
@View
struct BabyLabel {
    let title: String
    let theme: ButtonTheme
    let height: Double
    let fontSize: Double

    var body: some View {
        Text(title)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(theme.foreground)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0, opacity: 0.1))
                        .offset(x: 2, y: 2)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.background)
                }
            )
    }
}

/// A `Button` in this app's colours and sizes, with the button's own chrome
/// tinted away.
@View
struct BabyButton {
    let title: String
    let theme: ButtonTheme
    let height: Double
    let fontSize: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BabyLabel(title: title, theme: theme, height: height, fontSize: fontSize)
        }
        .tint(.clear)
    }
}

@View
struct MainScreen {
    var body: some View {
        VStack(spacing: 30) {
            Text("Baby Lights")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Theme.title)
                .multilineTextAlignment(.center)
            Text("Simple visual effects for your little one")
                .font(.system(size: 18))
                .foregroundColor(Theme.subtitle)
                .multilineTextAlignment(.center)
            VStack(spacing: 20) {
                BabyButton(title: "START", theme: .baby, height: 80, fontSize: 24) {
                    AppModel.shared.modal = .startConfirmation
                }
                BabyButton(title: "About", theme: .secondary, height: 36, fontSize: 12) {
                    AppModel.shared.modal = .about
                }
                .frame(width: 120)
                NavigationLink(title: "Settings") {
                    SettingsScreen()
                } label: {
                    BabyLabel(title: "Settings", theme: .secondary, height: 36, fontSize: 12)
                }
                .frame(width: 120)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(horizontal: 16, vertical: 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

// MARK: - Dialogs

/// A dimmed layer that swallows presses, with a card in the middle. Which
/// buttons it has, and what they do, follows from `kind`, so the view holds
/// no closures and is rebuilt only when the kind changes.
@View
struct Dialog {
    let kind: AppModel.Modal
    @Environment(\.touchManager) private var touchManager

    init(_ kind: AppModel.Modal) {
        self.kind = kind
    }

    var body: some View {
        ZStack {
            Color(white: 0, opacity: 0.3)
                .onTapGesture {}
            VStack(spacing: 20) {
                Text(kind.title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(Theme.title)
                Text(kind.message)
                    .font(.system(size: 18))
                    .foregroundColor(Theme.title)
                    .multilineTextAlignment(.center)
                buttons
            }
            .padding(20)
            .frame(width: 340)
            .background(Theme.background)
            .cornerRadius(12)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var buttons: some View {
        HStack(spacing: 15) {
            switch kind {
            case .startConfirmation:
                BabyButton(title: "Cancel", theme: .secondary, height: 40, fontSize: 14) {
                    AppModel.shared.modal = nil
                }
                BabyButton(title: "Start", theme: .baby, height: 40, fontSize: 14) {
                    AppModel.shared.modal = nil
                    touchManager.start()
                    AppModel.shared.screen = .lights
                }
            case .about:
                BabyButton(title: "Got it", theme: .baby, height: 40, fontSize: 14) {
                    AppModel.shared.modal = nil
                }
                .frame(width: 120)
            case .exitConfirmation:
                BabyButton(title: "Stay", theme: .secondary, height: 40, fontSize: 14) {
                    touchManager.exitRequested = false
                }
                BabyButton(title: "Exit", theme: .baby, height: 40, fontSize: 14) {
                    touchManager.clear()
                    AppModel.shared.screen = .main
                }
            }
        }
    }
}
