# Recipe Sharpener — Architecture & File Reference

This is the long-form design document. For a quick session-start
orientation, read `CLAUDE.md` first.

## 1. What the app does, end-to-end

1. **Add recipe** — user opens the sheet, picks a mode:
   - **Dish name**: type a name in any language. AI looks up a starter
     recipe.
   - **Paste recipe**: paste freeform text; AI parses it into structured
     form.
   - **Link**: paste a URL; the app fetches the page, extracts via
     JSON-LD or a heuristic, then optionally runs an AI translation
     pass to match the user's expected-dish language.
2. **Profile photo resolution**:
   - URL mode: og:image / JSON-LD image from source page (real photo).
   - Other modes: Wikipedia search + AI-validated for visual similarity
     to the dish; if no match, alternative names tried; if still none,
     `ImagePlayground` generates a cooking-in-action illustration
     labeled "AI generated".
3. **Card UI**: thumbnail + collapsible description + last-improvement
   line + Give-feedback CTA + collapsible steps (with optional inline
   illustrations per key step) + footer buttons (Variations, Illustrate,
   Analysis). Long-press menu for Delete and Undo-last-refinement.
4. **Feedback flow**: user enters feedback + optional rating →
   `LanguageModelSession` diagnoses cause and proposes minimal targeted
   changes → user reviews diff + Apply or Discard. Approved refinements
   add a new revision; rejected ones leave state untouched.
5. **Variations**: user gives a directive ("without chili"); AI branches
   from the current best base revision and creates an independent
   revision chain for the variation.
6. **Final analysis**: AI writes a journey narrative + a polished
   final document containing the best-of-base recipe and best-of-each-
   variation recipe.
7. **Step illustrations**: explicit on-demand button per card; AI picks
   2-4 key visual moments (cookbook convention) and generates
   illustrations via `ImagePlayground`. Inline under their step in the
   card.

## 2. Architecture overview

```
                 ┌─────────────────────────────────────┐
SwiftUI Views ──▶│ View Models (@Observable @MainActor)│
                 └─────────────────────────────────────┘
                              │ depend on protocols
                              ▼
                 ┌─────────────────────────────────────┐
                 │ Service Protocols                   │
                 │  • RecipeGenerator                  │
                 │  • RecipeRefiner                    │
                 │  • VariationBrancher                │
                 │  • RecipeFinalizer                  │
                 │  • RecipeImageService               │
                 │  • RecipeStore                      │
                 └─────────────────────────────────────┘
                              ▲
                              │ implemented by
                 ┌────────────┴────────────┐
                 │                         │
       Real (AppleIntelligence*)     Mock (Mock*) — for devices
                 │                    without Apple Intelligence
                 │
       Decorators (Traced*, Validated*, Fallback*)
                 │
       Composition root: RootViewModel.init() in App.swift
```

### Principles applied

- **SRP**: each module owns one thing. Domain types know nothing of UI,
  persistence, or AI. Views don't construct services.
- **OCP**: adding a new image source means adding a new `RecipeImageService`
  conformance and wiring it in the composition root. No existing service
  changes.
- **LSP**: substituting `Mock*` for `AppleIntelligence*` keeps every
  view working — both conform to the same protocol.
- **ISP**: AI is four narrow protocols (`RecipeGenerator`,
  `RecipeRefiner`, `VariationBrancher`, `RecipeFinalizer`) instead of one
  fat "AIService". Views import only the protocol they need.
- **DIP**: the composition root (`RootViewModel.init` in `App.swift`)
  is the only place that knows the concrete types. Everything else takes
  protocols via initializer injection.

### Layered composition for `RecipeImageService`

```
FallbackImageService (Wikipedia first, AI generation fallback)
  └── primary: ValidatedImageService (validates Wikipedia match)
        ├── base: WikimediaImageService (real Wikipedia search)
        ├── validator: AppleIntelligenceRecipeGenerator.validateImageMatch
        └── alternativeNameProvider: AppleIntelligenceRecipeGenerator.suggestAlternativeNames
  └── fallback: AppleIntelligenceStepIllustrator.generateRecipeImage
```

### Decorators

| Decorator | Wraps | Adds |
|---|---|---|
| `TracedRecipeGenerator` etc. | any AI service | per-call entry in `AITraceLog` for Settings → AI trace |
| `DefaultRecipeGenerator` | fallback generator | adds URL extraction via `WebRecipeExtractor` + optional translation |
| `ValidatedImageService` | image service | AI-validates the article title against the dish name, retries with alternative names |
| `FallbackImageService` | image service | swaps in an AI generator when the primary returns nil |

