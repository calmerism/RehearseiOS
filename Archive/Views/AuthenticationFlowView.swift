import SwiftUI

/// Local-only account entry for the prototype. It establishes the product
/// journey without pretending to connect to a real authentication service.
struct AuthenticationFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var route: Route = .welcome

    private enum Route: Equatable {
        case welcome
        case signIn
        case signUp
    }

    var body: some View {
        AppScreen {
            ZStack {
                switch route {
                case .welcome:
                    AccountWelcomeView(
                        onCreateAccount: { move(to: .signUp) },
                        onSignIn: { move(to: .signIn) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                case .signIn:
                    SignInView(
                        onBack: { move(to: .welcome) },
                        onCreateAccount: { move(to: .signUp) },
                        onComplete: appState.finishAuthentication
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .signUp:
                    SignUpView(
                        onBack: { move(to: .welcome) },
                        onSignIn: { move(to: .signIn) },
                        onComplete: appState.finishAuthentication
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .animation(reduceMotion ? nil : AppTheme.Motion.emphasized, value: route)
        }
    }

    private func move(to destination: Route) {
        route = destination
    }
}

private struct AccountWelcomeView: View {
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var markIsVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 42)

            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.brandTint)
                            .frame(width: 44, height: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.brand.opacity(0.18), lineWidth: 1)
                            }
                        Image(systemName: "waveform")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.brand)
                    }

                    Text("Rehearse")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                }
                .opacity(markIsVisible ? 1 : 0)
                .offset(y: markIsVisible ? 0 : 8)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Your final rehearsal\nbefore the real interview.")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Practice aloud, learn what to improve, and go in prepared.")
                        .font(.title3)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Create Account", icon: "arrow.right") {
                    AppTheme.Haptics.medium()
                    onCreateAccount()
                }
                SecondaryButton(title: "Log In") {
                    AppTheme.Haptics.light()
                    onSignIn()
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .onAppear {
            if reduceMotion {
                markIsVisible = true
            } else {
                withAnimation(.snappy(duration: 0.5, extraBounce: 0.08)) {
                    markIsVisible = true
                }
            }
        }
    }
}

private struct SignInView: View {
    let onBack: () -> Void
    let onCreateAccount: () -> Void
    let onComplete: () -> Void
    @State private var email = ""
    @State private var password = ""

    private var canContinue: Bool {
        email.contains("@") && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountBackButton(action: onBack)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Welcome back.")
                        .font(.largeTitle.weight(.bold))
                    Text("Pick up where you left off.")
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.top, 34)

                VStack(spacing: 16) {
                    AccountTextField(title: "Email", prompt: "you@example.com", text: $email, isEmail: true)
                    AccountSecureField(title: "Password", text: $password)
                }
                .padding(.top, 34)

                PrimaryButton(title: "Log In") {
                    AppTheme.Haptics.medium()
                    onComplete()
                }
                .padding(.top, 30)
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.55)

                accountAlternativeActions

                HStack(spacing: 4) {
                    Text("New to Rehearse?")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("Create Account") {
                        AppTheme.Haptics.selection()
                        onCreateAccount()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var accountAlternativeActions: some View {
        VStack(spacing: 10) {
            Text("or continue with")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.top, 24)
            SecondaryButton(title: "Continue with Apple", icon: "apple.logo") {
                AppTheme.Haptics.light()
                onComplete()
            }
            SecondaryButton(title: "Continue with Google") {
                AppTheme.Haptics.light()
                onComplete()
            }
        }
    }
}

private struct SignUpView: View {
    let onBack: () -> Void
    let onSignIn: () -> Void
    let onComplete: () -> Void
    @State private var name = ""
    @State private var school = ""
    @State private var email = ""
    @State private var password = ""
    @State private var year = "3rd Year"

    private let years = ["1st Year", "2nd Year", "3rd Year", "4th Year", "New Graduate"]

    private var canContinue: Bool {
        !name.isEmpty && email.contains("@") && password.count >= 4
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AccountBackButton(action: onBack)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Start your prep\njourney.")
                        .font(.largeTitle.weight(.bold))
                    Text("A few details, then we’ll set up your first rehearsal.")
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 34)

                VStack(spacing: 16) {
                    AccountTextField(title: "Name", prompt: "Alex", text: $name)
                    AccountTextField(title: "University / College", prompt: "Your school", text: $school)
                    AccountTextField(title: "Email", prompt: "you@example.com", text: $email, isEmail: true)
                    AccountSecureField(title: "Password", text: $password)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Year of study")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                        Picker("Year of study", selection: $year) {
                            ForEach(years, id: \.self) { year in
                                Text(year).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                    }
                }
                .padding(.top, 30)

                PrimaryButton(title: "Create Account", icon: "arrow.right") {
                    AppTheme.Haptics.medium()
                    onComplete()
                }
                .padding(.top, 30)
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.55)

                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("Log In") {
                        AppTheme.Haptics.selection()
                        onSignIn()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }
}

private struct AccountBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            AppTheme.Haptics.light()
            action()
        }) {
            Label("Back", systemImage: "chevron.left")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(minHeight: AppTheme.Size.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }
}

private struct AccountTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    var isEmail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(isEmail ? .never : .words)
                .keyboardType(isEmail ? .emailAddress : .default)
                .autocorrectionDisabled(isEmail)
                .foregroundStyle(AppTheme.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
        }
    }
}

private struct AccountSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            SecureField("Password", text: $text)
                .textContentType(.password)
                .foregroundStyle(AppTheme.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
        }
    }
}

#Preview("Account entry") {
    AuthenticationFlowView()
        .environment(AppState())
}
