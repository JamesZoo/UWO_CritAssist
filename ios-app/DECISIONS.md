# Decisions — Recipe Sharpener

Decision records (lightweight ADRs). Each entry: what was decided,
context that forced the decision, what alternatives were considered,
why this choice over the others, what the trade-offs are. New
sessions should read this when about to revisit any of these areas —
the existing choice probably has a reason that wasn't obvious.

Entries are roughly chronological. Cross-references in `commit:` cite
the git commit that landed the change.

---

## D-28. Framework-agnostic AI abstraction via factory + capability protocols

**Decided**: The composition root (`RootViewModel.init`) depends only
on an `AIBackendFactory` protocol and the AI capability protocols
defined in `AICapabilities.swift` (`StepIllustrator`,
`ProfileImageGenerator`, `RecipeTranslator`, `DishImageMatchValidator`,
`DishAlternativeNameProvider`). The factory produces an `AIBackend`
bundle holding the four core service protocols plus the auxiliary
capability protocols. The concrete Apple Intelligence factory
(`AppleIntelligenceBackendFactory`) and the mock factory
(`MockAIBackendFactory`) live in their own files; everything else is
framework-agnostic.

**Context**: Before this change, `App.swift` directly instantiated
`AppleIntelligenceRecipeGenerator`, `AppleIntelligenceRecipeRefiner`,
etc., and pulled auxiliary methods (`translateDraft`,
`validateImageMatch`, `suggestAlternativeNames`, `generateRecipeImage`)
off the concrete generator and illustrator as `@Sendable` closures
plumbed into `DefaultRecipeGenerator`, `ValidatedImageService`, and
`FallbackImageService`. Apple Intelligence is convenient for on-device
development but the user wants the freedom to swap in a different AI
provider (e.g. a Claude-powered backend) without touching any client
or service code.

**Alternatives considered**:
- *Keep closures, add a single closure-producing factory*. Lower
  ceremony but harder to reason about — closures don't document
  capabilities the way named protocols do, and Swift error messages
  about misshaped closures are worse than protocol-conformance errors.
- *One fat `AIService` protocol holding every method*. Violates ISP,
  forces mock and tests to stub methods they don't care about, and
  prevents the natural "this backend doesn't do image generation"
  composition we have today.
- *Generic types over the backend*. `RootViewModel<F: AIBackendFactory>`.
  Adds a generic parameter that has to be threaded through every view
  that holds the view model — including `RootViewModel` itself which
  is `@Observable`. Existentials are fine here; no perf-critical hot
  path runs through the abstraction.
- *Service locator / DI container*. Overkill for a single-process app
  with one composition root. Constructor injection covers it.

**Why factory + capability protocols**:
- Single point of replacement: change one default-parameter value in
  `RootViewModel.init` to swap the entire AI stack.
- Capability protocols name each contract narrowly so each backend can
  opt out by returning `nil` (the mock backend has no translator or
  image validator and the code paths degrade gracefully).
- Apple-specific machinery (`@Generable` types, `LanguageModelSession`,
  `ImagePlayground`, `FoundationModels` import) is now confined to
  exactly three files: `AppleIntelligenceServices.swift`,
  `AppleIntelligenceStepIllustrator.swift`,
  `AppleIntelligenceBackendFactory.swift` (plus the
  `#if canImport(FoundationModels)` shim in `RecipeRefinementSessionStore`).
  Adding a Claude backend later means: implement the four service
  protocols + the auxiliary protocols against the Claude SDK, write a
  `ClaudeBackendFactory`, inject it.
- `KeyVisualMoment` is now a plain Swift struct in `AICapabilities.swift`;
  the Apple illustrator uses an internal `GeneratedKeyVisualMoment`
  `@Generable` mirror and converts before returning, keeping the
  `StepIllustrator` protocol framework-agnostic.

**Trade-offs**:
- Two new types (`AIBackend` struct + `AIBackendFactory` protocol) and
  one new file of capability protocols. Modest surface area for
  significant decoupling.
- `AIBackend` exposes everything the composition root might need,
  including optional capabilities. That's a tiny "container" shape —
  acceptable because every member is itself a protocol-typed slot
  and the bundle stays close to the seam.
- The mock backend declines several capabilities by returning `nil`
  (no translator, validator, illustrator, profile-image fallback).
  Consumers already handled the optional case before this refactor,
  so behavior is unchanged.

**Commit**: lands in the refactor that introduces `AICapabilities.swift`,
`AIBackend.swift`, `AppleIntelligenceBackendFactory.swift`, rewrites
`RootViewModel.init`, and converts `DefaultRecipeGenerator` /
`ValidatedImageService` / `FallbackImageService` from closure-based to
protocol-based dependencies.

---

## D-1. Build target: Swift Playgrounds `.swiftpm` on iPad

**Decided**: Project ships as a `.swiftpm` package opened in Swift
Playgrounds on iPad, not as a `.xcodeproj` opened in Xcode on a Mac.

**Context**: User has no Mac. Only iPad M5 Pro + iPhone 16 Pro Max.

**Alternatives considered**:
- `.xcodeproj` via XcodeGen + macOS CI runner — would need a Mac to
  ever build locally; user can't run CI failures interactively.
- Cloud Mac service (MacInCloud, etc.) — costs money, awkward.
- Web-based iOS sandbox — none mature enough.

**Why .swiftpm**: only Mac-free iOS authoring path. Swift Playgrounds
on iPadOS 26 can build and run SwiftUI apps that import system
frameworks including FoundationModels and ImagePlayground (verified
via probes). User pulls via Working Copy, edits / runs in Swift
Playgrounds.