## 3. Domain model

Pure Codable value types in their own files. No UI, persistence, or AI
dependencies.

```
Recipe
├── revisions: [Revision]
│     └── steps: [Step]
│         (each step optionally has imageURL for AI-generated illustration)
│     └── ingredients: [Ingredient]
│     └── changes: [Change] — model-emitted edit records, each tied to a feedback ID
├── variations: [Variation]
│     └── revisions: [Revision]
│     └── feedback: [Feedback]
├── feedback: [Feedback]
├── imageURL, imageAttribution — profile photo
```

The "current best version" is the latest revision in each list. The
`BestRevisionPicker` (pure Swift) picks based on user ratings.

## 4. AI service overview

### Generator (`AppleIntelligenceRecipeGenerator`)

- `generateInitialRecipe(dishName:)` — three-attempt retry against the
  Apple safety filter (catalog framing → simpler English → Chinese-only
  for CJK inputs). Throws `safetyDeclined` if all three fail.
- `parseRecipe(fromURL:)` — throws `unsupportedInput`; URL extraction is
  delegated to `WebRecipeExtractor` via `DefaultRecipeGenerator`.
- `parseRecipe(fromText:)` — AI parses messy pasted text into clean
  structured form; respects expected-dish language.
- `translateDraft(_:toLanguage:)` — preserves ingredient/step structure;
  translates the text fields only.
- `enforceLanguage(draft:referenceText:)` — post-generation safety net.
  Detects language mismatch via `LanguageHeuristics` and runs translation
  if needed.
- `validateImageMatch(articleTitle:dishName:)` — visual-similarity
  reasoning over an article title; used by `ValidatedImageService`.
- `suggestAlternativeNames(for:)` — returns up to 3 alternative search
  terms (English translation, regional alternates, **main ingredient**)
  used to retry Wikipedia search.

### Refiner (`AppleIntelligenceRecipeRefiner`)

- `refine(recipeID:previousRevision:newFeedback:feedbackHistory:)` —
  AI diagnoses why the feedback happened, proposes minimal targeted
  changes, returns structured `RefinedRevisionDraft`.
- **Per-recipe `LanguageModelSession`**: `RecipeRefinementSessionStore`
  keeps one session per recipe across multiple `refine()` calls. The
  model retains memory of prior refinements' reasoning so iteration
  within a single recipe is continuous. Different recipes get
  independent sessions.
  - First call for a recipe: sends the full recipe + new feedback
    (`buildFullPrompt`).
  - Subsequent calls: still sends the current recipe state as ground
    truth (in case session memory has drifted from undo or other
    edits) plus just the new feedback (`buildIncrementalPrompt`).
  - The `feedbackHistory` parameter is intentionally NOT included in
    any prompt — it accumulated to 4096 tokens before this design.
  - On `exceededContextWindowSize`: the session is reset and the call
    retries once with the full prompt against a fresh session.
- `resetContext(for:)` — clears a recipe's session state. Called
  from `RootViewModel.undoLastRefinement(on:)` so the model doesn't
  reason from a stale memory after the user rolls back.
- `enforceLanguage` + `translateRefinement` — same post-generation
  pattern; preserves structural metadata (IDs, change kinds, feedback
  links).

### Variation brancher (`AppleIntelligenceVariationBrancher`)

- `branch(from baseRevision:directive:)` — produces a variation that
  honors the directive while keeping the dish's character.
- **Language-targeted prompts**: when the base recipe is CJK
  (`isMostlyCJK` threshold), the brancher uses a fully-Chinese system
  prompt + Chinese user prompt path (`chineseInstructions` +
  `buildChinesePrompt`) — no bilingual surface for the model to drift
  on. Non-CJK base uses the English variants.
- `enforceLanguage(draft:referenceText:)` — same post-generation
  pattern as the refiner. Stricter threshold for CJK bases: requires
  `cjkRatio > 0.6` (vs the generic 30%) so mixed-language drift
  triggers translation.
- `translateVariation(_:toLanguage:)` — preserves structure
  (ingredient count, step order, change records) and translates the
  text fields. Uses `TranslatedVariationContent` `@Generable`.

### Finalizer (`AppleIntelligenceRecipeFinalizer`)

- `finalize(recipe:)` — uses the pure `BestRevisionPicker` for the
  selection; AI writes the journey narrative + polished final document.

### Step illustrator (`AppleIntelligenceStepIllustrator`)

- `selectKeyMoments(in:dishName:)` — picks 2-4 cooking-in-action
  checkpoints per cookbook convention.
