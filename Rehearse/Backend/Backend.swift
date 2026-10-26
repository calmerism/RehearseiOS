import Foundation
import Supabase

/// The app's one Supabase client, or nothing when the project isn't set up
/// yet, in which case every feature falls back to mock data.
nonisolated enum Backend {
    static let client: SupabaseClient? = {
        guard let url = URL(string: BackendSecrets.supabaseURL),
              url.scheme == "https",
              !BackendSecrets.supabaseAnonKey.isEmpty
        else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: BackendSecrets.supabaseAnonKey)
    }()

    static var isConfigured: Bool { client != nil }
}
