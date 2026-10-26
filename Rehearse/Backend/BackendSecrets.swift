import Foundation

/// Where the app's Supabase project lives. Fill both in from the Supabase
/// dashboard (Project Settings > API) and the app signs in for real. Left
/// empty, the app runs on its mock data, as the prototype always has.
///
/// The anon key is meant to ship in the app: row level security in
/// `supabase/schema.sql` keeps every user to their own rows. Never put the
/// service role key here.
nonisolated enum BackendSecrets {
    static let supabaseURL = ""
    static let supabaseAnonKey = ""
}
