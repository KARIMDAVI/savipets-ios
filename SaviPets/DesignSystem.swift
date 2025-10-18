import SwiftUI

// MARK: - SaviPets Design System

enum SPDesignSystem {
    // MARK: Roles - canonical values used across the app and in Firestore
    enum Roles {
        static let petOwner: String = "petOwner"
        static let petSitter: String = "petSitter"
        static let admin: String = "admin"
    }
    // MARK: Colors
    enum Colors {
        static let primary = Color(hex: "#FFD700")
        static let secondary = Color(hex: "#F4C430")
        static let darkYellow = Color(hex: "#262200")
        static let dark = Color(hex: "#333333")
        static let white = Color.white
        static let success = Color(hex: "#34C759")
        static let error = Color(hex: "#FF3B30")
        
        // Chat-specific colors (Smartsupp-inspired with SaviPets yellow theme)
        static let chatYellow = Color(hex: "#FFD54F")       // Primary yellow for outgoing messages
        static let chatYellowLight = Color(hex: "#FFF9E6")  // Light yellow for backgrounds
        static let chatTextDark = Color(hex: "#333333")     // Dark text
        static let chatBubbleIncoming = Color.white         // Incoming message background
        static let chatBubbleBorder = Color(hex: "#E0E0E0") // Border for incoming messages

        // Balanced surfaces for light/dark
        static func surface(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.06) : Color.white
        }
        static func elevatedSurface(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.9)
        }

        // Adjusted primary for light mode to avoid excessive brightness
        static func primaryAdjusted(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? primary : darkYellow
        }

        static func goldenGradient(_ scheme: ColorScheme) -> LinearGradient {
            let start = primaryAdjusted(scheme)
            let end = scheme == .dark ? secondary : darkYellow
            return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        static var glassBorder: LinearGradient {
            LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        // Background for content views (balanced for light/dark)
        static func background(scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hex: "#1A1A1A") : Color(hex: "#F5F5F5")
        }
    }

    // MARK: Spacing (8pt grid)
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
    }

    // MARK: Typography
    enum Typography {
        // Brand/Display
        static func brandLarge() -> Font { .custom("Apple SD Gothic Neo", size: 46, relativeTo: .largeTitle) }
        static func brandMedium() -> Font { .custom("Apple SD Gothic Neo", size: 29, relativeTo: .title) }
        static func display() -> Font { .system(.largeTitle, design: .rounded).weight(.heavy) }

        // Headings
        static func heading1() -> Font { .system(.title, design: .rounded).weight(.bold) }
        static func heading2() -> Font { .system(.title2, design: .rounded).weight(.semibold) }
        static func heading3() -> Font { .system(.title3, design: .rounded).weight(.semibold) }

        // Body: SF Pro Text
        static func body() -> Font { .system(.body, design: .default) }
        static func bodyMedium() -> Font { .system(.body, design: .default).weight(.medium) }
        static func callout() -> Font { .system(.callout, design: .default) }
        static func footnote() -> Font { .system(.footnote, design: .default) }
        static func button() -> Font { .system(.headline, design: .rounded).weight(.semibold) }
    }
}

// MARK: - Utilities

extension Color {
    init(hex: String) {
        let r, g, b, a: CGFloat

        var hexString = hex
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        if hexString.count == 6 { hexString.append("FF") }

        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0

        if scanner.scanHexInt64(&hexNumber) {
            r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000FF) / 255
        } else {
            r = 1; g = 1; b = 1; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Components

// Standard card (glassy)
struct SPCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .padding(SPDesignSystem.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCardStyle()
    }
}

struct GlassBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SPDesignSystem.Colors.glassBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 3, x: 0, y: 1)
    }
}

extension View {
    func glass() -> some View { modifier(GlassBackground()) }
    func glassCardStyle() -> some View { modifier(GlassBackground()) }
    func threeDButtonStyle() -> some View { modifier(ThreeDButtonModifier()) }
}

// MARK: - 3D Button Modifier
struct ThreeDButtonModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: .black.opacity(isPressed ? 0.1 : 0.2), radius: isPressed ? 8 : 15, x: 0, y: isPressed ? 4 : 8)
            .shadow(color: .black.opacity(isPressed ? 0.05 : 0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
            }
    }
}

// MARK: - Buttons