**Trade-offs**: Can't run unit tests in Swift Playgrounds (D-11). No
TestFlight pipeline without a Mac (deferred). Some Apple capabilities
unavailable to .swiftpm builds.

**Commit**: project scaffolded in the initial PR.

---

## D-2. Probe-first methodology for new Apple APIs

**Decided**: Before wiring any new Apple framework call into the main
app, write a standalone `.swiftpm` probe under `ios-app/AIProbes/`
that tests one API hypothesis. Only after the user confirms the
probe builds and works do we add the call to the main app.

**Context**: The initial FoundationModels wiring (commit `1067f4b`)
used `==` to check `SystemLanguageModel.default.availability`. That
enum has associated values and isn't equatable; the file failed to
compile; the `AppleIntelligenceRecipeGenerator` type vanished from
scope; App.swift cascaded into "Cannot find …" errors; the whole
build broke. Reverted in commit `3e7d163`. Cost the user a full
pull-test-screenshot cycle.

**Alternatives considered**:
- Continue guessing — fast iteration but a single wrong guess
  destroys the build.
- Reading Apple docs from the assistant's side — not reliable enough
  given internet access constraints.
- User typing autocomplete prefixes and screenshotting — works but
  slower than probes.

**Why probes**: each probe is a single-file `.swiftpm`, isolates the
hypothesis, lets the user verify in 30s with a YES / NO / error
screenshot. Five text-AI probes confirmed the FoundationModels API
surface in one round. Four vision probes ruled out direct image
input + confirmed Vision and ImagePlayground.

**Trade-offs**: slight upfront cost per probe. Pays for itself many
times over by avoiding revert cycles.

**Commit**: text probes added in `bab0e34`; vision probes in `160dd38`.

---

## D-3. Mock services kept in production code as protocol fallbacks

**Decided**: `MockRecipeGenerator`, `MockRecipeRefiner`, etc. remain
in the production build, not removed after real services were wired.

**Context**: Devices without Apple Intelligence (e.g. older iPads, a
hypothetical macOS / iPad simulator that lacks AI access) still need
to compile and run the app. The protocols + composition root pattern
means substituting Mock* for AppleIntelligence* requires zero code
change at call sites.

**Alternatives considered**:
- Delete mocks once real services work — would break on non-Apple-
  Intelligence devices.
- Move mocks to a test target — Swift Playgrounds has no test target
  (D-11), so the mocks would have nowhere to live.

**Why kept**: zero-cost insurance. Mocks are tiny and deterministic;
they exercise the same protocols; they're useful for offline UI work
even on capable devices.

**Trade-offs**: slight bundle-size cost (negligible). Risk of a stale
mock confusing future development — addressed by the composition
root's `aiAvailable` check always preferring real when available.

---

## D-4. Catalog-lookup framing for the safety filter

**Decided**: When asking the LLM to "generate a recipe", the system
prompt presents the dish name as a benign label in a catalog of
known dishes (Chinese and Western mixed examples), and the user
prompt uses "Look up" rather than "Create".

**Context**: Apple Intelligence's content safety filter rejected
benign Chinese dish names like `红烧排骨` (Red-braised Pork Ribs)
and `回锅肉` (Twice-cooked Pork) with `guardrailViolation`. Initial
prompts framed the request as "Create a recipe for X" — the model's
filter scrutinized X heavily.

**Alternatives considered**:
- Avoid safety-touchy ingredients entirely — would miss legitimate
  dishes the user wants.
- Translate to English first — adds latency, doesn't always help.
- File an Apple Feedback report and wait — not actionable now.

**Why catalog framing**: shifts the model's interpretation of the
task from "generate sensitive content" to "retrieve a known catalog
entry". The example list normalizes Chinese dish names as benign
international cuisine references. Dramatically reduced rejection
rates in user testing.

**Trade-offs**: more verbose system prompt. Still fails on the
hardest cases (`爆炒腰花` — organ meat); D-5 covers the retry ladder
for those.

**Commit**: `4bd3c40`.

---

## D-5. Three-attempt safety-filter retry with same-language fallback

**Decided**: When the catalog-framed first attempt still hits the
guardrail, retry with a simpler English prompt, then for CJK input,
retry with a fully Chinese system + user prompt. If all three fail,
throw `safetyDeclined` and surface a friendly fallback banner in the
UI that auto-switches to Paste mode.

**Context**: Even with catalog framing, dishes like `爆炒腰花` can
still be rejected. The user shouldn't see a raw error.

**Why same-language for CJK**: empirically, the bilingual surface
(English prompt asking about a Chinese dish) seems to trigger the
filter more aggressively than a fully Chinese prompt. Removing the
language mismatch helps in some cases.

**Why throw a specific error case rather than generic**: lets the UI
handle it deliberately. `unknownDish` would have been misleading —
the dish exists, the filter just refuses to talk about it.

**Trade-offs**: up to 3× latency on rejected dishes. Acceptable
because rejection is rare in practice.

**Commit**: retry ladder in `e02533e` (3 attempts); safetyDeclined
case in `a9fa448`.

---

## D-6. Post-generation language enforcement (translate if mismatched)

**Decided**: After the model returns a recipe / refinement /
variation, detect whether the output body language matches the input
reference language. If mismatched, run a translation pass before
returning the result.

**Context**: The model occasionally outputs English ingredients and
steps for a Chinese dish name despite explicit LANGUAGE RULE
directives in the system prompt. In-prompt directives aren't
reliable.

**Alternatives considered**:
- Trust the prompt entirely — broken in practice; user kept getting
  English outputs for Chinese dishes.
- Translate every output blindly — wastes calls when the model
  already got it right.
- Reject and retry — uncertain if a retry helps; doubles latency.

