import SwiftUI

// MARK: - Liquid Glass Design System (macOS)

extension View {
    func glassContainer(cornerRadius: CGFloat = 10) -> some View {
        modifier(GlassContainer(cornerRadius: cornerRadius))
    }

    func glassButtonPress() -> some View {
        modifier(GlassButtonPress())
    }

    func glassChip() -> some View {
        modifier(GlassChip())
    }
}

// MARK: - Glass Container

struct GlassContainer: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)

                    // Subtle inner glow at top edge for glass reflection
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.08), location: 0),
                            .init(color: .white.opacity(0.02), location: 0.5),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.12), location: 0),
                                .init(color: .white.opacity(0.04), location: 0.5),
                                .init(color: .white.opacity(0.06), location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Glass Button Press

struct GlassButtonPress: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1)
            .brightness(isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Glass Chip

struct GlassChip: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .opacity(isHovered ? 0.7 : 0.4)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(isHovered ? 0.08 : 0.03))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.white.opacity(isHovered ? 0.15 : 0.06))
            )
            .scaleEffect(isHovered ? 1.02 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            .onHover { h in isHovered = h }
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    let tint: Color
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isActive {
                        tint.opacity(0.85)
                    } else {
                        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                            .overlay(tint.opacity(0.3))
                    }

                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.1), location: 0),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Glass Menu Bar Background

struct GlassMenuBarBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.06), location: 0),
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.1), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Glass Divider

struct GlassDivider: View {
    var body: some View {
        Divider()
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.08), location: 0),
                        .init(color: .white.opacity(0.03), location: 0.5),
                        .init(color: .white.opacity(0.08), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// MARK: - Glass Slider Row

struct GlassSliderRow: View {
    let label: String
    let value: Binding<Float>
    let format: String
    let range: ClosedRange<Float>
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(format)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
            Slider(value: value, in: range)
                .controlSize(.small)
                .tint(tint)
        }
    }
}

// MARK: - Spring animation constants

let glassSpring = Animation.spring(response: 0.3, dampingFraction: 0.75)
let glassSpringFast = Animation.spring(response: 0.16, dampingFraction: 0.6)
let glassEaseOut = Animation.easeOut(duration: 0.18)
let glassEaseInOut = Animation.easeInOut(duration: 0.25)
