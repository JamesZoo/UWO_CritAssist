# Skills — reusable techniques developed on this project

Techniques that worked, with a brief explanation of when and how to apply
them. Not architectural — those go in DESIGN.md. These are tactical moves
the assistant has learned to reach for.

## Probe-first API discovery

**When**: Before wiring any new Apple framework into the main app.

**How**: Write a standalone `.swiftpm` probe app under `ios-app/AIProbes/`
(text AI) or `ios-app/AIProbes/Vision/` (vision/image generation). One
hypothesis per probe. Use `PhotosPicker` if image input is needed.

The probe should:

- Import the suspected framework.
- Call the API with the suspected signature.
- Render big YES (green) on success with the type + value in a scrollable
  text box, big NO (red) with error details on runtime failure, or
  build-error red markers on compile failure.

**Why**: The text-AI probes 01–05 confirmed the FoundationModels API
surface in one round each. The vision probes ruled out direct image
input fast. The alternative — guessing in the main app — caused the
`1067f4b → 3e7d163` revert cycle.

## Catalog-lookup framing for safety-filter-aggressive content

**When**: A FoundationModels prompt is being rejected with
`GenerationError.guardrailViolation`, especially on legitimate non-
English content.

**How**: Frame the system prompt as "a recipe lookup service for known
catalog entries" with a mixed list of example dishes (Chinese + Western)
so the suspect term is normalized as one entry among many. User prompt
uses "look up" rather than "create" or "generate".

```swift
private static let catalogInstructions = """
You are a recipe lookup service. The user submits a dish name — a text
label that identifies a well-known dish from world cuisine — and you
return its standard home preparation. Examples in this catalog:
宫爆鸡丁, 麻婆豆腐, 红烧排骨, Coq au Vin, Pad Thai, Tiramisu...
The dish name is a benign culinary reference label.
"""
```

**Why**: Reframes the task from "generate content" (which the filter
scrutinizes) to "retrieve a known item" (which the filter mostly leaves
alone). Reduced rejection rates dramatically on Chinese dish names.

## Same-language retry for CJK

**When**: After the catalog framing, an English-language prompt is
still hitting the guardrail on a CJK dish name.

**How**: For a final retry, switch the **entire prompt** — system + user
— to the dish's language. No bilingual surface for the filter to react
to.

```swift
attempts.append((
    chineseCatalogInstructions, // entirely in Chinese
    "查询并输出这道菜的标准家常做法：\(dishName)"
))
```

**Why**: Empirically, bilingual prompts triggered more guardrail
violations than monolingual ones on CJK input.

## Post-generation language enforcement

**When**: The model's output occasionally drifts to English despite
explicit in-prompt language rules.

**How**:

1. Sample the produced body (summary + ingredient names + step text +
   rationale + change summaries).
2. Use `LanguageHeuristics.isMostlyCJK(sample)` and
   `LanguageHeuristics.containsCJK(referenceText)` to detect mismatch.
3. If mismatched, run a structured translation pass via a separate
   `LanguageModelSession` with a translateInstructions system prompt
   ("preserve structure, translate text fields only"). Re-package the
   translated content into the original draft type, preserving every
   ID and structural field.
4. Best-effort: on translation failure, return the original draft
   rather than failing the whole flow.

**Why**: Trust the model less, verify more. Combined with the prompt-
level "draw on language-appropriate sources" hint, this makes the
common case cheap (no extra AI call) and the edge case robust.

## Visual-similarity image validation

**When**: Choosing whether a public-source image (Wikipedia article hero)
is a reasonable representative for a dish.

**How**: Don't ask "is this article about this dish?". Ask "would this
article's typical hero photo *look like* this dish?". Reframes the
judgment from topical identity (narrow) to visual likelihood (broader),
accepts main-ingredient matches and dish-family matches, still rejects
broad cuisine categories.

```swift
@Guide(description: "True if the article's typical hero image would
VISUALLY look similar enough to the named dish... Reason about visual
likelihood, not just topical identity: same food type, dominant
ingredients on the plate, cooking method, color and texture profile.")
var matches: Bool
```