**Why post-generation conditional translation**: detection is cheap
(local CJK heuristic, microseconds). Translation only fires on actual
mismatches (rare with strong prompt biasing). Safety net rather than
primary mechanism.

**Trade-offs**: when translation does fire, it adds one more LLM
call (~5-15s). User experiences a longer loading time. Acceptable
because the alternative is wrong-language output.

**Commit**: generator enforcement in `4f423ba`; refiner in `5508230`.

---

## D-7. Visual-similarity (not topical-identity) image validator

**Decided**: The AI-driven validator that decides whether a Wikipedia
article's photo is suitable for a dish asks "would the article's
typical hero photo *look like* this dish?" rather than "is this
article about this dish?".

**Context**: Strict topical identity rejected legitimate matches —
e.g. `猪蹄` (pig trotters ingredient article) was rejected for
`东北酱猪蹄` (specific dish) even though the article's hero photo
is exactly what we want. At the same time, lenient topical matching
accepted `广东菜` (Cantonese cuisine article) for `广式红烧肉` —
whose hero image is dim sum, not braised pork.

**Why visual-similarity reasoning**: the actual concern is "will the
user see a photo that *looks like* their dish?". The model can
reason about likely hero-image content given the article title (food
type, dominant ingredients, cooking method, color). Accepts main
ingredient articles + dish-family articles; rejects broad cuisine
categories.

**Alternatives considered**:
- True image-content vision validation — direct image input to
  LanguageModelSession doesn't exist (D-9).
- Hardcoded list of "broader category" articles to always reject —
  brittle, doesn't scale.

**Trade-offs**: validation accuracy depends on the model
understanding what article titles imply visually. The system prompt
gives examples to anchor reasoning.

**Commit**: `ef27d4b`.

---

## D-8. Image-source priority: real (Wikipedia) first, AI generated as fallback

**Decided**: For the recipe profile photo, try Wikipedia (validated)
first. If that returns nil, generate an illustration via
`ImagePlayground`. The AI-generated image carries an explicit "AI
generated" attribution chip.

**Context**: User wants real photos when possible. Some dishes don't
have Wikipedia coverage. Placeholder fork-knife icon was too
frequent.

**Alternatives considered**:
- AI-generated only — loses real photos when available.
- External photo APIs (Unsplash, Pexels) — requires user-provided
  API key, deferred until user asks.
- Google Image Search — paid API key, ruled out.

**Why this priority**: real photos when available match user
expectation. AI illustration is degraded but better than blank.
Honesty preserved via attribution chip.

**Trade-offs**: ImagePlayground only supports `.animation` style
(per probe 04) which is stylized cartoon, not photorealistic. The
user sees a noticeable style shift when they get an AI-generated
profile photo. Acceptable given the alternative is nothing.

**Commit**: `8715929`.

---

## D-9. Text-only image validation (no direct vision input)

**Decided**: Validate image matches by comparing the article title to
the dish name in text, not by sending the actual image bytes to a
vision model.

**Context**: Vision probe 1 (`Vision/01-DirectImageInput.swiftpm`)
confirmed `LanguageModelSession.respond(to: prompt, image:)` does NOT
exist. Vision probe 3 (Vision+LLM chain via `VNClassifyImageRequest`)
worked but the classification labels are too generic — sushi was
confused for pizza.

**Why text-based**: it's the only reliable path right now. Vision+LLM
chain has English bias (D-12) and poor dish recognition.

**Trade-offs**: if a Wikipedia article has the right title but the
wrong hero image (rare), we can't catch it. Accepted as a known
limit.

**Future**: when Apple ships direct vision input to LLMs in a later
iOS, revisit. The validator could then literally look at the image.

**Commit**: D-7 commits cover the text validator. D-9 is the
*absence* of a vision validator — documented for clarity.

---

## D-10. Per-recipe `LanguageModelSession` for refinement loop

**Decided**: Refinement sessions are scoped per-recipe. Multiple
`refine()` calls on the same recipe share a `LanguageModelSession`
so the model retains memory of prior refinements' reasoning.
Different recipes get independent sessions.

**Context**: User hit `exceededContextWindowSize` because the refiner
prompt was accumulating prior-feedback history text in every call.
A long refinement chain crossed the 4096-token limit.

**First attempt** (commit `1d34879`): drop feedback history from the
prompt entirely. Solved the overflow but removed reasoning
continuity.

**User feedback**: "Only generation within a single recipe should be
in the same context" — wanted continuity preserved within a recipe,
not across recipes.

**Final design** (commit `671ee05`):
- `RecipeRefinementSessionStore` keeps sessions per recipe ID.
- First call sends full recipe + new feedback (session seeded).
- Subsequent calls still send current recipe state (ground-truth
  safety net) + only the new feedback. Session memory contributes
  reasoning continuity.
- Undo and `exceededContextWindowSize` both reset the session.

**Alternatives considered**:
- Single global session across all recipes — would mix contexts,
  confusing the model.
- One session per (recipe × operation type) — more bookkeeping for
  marginal benefit; refinement is the only iterative operation.
- Session-only memory (no recipe text resend) — risk of session
  memory drifting from actual recipe state, especially after undo.

**Trade-offs**: still sending recipe text in incremental prompts
means token savings are modest. The win is reasoning continuity, not
context budget reduction. If we later trust session memory enough to
drop the recipe text, prompts shrink further but with drift risk.

---

## D-11. No test target in `Package.swift`

**Decided**: Tests live on disk under `Tests/AppModuleTests/` but
are NOT declared as a `testTarget` in `Package.swift`.

**Context**: Swift Playgrounds can't link the Swift Testing framework
when building an `iOSApplication` product. Declaring the testTarget
breaks the build (commit `93d8591` removed it after the initial
scaffold).

