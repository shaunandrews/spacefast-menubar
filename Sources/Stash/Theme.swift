import AppKit
import CoreText
import SwiftUI

/// Stash's look, borrowed from spacefast.com: a slab with big rounded
/// corners, Strichpunkt Sans, quiet greys, and the Spacefast green. Green is a
/// fill with ink on top (the current tab, a button) in both modes; as type or
/// a small mark it's the green itself on dark, and a darker, readable green on
/// light (the bright one is 1.4:1 on white).
enum Theme {
    static let page = adaptive(light: NSColor(white: 1, alpha: 1), dark: NSColor(white: 0.055, alpha: 1))
    static let slab = adaptive(light: NSColor(white: 0.945, alpha: 1), dark: NSColor(white: 0.10, alpha: 1))
    static let raised = adaptive(light: NSColor(white: 0.895, alpha: 1), dark: NSColor(white: 0.16, alpha: 1))
    static let hairline = adaptive(light: NSColor(white: 0, alpha: 0.09), dark: NSColor(white: 1, alpha: 0.09))
    static let text = adaptive(light: NSColor(white: 0.08, alpha: 1), dark: .white)
    static let muted = adaptive(light: NSColor(white: 0.42, alpha: 1), dark: NSColor(white: 0.56, alpha: 1))
    static let faint = adaptive(light: NSColor(white: 0.60, alpha: 1), dark: NSColor(white: 0.40, alpha: 1))
    /// Selected or hovered rows.
    static let wash = adaptive(light: NSColor(white: 0, alpha: 0.05), dark: NSColor(white: 1, alpha: 0.06))
    /// Buttons that float over a screenshot: opaque enough to read on anything.
    static let chip = adaptive(light: NSColor(white: 1, alpha: 0.96), dark: NSColor(white: 0.07, alpha: 0.94))
    static let green = Color(red: 30 / 255, green: 254 / 255, blue: 87 / 255) // #1efe57, always a fill
    static let accent = adaptive(light: NSColor(red: 0.03, green: 0.52, blue: 0.20, alpha: 1),
                                 dark: NSColor(red: 30 / 255, green: 254 / 255, blue: 87 / 255, alpha: 1))
    static let greenSoft = adaptive(light: NSColor(red: 30 / 255, green: 254 / 255, blue: 87 / 255, alpha: 0.22),
                                    dark: NSColor(red: 30 / 255, green: 254 / 255, blue: 87 / 255, alpha: 0.14))
    static let ink = Color(white: 0.08) // type on green, both modes

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    static let panelRadius: CGFloat = 16
    static let rowRadius: CGFloat = 12
    static let thumbRadius: CGFloat = 12

    /// Strichpunkt Sans at a fixed size; Medium is the UI workhorse.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name = switch weight {
        case .medium: "StrichpunktSans-Medium"
        case .semibold, .bold, .heavy, .black: "StrichpunktSans-SemiBold"
        default: "StrichpunktSans-Regular"
        }
        return .custom(name, fixedSize: size)
    }

    /// The record-keeping voice: ages, codes, keycaps.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// A file from Resources: in the app bundle, or, for the bare binary (the
    /// website's screenshot render), the source tree.
    static func resource(_ path: String) -> URL? {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appending(path: "Resources")
        return [Bundle.main.resourceURL, source].compactMap { $0?.appending(path: path) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// The Spacefast mark, as a template image at `height` points.
    static func mark(height: CGFloat) -> NSImage? {
        guard let url = resource("MenuBarIcon.svg"), let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: height * image.size.width / max(image.size.height, 1), height: height)
        image.isTemplate = true
        return image
    }

    /// Strichpunkt Sans ships in Resources/Fonts.
    static func registerFonts() {
        guard let folder = resource("Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return }
        for file in files where file.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
    }
}

/// A round icon button on the slab, like spacefast.com's search button.
struct RoundButton: View {
    let symbol: String
    var size: CGFloat = 26
    var help: String = ""
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(hovering ? Theme.text : Theme.muted)
                .frame(width: size, height: size)
                .background(hovering ? Theme.raised : Theme.slab, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// The green pill: Spacefast green with ink type, and an arrow when it goes somewhere.
struct GreenPill: View {
    let title: String
    var arrow = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if arrow { Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)) }
            }
            .font(Theme.font(13, .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Theme.green.opacity(hovering ? 0.88 : 1), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A quiet pill on the slab, for the secondary action next to a green one.
struct SlabPill: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.font(13, .medium))
                .foregroundStyle(hovering ? Theme.text : Theme.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(hovering ? Theme.raised : Theme.slab, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

extension Date {
    /// "now", "36m", "3h", "2d", "5w": an age that fits a mono column.
    var compactAge: String {
        let seconds = max(0, Date().timeIntervalSince(self))
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3600))h"
        case ..<(86_400 * 7): return "\(Int(seconds / 86_400))d"
        case ..<(86_400 * 365): return "\(Int(seconds / (86_400 * 7)))w"
        default: return "\(Int(seconds / (86_400 * 365)))y"
        }
    }
}

// MARK: - Action bar

/// Hover actions as one connected bar: a rounded rect split into icon
/// segments. On a screenshot it floats, opaque with a hairline and a shadow.
struct ActionBar<Content: View>: View {
    var floating = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .padding(2)
            .background(floating ? Theme.chip : Theme.slab, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.hairline)
            }
            .shadow(color: .black.opacity(floating ? 0.22 : 0), radius: 8, y: 3)
    }
}

