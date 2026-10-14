import SwiftUI

/// The way in: the wordmark, Sign in with Apple first, then email and
/// password in one grouped card, as Settings asks for an account. The same
/// screen creates an account. It behaves like the real thing: the email is
/// checked, the password can be shown, new passwords show their rules as
/// they're met, buttons wait while they work, and a forgotten password gets
/// a reset link. In this prototype nothing is sent: logging in opens the
/// returning candidate's app, and a new account opens a new candidate's.
struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isCreatingAccount = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showsPassword = false
    /// Which button is waiting, if any.
    @State private var working: Working?
    @State private var emailError: String?
    @State private var isResettingPassword = false
    @FocusState private var field: Field?

    private enum Field { case name, email, password }
    private enum Working { case apple, email }

    // MARK: - Rules

    private static let minimumPasswordLength = 8

    private var emailLooksValid: Bool {
        let parts = email.trimmingCharacters(in: .whitespaces).split(separator: "@")
        return parts.count == 2 && parts[0].count > 0 && parts[1].contains(".") && !parts[1].hasSuffix(".")
    }

    private var passwordRules: [(text: String, isMet: Bool)] {
        [
            ("\(Self.minimumPasswordLength) characters", password.count >= Self.minimumPasswordLength),
            ("A number", password.contains(where: \.isNumber)),
            ("A letter", password.contains(where: \.isLetter)),
        ]
    }

    /// What's still missing, one thing at a time, in plain words.
    private var passwordHint: String {
        let short = Self.minimumPasswordLength - password.count
        if short > 0 { return short == 1 ? "1 more character" : "\(short) more characters" }
        if !password.contains(where: \.isNumber) { return "Add a number" }
        if !password.contains(where: \.isLetter) { return "Add a letter" }
        return "Good password"
    }

    private var canSubmit: Bool {
        guard working == nil, !email.isEmpty, !password.isEmpty else { return false }
        if isCreatingAccount {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && passwordRules.allSatisfy(\.isMet)
        }
        return true
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                // One page in both modes: the deck takes whatever height is
                // left, so spare room sits evenly round it rather than in a
                // gap above the buttons, and sign up simply gives it less.
                VStack(spacing: AppTheme.Spacing.md) {
                    wordmark
                        .padding(.top, AppTheme.Spacing.xs)
                    LoginDeck(isCreatingAccount: isCreatingAccount)
                        .frame(minHeight: 150, maxHeight: 260)
                    header

                    VStack(spacing: AppTheme.Spacing.sm) {
                        fields
                        belowFields
                    }

                    // The actions sit together at the bottom, in reach of
                    // a thumb.
                    VStack(spacing: AppTheme.Spacing.sm) {
                        PrimaryButton(title: isCreatingAccount ? "Create Account" : "Log In") {
                            submit()
                        }
                        .disabled(!canSubmit)
                        .overlay {
                            if working == .email {
                                ProgressView()
                                    .tint(.white)
                            }
                        }

                        orDivider
                        appleButton

                        switchModeLink
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.sm)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .disabled(working != nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .groupedBackground()
        .animation(.smooth(duration: 0.3), value: isCreatingAccount)
        .animation(.smooth(duration: 0.25), value: emailError)
        .sheet(isPresented: $isResettingPassword) {
            ResetPasswordSheet(email: email)
        }
        .onChange(of: email) { emailError = nil }
        .onAppear {
            // Get Started on the welcome opens straight on Sign Up.
            if appState.opensSignUp {
                isCreatingAccount = true
                appState.opensSignUp = false
            }
        }
        #if DEBUG
        .onAppear {
            // `-signup`, `-loginError` and `-reset` open those states, for screenshots.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-signup") {
                isCreatingAccount = true
                name = "Sukhraj"
                email = "sukhraj@icloud.com"
                password = "rehearse"
            }
            if arguments.contains("-loginError") {
                email = "sukhraj@icloud"
                password = "password1"
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    submit()
                }
            }
            if arguments.contains("-reset") {
                email = "sukhraj@icloud.com"
                isResettingPassword = true
            }
        }
        #endif
    }

    // MARK: - Header

    /// The logo and the wordmark, small, as the welcome pages head
    /// themselves.
    private var wordmark: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            AppLogo(size: 28)
            Text("\(Text("Rehearse").tracking(-0.6))\(Text(".").foregroundStyle(AppTheme.brand))")
                .font(.title3.bold())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rehearse")
    }

    /// The headline and its line, set like the welcome pages': large, bold
    /// and tight, on the left.
    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(isCreatingAccount ? "Create your account." : "Welcome back.")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.8)
                .contentTransition(.opacity)
            Text(isCreatingAccount
                 ? "Every interview you practice is saved, so you can watch yourself improve."
                 : "Your interviews and scores are right where you left them.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    /// A hairline either side of "or", as iOS separates sign-in choices.
    private var orDivider: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Text("or")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
        .accessibilityHidden(true)
    }

    // MARK: - Sign in with Apple

    /// Drawn to Apple's guidelines: black on light, white on dark, the logo
    /// and the standard wording. It waits a moment, as the system sheet would.
    private var appleButton: some View {
        let isDark = colorScheme == .dark
        return Button {
            signIn(with: .apple)
        } label: {
            ZStack {
                if working == .apple {
                    ProgressView()
                        .tint(isDark ? .black : .white)
                } else {
                    Label(isCreatingAccount ? "Sign up with Apple" : "Sign in with Apple", systemImage: "apple.logo")
                        .font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(isDark ? Color.black : Color.white)
            .background(isDark ? Color.white : Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Email and password

    private var fields: some View {
        VStack(spacing: 0) {
            if isCreatingAccount {
                fieldRow(symbol: "person.fill") {
                    TextField("Name", text: $name)
                        .textContentType(.givenName)
                        .focused($field, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { field = .email }
                }
                Divider().padding(.leading, Self.dividerInset)
            }
            fieldRow(symbol: "envelope.fill") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($field, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { field = .password }
            }
            Divider().padding(.leading, Self.dividerInset)
            fieldRow(symbol: "lock.fill") {
                HStack {
                    Group {
                        if showsPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textContentType(isCreatingAccount ? .newPassword : .password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($field, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canSubmit { submit() } }
                    Button {
                        showsPassword.toggle()
                    } label: {
                        Image(systemName: showsPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsPassword ? "Hide Password" : "Show Password")
                }
            }
        }
        .cardBackground()
    }

    /// Dividers start under the text, past the symbol, as in Settings.
    private static let dividerInset: CGFloat = AppTheme.Spacing.md + 24 + AppTheme.Spacing.sm

    private func fieldRow<Content: View>(symbol: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            content()
                .font(.body)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .frame(minHeight: 54)
    }

    /// An email error, the new password's rules, or Forgot Password.
    @ViewBuilder
    private var belowFields: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            if let emailError {
                Label(emailError, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.record)
                    .transition(.opacity)
            }
            if isCreatingAccount {
                // Only once a password is being typed, all on one line.
                if !password.isEmpty {
                    PasswordStrength(met: passwordRules.filter(\.isMet).count, total: passwordRules.count, hint: passwordHint)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                Button("Forgot Password?") { isResettingPassword = true }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.brand)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .tapTarget()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
        .animation(.smooth(duration: 0.2), value: password)
    }

    // MARK: - Switching between log in and sign up

    private var switchModeLink: some View {
        HStack(spacing: 4) {
            Text(isCreatingAccount ? "Already have an account?" : "New to Rehearse?")
                .foregroundStyle(.secondary)
            Button(isCreatingAccount ? "Log In" : "Sign Up") {
                isCreatingAccount.toggle()
                emailError = nil
                showsPassword = false
            }
            .fontWeight(.semibold)
            .foregroundStyle(AppTheme.brand)
        }
        .font(.subheadline)
        .tapTarget()
    }

    // MARK: - Signing in

    private func submit() {
        guard emailLooksValid else {
            emailError = "Enter an email address like name@example.com."
            field = .email
            return
        }
        signIn(with: .email)
    }

    /// Waits as a real request would, then opens the app: a new account as a
    /// new candidate, a log in as the returning one.
    private func signIn(with method: Working) {
        field = nil
        working = method
        let isNew = isCreatingAccount
        let firstName = name.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init)
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            appState.load(isNew ? .newUser : .returning)
            if isNew, let firstName { appState.candidateName = firstName }
            withAnimation(.smooth(duration: 0.4)) {
                // A new account sets up its profile first.
                appState.needsProfileSetup = isNew
                appState.isSignedIn = true
            }
            working = nil
        }
    }
}

/// How far a new password has got: a thin bar in three parts that fill as
/// each rule is met, red to orange to green, and one line saying what's
/// still missing.
private struct PasswordStrength: View {
    let met: Int
    let total: Int
    let hint: String

    private var color: Color {
        switch met {
        case total: AppTheme.practiced
        case 2: .orange
        default: AppTheme.record
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index < met ? color : AppTheme.track)
                        .frame(height: 4)
                }
            }
            .frame(width: 96)
            Text(hint)
                .font(.footnote.weight(met == total ? .semibold : .regular))
                .foregroundStyle(met == total ? AppTheme.practiced : Color.secondary)
                .contentTransition(.opacity)
            Spacer(minLength: 0)
        }
        .animation(.smooth(duration: 0.25), value: met)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Password: \(hint)")
    }
}

// MARK: - The deck

/// What's waiting inside, as cards fanned out like the welcome pages show
/// the app: the next interview behind, the last score in front. They rise
/// into place when the screen appears. Signing up, the front card shows
/// where a first score will go.
private struct LoginDeck: View {
    let isCreatingAccount: Bool
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            interviewCard
                .rotationEffect(.degrees(shown ? -5 : 0))
                .offset(x: shown ? -22 : 0, y: shown ? -50 : 0)
                .scaleEffect(0.92)
            scoreCard
                .rotationEffect(.degrees(shown ? 2.5 : 0))
                .offset(x: shown ? 18 : 0, y: shown ? 34 : 20)
        }
        .frame(height: 190)
        .scaleEffect(isCreatingAccount ? 0.88 : 1)
        .frame(maxHeight: .infinity)
        .opacity(shown ? 1 : 0)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.25).delay(0.1)) { shown = true }
        }
    }

    private var interviewCard: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            VStack(spacing: -3) {
                Text("OCT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("15")
                    .font(.title2.bold())
            }
            .frame(width: 52, height: 52)
            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple")
                    .font(.headline)
                Text("In 3 days at 3:00 PM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: 250)
        .cardBackground()
        .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
    }

    private var scoreCard: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            if isCreatingAccount {
                // No score yet: an empty ring waiting, with the way in.
                Circle()
                    .stroke(AppTheme.track, lineWidth: 8)
                    .padding(4)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.brand)
                            .offset(x: 1.5)
                    }
            } else {
                ScoreRing(score: 78, size: 60)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isCreatingAccount ? "Your First Score" : "Last Mock Interview")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(isCreatingAccount ? "Take an Interview" : "Software Engineer")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if !isCreatingAccount {
                    Label("4 since last time", systemImage: "arrow.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.success)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: 290)
        .cardBackground()
        .shadow(color: .black.opacity(0.1), radius: 16, y: 7)
    }
}

