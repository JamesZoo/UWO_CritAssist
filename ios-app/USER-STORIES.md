# User Stories & Use Cases — Recipe Sharpener

The architectural docs (DESIGN.md, MEMORIES.md) describe what the code is.
This doc describes **what the user wants from the app** and **what
workflows the assistant has been tuning for**. A new Claude session
needs this context to make good design judgments — without it, the
"why" behind decisions like catalog framing or per-recipe sessions
won't make sense.

## Persona

**The developer-cook** — single user, technical enough to test
end-to-end, cooks regularly at home, prefers Chinese cuisine but also
cooks Western dishes. Uses an iPad M5 Pro for development and
testing; secondary device is an iPhone 16 Pro Max. Bilingual English
and Chinese. Doesn't have a Mac and won't accept a workflow that
requires one. Will spend the time to iterate on a recipe over many
rounds of cooking and feedback to get a personalized "best version".

There is no public user base — this is a personal-use tool that the
developer is building for themselves and may eventually share.

## Core user stories

In rough priority order (top is most important to get right):

1. **Iterate a recipe via natural-language feedback.**
   *As a cook, I want to give the AI a sentence about what was wrong
   with the dish ("meat too chewy, soup too sour"), have it diagnose
   the cause, propose targeted changes, and let me approve or discard.*
   This is the heart of the app. Everything else supports this loop.

2. **Understand causation between feedback and changes.**
   *I want to see why the AI changed what it changed — which specific
   feedback drove each ingredient swap or step edit — so I can trust
   (or reject) the model's reasoning.*

3. **Add a recipe with just a dish name in any language.**
   *I want to type `回锅肉` or `Coq au Vin` and get a usable starting
   recipe drawn from public-source knowledge, in the same language as
   my input.*

4. **Bring my own recipe when the model doesn't know it.**
   *When the AI declines a dish (rare name, safety filter, etc.), I
   want to paste my own recipe text or share a URL, with a short note
   about what kind of dish to expect.*

5. **Branch variations from a base recipe.**
   *I want to fork "without chili" or "vegetarian" or "extra spicy"
   from a working base recipe, and refine each branch independently.*

6. **Get a representative photo for each recipe.**
   *I want a real public-source photo when one exists, an AI-generated
   illustration when it doesn't, clearly labeled. Photos must persist
   across app launches.*

7. **See key cooking moments illustrated.**
   *I want 2-4 step illustrations at the meaningful checkpoints
   (after prep, during the critical transformation, near completion)
   — not every step. Generated on demand, persisted.*

8. **Produce a final shareable document.**
   *After several rounds of refinement, I want a polished write-up of
   the best base recipe plus the best version of each variation, with
   a narrative summary of the journey.*

9. **Undo a refinement if it was wrong.**
   *I want to roll back to the previous revision when a proposal
   turned out badly in practice.*

10. **Delete recipes I no longer need.**

## Detailed use cases

These are the concrete walkthroughs that have been used to drive
design and test the implementation. They double as a regression
checklist.

### UC-1: First refinement of a known dish

1. User taps `+` → "Dish name" → types `宫爆鸡丁` → Create.
2. Apple Intelligence returns a Chinese-language recipe with
   ingredients (chili, peanuts, Sichuan peppercorns, chicken thigh,
   Chinkiang vinegar) and steps.
3. Profile photo comes from Wikipedia / Wikimedia, validated for
   visual similarity.
4. User taps `Give first feedback` on the card → enters
   *"肉太柴，汤太酸"* (meat too tough, soup too sour) → Refine recipe.
5. App shows the refinement proposal: diagnosis, rationale, change
   list each tagged with the feedback that caused it, structural
   diff.
6. User taps Apply → recipe is updated with the new revision.

**Success**: response is in Chinese, diagnosis is plausible, changes
address the feedback, no error.

### UC-2: First refinement of a niche dish

1. User types `东北酱猪蹄`.
2. Apple Intelligence first attempt may be guardrail-rejected;
   catalog-lookup retry succeeds.
3. Wikipedia search returns a broader article (`东北菜` cuisine).
   Validator rejects (cuisine category, not dish). Alternative-name
   provider returns `["猪蹄", "酱猪蹄", "pig trotters"]`. Wikipedia
   search for `猪蹄` returns the ingredient article. Validator
   accepts (main ingredient, visually similar). Photo shows pig
   trotters.
4. Refinement loop proceeds normally.

**Success**: a representative photo appears (not dim sum, not blank),
recipe is in Chinese, the dish actually gets generated despite being
niche.

### UC-3: Multi-round refinement

1. Recipe exists with one refinement applied.
2. User taps `Give feedback` again, enters new feedback.
3. The refiner reuses the same `LanguageModelSession` for this
   recipe (per-recipe session store).
4. Model's response references its prior diagnosis if relevant.
5. Repeat for 3-5 rounds.

**Success**: no context-window overflow error, model maintains
reasoning continuity across rounds, language stays consistent.

### UC-4: Undo a bad refinement

1. User applies a refinement that turns out wrong in practice.
2. User long-presses the card → `Undo last refinement` → confirm.
3. Latest revision is popped; feedback that drove it is removed; the
   per-recipe refinement session is reset so the model doesn't reason
   from a stale memory next time.

**Success**: card reverts to the prior revision's content. Next
refinement starts with a fresh session.

### UC-5: Import from URL with translation

1. User taps `+` → `Link` → pastes an English seriouseats.com recipe
   URL → types `红烧肉` in the "What kind of dish do you expect?"
   field → Create.
2. `WebRecipeExtractor` fetches the page; JSON-LD path succeeds.
3. `DefaultRecipeGenerator` detects a language mismatch (description
   CJK, extracted content English) → runs the AI translator.
