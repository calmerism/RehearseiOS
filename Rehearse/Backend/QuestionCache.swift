import Foundation

/// The question bank as last downloaded, kept on the phone so the Library and
/// Warm Up appear at once on launch while a fresh copy loads behind them.
/// It's shared content, not the account's own, so it can stay across sign-ins.
/// The file is several megabytes, so reading and writing happen off the main
/// thread.
nonisolated enum QuestionCache {
    private static var url: URL {
        URL.cachesDirectory.appending(path: "questions.json")
    }

    /// The saved bank, or nothing before the first download.
    @concurrent
    static func load() async -> [Question] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Question].self, from: data)) ?? []
    }

    @concurrent
    static func save(_ questions: [Question]) async {
        guard !questions.isEmpty, let data = try? JSONEncoder().encode(questions) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
