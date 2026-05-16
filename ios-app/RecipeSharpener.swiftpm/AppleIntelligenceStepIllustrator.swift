import Foundation
import FoundationModels
import ImagePlayground
import UIKit

@Generable
struct KeyVisualMoment {
    @Guide(description: "1-based step index this visual moment belongs to. Must match an existing step's index.")
    var stepIndex: Int

    @Guide(description: "Short illustration prompt describing a cooking-in-action scene for this step. Focus on food, ingredients, cookware in motion — chopping mid-stroke, ingredients dropping into a hot pan, sauce being stirred, dough being folded. Include steam, sizzle, or movement when appropriate. Avoid people, faces, hands, brand names, and text overlays. Examples: 'cubed pork belly being added to a sizzling wok with chili and Sichuan peppercorns, oil splashing', 'sauce reducing in a pan, syrupy and glossy, wooden spoon stirring', 'dumplings being pleated on a bamboo board, flour dust in the air'.")
    var imagePrompt: String
}

@Generable
struct KeyVisualMoments {
    @Guide(description: "The 2 to 4 most useful cooking-in-action checkpoints in the recipe to illustrate. Standard cookbook demonstration convention: prep / cutting underway (ingredients being prepared), the critical cooking transformation (e.g. browning meat, glazing sauce, kneading dough), and the dish just before serving. Skip routine steps like 'wash vegetables', 'preheat oven', 'measure water'. Pick fewer when the recipe is short; pick up to 4 only when more distinct moments are clearly worth illustrating.")
    var moments: [KeyVisualMoment]
}

struct AppleIntelligenceStepIllustrator: Sendable {
    private static let selectorInstructions = """
    You pick the few key visual moments to illustrate in a recipe for a \
    cookbook demonstration — moments that show cooking IN ACTION. Standard \
    convention:
    1. Mise en place / prep underway: ingredients being cut, measured, or \
       arranged on a board.
    2. Cooking in progress: a transformation captured mid-action — meat \
       browning in a wok, sauce being stirred and thickened, dumplings \
       being folded, dough being kneaded.
    3. Near completion: the last step before serving, dish being lifted \
       from the pan or plated.
    Pick 2-4 moments depending on the recipe. Skip routine steps (wash, \
    preheat, measure water).
    For each moment, write a short illustration prompt that describes the \
    cooking moment in action — food and cookware in motion, mid-step, with \
    steam, sizzle, or movement as appropriate. No people, no faces, no \
    hands, no text overlays. Match the dish's cultural context (wok for \
    Chinese stir-fry, cazuela for Spanish stews, donabe for Japanese hot \
    pot, etc.).
    """

    func selectKeyMoments(in revision: Revision, dishName: String) async throws -> [KeyVisualMoment] {
        let session = LanguageModelSession(instructions: Self.selectorInstructions)
        let stepText = revision.steps.map { "\($0.index). \($0.text)" }.joined(separator: "\n")
        let prompt = "Dish: \(dishName)\n\nSteps:\n\(stepText)\n\nPick key visual moments showing cooking in action and write a short prompt for each."
        let response = try await session.respond(
            to: prompt,
            generating: KeyVisualMoments.self
        )
        let validIndices = Set(revision.steps.map(\.index))
        return response.content.moments.filter { validIndices.contains($0.stepIndex) }
    }

    /// Generate a representative profile image for a dish when no public-source
    /// photo is available. Output is labeled "AI generated" in the attribution
    /// chip so users know it isn't a real photo.
    func generateRecipeImage(for dishName: String) async throws -> RecipeImageResult {
        let prompt = "\(dishName) being cooked — captured mid-cooking with steam, sizzle, or motion visible. Close-up of food in the pan or wok, food and cookware only. Cookbook demonstration style."
        let url = try await generateImage(prompt: prompt)
        return RecipeImageResult(
            imageURL: url,
            attribution: ImageAttribution(
                sourceName: "AI generated",
                pageURL: nil,
                author: nil,
                licenseName: "Apple Image Playground",
                licenseURL: nil,
                title: nil
            )
        )
    }

    func generateImage(prompt: String) async throws -> URL {
        let framedPrompt = "Cookbook recipe demonstration illustration: \(prompt). The image depicts cooking IN ACTION — food being actively cooked or prepared, captured during the cooking process with steam, sizzle, or motion as appropriate. No people, no faces, no hands, no text."
        let creator = try await ImageCreator()
        for try await image in creator.images(
            for: [.text(framedPrompt)],
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
