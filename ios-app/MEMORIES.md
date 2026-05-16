# Memories — accumulated context for the Claude assistant

Things the assistant has learned about this user, this project, and Apple
Intelligence in Swift Playgrounds. Mostly hard-won — listed here so a new
session doesn't re-discover them from scratch.

## About the user

- **No Mac**. Develops on **iPad M5 Pro** and an **iPhone 16 Pro Max** —
  both Apple Intelligence capable. Edits via Working Copy (git) + opens
  `.swiftpm` packages in Swift Playgrounds. No Xcode. No CI yet.
- **Bilingual** English + Chinese. Asks questions in either language;
  match the language they wrote in.
- **Tight communicator**. Short questions, expects short answers with
  file names + line numbers, no emojis, no fluff.
- **Tests by running**. The only feedback loop is: assistant pushes →
  user pulls → user rebuilds in Swift Playgrounds → user sends back a
  screenshot of the result. Make each push self-contained.
- **Catches screenshot details**. Reads error messages closely. The
  assistant has been corrected at least twice for misreading errors.
- **Patient through revert cycles**, but visibly frustrated when
  progress reverses. The revert at `3e7d163` after the bad FoundationModels
  guess (`1067f4b`) cost real time.

## About Apple Intelligence on Swift Playgrounds

### Text AI (confirmed via probes `01–05`)

- `import FoundationModels` works.
- `SystemLanguageModel.default.availability` is an enum with associated
  values, **not equatable** — use `if case .available = …` to check.
  This caused the `1067f4b` revert.
- `LanguageModelSession(instructions: String)` initializer exists.
- `session.respond(to: prompt)` returns text. `session.respond(to: prompt,
  generating: T.self)` returns a structured `T`.
- `@Generable` macro works on structs. `@Guide(description:)` works on
  properties. Nested `@Generable` types in arrays work
  (`[GeneratedChange]` inside `GeneratedRefinement`).
- `LanguageModelSession.GenerationError.guardrailViolation(Context)` is
  the safety-filter case. Caught with `if case .guardrailViolation = …`.

### Image AI

- **No direct image input to `LanguageModelSession`**. Probe `Vision/01`
  build-errored: "Extra argument 'image' in call". `respond(to:image:)`
  doesn't exist.
- `Vision.VNClassifyImageRequest` works (`Vision/02`) but its labels are
  too generic for dish-level identification. `Vision/03` confirmed the
  chain `Vision → LLM text` confuses sushi for pizza on real photos.
- `ImagePlayground.ImageCreator` works with `.animation` style
  (`Vision/04` confirmed). Other styles untested. Output is stylized
  cartoon, not photorealistic.
- The model has English-classifier bias that makes Vision+LLM unfair
  to Chinese inputs.

## About Apple Intelligence's safety filter

The on-device model is **aggressive on Chinese dish names**. Confirmed
guardrail violations for:

- `爆炒腰花` (pork kidney — likely tripping on "organ meat")
- `红烧排骨` (red-braised pork ribs — completely benign, still rejected
  on first prompt phrasing)

Working mitigation chain (in `AppleIntelligenceRecipeGenerator.generateInitialRecipe`):

1. **Catalog-lookup framing**: present the dish name as a label in a
   catalog of well-known dishes with mixed Chinese + Western examples.
2. **Same-language retry for CJK**: if the English-framed catalog
   request fails, retry with a fully-Chinese system prompt and user
   prompt — removes the bilingual surface the filter reacts to.
3. **Friendly fallback**: if all three attempts hit the guardrail,
   throw `safetyDeclined`, auto-switch the UI to Paste mode, and show
   a banner that says the **safety filter** declined — not "no recipe
   found", because the recipe exists.

## About language drift

Even with explicit LANGUAGE RULE in the system prompt, the model
frequently outputs English ingredients and steps for a Chinese dish
name. Mitigation: **trust nothing, verify the body language after
generation**, translate if mismatched. See `enforceLanguage` methods on
the generator and refiner. The verification uses
`LanguageHeuristics.isMostlyCJK`.