// MARK: - Forgot password

/// Asks for the email, sends a reset link (nothing is sent in the
/// prototype) and confirms where it went.
private struct ResetPasswordSheet: View {
    @State var email: String
    @State private var isSending = false
    @State private var isSent = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    private var emailLooksValid: Bool {
        let parts = email.trimmingCharacters(in: .whitespaces).split(separator: "@")
        return parts.count == 2 && parts[1].contains(".")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                if isSent {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.graphic)
                            .symbolEffect(.bounce, value: isSent)
                        Text("Check Your Email")
                            .font(.title2.bold())
                        Text("We sent a link to reset your password to \(email).")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, AppTheme.Spacing.xl)
                    .transition(.opacity)
                    Spacer()
                    PrimaryButton(title: "Done") { dismiss() }
                } else {
                    Text("Enter the email you signed up with and we’ll send you a link to reset your password.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.send)
                        .onSubmit(send)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .frame(minHeight: 52)
                        .cardBackground()
                    Spacer()
                    PrimaryButton(title: "Send Link", action: send)
                        .disabled(!emailLooksValid || isSending)
                        .overlay {
                            if isSending { ProgressView().tint(.white) }
                        }
                }
            }
            .padding(AppTheme.Spacing.md)
            .groupedBackground()
            .navigationTitle(isSent ? "" : "Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSent {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .animation(.smooth(duration: 0.3), value: isSent)
            .onAppear { if email.isEmpty { isFocused = true } }
        }
        .presentationDetents([.medium])
    }

    private func send() {
        guard emailLooksValid, !isSending else { return }
        isFocused = false
        isSending = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            isSending = false
            isSent = true
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
