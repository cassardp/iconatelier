import SwiftUI
import Speech
import AVFoundation
import UIKit

// MARK: - Capture engine

@MainActor
@Observable
final class VoiceCapture {
    enum Status: Equatable {
        case idle
        case preparing
        case ready
        case recording
        case paused
        case denied
        case unavailable
        case error(String)
    }

    static let barCount = 28

    var status: Status = .idle
    var transcript: String = ""
    var levels: [Double] = Array(repeating: 0, count: VoiceCapture.barCount)
    var currentLocale: Locale
    let availableLocales: [Locale]

    private var recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var committedPrefix: String = ""
    private var tapCounter = 0

    init() {
        let supportedSet = SFSpeechRecognizer.supportedLocales()
        let resolved = Self.resolveLocale(supported: supportedSet)
        self.currentLocale = resolved
        self.recognizer = SFSpeechRecognizer(locale: resolved)
        self.availableLocales = supportedSet.sorted { a, b in
            let an = Locale.current.localizedString(forIdentifier: a.identifier) ?? a.identifier
            let bn = Locale.current.localizedString(forIdentifier: b.identifier) ?? b.identifier
            return an.localizedCaseInsensitiveCompare(bn) == .orderedAscending
        }
    }

    private static func resolveLocale(supported: Set<Locale>) -> Locale {
        for pref in Locale.preferredLanguages {
            let candidate = Locale(identifier: pref)
            let lang = candidate.language.languageCode?.identifier
            let region = candidate.region?.identifier
            if let lang, let region,
               let exact = supported.first(where: {
                   $0.language.languageCode?.identifier == lang
                   && $0.region?.identifier == region
               }) {
                return exact
            }
            if let lang,
               let anyMatch = supported.first(where: {
                   $0.language.languageCode?.identifier == lang
               }) {
                return anyMatch
            }
        }
        return Locale(identifier: "en-US")
    }

    func switchLocale(_ locale: Locale) {
        guard locale != currentLocale else { return }
        let wasRecording = status == .recording
        cleanup()
        committedPrefix = ""
        transcript = ""
        currentLocale = locale
        recognizer = SFSpeechRecognizer(locale: locale)
        status = .idle
        Task { await prepareAndStart() }
        _ = wasRecording
    }

    func prepareAndStart() async {
        guard status == .idle else { return }
        status = .preparing
        let granted = await requestPermissions()
        guard granted else { status = .denied; return }
        guard let recognizer, recognizer.isAvailable else { status = .unavailable; return }
        status = .ready
        start()
    }

    func toggle() {
        switch status {
        case .recording: pause()
        case .ready, .paused: start()
        default: break
        }
    }

    func start() {
        guard let recognizer else { return }
        guard status == .ready || status == .paused else { return }

        do {
            task?.cancel()
            task = nil

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if #available(iOS 16, *) { req.addsPunctuation = true }
            self.request = req

            let prefix = committedPrefix
            self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                let liveText: String? = result.map { $0.bestTranscription.formattedString }
                let failed = error != nil
                Task { @MainActor in
                    if let liveText {
                        self.transcript = self.merged(prefix: prefix, addition: liveText)
                    }
                    if failed {
                        self.cleanup()
                        if self.status == .recording { self.status = .paused }
                    }
                }
            }

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, weak req] buffer, _ in
                req?.append(buffer)
                self?.ingestLevel(from: buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            status = .recording
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            cleanup()
            status = .error(error.localizedDescription)
        }
    }

    func pause() {
        committedPrefix = transcript
        cleanup()
        status = .paused
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    func teardown() {
        cleanup()
        if status == .recording || status == .paused { status = .ready }
    }

    func reset() {
        committedPrefix = ""
        transcript = ""
    }

    // MARK: Private

    private func cleanup() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        levels = Array(repeating: 0, count: Self.barCount)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func merged(prefix: String, addition: String) -> String {
        let trimmedAddition = addition.trimmingCharacters(in: .whitespacesAndNewlines)
        if prefix.isEmpty { return trimmedAddition }
        if trimmedAddition.isEmpty { return prefix }
        return prefix + " " + trimmedAddition
    }

    private nonisolated func ingestLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        var sum: Float = 0
        for i in 0..<frames {
            let s = channelData[i]
            sum += s * s
        }
        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(max(rms, 0.000_001))
        let normalized = Double(max(0, min(1, (db + 50) / 50)))

        Task { @MainActor in
            self.pushLevel(normalized)
        }
    }

    private func pushLevel(_ level: Double) {
        tapCounter &+= 1
        guard tapCounter % 2 == 0 else { return }
        var copy = levels
        copy.removeFirst()
        copy.append(level)
        levels = copy
    }

    private func requestPermissions() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

