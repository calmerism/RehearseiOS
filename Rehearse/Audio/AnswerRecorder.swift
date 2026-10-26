import AVFoundation
import OSLog
import Speech

nonisolated let recorderLog = Logger(subsystem: "com.rehearse.prototype", category: "recorder")

/// What was heard for one answer: the words, and what was measured from how
/// they were said.
nonisolated struct SpokenAnswer: Sendable {
    let text: String
    let measurements: Measurements
}

/// Records one answer at a time from the microphone and transcribes it, on
/// the phone when the phone can. Nothing is kept but the transcript and the
/// measurements; no audio is saved.
@MainActor
final class AnswerRecorder {
    enum Failure: LocalizedError {
        case microphoneDenied, speechDenied, unavailable

        var errorDescription: String? {
            switch self {
            case .microphoneDenied: "Rehearse needs the microphone to hear your answer. Turn it on in Settings."
            case .speechDenied: "Rehearse needs Speech Recognition to understand your answer. Turn it on in Settings."
            case .unavailable: "Speech recognition isn’t available on this device right now. Check that Siri & Dictation is on and try again."
            }
        }
    }

    private var session: RecordingSession?

    var isRecording: Bool { session != nil }

    /// Asks for the microphone and speech recognition the first time, then
    /// starts listening.
    func start() async throws {
        cancel()
        try await Self.requestPermissions()
        let session = try RecordingSession()
        try session.start()
        self.session = session
    }

    /// Stops listening and returns what was heard, or nil if nothing was.
    /// Throws if speech recognition itself failed, so the candidate is told
    /// that rather than asked to speak up.
    func stop() async throws -> SpokenAnswer? {
        guard let session else { return nil }
        self.session = nil
        return try await session.finish()
    }

    /// Stops without keeping anything, as when the interview is left.
    func cancel() {
        session?.cancel()
        session = nil
    }

    /// Nonisolated: the system answers on a background queue, and a closure
    /// tied to the main actor would trap there.
    nonisolated private static func requestPermissions() async throws {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { throw Failure.speechDenied }
        guard await AVAudioApplication.requestRecordPermission() else { throw Failure.microphoneDenied }
    }
}

/// One recording: the audio engine feeding the recognizer. Its callbacks
/// arrive on audio and recognition threads, so its state is guarded by a lock.
private nonisolated final class RecordingSession: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private let recognizer: SFSpeechRecognizer
    private var task: SFSpeechRecognitionTask?

    private let lock = NSLock()
    private var latest: SFSpeechRecognitionResult?
    private var isDone = false
    private var failed = false
    private var waiter: CheckedContinuation<Void, Never>?

    init() throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            throw AnswerRecorder.Failure.unavailable
        }
        self.recognizer = recognizer
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        // Private and offline where the phone has the model. The simulator
        // reports the model but can't start it, so it uses Apple's servers.
        #if !targetEnvironment(simulator)
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        #endif
    }

    func start() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audio.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [self] buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [self] result, error in
            if let error { recorderLog.error("Speech recognition failed: \(error.localizedDescription)") }
            lock.lock()
            if let result { latest = result }
            if error != nil, result == nil { failed = true }
            let finished = (result?.isFinal ?? false) || error != nil
            let resume = finished ? takeWaiter() : nil
            lock.unlock()
            resume?.resume()
        }
    }

    /// Stops the audio and waits briefly for the final transcript.
    func finish() async throws -> SpokenAnswer? {
        stopAudio()
        request.endAudio()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isDone {
                lock.unlock()
                continuation.resume()
                return
            }
            waiter = continuation
            lock.unlock()
            // A final result usually arrives in well under a second.
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [self] in
                lock.lock()
                let resume = takeWaiter()
                lock.unlock()
                resume?.resume()
            }
        }
        task?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let (result, failed) = lock.withLock { (latest, failed) }
        if result == nil, failed { throw AnswerRecorder.Failure.unavailable }
        return result.flatMap(SpeechMeasurer.answer(from:))
    }

    func cancel() {
        task?.cancel()
        stopAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopAudio() {
        guard engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    /// Marks the recording done and hands back whoever is waiting. Call with
    /// the lock held.
    private func takeWaiter() -> CheckedContinuation<Void, Never>? {
        isDone = true
        let waiting = waiter
        waiter = nil
        return waiting
    }
}