**Alternatives considered**:
- Use XCTest instead — same problem.
- Run tests in a separate Swift Package (no app product) — splits the
  project across two packages, awkward in Working Copy.
- Wait until CI is wired and add testTarget there only.

**Why no testTarget here**: the build must always succeed for the
user's iterate-on-iPad loop. Test running can wait for CI.

**Trade-offs**: tests aren't run on every edit. Pure-algorithm tests
(RevisionDiffTests, ChangeAttributionTests, etc.) sit unused. Once
CI lands, revisit and add the testTarget in a CI-only manifest.

---

## D-12. Drop Vision+LLM chain for image matching

**Decided**: Don't wire the Vision + LLM image-classification chain
into the main app. Stay with text-based article-title validation
(D-7).

**Context**: Probe 3 (`Vision/03-VisionPlusLLM.swiftpm`) confirmed
that `VNClassifyImageRequest` returns labels in English (regardless
of dish-name language) and at coarse granularity ("food", "meat",
"bowl"). The LLM judging "is this 红烧排骨" from those labels is
unreliable — confused sushi for pizza on real photos. Also has
language bias against Chinese.

**Why dropped**: text title comparison is more precise. `猪蹄` vs
`东北酱猪蹄` is a clean string-similarity reasoning task; visual-
labels-vs-Chinese-dish-name is fuzzy and biased.

**Trade-offs**: we lose the option to validate based on actual image
content. Acceptable because text validation already works well.

**Commit**: this is a *non-implementation* decision; the probes
landed in `160dd38`.

---

## D-13. On-demand step illustrations (not automatic)

**Decided**: Step illustrations are triggered by an explicit
"Illustrate" button on each card, not generated automatically when
a recipe is created or refined.

**Context**: Each illustration takes ~10-15s via ImagePlayground.
2-4 illustrations per recipe = 30-60s. Generating automatically on
recipe creation would massively slow the add-recipe flow.

**Alternatives considered**:
- Generate automatically in background after creation — would
  consume battery + AI compute even when user doesn't care.
- Generate when card is opened — same latency issue, less
  predictable.
- Generate on hover/long-press — gestures already used for delete/undo.

**Why on-demand button**: explicit user control over the latency
budget. User chooses when to wait. Subsequent regenerations also
work via the same button.

**Trade-offs**: requires the user to know about and tap the button.
Confused user once who didn't realize the button existed
(addressed by a more explicit response in chat at the time).

**Commit**: `ad436b5`.

---

## D-14. Cookbook-style "cooking in action" prompt framing

**Decided**: Image generation prompts (both profile photo fallback
and step illustrations) wrap the user / selector-supplied prompt in
a "Cookbook recipe demonstration illustration: … cooking IN ACTION,
captured during the cooking process with steam, sizzle, or motion"
framing.

**Context**: User explicitly asked for cookbook-demonstration
aesthetic, not static plated-dish photos.

**Why**: cookbook convention is to show transformation moments. The
framing biases the model toward action verbs and sensory cues.

**Trade-offs**: minor — slightly more verbose prompts. Output quality
visibly better for the cooking-demonstration use case.

**Commit**: `4c6ba24`.

---

## D-15. Approval gate for refinements (Apply / Discard)

**Decided**: The refinement result view requires explicit user
approval (Apply button) before saving. Discard button rejects the
refinement entirely. No auto-apply.

**Context**: User asked for explicit causation review before any
recipe change is persisted.

**Alternatives considered**:
- Auto-apply with undo — simpler but the user can't preview before
  committing.
- Auto-apply with a notification — same problem.

**Why approval gate**: matches the user's "I want to verify the
reasoning before accepting" intent. Combined with the undo
mechanism (D-via-card-context-menu), the user has full control.

**Trade-offs**: one extra tap per refinement.

**Commit**: `3e7d163`.

---

## D-16. File-system store (JSON-per-recipe) not SwiftData

**Decided**: Recipes are persisted as `<id>.json` files under
`Documents/Recipes/` via `FileSystemRecipeStore`. Not SwiftData,
not Core Data, not CloudKit.

**Context**: Recipe content is small (KB per recipe). User cares
about inspectability — can browse Documents in the Files app and see
JSON. Future iCloud sync is easier with file-based storage than with
SwiftData migration.

**Alternatives considered**:
- SwiftData — Apple's recommended path, but locks us into framework
  evolution and migration complexity. Overkill for this data size.
- CoreData — older, more brittle.
- Single JSON file with all recipes — write contention, large file
  rewrites, harder to merge in iCloud sync future.

**Why JSON-per-recipe**: simple, debuggable, granular writes, easy
to ship via iCloud Drive later, easy to export individual recipes.

**Trade-offs**: no built-in query language; we hand-roll `allRecipes()`
+ in-memory filtering / sorting / search ranking. Acceptable at this
scale.

**Commit**: `70fa159` (initial), still in use.

---

## D-17. `LocalImagePathResolver` for AI-generated image URLs

**Decided**: When displaying any saved file URL (AI-generated image),
pass it through `LocalImagePathResolver.resolved(_:)` to re-root
against the current Documents directory.

**Context**: iOS app container UUIDs change between launches in Swift
Playgrounds. Saved absolute paths like
`/var/mobile/Containers/Data/Application/<old-UUID>/Documents/...`
become stale. AsyncImage failed silently → blank thumbnails.

**Alternatives considered**:
- Store relative paths only — would require a domain-model schema
  change.
- Use ubiquity container — adds iCloud dependency.
- Always regenerate on miss — wastes AI compute.

**Why path resolver**: backward-compatible (no schema change), works
for both fresh and existing recipes, single point of change at
display time.

**Trade-offs**: silent re-resolution if the file truly is deleted —
the resolver returns a URL that fails to load, falling back to the
placeholder. User can regenerate via the Illustrate button.