// MARK: - Sheet

struct VoiceCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onUse: (String) -> Void

    @State private var capture = VoiceCapture()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                languagePicker
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                transcriptArea
                Spacer(minLength: 8)
                Waveform(levels: capture.levels, isActive: capture.status == .recording)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                hintLabel
                    .padding(.bottom, 18)
                micButton
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Voice prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onUse(transcriptTrimmed)
                        dismiss()
                    }
                    .disabled(transcriptTrimmed.isEmpty)
                }
            }
        }
        .task { await capture.prepareAndStart() }
        .onDisappear { capture.teardown() }
    }

    @ViewBuilder
    private var languagePicker: some View {
        Menu {
            ForEach(capture.availableLocales, id: \.identifier) { loc in
                Button {
                    capture.switchLocale(loc)
                } label: {
                    if loc == capture.currentLocale {
                        Label(localeName(loc), systemImage: "checkmark")
                    } else {
                        Text(localeName(loc))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.footnote.weight(.semibold))
                Text(localeName(capture.currentLocale))
                    .font(.footnote.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
        .accessibilityLabel("Recognition language")
    }

    private func localeName(_ loc: Locale) -> String {
        let display = Locale.current.localizedString(forIdentifier: loc.identifier)
            ?? loc.identifier
        return display.prefix(1).uppercased() + display.dropFirst()
    }

    private var transcriptTrimmed: String {
        capture.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var transcriptArea: some View {
        ScrollView {
            Text(transcriptTrimmed.isEmpty ? placeholderText : capture.transcript)
                .font(.title2.weight(.regular))
                .foregroundStyle(transcriptTrimmed.isEmpty ? Color.secondary : Color.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.top, 12)
        }
        .frame(maxHeight: 220)
    }

    private var placeholderText: String {
        switch capture.status {
        case .denied:
            return "Microphone or speech access was denied. Enable it in Settings."
        case .unavailable:
            return "Speech recognition isn't available on this device."
        case .error(let msg):
            return msg
        default:
            return "Describe the icon you want…"
        }
    }

    @ViewBuilder
    private var hintLabel: some View {
        let text: String = {
            switch capture.status {
            case .preparing: return "Preparing…"
            case .recording: return "Listening — tap to pause"
            case .paused: return transcriptTrimmed.isEmpty ? "Tap to start" : "Tap to keep going"
            case .ready: return "Tap to start"
            case .denied, .unavailable, .error: return ""
            case .idle: return ""
            }
        }()
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(height: 16)
    }

    @ViewBuilder
    private var micButton: some View {
        let recording = capture.status == .recording
        let enabled: Bool = {
            switch capture.status {
            case .ready, .recording, .paused: return true
            default: return false
            }
        }()

        Button {
            capture.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(recording ? Color.red : Color.primary)
                    .frame(width: 92, height: 92)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)

                if recording {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .animation(.smooth(duration: 0.25), value: recording)
        .accessibilityLabel(recording ? "Pause recording" : "Start recording")
    }
}

// MARK: - Waveform

private struct Waveform: View {
    let levels: [Double]
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            let maxHeight = geo.size.height
            HStack(spacing: 4) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    Capsule(style: .continuous)
                        .fill(barColor(for: index))
                        .frame(width: 4, height: barHeight(level: level, max: maxHeight))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 60)
        .animation(.smooth(duration: 0.12), value: levels)
    }

    private func barHeight(level: Double, max: CGFloat) -> CGFloat {
        let shaped = pow(level, 0.65)
        return Swift.max(4, CGFloat(shaped) * max)
    }

    private func barColor(for index: Int) -> Color {
        if !isActive { return .secondary.opacity(0.35) }
        let recent = index >= levels.count - 6
        return recent ? .primary : .primary.opacity(0.7)
    }
}
