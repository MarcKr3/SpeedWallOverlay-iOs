import SwiftUI

// MARK: - App version

/// Version text for the about card. Read from the bundle so it cannot go
/// stale when MARKETING_VERSION changes.
enum AppVersion {
    /// CFBundleShortVersionString, e.g. "1.0.1".
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

// MARK: - staccato.run promo

/// Target of the "Details at staccato.run" line.
enum StaccatoLink {
    static let url = URL(string: "https://staccato.run")!
}

/// "Speed Climbing Analysis and Training" block, shared by the welcome
/// popup and the about card.
struct StaccatoPromoSection: View {
    @Environment(\.openURL) private var openURL
    @State private var confirmLeavingApp = false

    var body: some View {
        VStack(spacing: 8) {
            Text("Speed Climbing Analysis and Training")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Desktop-App for Coaches and Athletes")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Hidden from VoiceOver: the link below is the labeled route to
            // the same action.
            Button(action: { confirmLeavingApp = true }) {
                Image("og-image")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityHidden(true)

            // The whole sentence is the tap target; only "staccato.run" is
            // styled as a link.
            Button(action: { openURL(StaccatoLink.url) }) {
                Text("Details at \(Text(verbatim: "staccato.run").underline().foregroundColor(.accentColor))")
                    .font(.subheadline)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
        }
        // The image is a large target that is easy to hit by accident, so
        // it asks before leaving the app. The text link opens directly.
        .alert("Open staccato.run?", isPresented: $confirmLeavingApp) {
            Button("Open") { openURL(StaccatoLink.url) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will leave SpeedWall Overlay and open staccato.run in your browser.")
        }
    }
}

// MARK: - Info card

enum InfoCardPlacement {
    case center
    case bottom
}

/// Dimmed scrim plus the material card used by the about section and the
/// welcome popup. The card scrolls when the screen is shorter than its
/// content (landscape iPhone).
struct InfoCardOverlay<Content: View, Corner: View>: View {
    let placement: InfoCardPlacement
    private let content: () -> Content
    private let corner: () -> Corner

    /// - Parameter corner: Small print anchored to the card's bottom-left
    ///   corner, drawn over the card's padding.
    init(
        placement: InfoCardPlacement,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder corner: @escaping () -> Corner
    ) {
        self.placement = placement
        self.content = content
        self.corner = corner
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    card
                    if placement == .center {
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                .contentShape(Rectangle())
            }
        }
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }

    private var card: some View {
        VStack(spacing: 16, content: content)
            .padding(30)
            .background(.regularMaterial)
            .cornerRadius(20)
            .overlay(alignment: .bottomLeading, content: corner)
            .padding()
    }
}

extension InfoCardOverlay where Corner == EmptyView {
    init(placement: InfoCardPlacement, @ViewBuilder content: @escaping () -> Content) {
        self.init(placement: placement, content: content, corner: { EmptyView() })
    }
}

// MARK: - Checkbox

/// iOS has no checkbox toggle style. This one looks like the macOS
/// checkbox: a small rounded square, filled with the accent color and a
/// white checkmark when on.
struct CheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(configuration.isOn ? Color.accentColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(configuration.isOn ? Color.accentColor : Color.secondary, lineWidth: 1.5)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(configuration.isOn ? 1 : 0)
                    )
                    .frame(width: 18, height: 18)

                configuration.label
                    .font(.subheadline)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

// MARK: - Welcome popup

/// Startup popup. `AppState.showWelcome` keeps it visible on every launch
/// until the user checks "Don't show again".
struct WelcomeOverlay: View {
    @EnvironmentObject var appState: AppState
    @State private var dontShowAgain = false

    var body: some View {
        InfoCardOverlay(placement: .center) {
            Text("Thanks for using SpeedWall Overlay!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Divider()

            StaccatoPromoSection()

            Toggle("Don't show again", isOn: $dontShowAgain)
                .toggleStyle(CheckboxStyle())

            Button("Close") {
                appState.dismissWelcome(dontShowAgain: dontShowAgain)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Welcome") {
    WelcomeOverlay()
        .environmentObject(AppState())
}
