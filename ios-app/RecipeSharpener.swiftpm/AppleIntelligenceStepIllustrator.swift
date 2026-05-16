import Foundation
import FoundationModels
import ImagePlayground
import UIKit

@Generable
struct KeyVisualMoment {
    @Guide(description: "1-based step index this visual moment belongs to. Must match an existing step's index.")
    var stepIndex: Int

    @Guide(description: "Short illustration prompt describing what should appear in the image. Focus on the food, ingredients, cookware, and the visible state of preparation. Avoid people, faces, hands, brand names, and text overlays. Examples: 'cubed pork belly arranged on cutting board next to ginger and scallions', 'wok with sizzling chili and Sichuan peppercorns', 'finished red-braised pork belly in a ceramic bowl with rice'.")
    var imagePrompt: String
}

@Generable
struct KeyVisualMoments {
    @Guide(description: "The 2 to 4 most useful visual checkpoints in the recipe to illustrate. Standard cookbook convention: after prep / cutting is complete, at the critical cooking transformation (e.g. when sauce comes together), and at the finished plated dish. Skip routine steps like 'wash vegetables', 'preheat oven', 'measure water'. Pick fewer when the recipe is short; pick up to 4 only when more checkpoints are clearly distinct.")
    var moments: [KeyVisualMoment]
}

struct AppleIntelligenceStepIllustrator: Sendable {
    private static let selectorInstructions = """
    You pick the few key visual moments to illustrate in a recipe — the ones \
    that a cookbook photographer would actually shoot. Standard convention:
    1. Mise en place / prep complete: ingredients cut, measured, arranged.
    2. Critical cooking moment: a transformation worth seeing (browning, sauce \
       glazing, dumpling sealing, dough rising).
    3. Finished plated dish.
    Pick 2-4 moments depending on the recipe. Skip routine steps (wash, \
    preheat, measure). For each moment, write a short illustration prompt \
    that describes what should appear in the image — focused on food and \
    cookware, no people, no faces, no text. Match the dish's cultural \
    context where appropriate (e.g. mention wok for Chinese stir-fry, \
    cazuela for Spanish stews).
    """

    func selectKeyMoments(in revision: Revision, dishName: String) async throws -> [KeyVisualMoment] {
        let session = LanguageModelSession(instructions: Self.selectorInstructions)
        let stepText = revision.steps.map { "\($0.index). \($0.text)" }.joined(separator: "\n")
        let prompt = "Dish: \(dishName)\n\nSteps:\n\(stepText)\n\nPick key visual moments and write a short prompt for each."
        let response = try await session.respond(
            to: prompt,
            generating: KeyVisualMoments.self
        )
        let validIndices = Set(revision.steps.map(\.index))
        return response.content.moments.filter { validIndices.contains($0.stepIndex) }
    }

    func generateImage(prompt: String) async throws -> URL {
        let creator = try await ImageCreator()
        for try await image in creator.images(
            for: [.text(prompt)],
            style: .animation,
            limit: 1
        ) {
            let cgImage = image.cgImage
            let uiImage = UIImage(cgImage: cgImage)
            guard let pngData = uiImage.pngData() else {
                throw IllustrationError.encodingFailed
            }
            let url = try Self.saveToDocuments(pngData)
            return url
        }
        throw IllustrationError.noImageReturned
    }

    private static func saveToDocuments(_ data: Data) throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs.appending(path: "StepIllustrations")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appending(path: "\(UUID().uuidString).png")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}

enum IllustrationError: Error, Sendable {
    case encodingFailed
    case noImageReturned
}