- `generateImage(prompt:)` — `ImagePlayground.ImageCreator` with
  `.animation` style; saves PNG to `Documents/StepIllustrations/<uuid>.png`.
  Wraps every prompt in a "cookbook demonstration illustration" framing.
- `generateRecipeImage(for:)` — same generator, with a "dish being
  cooked, captured mid-cooking" prompt for profile photos.

### Mock services (`MockServices.swift`)

Used when Apple Intelligence isn't available. Returns deterministic,
hardcoded output. Keyword-driven refinement (recognizes "sour" "salty"
"chewy" "blood" "spicy"); two known dishes (`宫爆鸡丁`, `麻婆豆腐`)
for the generator; everything else throws `unknownDish`.

## 5. Cross-cutting helpers

- **`LanguageHeuristics`** (`LanguageHeuristics.swift`) — single source
  of truth for CJK detection (`containsCJK`, `isMostlyCJK`).
- **`LocalImagePathResolver`** (`LocalImagePathResolver.swift`) —
  re-roots saved `file://` URLs to the current Documents directory.
  Handles iOS container UUID changes between launches.
- **`AITraceLog`** + `Traced*` decorators (`AITrace.swift`) — captures
  every AI call's prompt summary, response summary, latency, and
  backend kind. Surfaces in Settings → AI trace.

## 6. File-by-file reference

### Domain (`*.swift` value types)

| File | Purpose |
|---|---|
| `Recipe.swift` | Aggregate root: name, summary, revisions, variations, feedback, profile photo. Now also carries servings, prepMinutes, cookMinutes (with a derived totalMinutes computed property). |
| `Revision.swift` | Versioned snapshot of a recipe state: ingredients + steps + rationale + changes + addressed feedback IDs. |
| `Variation.swift` | Branched recipe with its own revision chain and feedback. |
| `Ingredient.swift` | Name + quantity + optional notes. |
| `Step.swift` | Index + text + optional technique/time + optional temperatureC + optional doneness cue + optional `imageURL` for AI illustrations. |
| `Change.swift` | Model-emitted edit record. Kind enum (`stepAdded` etc.) + summary + feedback ID. |
| `Feedback.swift` | User feedback: text + optional rating + revision ID + optional tester note. |
| `ImageAttribution.swift` | Source name + page URL + author + license + title for image attribution chips. |

### Service protocols

| File | Purpose |
|---|---|
| `RecipeGenerator.swift` | Protocol + `InitialRecipeDraft` + `RecipeGeneratorError` (`unknownDish`, `parsingFailed`, `networkUnavailable`, `unsupportedInput`, `safetyDeclined`). |
| `RecipeRefiner.swift` | Protocol + `RefinedRevisionDraft`. |
| `VariationBrancher.swift` | Protocol + `VariationDraft`. |
| `RecipeFinalizer.swift` | Protocol + `RecipeAnalysis`. |
| `RecipeImageService.swift` | Protocol + `RecipeImageResult`. |
| `RecipeStore.swift` | Protocol: allRecipes, recipe(id:), save, delete, wipeAll. |
| `Clock.swift` | Time abstraction for tests. |

### Apple Intelligence implementations

| File | Purpose |
|---|---|
| `AppleIntelligenceServices.swift` | Big file with `AppleIntelligence` availability enum + four AI service implementations (generator, refiner, brancher, finalizer) + all `@Generable` schemas (`GeneratedRecipeContent`, `GeneratedRefinement`, `GeneratedVariation`, `GeneratedAnalysis`, `ImageMatchResult`, `AlternativeNames`, `TranslatedRefinementContent`, `GeneratedChange`). Includes the three-attempt safety-filter retry, the visual-similarity image validator, alternative-name suggestor, post-generation language enforcement, and the per-recipe-session refinement loop. |
| `AppleIntelligenceStepIllustrator.swift` | Selector for key visual moments + `ImagePlayground` image generation. Saves PNGs under `Documents/StepIllustrations/`. Also generates profile-photo fallbacks via `generateRecipeImage`. |
| `RecipeRefinementSessionStore.swift` | `@MainActor` registry mapping recipe ID → `LanguageModelSession` so refinement on the same recipe shares context. `reset(for:)` is called on undo or context-window overflow. Stub provided for environments without `FoundationModels`. |
| `IDPreservingMatcher.swift` | Match AI-generated ingredient lines and step texts against a base revision by text similarity (Jaccard, language-aware), reusing base item IDs for matches above the 0.5 threshold. Required for `RevisionDiffer` to produce meaningful diffs — without it, every refinement and variation showed every base item as "removed" and every new item as "added". |

### Mocks and concrete fallbacks

