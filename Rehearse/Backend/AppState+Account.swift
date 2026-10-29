import OSLog
import SwiftUI

/// Signing in and out of a real account, and keeping its data in step.
/// Without Supabase set up, the prototype's own flows in `LoginView` and
/// `ProfileView` still apply and nothing here runs.
extension AppState {
    /// Opens the app for the account, then fills it with the question bank
    /// and the account's saved data. A new account sets up its profile
    /// first.
    func didSignIn(_ account: AuthService.Account, isNew: Bool) {
        load(.newUser)
        self.account = account
        // A real account sees only the real question bank, and starts with
        // nothing saved; both fill in once loaded.
        library = []
        savedQuestionIDs = []
        // A new account has nothing saved to load, so its changes save
        // straight away.
        hasLoadedAccount = isNew
        if let firstName = account.firstName { candidateName = firstName }
        withAnimation(.smooth(duration: 0.4)) {
            needsProfileSetup = isNew
            isSignedIn = true
        }
        Task {
            // The saved bank first, read off the main thread, so Warm Up and
            // the Library fill in at once; the download then replaces it.
            let cached = await QuestionCache.load()
            if library.isEmpty { library = cached }
            if isNew {
                // Nothing of its own to load yet, only the question bank.
                await loadQuestionBank()
            } else {
                await refreshFromAccount()
            }
        }
    }

    /// Loads the account's interviews and rehearsals. If that fails, the app
    /// keeps what it has and tries again on the next sign in.
    func refreshFromAccount() async {
        guard account != nil else { return }
        do {
            let data = try await SyncService.load()
            // No animation: diffing thousands of questions animated stalls
            // the main thread.
            apply(data)
            hasLoadedAccount = true
        } catch {
            Logger.sync.error("Loading the account failed: \(error.localizedDescription)")
        }
    }

    func loadQuestionBank() async {
        do {
            library = try await SyncService.loadQuestions()
            await QuestionCache.save(library)
        } catch {
            Logger.sync.error("Loading the question bank failed: \(error.localizedDescription)")
        }
    }

    /// On launch, picks up the account from last time so it isn't asked to
    /// log in again.
    func restoreAccount() async {
        #if DEBUG
        // `-screen login` shows a signed-out app
        // without signing the saved account out.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-screen"), arguments.indices.contains(index + 1),
           ["welcome", "login"].contains(arguments[index + 1]) { return }
        #endif
        guard Backend.isConfigured, !isSignedIn,
              let account = await AuthService.restoredAccount() else { return }
        didSignIn(account, isNew: false)
    }

    /// Signs out of the account, if there is one, and returns to the login.
    func signOut() {
        Task {
            if Backend.isConfigured { await AuthService.signOut() }
            account = nil
            hasLoadedAccount = false
            unsavedChanges = []
            load(.newUser)
            withAnimation(.smooth(duration: 0.4)) {
                needsProfileSetup = false
                isSignedIn = false
            }
        }
    }

    /// Saves the profile, settings and Saved list after any of them changes.
    func syncProfile() {
        guard hasLoadedAccount, let account, let profile = profileSnapshot else { return }
        sync { try await SyncService.save(profile, for: account.id) }
    }

    /// Saves a change to the account in the background. The change has
    /// already happened on screen. A save that fails is tried twice more,
    /// then kept to try again later; Home says so until it goes through.
    func sync(_ work: @escaping @Sendable () async throws -> Void) {
        guard account != nil else { return }
        Task {
            if await Self.attempt(work) {
                await retryUnsavedChanges()
            } else {
                unsavedChanges.append(work)
            }
        }
    }

    /// Tries every save that failed earlier, in order, keeping any that
    /// still fail. Runs after a save succeeds, when the app comes back to the
    /// front, and from Home's Try Again.
    func retryUnsavedChanges() async {
        guard account != nil, !unsavedChanges.isEmpty, !isRetryingSaves else { return }
        isRetryingSaves = true
        defer { isRetryingSaves = false }
        let waiting = unsavedChanges
        var stillFailing: [@Sendable () async throws -> Void] = []
        for work in waiting where !(await Self.attempt(work, tries: 1)) {
            stillFailing.append(work)
        }
        // Keep saves that failed while these were being tried, too.
        unsavedChanges = stillFailing + unsavedChanges.dropFirst(waiting.count)
    }

    /// Runs a save up to `tries` times, waiting longer between each.
    private static func attempt(_ work: @Sendable () async throws -> Void, tries: Int = 3) async -> Bool {
        for attempt in 0..<tries {
            do {
                try await work()
                return true
            } catch {
                Logger.sync.error("Saving to the account failed: \(error.localizedDescription)")
                if attempt < tries - 1 { try? await Task.sleep(for: .seconds(1 << attempt)) }
            }
        }
        return false
    }

    /// Deletes the account and everything saved to it, then returns to the
    /// login. Throws, with a message to show, if it couldn't.
    func deleteAccount() async throws {
        try await AuthService.deleteAccount()
        account = nil
        hasLoadedAccount = false
        unsavedChanges = []
        load(.newUser)
        withAnimation(.smooth(duration: 0.4)) {
            needsProfileSetup = false
            isSignedIn = false
        }
    }
}

private extension Logger {
    static let sync = Logger(subsystem: "com.rehearse.prototype", category: "sync")
}