enum SPButtonKind { case primary, secondary, dark, ghost }

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SPDesignSystem.Typography.button())
            .padding(.vertical, SPDesignSystem.Spacing.m - 2)
            .frame(maxWidth: .infinity)
            .background(SPDesignSystem.Colors.goldenGradient(colorScheme))
            .foregroundColor(SPDesignSystem.Colors.dark)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.2), radius: configuration.isPressed ? 8 : 15, x: 0, y: configuration.isPressed ? 4 : 8)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.1), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Variant: in light mode, force bright yellow gradient (primary/secondary)
struct PrimaryButtonStyleBrightInLight: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        let bg: LinearGradient = {
            if colorScheme == .light {
                return LinearGradient(colors: [SPDesignSystem.Colors.primary, SPDesignSystem.Colors.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                return SPDesignSystem.Colors.goldenGradient(colorScheme)
            }
        }()

        return configuration.label
            .font(SPDesignSystem.Typography.button())
            .padding(.vertical, SPDesignSystem.Spacing.m - 2)
            .frame(maxWidth: .infinity)
            .background(bg)
            .foregroundColor(SPDesignSystem.Colors.dark)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.2), radius: configuration.isPressed ? 8 : 15, x: 0, y: configuration.isPressed ? 4 : 8)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.1), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SPDesignSystem.Typography.button())
            .padding(.vertical, SPDesignSystem.Spacing.m - 2)
            .frame(maxWidth: .infinity)
            .background(SPDesignSystem.Colors.secondary)
            .foregroundColor(SPDesignSystem.Colors.dark)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.2), radius: configuration.isPressed ? 8 : 15, x: 0, y: configuration.isPressed ? 4 : 8)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.1), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SPDesignSystem.Typography.button())
            .padding(.vertical, SPDesignSystem.Spacing.m - 2)
            .frame(maxWidth: .infinity)
            .background(SPDesignSystem.Colors.dark)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.2), radius: configuration.isPressed ? 8 : 15, x: 0, y: configuration.isPressed ? 4 : 8)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.1), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SPDesignSystem.Typography.button())
            .padding(.vertical, SPDesignSystem.Spacing.m - 2)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.4) : SPDesignSystem.Colors.dark.opacity(0.25), lineWidth: 1)
            )
            .foregroundColor(colorScheme == .dark ? .white : SPDesignSystem.Colors.dark)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.1), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SPButton: View {
    let title: String
    let kind: SPButtonKind
    var isLoading: Bool = false
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        let label = HStack(spacing: SPDesignSystem.Spacing.s) {
            if isLoading {
                let tint: Color = (kind == .primary || kind == .secondary) ? SPDesignSystem.Colors.dark : .white
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: tint))
            }
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .frame(maxWidth: .infinity)

        let button = Button(action: { if !isLoading { action() } }) { label }
            .disabled(isLoading)

        switch kind {
        case .primary:
            button.buttonStyle(PrimaryButtonStyle())
        case .secondary:
            button.buttonStyle(SecondaryButtonStyle())
        case .dark:
            button.buttonStyle(DarkButtonStyle())
        case .ghost:
            button.buttonStyle(GhostButtonStyle())
        }
    }
}

// MARK: - Floating Text Field

struct FloatingTextField: View {
    enum FieldKind { case text, email, secure }

    let title: String
    @Binding var text: String
    var kind: FieldKind = .text
    var error: String? = nil

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
                    )
                    .frame(height: 56)

                field
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(kind == .email ? .emailAddress : .default)
                    .focused($isFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, (isFocused || !text.isEmpty) ? 12 : 0)

                Text(title)
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(titleColor)
                    .padding(.horizontal, SPDesignSystem.Spacing.s)
                    .background(Color(.secondarySystemBackground))
                    .offset(y: (isFocused || !text.isEmpty) ? -24 : 0)
                    .scaleEffect((isFocused || !text.isEmpty) ? 0.9 : 1, anchor: .leading)
                    .offset(x: (isFocused || !text.isEmpty) ? 8 : 16)
                    .animation(.easeOut(duration: 0.2), value: isFocused || !text.isEmpty)
            }

            if let error, !error.isEmpty {
                Text(error)
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(SPDesignSystem.Colors.error)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }

    private var borderColor: Color {
        if let error, !error.isEmpty { return SPDesignSystem.Colors.error }
        return isFocused ? SPDesignSystem.Colors.primaryAdjusted(colorScheme) : Color.primary.opacity(0.12)
    }

    private var titleColor: Color {
        if let error, !error.isEmpty { return SPDesignSystem.Colors.error }
        if isFocused {
            return colorScheme == .dark ? SPDesignSystem.Colors.primary : SPDesignSystem.Colors.darkYellow
        }
        return Color.secondary
    }

    @ViewBuilder private var field: some View {
        switch kind {
        case .text, .email:
            TextField("", text: $text)
        case .secure:
            SecureField("", text: $text)
        }
    }
}

