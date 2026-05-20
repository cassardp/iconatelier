import SwiftUI
import UIKit

@MainActor
@Observable
final class AIFlowController {
    static let generationTimeoutSeconds: Int = 90

    var showPromptSheet: Bool = false
    var isGenerating: Bool = false
    var generationStartDate: Date?
    var generationError: String?
    var showNoAPIKeyAlert: Bool = false

    private var generationTask: Task<Void, Never>?

    func submit(
        subject: String,
        style: AIStyle?,
        material: AIMaterial?,
        reference: UIImage?,
        transparent: Bool,
        project: IconProject,
        session: ProjectSession,
        onSuccess: @escaping () -> Void
    ) {
        let task = Task { @MainActor in
            guard let key = await APIKeyStore.shared.load(), !key.isEmpty else {
                showNoAPIKeyAlert = true
                return
            }
            _ = key
            generationStartDate = Date()
            isGenerating = true

            let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            let subjectText = trimmedSubject.isEmpty
                ? "the subject shown in the reference image"
                : trimmedSubject
            let materialClause = material.map { ". Surface and material: \($0.promptFragment)" } ?? ""
            let finalPrompt: String
            if let style {
                let isolation = transparent ? "isolated on transparent background, " : ""
                finalPrompt = "\(subjectText), \(isolation)rendered as \(style.promptFragment)\(materialClause)"
            } else {
                finalPrompt = "\(subjectText)\(materialClause)"
            }

            let outcome: Result<UIImage, Error>
            do {
                let references = reference.map { [$0] } ?? []
                let image = try await OpenAIImageService().generateOverlay(
                    prompt: finalPrompt,
                    transparent: transparent,
                    references: references
                )
                outcome = .success(image)
            } catch {
                outcome = .failure(error)
            }

            withAnimation(.easeInOut(duration: 0.35)) {
                isGenerating = false
            }
            generationStartDate = nil
            generationTask = nil

            switch outcome {
            case .success(let image):
                withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
                    let layer = project.addGeneratedImage(image: image)
                    session.selectLayer(layer.uuid)
                }
                onSuccess()
            case .failure(let error):
                if error is CancellationError
                    || (error as? URLError)?.code == .cancelled {
                    generationError = "Generation timed out after \(Self.generationTimeoutSeconds) seconds. Please try again."
                } else {
                    generationError = error.localizedDescription
                }
            }
        }
        generationTask = task

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.generationTimeoutSeconds))
            task.cancel()
        }
    }
}