Also helps: in the system prompt, instruct the model to draw on
language-appropriate culinary sources (Chinese cookbooks, zh.wikipedia.org
for Chinese dish names). The model's training data includes these, and
the hint biases its voice. This reduces mismatch frequency but doesn't
eliminate it.

## About image-source matching

Wikipedia search often returns broader-category articles (e.g. `广东菜`
when searching for `广式红烧肉`). The hero image of those articles is
unrelated to the actual dish.

Mitigation chain in `ValidatedImageService`:

1. AI validates the article title against the dish name with **visual-
   similarity reasoning**, not identity: "would this article's typical
   hero photo *look like* the dish?". Accepts: exact, alternate name,
   same dish family, main ingredient. Rejects: broader cuisine category.
2. If rejected, AI suggests up to 3 alternative names (incl. main
   ingredient and English translation) to re-search.
3. If all alternatives also rejected, falls through to AI generation
   via `FallbackImageService` → `AppleIntelligenceStepIllustrator.generateRecipeImage`
   (labeled "AI generated" in the attribution chip).

## About file paths in Swift Playgrounds

Apps built by Swift Playgrounds save `Documents/`-rooted files under
`/var/mobile/Containers/Data/Application/<UUID>/Documents/...`. The
`<UUID>` part **gets reassigned** between launches more often than in a
TestFlight build — saved absolute paths become stale.

Mitigation: `LocalImagePathResolver.resolved(_:)` finds the `/Documents/`
segment in the saved URL, strips the prefix, and re-attaches the
suffix to the current launch's Documents directory. Use it on every
view that displays an AI-generated image URL.

## About Swift Playgrounds quirks

- Test targets don't link — Swift Playgrounds can't find the Swift
  Testing framework. The test target was excluded from `Package.swift`
  early on (commit `93d8591`). Tests still exist under `Tests/AppModuleTests/`
  for future CI use, but `swift test` works only when run on a Mac.
- Some `AppleProductTypes` enum values that look reasonable (e.g.
  `.bowlOfRice` for `appIcon`) don't actually exist. Same commit
  `93d8591` removed an early guess.
- First-time compile of a `.swiftpm` that imports `FoundationModels` can
  hang for ~60s while Apple resolves the framework. Don't assume hang ==
  broken; the user already learned this with probe 1.
- Compile errors that originate in one file can cascade into "Cannot
  find X in scope" errors in unrelated files. When that happens, look
  for the **root error in the originating file**, not the cascade.

## Decisions and why

| Decision | Why |
|---|---|
| Mock services kept around in production code | Devices without Apple Intelligence (and the unit-test path) substitute mocks via the same protocols. LSP test substrate. |
| Image validator uses text comparison, not vision | Direct vision input to `LanguageModelSession` doesn't exist. Vision+LLM chain proven unreliable for dish recognition. |
| `LanguageHeuristics` 30% threshold for "mostly CJK" | Empirical — handles bilingual content (e.g. "Chinese mapo tofu") without false positives on dish names that contain a few CJK characters. |
| ImagePlayground `.animation` style for everything | Only style confirmed via probe 4. Other styles untested. Cartoon look is acceptable for step illustrations (cookbook-style), tolerable for fallback profile photos. |
| Post-generation translation runs only on mismatch detection | First-attempt prompt biasing is preferred — saves an AI call on the common case. Translation is the safety net. |
| Step illustration is on-demand (button), not automatic | Avoids 30-60s wait on every recipe creation. User chooses when to spend the latency budget. |
| Test target excluded from `.swiftpm` | Swift Playgrounds can't link Swift Testing. Re-include when CI is wired. |

## What's still unsolved

- Direct image input to LLM (waiting on a future iOS release)
- Photorealistic AI image generation (would need external API + paid key)
- Step photos from real public sources (Google Images requires paid key;
  Wikimedia Commons search is the proposed compromise, not yet wired)
- iCloud sync, TestFlight pipeline (deferred; documented in DESIGN.md
  future-work section)