// MARK: - Loading / Skeleton

struct ShimmerView: View {
    @State private var phase: CGFloat = -1
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        let base = SPDesignSystem.Colors.primaryAdjusted(colorScheme)
        let gradient = LinearGradient(colors: [base.opacity(0.05), base.opacity(0.25), base.opacity(0.05)], startPoint: .leading, endPoint: .trailing)

        Rectangle()
            .fill(gradient)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(gradient: Gradient(stops: [
                            .init(color: .white.opacity(0), location: 0),
                            .init(color: .white, location: 0.5),
                            .init(color: .white.opacity(0), location: 1)
                        ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: phase * 300)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.m) {
            ShimmerView().frame(height: 56)
            ShimmerView().frame(height: 120)
            ShimmerView().frame(height: 56)
        }
        .padding(SPDesignSystem.Spacing.m)
    }
}

// MARK: - Preview

struct SaviPetsDesignSystem_Preview: View {
    @State private var emailText: String = ""
    @State private var passwordText: String = ""
    @State private var nameText: String = "Savi the Pet"
    @State private var isLoading: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.xl) {
                Text("SaviPets Design Showcase")
                    .font(SPDesignSystem.Typography.display())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))

                SPCard {
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Headings").font(SPDesignSystem.Typography.heading1())
                        Text("Heading 2: Pet Profile").font(SPDesignSystem.Typography.heading2())
                        Text("Heading 3: Subtitle/Callout").font(SPDesignSystem.Typography.heading3())
                        Divider()
                        Text("This is the main body text used for descriptions and content. It's legible and clear.")
                            .font(SPDesignSystem.Typography.body())
                        Text("Footnote text for smaller details, terms, or dates.")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                    }
                }

                SPCard {
                    VStack(spacing: SPDesignSystem.Spacing.l) {
                        Text("Form Elements").font(SPDesignSystem.Typography.heading1()).frame(maxWidth: .infinity, alignment: .leading)
                        FloatingTextField(title: "Pet Name", text: $nameText, kind: .text)
                        FloatingTextField(title: "Email Address", text: $emailText, kind: .email, error: emailText.isEmpty ? "Email is required." : nil)
                        FloatingTextField(title: "Password", text: $passwordText, kind: .secure, error: "Password must be at least 8 characters.")
                    }
                }

                SPCard {
                    VStack(spacing: SPDesignSystem.Spacing.m) {
                        Text("Buttons").font(SPDesignSystem.Typography.heading1()).frame(maxWidth: .infinity, alignment: .leading)
                        SPButton(title: "Primary Action", kind: .primary, systemImage: "pawprint.fill", action: { isLoading.toggle() })
                        SPButton(title: "Secondary Button", kind: .secondary, systemImage: "sparkles", action: {})
                        SPButton(title: "Dark/Confirmation Button", kind: .dark, systemImage: "lock.fill", action: {})
                        SPButton(title: "Ghost/Tertiary Button", kind: .ghost, action: {})
                    }
                }

                VStack(alignment: .leading) {
                    Text("Loading State (Shimmer)").font(SPDesignSystem.Typography.heading1()).padding(.leading, SPDesignSystem.Spacing.m)
                    LoadingStateView()
                }
            }
            .padding(SPDesignSystem.Spacing.l)
            .padding(.top, SPDesignSystem.Spacing.xxl)
        }
        .background(SPDesignSystem.Colors.background(scheme: colorScheme).ignoresSafeArea())
    }
}

struct SaviPetsDesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        SaviPetsDesignSystem_Preview()
            .preferredColorScheme(.dark)
    }
}