| File | Purpose |
|---|---|
| `MockServices.swift` | All mock implementations + `Mock*Generator/Refiner/Brancher/Finalizer/ImageService`. Used when Apple Intelligence isn't available. |
| `InMemoryRecipeStore.swift` | Actor-isolated dict-backed store; supports optional seed. Used as fallback when filesystem store fails. |
| `FileSystemRecipeStore.swift` | Production store: each recipe as `<id>.json` in `Documents/Recipes/`. Includes `seedIfEmpty` for first-launch fixtures. |
| `WikimediaImageService.swift` | Real Wikipedia search + pageimages API. CJK-aware (tries zh.wikipedia.org first for CJK queries). |
| `WebRecipeExtractor.swift` | URL fetcher with JSON-LD parser (tier 1) + heuristic HTML-to-text + section-keyword extraction (tier 2, includes Chinese keywords). |

### Composition / decorators

| File | Purpose |
|---|---|
| `DefaultRecipeGenerator.swift` | Composes a dish-name fallback with `WebRecipeExtractor` for URL mode and an optional translator for cross-language URL imports. |
| `ValidatedImageService.swift` | Wraps any image service with AI title-vs-dish-name validation + alternative-name retry. |
| `FallbackImageService.swift` | Wraps a primary image service with an optional AI-generation fallback. |
| `AITrace.swift` | `AITraceLog` + four `Traced*` decorators for all AI services. Records each call's metadata for Settings → AI trace. |

### View models

| File | Purpose |
|---|---|
| `RecipeListViewModel.swift` | Observable. Holds the store + search query. Exposes `displayed` via `SearchRanking`. |
| `AddRecipeViewModel.swift` | Mode picker (dishName / pasteText / url) + dish name + description + URL. Handles `unknownDish` and `safetyDeclined` fallbacks with auto-switch to Paste mode. |
| `FeedbackViewModel.swift` | Captures feedback text + rating + tester note. Runs the refiner and exposes the result for the approval gate. |
| `VariationsViewModel.swift` | Manages variation list and branch directive. |
| `FinalAnalysisViewModel.swift` | Wraps the finalizer call. |
| `SettingsViewModel.swift` | Settings sheet state: fixtures loader, export, wipe, AI backend toggle (currently disabled — see "Known limitations" in CLAUDE.md). |

### Views

| File | Purpose |
|---|---|
| `App.swift` | `@main` entry. `RootViewModel` composition root + `RootView` with all the sheet bindings. |
| `RecipeListView.swift` | Top-level list with search bar, settings/add toolbar items, delete and undo confirmation alerts. |
| `RecipeCardView.swift` | The primary interactive card surface. Thumbnail (with `LocalImagePathResolver` re-rooting) + collapsible description + last-improvement + collapsible steps with inline images + footer buttons (Variations, Illustrate, Analysis) + context menu (Delete, Undo). |
| `AddRecipeView.swift` | New-recipe sheet with mode picker and conditional input fields. |
| `FeedbackSheet.swift` | Two-state sheet: form first, swaps to `RefinementResultView` after submission. |
| `RefinementResultView.swift` | Approval gate: shows diagnosis + rationale + model-reported changes + structural diff (via `RevisionDiffer`) + Apply / Discard buttons. |
| `VariationsView.swift` | Lists variations, lets user propose a new one from a directive, hand off to feedback flow for a specific variation. When a pending proposal exists, swaps to `VariationResultView` for the approval gate. |
| `VariationResultView.swift` | Approval gate for a newly-generated variation. Shows model-reported change list + structural diff via `RevisionDiffer` (parallel to `RefinementResultView`). Apply / Discard buttons. |
| `DiffViews.swift` | Reusable `StepDiffRow` + `IngredientDiffRow` views shared by `RefinementResultView` and `VariationResultView`. |
| `FinalAnalysisView.swift` | Renders the journey summary + final markdown document. |
| `SettingsView.swift` | About + AI backend toggle (disabled) + fixtures + export + reset + AI trace. |

### Pure algorithms (unit-tested in `Tests/AppModuleTests/`)

| File | Purpose |
|---|---|
| `RevisionDiff.swift` | Pure diff between two revisions: added / removed / edited / moved steps, added / removed / edited ingredients. Tested in `RevisionDiffTests.swift`. |
| `ChangeAttribution.swift` | Group changes by feedback, find revisions addressing a feedback. Tested in `ChangeAttributionTests.swift`. |
| `SearchRanking.swift` | Weighted text search across name, summary, ingredients, steps, variation names. Tested in `SearchRankingTests.swift`. |
| `BestRevisionPicker.swift` | Picks the best revision per recipe / variation based on average rating + recency. Tested in `BestRevisionPickerTests.swift`. |

