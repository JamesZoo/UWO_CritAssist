# Vision Probes

Four standalone iPad apps that test Apple Intelligence / Vision API
symbols related to **image input** for AI. The point: figure out which
API surfaces are actually usable on Swift Playgrounds before wiring
them into the main app (so we don't repeat the
"guess-and-revert" cycle from the text-AI probes).

Future use cases the main app will eventually need:
1. Validate that a photo (from Wikipedia, Image Playground, or the
   user) actually depicts the named dish.
2. Let the user take a photo of the **cooked dish** and have the AI
   compare the outcome to the recipe (e.g. "the sauce looks too
   reduced" or "the meat doesn't look browned").

## How to run

For each `.swiftpm` folder:

1. Pull this branch in Working Copy.
2. Files app → Working Copy → UWO_CritAssist → ios-app → AIProbes →
   Vision → `01-DirectImageInput.swiftpm` (or whichever).
3. Long-press → "Open in Swift Playgrounds".
4. Tap ▶ Play.
5. Use the **Pick a photo** button to choose any image from your
   library.
6. Tap **Run probe**.
7. Read the result and screenshot it back to me.

Three possible outcomes per probe:

- **Green YES + response text** — the API exists and produced a result.
  The response text in the box tells me the actual return type and a
  sample value.
- **Red NO + error message** — the API exists at compile time but
  failed at runtime. The error text identifies why.
- **Won't build, red markers in editor** — the symbol doesn't exist
  by that name. Screenshot the red markers so I know which symbol is
  wrong.

## The probes

| # | Folder | Tests |
|---|---|---|
| 1 | `01-DirectImageInput.swiftpm` | Does `LanguageModelSession.respond(to:image:)` exist? The cleanest path — pass an image directly to the on-device model. |
| 2 | `02-VisionClassify.swiftpm` | Does `Vision.VNClassifyImageRequest` return useful labels? The fallback if direct image input isn't supported — get labels via Vision, then ask the LLM about those labels. |
| 3 | `03-VisionPlusLLM.swiftpm` | Combines probe 2's classifier with a text query to `LanguageModelSession`. End-to-end test of the chained approach. |
| 4 | `04-ImagePlayground.swiftpm` | Does `ImagePlayground.ImageCreator` (or similar) exist? Tests image *generation* for the "if no public photo found, generate via AI" fallback the user mentioned earlier. |

## What I'll do with the results

- If probe 1 works → wire `respond(to:image:)` into a new
  `AppleIntelligenceImageValidator` service to replace the current
  title-comparison validator in `ValidatedImageService`. Same service
  can later be reused for the "compare cooked-dish photo against
  recipe" feature.
- If probe 1 fails but probes 2 + 3 work → wire the Vision + LLM
  chain instead. Slightly less elegant but functionally equivalent
  for our purposes.
- If probe 4 works → add an Image Playground fallback for the case
  where Wikipedia returns no usable image at all.