**Why**: Topical identity is too strict — `猪蹄` (pig trotters ingredient
article) gets rejected for `东北酱猪蹄` (specific dish) even though the
photo is visually identical. Visual reasoning is what we actually want.

## Cooking-in-action prompt framing for image generation

**When**: Generating cookbook-style illustrations.

**How**: Wrap every prompt with a demonstration framing prefix:

```swift
let framedPrompt = "Cookbook recipe demonstration illustration: \(prompt).
The image depicts cooking IN ACTION — food being actively cooked or
prepared, captured during the cooking process with steam, sizzle, or
motion as appropriate. No people, faces, hands, or text."
```

Bias the step selector toward "transformation mid-action" moments over
"finished plated dish" moments. Use action verbs in example prompts:
"being added", "being stirred", "being folded".

**Why**: Image Playground's `.animation` style produces stylized output;
if the prompt is "finished plated dish", the result is a static cartoon
plate. Cooking-in-action prompts produce visibly more interesting
output that fits a cookbook demonstration aesthetic.

## Path resolver for AI-generated images

**When**: Loading any file URL that was generated and saved in a
previous app launch.

**How**: Always use `LocalImagePathResolver.resolved(_:)` before passing
a URL to `AsyncImage` or any view that loads from disk.

```swift
if let url = LocalImagePathResolver.resolved(step.imageURL) {
    AsyncImage(url: url) { ... }
}
```

**Why**: iOS app container UUIDs change between launches in Swift
Playgrounds. Saved absolute paths become stale. The resolver re-roots
the file URL to the current Documents directory.

## Avoiding Swift type-checker timeouts

**When**: A function with several `.map().joined()` chains combined
with `+` string concatenation.

**How**: Extract each `.map().joined()` to a local `let`, then build
the final string with **string interpolation** or `Array.joined`.

```swift
// BAD — type-checker timeout
let sample = draft.summary
    + " " + draft.ingredients.map(\.name).joined(separator: " ")
    + " " + draft.steps.map(\.text).joined(separator: " ")

// GOOD — type-checker handles in microseconds
let summary = draft.summary
let ingredients = draft.ingredients.map(\.name).joined(separator: " ")
let steps = draft.steps.map(\.text).joined(separator: " ")
let sample = "\(summary) \(ingredients) \(steps)"
```

**Why**: Swift's overloaded `+` operator on `String` combined with
generic method chains is a known type-inference pathology. Each
intermediate is a separate inference problem the compiler can't
combine cheaply.

## Sendable closure annotation

**When**: Assigning a closure literal to a property typed as
`@Sendable (...) async throws -> ...`.

**How**: Annotate the inner closure literal with `@Sendable`:

```swift
let imageValidator: (@Sendable (String, String) async throws -> Bool)? =
    appleGenerator.map { gen in
        return { @Sendable articleTitle, dishName in
            try await gen.validateImageMatch(...)
        }
    }
```

**Why**: Without the annotation, Swift emits a "Converting non-Sendable
function value..." warning. The closure captures must be Sendable for
this to be safe; in our case `gen` (a Sendable struct) is fine.

## Decorator-pattern composition

**When**: Adding cross-cutting behavior to a service without changing
its protocol or callers.

**How**: Create a wrapper struct that conforms to the same protocol,
delegates to an inner service, and adds the behavior before/after the
delegation. Examples in this codebase: `TracedRecipeGenerator` (trace
logging), `ValidatedImageService` (AI validation + retry),
`FallbackImageService` (primary + fallback), `DefaultRecipeGenerator`
(URL extraction + translation orchestration).

**Why**: Layered behavior at composition time, without protocol or
caller changes. Each layer has one responsibility and substitutes for
the inner service via LSP.

## Document maintenance alongside code

**When**: Any commit that changes the file set, a service's behavior,
the composition root, or a user-visible flow.

**How**: Edit `DESIGN.md` in the same commit. Treat it as part of the
change. The commit message should mention what changed in the doc.

**Why**: The doc is the orientation surface for the next Claude session
and for the user. Drift between code and doc compounds over time and
becomes expensive to fix.