### Cross-cutting helpers

| File | Purpose |
|---|---|
| `LanguageHeuristics.swift` | `containsCJK`, `isMostlyCJK` — single source of truth for CJK detection. |
| `LocalImagePathResolver.swift` | Re-roots saved file URLs to the current Documents directory. Use it on every AI-generated image at display time. |
| `BuildInfo.swift` | Version + build + git SHA + build date. Injected from `Info.plist` at CI time (not wired yet). |
| `Fixtures.swift` | Hardcoded `宫爆鸡丁` scenario for first-launch seed and the Settings "Load fixtures" button. |
| `RecipeExporter.swift` | JSON-encodes recipes for the Settings "Export all" ShareLink. |

### Probes (don't ship in the main app — these are separate `.swiftpm` packages)

| Folder | Purpose |
|---|---|
| `ios-app/AIProbes/01–05` | Text AI probes — confirmed `import FoundationModels`, `SystemLanguageModel.default.availability`, `LanguageModelSession(instructions:)`, `respond(to:)`, `@Generable` + `respond(to:generating:)`. All five pass. |
| `ios-app/AIProbes/Vision/01–04` | Vision probes — confirmed `Vision.VNClassifyImageRequest` works (probe 2), Vision+LLM chain compiles but recognition is unreliable (probe 3 — confused sushi for pizza), `ImagePlayground.ImageCreator` works with `.animation` style (probe 4). Direct image input to `LanguageModelSession` does NOT exist (probe 1 build error: "Extra argument 'image' in call"). |

## 7. Recent significant decisions

- **Catalog-lookup framing for the safety filter** (commit `4bd3c40`):
  the system prompt presents the dish name as a "label in a catalog of
  benign culinary entries" with example Chinese + Western dishes, rather
  than asking the model to "create a recipe". Dramatically reduces
  guardrail rejections.
- **Post-generation language enforcement** (commits `4f423ba`, `5508230`):
  the model frequently ignores the in-prompt LANGUAGE RULE for CJK
  inputs. The fix is to verify the produced body language after
  generation and translate if mismatched. Applied to generator and
  refiner.
- **Visual-similarity image validator** (commit `ef27d4b`): reframe the
  image match question from "is the article about this dish?" to "would
  the article's typical hero photo *look* like this dish?". Accepts main
  ingredient and dish family matches, still rejects broad cuisine
  categories.
- **Cooking-in-action prompt framing** (commit `4c6ba24`): every
  generated image gets a "cookbook recipe demonstration illustration"
  wrapper that asks for steam, sizzle, motion — biases away from static
  plated dishes.
- **Path resolver for AI-generated images** (commit `35112e6`): saved
  absolute paths include the app container UUID which can change.
  Display-time resolution against current Documents fixes the "image
  disappears on next launch" bug.
- **Drop feedback history from refiner prompt** to avoid context-window
  overflow on long refinement chains. The text version of history is
  no longer sent in any prompt.
- **Per-recipe `LanguageModelSession` for refinement**: refinement is
  now session-stateful within a single recipe — multiple `refine()`
  calls on the same recipe share a session so the model retains
  reasoning continuity. Different recipes get fresh sessions. Undo
  resets the session. Context-window overflow auto-resets and retries
  with a full prompt. See `RecipeRefinementSessionStore` and the
  Refiner section above.
- **Recipe-level and step-level metric metadata** added (servings,
  prep minutes, cook minutes on Recipe; temperatureC + doneness cue
  on Step; estimatedMinutes already existed). `GeneratedRecipeContent`
  + `GeneratedRefinement` schemas now ask the AI to populate these
  and to embed time/temperature/doneness in step text. URL imports
  also extract `recipeYield`, `prepTime`, `cookTime` from JSON-LD
  (ISO-8601 duration parsing). The card shows servings + prep/cook
  pills in the header; per-step chips render time / temperature /
  technique / doneness when present.

## 8. Future work / not yet done

- iCloud sync for recipes
- CI / TestFlight pipeline
- Cooked-dish photo capture + AI feedback (blocked: no direct vision
  input API in FoundationModels)
- AI photo regeneration button for profile photos
- Image Playground style selection beyond `.animation` (untested)
- About screen showing real git SHA (CI injection step deferred)
- Real-time backend switching from the Settings AI toggle (it's
  cosmetically there but disabled)

When picking up work, prefer addressing items here in roughly the order
listed — iCloud and CI unblock testing on more devices, the rest is
polish.