**Commit**: `35112e6`.

---

## D-19. Recipe-level and step-level metric metadata

**Decided**: Add `servings`, `prepMinutes`, `cookMinutes` to `Recipe`,
and `temperatureC` + `doneness` to `Step` (alongside the
already-existing `estimatedMinutes`). Have the AI populate these via
new `@Generable` schema fields, and extract them from JSON-LD on URL
imports. Display in the card header and per-step chips.

**Context**: User reported "recipe seems to miss a lot of metric
information". Cookbook conventions include serving yield, prep time,
cook time, per-step time and temperature. None of that was modeled
before — ingredient quantities lived inside the ingredient text and
step timing was implicit at best.

**Alternatives considered**:
- Strengthen the existing `@Guide` to demand inline metrics in step
  text only (no schema change) — simpler, but unstructured. Hard to
  display compactly or query later.
- Full nested `@Generable Step` with structured fields — most correct,
  but a bigger refactor touching every AI service that produces steps.
- Recipe-level only (skip step-level) — easier but leaves the per-
  step "how long" question unanswered.

**Why this scope**: recipe-level fields land on `Recipe` so they
survive refinement and variation (those modify revisions, not the
parent metadata). Step-level adds the most user-visible signals
(time, temperature, doneness) without forcing every step into nested
DTO territory. The strengthened `steps` `@Guide` also tells the AI
to embed time/temperature/doneness in the step text itself — belt
and suspenders.

**Trade-offs**:
- Schema expansion costs a few hundred tokens per AI call —
  acceptable.
- Refinement doesn't re-populate step-level metadata yet (it would
  need its own structured step DTO). Initial generation does. URL
  imports do (from JSON-LD). Refinement steps fall back to whatever
  metadata the model decides to include in step text.
- Mock services don't produce metric data — acceptable for offline
  UI work.

**Commit**: this commit.

---

## D-27. Final document composed deterministically in Swift, not by AI

**Decided**: The Analyze final document is no longer written by the
AI. Swift composes it directly from the recipe data
(`composeFinalDocument(...)`). The AI is responsible only for the
journey summary narrative. Same recipe → same document, every time.

**Context**: User report — "analyze的结果非常随机, 一会儿肉1.5kg,
一会儿1kg, 一会儿显示用量, 一会儿不显示". The AI was rewriting the
recipe each time Analyze ran, inventing different quantities,
sometimes omitting them entirely, sometimes producing HTML, sometimes
omitting sections. No amount of prompt strengthening fixed the
non-determinism because the underlying issue is that LLM generation
is non-deterministic by nature.

**Alternatives considered**:
- Continue trying to discipline the AI with stricter prompts /
  schema rules — the previous several commits had been doing this
  (D-25, then HTML+language fix `684383e`, then quantities fix
  `54ce2da`). Each made things marginally better but didn't reach
  determinism. Diminishing returns.
- Cache a single AI output and reuse it — masks the problem, doesn't
  fix it; also stale when the user refines further.
- Lower temperature on the model — `LanguageModelSession` doesn't
  expose temperature controls in the API we have.

**Why deterministic Swift composition**: the final document is a
**formatting task**, not a creative task. Take the data we already
have (best base + best variations, each with ingredient lines and
steps) and emit Markdown. No reason for AI to be involved. Same
input → same output is exactly what the user wants. Quantities are
preserved exactly as stored; no invention.

**What stays AI-driven**: the journey summary. That genuinely is a
narrative task — connecting prior feedback to changes, telling the
story of the iterations. AI is appropriate there. Some variance
between runs is acceptable for a narrative.

**Implementation**:
- `GeneratedAnalysis` `@Generable` now has only `journeySummary`
  (was: journeySummary + finalDocument).
- `TranslatedAnalysisContent` likewise simplified to
  `journeySummary` only.
- Old `enforceLanguage(journeySummary:finalDocument:referenceText:)`
  → new `enforceJourneyLanguage(journeySummary:referenceText:)`.
  Translation only covers the journey since the document is
  composed in Swift from already-language-correct source data.
- New `composeFinalDocument(recipe:bestBase:variationBestRevisions:)`
  pure Swift function emits the Markdown document.
- New `AnalysisLabels` private struct centralizes the bilingual
  section labels (`食材` / `Ingredients`, `步骤` / `Steps`,
  `变体` / `Variation`, etc.).
- System prompts shortened — they only need to set context for the
  journey now, not for the document.

**Trade-offs**:
- Final document is more mechanical now — no AI "polish" like
  rephrasing steps, combining lines, or adding flair. The user gets
  consistency and accuracy at the cost of variety. Worth it given
  what was reported.
- If the recipe data itself has poor ingredient lines (e.g. missing
  quantities), the document reflects that exactly. That's still
  better than the AI making numbers up. Recipe quality is the
  generator/refiner's job, not the finalizer's.
- HTML stripping is no longer needed for the document (Swift never
  emits HTML); kept for the journey just in case the model still
  slips.

**Commit**: this commit.

---

## D-26. Variations can compound: "Branch from" picker

**Decided**: Add a "Branch from" picker to the New Variation form. When
the recipe has existing variations, the user can choose to base the new
variation on an existing variation's current revision rather than always
on the base recipe. The picker defaults to the base, so existing
behavior is unchanged for users who don't engage the picker.

**Context**: User reported that proposing a new variation appeared to
"override" the changes from a previous variation. Diagnosis: every new
variation was branching from `recipe.currentRevision` (the base),
ignoring any work done in previous variations. So if variation A
removed chili, variation B started fresh from the base — chili
present again. From the user's mental model of "I want to keep
building on what I just did", that read as B "overwriting" A.