/// One segment of an `ActionBar`.
struct ActionIcon<Glyph: View>: View {
    var help = ""
    let action: () -> Void
    @ViewBuilder let glyph: Glyph
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            glyph
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovering ? Theme.text : Theme.muted)
                .frame(width: 28, height: 22)
                .background(hovering ? Theme.raised : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// A loading ring: a drawn arc, so it spins around its true center. (The
/// refresh arrow's visual center isn't its geometric one, so spinning the
/// arrow itself wobbles.)
struct Spinner: View {
    var size: CGFloat = 11
    @State private var turning = false

    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.88)
            .stroke(Theme.text, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(turning ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: turning)
            .onAppear { turning = true }
    }
}

// MARK: - Whimsy

/// A little tilted label stuck onto something, like the caption capsules on
/// spacefast.com's hand-drawn objects.
struct Sticker: View {
    let text: String
    var tilt: Double = -6

    var body: some View {
        Text(text)
            .font(Theme.font(10, .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.green, in: Capsule())
            .rotationEffect(.degrees(tilt))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
    }
}

/// Starring: eight specks of two sizes fly out at two distances and fade,
/// with a ring pulsing out behind them. Once per `trigger` change.
struct StarBurst: View {
    let trigger: Int

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.green, lineWidth: 2)
                .frame(width: 20, height: 20)
                .keyframeAnimator(initialValue: SpeckFrame(), trigger: trigger) { ring, frame in
                    ring.scaleEffect(frame.distance).opacity(frame.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.distance) {
                        LinearKeyframe(0.6, duration: 0.01)
                        CubicKeyframe(1.4, duration: 0.45)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0.9, duration: 0.01)
                        CubicKeyframe(0, duration: 0.5)
                    }
                }
            ForEach(0..<8, id: \.self) { index in
                let far = index.isMultiple(of: 2)
                Circle()
                    .fill(far ? Theme.green : Theme.accent)
                    .frame(width: far ? 3 : 4, height: far ? 3 : 4)
                    .keyframeAnimator(initialValue: SpeckFrame(), trigger: trigger) { speck, frame in
                        let angle = Double(index) / 8 * 2 * .pi + .pi / 8
                        speck
                            .offset(x: cos(angle) * frame.distance, y: sin(angle) * frame.distance)
                            .scaleEffect(frame.opacity)
                            .opacity(frame.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.distance) {
                            LinearKeyframe(6, duration: 0.01)
                            SpringKeyframe(far ? 16 : 12, duration: 0.45, spring: .snappy)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: 0.01)
                            LinearKeyframe(1, duration: 0.2)
                            CubicKeyframe(0, duration: 0.35)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Unstarring: three grey specks drop out of the star and fade.
struct StarDrop: View {
    let trigger: Int

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let drift = Double(index - 1) * 7
                Circle()
                    .fill(Theme.faint)
                    .frame(width: 4, height: 4)
                    .keyframeAnimator(initialValue: SpeckFrame(), trigger: trigger) { speck, frame in
                        speck.offset(x: drift * frame.distance / 18, y: frame.distance).opacity(frame.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.distance) {
                            LinearKeyframe(2, duration: 0.01)
                            CubicKeyframe(13 + Double(index % 2) * 4, duration: 0.5)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: 0.01)
                            CubicKeyframe(0, duration: 0.5)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SpeckFrame {
    var distance: Double = 0
    var opacity: Double = 0
}

/// The star's own motion: a scale and a twist.
struct StarFrame {
    var scale: Double = 1
    var angle: Double = 0
}

/// A fanned stack of cards, the doodle for empty states and sign-in: a stash.
struct CardStack: View {
    var symbol = "sparkle"
    @State private var fanned = false

    var body: some View {
        ZStack {
            card.rotationEffect(.degrees(fanned ? -14 : -6)).offset(x: fanned ? -12 : -4)
            card.rotationEffect(.degrees(fanned ? 10 : 4)).offset(x: fanned ? 12 : 4)
            card.overlay {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.accent)
            }
        }
        .frame(width: 70, height: 56)
        .onHover { inside in withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { fanned = inside } }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Theme.page)
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.hairline, lineWidth: 1.5))
            .frame(width: 34, height: 44)
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }
}
