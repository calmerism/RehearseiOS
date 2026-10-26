import Foundation
import Supabase

/// Accounts: creating one, logging in and out, resetting a password,
/// restoring the last session on launch, and deleting the account. Only
/// called when `Backend.isConfigured`; otherwise the app signs in to its
/// mock data as before.
nonisolated enum AuthService {
    /// Who is signed in, as the app needs them.
    struct Account: Sendable, Equatable {
        let id: UUID
        let email: String
        let fullName: String

        var firstName: String? {
            fullName.split(separator: " ").first.map(String.init)
        }
    }

    /// What happened when creating an account.
    enum SignUpResult: Sendable {
        /// Signed in straight away.
        case signedIn(Account)
        /// The project asks new accounts to confirm their email first.
        case confirmEmail
    }

    /// A failure, worded for the person signing in.
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static var auth: AuthClient {
        get throws {
            guard let client = Backend.client else {
                throw Failure(message: "Accounts aren’t set up in this build yet.")
            }
            return client.auth
        }
    }

    static func signUp(name: String, email: String, password: String) async throws -> SignUpResult {
        do {
            let response = try await auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(name)]
            )
            guard response.session != nil else { return .confirmEmail }
            return .signedIn(account(response.user))
        } catch {
            throw failure(error)
        }
    }

    static func signIn(email: String, password: String) async throws -> Account {
        do {
            let session = try await auth.signIn(email: email, password: password)
            return account(session.user)
        } catch {
            throw failure(error)
        }
    }

    static func sendPasswordReset(to email: String) async throws {
        do {
            try await auth.resetPasswordForEmail(email)
        } catch {
            throw failure(error)
        }
    }

    static func signOut() async {
        try? await auth.signOut()
    }

    /// The account from the last launch, if its session is still good.
    static func restoredAccount() async -> Account? {
        guard let session = try? await auth.session, !session.isExpired else { return nil }
        return account(session.user)
    }

    /// Deletes the account and everything in it. The database cascades the
    /// rows; see `delete_account` in `supabase/schema.sql`.
    static func deleteAccount() async throws {
        guard let client = Backend.client else { return }
        do {
            try await client.rpc("delete_account").execute()
            try? await client.auth.signOut()
        } catch {
            throw failure(error)
        }
    }

    // MARK: - Mapping

    private static func account(_ user: User) -> Account {
        Account(
            id: user.id,
            email: user.email ?? "",
            fullName: user.userMetadata["full_name"]?.stringValue ?? ""
        )
    }

    /// Supabase's error codes in plain words; anything else as it came.
    private static func failure(_ error: Error) -> Failure {
        if let failure = error as? Failure { return failure }
        if error is URLError {
            return Failure(message: "Couldn’t reach Rehearse. Check your connection and try again.")
        }
        let code = (error as? AuthError)?.errorCode.rawValue ?? ""
        switch code {
        case "invalid_credentials":
            return Failure(message: "That email and password don’t match.")
        case "user_already_exists", "email_exists":
            return Failure(message: "There’s already an account with this email. Log in instead.")
        case "email_not_confirmed":
            return Failure(message: "Confirm your email first, using the link we sent.")
        case "weak_password":
            return Failure(message: "Choose a stronger password.")
        case "over_email_send_rate_limit", "over_request_rate_limit":
            return Failure(message: "Too many tries. Wait a minute and try again.")
        default:
            return Failure(message: error.localizedDescription)
        }
    }
}
