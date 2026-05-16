# AI Probes

Five tiny standalone iPad apps that test individual Apple Intelligence /
FoundationModels API symbols. Run them one at a time in Swift Playgrounds.
Each app shows a big **YES** if the API worked, **NO + error details** if it
didn't, or fails to build if the symbol doesn't exist at all.

The point: figure out which API names actually exist in Swift Playgrounds
on iPadOS 26, so we can re-wire the real backend without another round of
broken guesses.

## How to run

For each probe folder (`01-Import.swiftpm`, `02-SystemModel.swiftpm`, …):

1. In Working Copy, navigate to `ios-app/AIProbes/<folder>`.
2. Open the `.swiftpm` package in Swift Playgrounds (same way you opened
   the main RecipeSharpener app).
3. Tap ▶ Play.
4. Three possible outcomes:
   - **Big green YES** → that API works. Note any text shown below it
     (type info, returned value, etc.).
   - **Big red NO** with error text → the symbol compiled but failed at
     runtime. Screenshot the error.
   - **Won't build, red markers in editor** → the symbol doesn't exist
     by that name. Screenshot the errors.
5. Send the screenshot (or just "YES" / the error text) back to me.

Do this in order — probe 1 first, then 2, then 3, etc. If probe 1 fails to
build, the others almost certainly will too; stop and report.

## The probes

| # | Folder | What it tests |
|---|---|---|
| 1 | `01-Import.swiftpm` | `import FoundationModels` resolves |
| 2 | `02-SystemModel.swiftpm` | `SystemLanguageModel.default.availability` exists and what it returns |
| 3 | `03-Session.swiftpm` | `LanguageModelSession(instructions:)` initializer exists |
| 4 | `04-Respond.swiftpm` | `session.respond(to:)` returns a usable response |
| 5 | `05-Generable.swiftpm` | `@Generable` + `@Guide` macros work, structured output via `respond(to:generating:)` |

After we know which probes pass, I'll re-wire the real backend in the main
app correctly the first time.