4. Saved recipe is in Chinese, image is the source page's hero photo.

**Success**: imported recipe is in Chinese (matching the user's
description), ingredients and steps are intact, source-page image is
retained with attribution.

### UC-6: Paste a "secret" recipe

1. User taps `+` → `Paste recipe` → pastes plain text in any
   language, may be messy with line breaks and minor noise → adds a
   short "expected dish" description.
2. AI parses the text, extracts ingredients with quantities and steps,
   ignores non-recipe content.
3. Recipe is saved in the language of the expected-dish description.
4. No public-source photo is found (it's a personal recipe) → AI
   generates an illustration as fallback, labeled "AI generated".

**Success**: messy input becomes clean structured recipe in the right
language, profile photo isn't blank.

### UC-7: Variation branching

1. User opens 宫爆鸡丁 card → `Variations` → types `不辣` → Create.
2. AI creates a "No-chili" variation, removes chili-related
   ingredients, adjusts other heat sources to keep balance, explains
   what changed.
3. User taps `Give feedback on this variation` → feedback is scoped
   to the variation, refining its own revision chain (not the base).

**Success**: base recipe untouched, variation has independent chain,
refinement of variation doesn't affect base.

### UC-8: Step illustrations on demand

1. User opens a recipe card → taps `Illustrate`.
2. AI picks 2-4 key cooking-in-action moments (after prep complete,
   transformation moment, near completion) — not every step.
3. For each moment, `ImagePlayground` generates a cookbook-style
   illustration. Each appears inline under the chosen step as it
   becomes ready.

**Success**: 2-4 steps gain inline images, others stay text only.
Images persist across app launches.

### UC-9: Final analysis after iteration

1. User has a recipe with 3+ base revisions and 1-2 variations.
2. User taps `Analysis` on the card → `Analyze`.
3. `BestRevisionPicker` picks the best base revision and best
   variation revisions (highest ratings or most recent).
4. AI writes a journey narrative + a polished markdown document with
   the best-of-each.

**Success**: narrative is coherent, final document contains best
ingredients + steps for base and each variation, formatted for
copy-paste.

### UC-10: Persistence across launches

1. User creates recipes, refines, illustrates, edits.
2. User force-quits the app → reopens.
3. All recipes are intact: revisions, variations, feedback,
   profile photos (including AI-generated), step illustrations.

**Success**: nothing is lost. Notably, AI-generated image file paths
re-resolve correctly via `LocalImagePathResolver` even if the app
container UUID changed.

### UC-11: Black-box testing the AI behavior

1. User opens Settings → loads a fixture scenario (e.g. 宫爆鸡丁).
2. User runs through UC-1 to UC-9 on the fixture.
3. After each AI call, user opens Settings → AI trace → reads the
   latest entry: service name, input summary, response summary,
   backend (`onDevice` / `mock`), latency.
4. User uses the tester-note field on feedback to record what they
   expected vs what they got.
5. User exports the full recipe JSON for offline comparison or to
   share a failure case.

**Success**: every AI call is traceable, fixtures are reproducible,
state can be exported and reset for clean re-runs.

## Success criteria across the app

- **Language consistency**: every text field of a recipe is in the same
  language as the dish name / expected-dish description. No mixed
  output.
- **Causation visibility**: every model change is tagged with the
  feedback that drove it. The refinement result view always shows the
  diagnosis explicitly.
- **No silent failures**: when AI is rejected by the safety filter,
  the user sees a clear banner and is steered to Paste mode — not
  "no recipe found" which would mislead.
- **Photos either match or are honestly labeled**: real Wikipedia
  photo passes the visual-similarity validator, AI-generated photo
  carries the "AI generated" attribution chip.
- **Latency is honest**: any operation that takes more than 1s shows
  a progress indicator. The user shouldn't wonder if the app froze.
- **Bilingual support throughout**: error messages, prompts, system
  text don't degrade when the active dish is Chinese.

## Out of scope (explicit anti-cases)

These have been considered and **deliberately excluded** to keep the
project focused:

- **Multi-user / sharing**: single-user app. Export-to-JSON is the
  sharing mechanism.
- **Nutrition info / dietary tracking**: not a fitness app.
- **Shopping list / pantry tracking**: not yet. Possible future
  feature but not part of the current loop.
- **Voice input / hands-free cooking mode**: not in scope.
- **Real-time photo analysis of cooking outcomes**: blocked by Apple's
  lack of a direct image-input API for `LanguageModelSession`.
- **Live web search for recipes**: would require a paid API key.
- **Photo-quality realism**: ImagePlayground only produces stylized
  cartoon output. Real-photo-style AI generation would require an
  external paid API.

## Test scenarios using real dishes (regression checklist)

When evaluating any AI-touching change, run through these:

| Dish | Tests |
|---|---|
| `宫爆鸡丁` | UC-1 happy path; language consistency; canonical refinement |
| `麻婆豆腐` | Same as above, second known dish |
| `回锅肉` | Catalog framing — was previously safety-filter rejected |
| `红烧排骨` | Same; benign dish that triggered guardrail |
| `爆炒腰花` | Worst-case safety filter — organ meat. Multi-attempt retry, may end in `safetyDeclined` and paste-mode auto-switch |
| `广式红烧肉` | Image validator must reject dim-sum-for-braised-pork |
| `东北酱猪蹄` | Alternative-name retry → finds `猪蹄` ingredient article |
| `奶奶秘制番茄面` (made-up) | AI generation fallback for profile photo |
| English `Beef Wellington` | Language consistency in English |
| Paste mode with English text + Chinese description | Translation pass works |