**Alternatives considered**:
- Always branch from the latest variation — breaks the independent-
  branch mental model that many users (and cookbook conventions)
  share.
- Auto-detect intent from the directive — fragile, AI judgment
  layer on top of UI choice.
- Show all prior variations as "context" to the AI but still branch
  from base — doesn't actually let the user compound; just makes
  the AI aware.

**Why a picker**: it's UI-first and explicit. The user sees the
branch source they're using before tapping Propose, with no AI
guesswork. Default is base (backward-compatible). When the user
wants to compound, they pick the variation they want to extend.

**Implementation**:
- `VariationsViewModel.branchFromVariationID: UUID?` — nil means
  base.
- `branchSource` derived getter returns the (Revision, name) pair
  to feed `brancher.branch(from:baseRecipeName:directive:)`. When
  the picked variation has no current revision it falls through to
  the base.
- `branchSourceLabel` computed for the picker's trailing label.
- `VariationsView` adds a `Menu` (SwiftUI dropdown) inside the
  "New variation directive" section, visible only when there are
  existing variations. Selected option gets a checkmark in the
  expanded menu.
- `VariationResultView` is fed `vm.branchSource?.revision` as its
  `baseRevision`, so the structural diff card correctly compares
  the proposal against whatever source it was branched from.

**Trade-offs**:
- Branching from variation X produces a new variation Y that's a
  sibling of X under the recipe, not a child of X. There's no
  variation-tree hierarchy modeled. The lineage isn't tracked
  beyond the user's choice at proposal time. Acceptable for now;
  if users need to see "Y was built on X", that's a future feature.
- If the picked variation's current revision is missing (data
  corruption), `branchSource` falls back to the base. Defensive,
  not a UX promise.

**Commit**: this commit.

---

## D-25. Finalizer language consistency (same fix pattern as generator / refiner / brancher)

**Decided**: The recipe analysis (`AppleIntelligenceRecipeFinalizer`)
gets the same language-consistency treatment that has worked
elsewhere: parallel Chinese-only and English instruction paths
selected based on the recipe's content language, plus post-
generation enforcement with translation when the body language
doesn't match the reference.

**Context**: User reported the journey summary in the analyze result
view was still in English even when the underlying recipe was in
Chinese. The finalizer had been missed when D-6 (generator), D-10
(refiner per-recipe session), D-21 (brancher CJK path) were applied.

**Alternatives considered**:
- Strengthen only the in-prompt language rule — proven unreliable in
  the same way the other services were.
- Post-generation enforcement only (no parallel CJK path) — works but
  triggers translation calls more often, adding latency.
- Drop the journey summary entirely and synthesize only from the
  finalDocument — loses useful narrative signal.

**Why this pattern**:
- Two prompt paths remove the bilingual surface for CJK recipes
  (English prompt asking about Chinese recipe content), which is the
  drift driver.
- Post-generation enforcement catches anything the proactive path
  misses, using the same `cjkRatio` thresholds the brancher tuned
  (>0.6 required, >0.3 detection on the inverse side).
- Translation preserves markdown structure in the `finalDocument` so
  the share-sheet export (D-24-adjacent commit `a726a6d`) and the
  in-app `LocalizedStringKey` rendering still work after translation.

**Implementation**:
- New `@Generable TranslatedAnalysisContent` carrying `journeySummary`
  + `finalDocument` (mirrors the refinement translation schema).
- `buildEnglishPrompt` (renamed from `buildPrompt`) and
  `buildChinesePrompt` produce equivalent content with locale-
  appropriate field labels ("Recipe name" vs "菜名", "Revision N" vs
  "第 N 版", etc.).
- `finalize` chooses the path by sampling the recipe's reference text
  with `LanguageHeuristics.isMostlyCJK`.
- Post-call `enforceLanguage` runs `TranslatedAnalysisContent`
  translation when sample CJK ratio drifts past the threshold.

**Trade-offs**:
- One additional AI call when language enforcement fires (rare in the
  common case now that the proactive CJK path is in place).
- Two parallel prompt builders — same duplication as the brancher
  accepted (D-21). Maintainable enough.

**Commit**: this commit.

---

## D-24. Wikipedia article grounding for dish-name recipe generation

**Decided**: When generating a recipe from a dish name alone, first
try to fetch the dish's native-language Wikipedia article and pass
its plain-text extract to the AI as source material. The AI then
synthesizes a structured recipe from authentic text rather than
generating from its own training data. Falls through to pure-AI
generation when no Wikipedia article exists.

**Context**: User reported a translation bug — `pork belly` was being
output as `猪肚` (pork stomach) instead of `五花肉` (pork belly) on
the Chinese recipe path. Diagnosis: the AI was generating in English
internally then translating ingredient names without cultural / culinary
context, producing wrong cuts. User proposed: search authentic recipe
sources in the dish's language and have AI read those.

**Alternatives considered**:
- Google Programmable Search API for full web search — requires user-
  provided paid API key; ruled out by the "no external paid APIs
  without consent" guardrail (GUARDRAILS.md).
- Spoonacular / Edamam recipe APIs — paid keys, weak coverage of
  Chinese cuisine.
- Strengthen the existing AI prompt with explicit "use 五花肉 not 猪肚"
  examples — brittle, doesn't generalize across dishes.
- A built-in ingredient dictionary / glossary — large, hard to
  maintain across cuisines.

**Why Wikipedia grounding**:
- No API key required, no cost, no paid-key guardrail violation.
- Native-language Wikipedia articles are authentic source material
  written by native speakers. For Chinese dishes, the article uses the
  correct Chinese ingredient names; the AI sees them and preserves
  them.
