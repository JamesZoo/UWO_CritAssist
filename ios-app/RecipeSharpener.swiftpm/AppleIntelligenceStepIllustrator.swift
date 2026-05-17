import Foundation
import FoundationModels
import ImagePlayground
import UIKit

@Generable
struct StepPhotoAssignment {
    @Guide(description: "0-based index into the provided photos list (0 = first photo).")
    var imageIndex: Int

    @Guide(description: "The step index (1-based, matching the step numbers in the recipe) that this photo best illustrates.")
    var stepIndex: Int
}

@Generable
struct StepPhotoAssignments {
    @Guide(description: "Pairs matching Wikipedia photos to recipe steps. Include only confident matches where the photo description clearly relates to what the step involves — same ingredient, technique, or cooking stage. Each imageIndex at most once. Skip photos with no description or with no clear step match.")
    var assignments: [StepPhotoAssignment]
}

struct AppleIntelligenceStepIllustrator: Sendable {
    private static let matchingInstructions = """
    You match food photos (described by their Wikipedia captions) to the steps \
    of a recipe. A photo matches a step when its caption clearly relates to what \
    that step does — the same ingredient, cooking technique, or stage of cooking. \
    Only make confident, specific matches. Skip photos whose caption is vague, \
    empty, or describes only the finished plated dish without relating to any \
    specific step.
    """

    // MARK: - StepIllustrator

    func illustrateSteps(in revision: Revision, dishName: String, sourceURL: URL?) async throws -> [(stepIndex: Int, imageURL: URL)] {
        // Tier 1: JSON-LD per-step images from the recipe source URL.
        // Each HowToStep carries its instruction text, which we use as the
        // photo description for AI matching — the same path as Wikipedia photos.
        // This handles cases where the JSON-LD has more images than recipe steps
        // or where the parsed step order differs from the website's order.
        if let url = sourceURL {
            let extractor = RecipeSourceImageExtractor()
            let pairs = await extractor.extractStepImages(from: url)
            if !pairs.isEmpty {
                let photos = pairs.map { ArticleStepPhoto(imageURL: $0.imageURL, description: $0.description) }
                let matched = await matchPhotosToSteps(photos: photos, revision: revision)
                var result: [(stepIndex: Int, imageURL: URL)] = []
                for (stepIndex, photo) in matched {
                    guard let local = try? await downloadAndSave(photo.imageURL) else { continue }
                    result.append((stepIndex: stepIndex, imageURL: local))
                }
                if !result.isEmpty { return result }
            }
        }

        // Tier 2: Wikipedia article photos matched by caption text.
        // Also used when sourceURL is nil (dish-name recipes) or when the
        // source page has no per-step JSON-LD images (including Wikipedia
        // itself, which lacks Schema.org recipe markup).
        let photoService = WikimediaStepPhotoService()
        let photos = await photoService.fetchArticlePhotos(for: dishName)
        guard !photos.isEmpty else { return [] }

        let matched = await matchPhotosToSteps(photos: photos, revision: revision)
        var result: [(stepIndex: Int, imageURL: URL)] = []
        for (stepIndex, photo) in matched {
            guard let local = try? await downloadAndSave(photo.imageURL) else { continue }
            result.append((stepIndex: stepIndex, imageURL: local))
        }
        return result
    }

    private func matchPhotosToSteps(
        photos: [ArticleStepPhoto],
        revision: Revision
    ) async -> [(stepIndex: Int, photo: ArticleStepPhoto)] {
        let session = LanguageModelSession(instructions: Self.matchingInstructions)
        let stepLines = revision.steps.map { "\($0.index). \($0.text)" }.joined(separator: "\n")
        var photoLines = ""
        for (i, photo) in photos.enumerated() {
            let desc = photo.description.isEmpty ? "(no description)" : photo.description
            photoLines += "\(i): \(desc)\n"
        }
        let prompt = "Recipe steps:\n\(stepLines)\n\nPhotos (index: caption):\n\(photoLines)\nMatch photos to steps."
        guard let response = try? await session.respond(
            to: prompt,
            generating: StepPhotoAssignments.self
        ) else { return [] }

        let validStepIndices = Set(revision.steps.map(\.index))
        var usedImageIndices = Set<Int>()
        var result: [(stepIndex: Int, photo: ArticleStepPhoto)] = []
        for assignment in response.content.assignments {
            guard assignment.imageIndex >= 0, assignment.imageIndex < photos.count else { continue }
            guard validStepIndices.contains(assignment.stepIndex) else { continue }
            guard !usedImageIndices.contains(assignment.imageIndex) else { continue }
            usedImageIndices.insert(assignment.imageIndex)
            result.append((stepIndex: assignment.stepIndex, photo: photos[assignment.imageIndex]))
        }
        return result
    }

    private func downloadAndSave(_ remoteURL: URL) async throws -> URL {
        var req = URLRequest(url: remoteURL)
        req.setValue("RecipeSharpener/0.1 (iPad)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: req)
        let ext = remoteURL.pathExtension.lowercased()
        let fileExt = ext.isEmpty ? "jpg" : ext
        return try Self.saveToDocuments(data, extension: fileExt)
    }

    // MARK: - ProfileImageGenerator

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

    private func generateImage(prompt: String) async throws -> URL {
        let framedPrompt = "Cookbook recipe demonstration illustration: \(prompt). Food being actively cooked or prepared with steam, sizzle, or motion. No people, no faces, no hands, no text."
        let creator = try await ImageCreator()
        for try await image in creator.images(
            for: [.text(framedPrompt)],
            style: .animation,
            limit: 1
        ) {
            let uiImage = UIImage(cgImage: image.cgImage)
            guard let pngData = uiImage.pngData() else {
                throw IllustrationError.encodingFailed
            }
            return try Self.saveToDocuments(pngData, extension: "png")
        }
        throw IllustrationError.noImageReturned
    }

    // MARK: - Disk persistence

    private static func saveToDocuments(_ data: Data, extension ext: String) throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs.appending(path: "StepIllustrations")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appending(path: "\(UUID().uuidString).\(ext)")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}

enum IllustrationError: Error, Sendable {
    case encodingFailed
    case noImageReturned
}
