# Guardrails — concrete don'ts for the Claude assistant

Hard rules. Each entry has a brief rationale, often tied to a past
incident in this repo. Read this list when picking up a task.

## Don't guess Apple API surfaces

**Rule**: Before writing main-app code that calls a FoundationModels,
Vision, ImagePlayground, or other Apple-Intelligence API, **confirm
the symbol exists** via a `.swiftpm` probe under `ios-app/AIProbes/`.

**Why**: Commit `1067f4b` shipped a FoundationModels generator with a
wrong availability check (`==` on an enum with associated values).
The whole `#if canImport(FoundationModels)` block stopped compiling,
the `AppleIntelligenceRecipeGenerator` type vanished from scope, and
App.swift errors cascaded. Reverted in `3e7d163`. The probes (`01–05`)
were created in response and have been reliable ever since.

## Don't bypass `LocalImagePathResolver`

**Rule**: When rendering an AI-generated image (file URL saved in a
prior launch), pass the URL through `LocalImagePathResolver.resolved(_:)`
**every time**.

**Why**: iOS app container UUIDs change between Swift Playgrounds
launches. Stale absolute paths leave the user with blank thumbnails
where there should be a generated photo. Commit `35112e6` introduced
the resolver — bypassing it re-opens the regression.

## Don't `+`-chain strings with `.map().joined()`

**Rule**: When building a sample string from multiple sources, use
**local `let`s and string interpolation**, not `+`-chained
concatenation.

**Why**: Swift's type checker times out on the combination of `String`
+ overload + generic `.map(\.x).joined(separator:)` chains. Commit
`9ab4aa0` fixed three sites that hit this; introducing new sites is
re-introducing the bug.

## Don't add a Swift Testing target to `Package.swift` in `.swiftpm`

**Rule**: Keep the test target out of the `Package.swift` manifest in
`RecipeSharpener.swiftpm/`. The `Tests/AppModuleTests/` directory on
disk is fine — it's just not declared as a target.

**Why**: Swift Playgrounds can't link the Swift Testing framework when
building an `iOSApplication` product. Including the `testTarget`
declaration makes the whole package unbuildable. Commit `93d8591`
removed it. When CI lands, the testTarget can be re-added in a
CI-only `Package.swift` variant or restored via a flag.

## Don't push a commit that obviously breaks the build

**Rule**: Before committing main-app code, sanity-check that:

- New API calls have been validated (see "Don't guess Apple API surfaces").
- New types are referenced consistently (don't gate one usage inside
  `#if canImport(X)` and another usage outside it).
- New `@Sendable` closures actually annotate the inner closure literal.
- New string-builder expressions don't trigger type-check timeouts.

**Why**: Each broken push costs the user a Working-Copy-pull + Swift-
Playgrounds-build + screenshot-back cycle. Their iteration loop is
slow; respect it.

## Don't pretend an unverified feature is shipped

**Rule**: When wiring a new Apple API into the main app, if you haven't
probed it, **say so**. Don't write commit messages or chat replies
implying the feature works end-to-end when only the wiring compiles.

**Why**: The user reads the chat to know what to test. False confidence
wastes their time and trust.

## Don't change `DESIGN.md`-relevant code without updating `DESIGN.md`

**Rule**: A commit that changes the file set, a service's responsibilities,
the composition root, the image/illustration/language pipeline, or a
user-visible flow must update `DESIGN.md` in the same commit.

**Why**: Documentation drift compounds. The next Claude session relies
on the doc being accurate to avoid re-deriving context from commit
history. See "Documentation maintenance — required" in CLAUDE.md.

## Don't use external paid APIs without explicit user consent

**Rule**: Don't add code that calls Google Custom Search, Unsplash,
Pexels, OpenAI, Anthropic API, or any other paid / keyed service
**without first asking** the user. If the user says yes, ask them to
provide the API key separately rather than committing it.

**Why**: Cost, key management, and external network dependency are
real trade-offs. Bake those in only with consent. Also: don't commit
secrets to the repo.

## Don't push to a branch the user didn't authorize

**Rule**: Push only to the branch the user has assigned for the current
task (currently `claude/test-and-bugfix-recipe-sharpener`). Don't
force-push, don't merge to `master`, don't push to other contributors'
branches.

**Why**: The user's PR review workflow assumes a single feature branch
per session. Surprises in branch state break that workflow.

## Don't widen the public surface area without need

**Rule**: Default to `private` / `fileprivate` on new types and helpers.
Widen to `internal` only when another file actually needs the symbol.
Don't make things `public` in an app target — it's not a library.

**Why**: Reduced surface area = less coupling and fewer accidental
dependencies. The `LanguageHeuristics` refactor (commit `dc1229d`) was
an example of folding three private duplicates into one `internal`
namespace; the namespace itself stays minimal.

## Don't break the user's ability to keep testing

**Rule**: Even when refactoring, prefer changes that compile end-to-end
in one commit. If a multi-step refactor is necessary, use
**deprecation shims** rather than a partial-state commit that breaks
the build between steps.

**Why**: The user can't easily roll back to a "last known good" via
TestFlight (no TestFlight). Each broken main branch state is a
disrupted iteration loop.