- Reuses the existing `parseRecipe(fromText:expectedDish:)` AI path —
  no new prompt machinery, no new system prompt, no new tests for the
  synthesis behavior. The Wikipedia extract is just one more "user-
  pasted text" the parser handles.
- Falls through gracefully to pure-AI generation when no article is
  found (rare dishes, made-up names, etc.).

**Implementation**:
- `WikipediaArticleFetcher.fetchArticle(for:)` uses MediaWiki's
  `prop=extracts` + `generator=search` to get the top search hit's
  plain-text body. Tries CJK-Wikipedia first for CJK queries, English
  first otherwise.
- Extract truncated to 2500 chars (~1000 tokens) so the synthesis call
  fits in the 4096-token context window.
- `WikipediaGroundedRecipeGenerator` wraps another `RecipeGenerator`.
  Its `generateInitialRecipe(dishName:)` fetches the article, prefixes
  with "Source: Wikipedia article \"<title>\" (<lang>.wikipedia.org)\n\n",
  and calls `fallback.parseRecipe(fromText:expectedDish:)`. URL / text
  modes pass through to the fallback unchanged.
- Composition root in `App.swift` wraps `AppleIntelligenceRecipeGenerator`
  with `WikipediaGroundedRecipeGenerator` when AI is available. Mock
  fallback unchanged.

**Trade-offs**:
- Latency: one Wikipedia HTTP call (~500ms-2s) before the AI call. The
  user sees a longer loading spinner when adding a recipe.
- Not every dish has a Wikipedia article. Rare or made-up dishes still
  use the pure-AI fallback and may still have the translation-drift
  problem there. Acceptable — common dishes are the ones with the
  biggest user pain.
- Wikipedia article content isn't a recipe — it's an encyclopedic
  description that may mention ingredients and techniques but isn't
  formatted as steps. The AI's `parseRecipe` synthesizer turns the
  description into a structured recipe; quality depends on the article.
  Some articles have detailed preparation sections (great); others
  are mostly history and trivia (weaker synthesis output).
- The `parseRecipe(fromText:expectedDish:)` post-generation language
  enforcement (D-6) still applies, so any drift in the synthesized
  output gets caught.

**Commit**: this commit.

---

## D-23. Variation must remain the same dish (same-dish rule, base-name anchoring)

**Decided**: The variation brancher's system prompt enforces a "same-
dish rule" — the variation MUST remain a recognizable version of the
base dish, not a different one. The brancher now also receives the
base recipe name as an explicit parameter and threads it through both
the system instructions (with concrete examples) and the user prompt
(as a hard constraint anchor and a suggested name template).

**Context**: User reported "variation changed the entire dish name.
For example sweet sour pork became wonton when asked about English
style". The model interpreted "English style" too liberally and
generated a completely different English dish (wonton) rather than
an English-influenced version of the original sweet & sour pork.

**Alternatives considered**:
- Post-generation name-similarity check + retry — would catch the
  problem but adds latency on a per-variation basis even when the AI
  was already correct.
- Post-generation rename ("\(baseName) (\(directive))") — fixes the
  label but the ingredients/steps would still be for the wrong dish,
  silently misleading.
- Force the AI to output a name template ("X version of Y") — too
  rigid, doesn't fit all directives.

**Why prompt-level enforcement**: the AI is the source of the
drift; fix it at the prompt level rather than papering over
downstream. The base recipe name is now passed as an explicit signal
to the AI (both in instructions and user prompt) so the AI has no
ambiguity about the constraint. Concrete examples in the system
prompt show what's acceptable (modifier on base name) and what's
not (different dish entirely).

**Trade-offs**:
- Protocol change: `VariationBrancher.branch` gained a
  `baseRecipeName: String` parameter. Mock and Traced implementations
  updated. Caller (`VariationsViewModel.generate`) passes
  `recipe.name`. One-time cost.
- The prompt's "name templates" are language-specific. For CJK we
  show CJK templates, for English we show English. Already split by
  language path (D-21).
- If the AI still drifts (silent name change despite the prompt),
  it's not currently caught — that's the next safety net (post-
  generation name similarity check + retry) if this prompt-only fix
  proves insufficient. Tracked as future work.

**Commit**: this commit.

---

## D-22. ID preservation via text similarity for refinement / variation diffs

**Decided**: When converting AI output (`GeneratedRefinement`,
`GeneratedVariation`) into draft structures, match each generated
ingredient line and step text against the base revision's items by
text similarity, and reuse the base's `Ingredient.id` / `Step.id`
for matches. Items that don't match a base item retain a fresh UUID.

**Context**: The user reported "in variation diff, the same element
is shown as + then -". `RevisionDiffer` matches by `id`, but every
AI call produces fresh UUIDs for all ingredients and steps. As a
result, every base item was "removed" and every variation item was
"added", even when 90% of the content was identical. The same bug
existed in the refinement diff display; the user just happened to
notice it on variation.

**Alternatives considered**:
- Content-based diff algorithm (don't match by ID at all) — would
  require rewriting `RevisionDiffer` and propagating the change to
  every diff consumer. Larger blast radius.
- Ask the AI to emit ID-preserving change records — would need a
  schema change so the AI tells us "step 3 became this new text".
  More tokens, complex to validate, model could lie.
- Disable the structural diff for variations — would hide useful
  visual signal.

**Why ID preservation via similarity**: minimal change. `RevisionDiffer`
stays as is. Only the AI→draft conversion changes. The matcher is
language-aware (Jaccard on characters for CJK, on words for
non-CJK), greedy and one-to-one, with a 50% similarity threshold.

**Implementation** (`IDPreservingMatcher.swift`):
- `matchIngredients(generated:against:)` — for each generated
  ingredient line, find the most similar unused base ingredient. If
  similarity ≥ 0.5, reuse the base's ID. Else fresh ID.
- `matchSteps(generatedTexts:against:)` — same pattern for steps.
  Preserves base step's structured metadata (technique, estimated-
  Minutes, temperatureC, doneness, imageURL) when matched —
  important for `step.imageURL` so previously-generated illustrations
  survive a refinement.
- `textSimilarity(_:_:)` — Jaccard. Character-level for CJK,
  word-level for non-CJK.

**Trade-offs**:
- A genuinely-edited step (e.g., "Sear for 3 min" → "Sear for 5 min
  at 200°C") may share enough content with the base to match. Correct
  outcome: classified as edited, not added/removed.
- A radically-rewritten step might fall below the threshold and be
  classified as new. Correct outcome — the base step is shown as
  removed, the new step as added. The visual rendering still pairs
  them in sequence so the user can compare.
- The first generated item that scores above 0.5 against a base item
  claims it; later generated items that would also have matched
  fall through to "new". Acceptable for our typical case (most
  ingredients have distinct names; collisions rare).

**Commit**: this commit.

---

## D-21. Language-targeted system + user prompts for brancher (CJK Chinese-only path)

**Decided**: For variation branching, when the base recipe is CJK,
use a fully-Chinese system prompt + Chinese user prompt path —
mirroring the catalog generator's CJK retry. Stricter post-generation
threshold (>60% CJK content required, vs the generic 30%) catches
mixed-language drift that the previous threshold missed. Strengthen
both system prompts with an explicit LANGUAGE RULE block stating that
the directive's language does not determine output language; the base
recipe's does.

**Context**: User reported "when applying the second variation, it
falls back to English". First variation came back in Chinese (the AI
happened to honor the implicit language hint); second variation drifted
to English. The previous post-generation check used `isMostlyCJK` which
returns true at only 30% CJK characters — a 50/50 mixed output passed
the check and never triggered translation.

**Alternatives considered**:
- Only strengthen the prompt — the model is non-deterministic, prompt
  alone isn't enough.
- Only raise the detection threshold — model would keep drifting,
  triggering more translation calls (slower).
- Always force translation post-generation when base is CJK — would
  add a guaranteed extra call on every variation. Costly.

**Why this scope**: matches the catalog generator's proven pattern.
Bilingual surface area (English prompt asking about Chinese base) is
the primary drift driver — removing it for CJK bases reduces drift at
the source. The stricter threshold catches whatever still leaks
through.

**Trade-offs**:
- A new `LanguageHeuristics.cjkRatio(_:)` exposes the raw 0…1 ratio so
  call sites can apply their own thresholds. `isMostlyCJK` is retained
  and delegates to `cjkRatio > 0.3` for callers that want the looser
  classification.
- Two parallel prompt builders (`buildEnglishPrompt`,
  `buildChinesePrompt`) — modest duplication. Worth it for clarity.

**Commit**: this commit.

---

## D-20. Variation approval gate + language enforcement + structural diff

**Decided**: The variation flow gets the same treatment as the
refinement flow — generation produces a proposal that the user
reviews via Apply / Discard, language is enforced against the base
recipe's language, and the proposal view shows the model-reported
changes plus the ground-truth structural diff vs the base revision.
The variation row in the saved list also surfaces the change list
(not just a truncated rationale) so users can see at a glance what
each variation modified.

**Context**: User reported three issues with the prior variation
flow:
1. Variation came back English even when base recipe was Chinese
   (no post-generation language enforcement, unlike the refiner).
2. Variation list row showed only a 2-line truncated rationale, no
   structural visibility into what changed.
3. Variations were auto-saved on Create — no review step.

**Alternatives considered**:
- Only fix language (skip approval / diff) — leaves the user with no
  preview of changes before commit. Inconsistent with refinement UX
  which already has an approval gate.
- Fix diff display in list only (skip approval) — still auto-applies;
  user can't reject a bad proposal without manually deleting.
- Build a full variation-history flow with per-variation revisions
  shown like the base — overkill; the immediate concern is the
  initial proposal.

**Why this scope**: each fix maps to a concrete user concern. The
approval gate mirrors the refinement gate the user already knows.
Language enforcement reuses the refiner's pattern with a
variation-specific `TranslatedVariationContent` schema. The diff
view extracts `StepDiffRow` + `IngredientDiffRow` from
`RefinementResultView` into a shared `DiffViews.swift` so both
result surfaces are visually consistent.

**Trade-offs**:
- One extra user tap per variation (Propose → Apply). Acceptable
  given the user explicitly asked for the gate.
- Reference language is the base recipe's, not the directive's. An
  English-speaking user typing "without chili" against a Chinese
  recipe gets a Chinese variation. Could be wrong if the user
  intends to fork into English; that's a future split-personality
  problem we'll deal with if it comes up.
- The diff view doesn't yet display the variation's metric metadata
  (servings, prep / cook minutes) compared to base — only ingredients
  and steps. Variations rarely change those metrics. Add later if
  needed.

**Commit**: this commit.

---

## D-18. Documentation maintenance is a hard rule

**Decided**: Any commit that affects the file set, service
responsibilities, composition root, image / illustration / language
pipelines, or user-visible flows must update `DESIGN.md` in the same
commit.

**Context**: Documentation drift compounds. A new Claude session
that reads stale docs makes wrong design judgments.

**Alternatives considered**:
- Update docs in a follow-up commit — never happens reliably.
- Keep docs minimal and oral — defeats the point of session
  continuity.

**Why same-commit**: enforced by ritual, not tooling (no pre-commit
hook). The CLAUDE.md "Documentation maintenance — required" section
states the rule.

**Trade-offs**: small per-commit time cost. Worth it.

**Commit**: rule added in `b971e46`.
