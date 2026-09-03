## 1. Documentation & Comments (STRICT — comment volume is currently too high, enforce hard)

- Default: No Comment. The default action is to write zero comments. A comment is the exception, not the norm, and must justify its own existence.
- One-Liners Only, No Exceptions Without Cause: When a comment is justified, it MUST be a single concise line. Multi-line comments are prohibited unless a single line genuinely cannot capture a necessary explanation (e.g. a non-obvious multi-step workaround) — this is rare, not routine.
- Focus on "Why", Never "What": Only comment non-obvious business logic, technical debt, or complex algorithms. Never describe what code does when the code already shows it.
- Self-Documenting Code: If logic is simple and easily understood, do not add a comment even if it "seems helpful." Rename variables/functions instead of explaining them.
- No "Vibe-Coding": Never restate function names, obvious syntax, or parameter meaning in comment form.
- Audit Before Adding: Before writing any comment, ask whether removing it would confuse a future reader. If not, delete it.
- No Emojis: Do not use emojis anywhere in code, comments, or documentation.
- No Em-dashes: Use standard punctuation only; avoid the use of em-dashes (—).

## 2. Logic & Architecture

- Prioritize Correctness: Do not sacrifice correctness for conciseness.
- Defensive Programming: Always implement input validation and explicit error boundaries.
- State Management: Be explicit about state transitions. Avoid side effects in pure functions.
- No Placeholders: Provide functional, executable code. Do not use `// implement logic here` or `...rest of code`.

## 3. Style & Patterns

- Explicit over Implicit: Avoid "magic" syntax or clever one-liners that obscure intent.
- Naming: Use domain-specific, descriptive nouns. Avoid generic names like `data`, `info`, or `handleResult`.

## 4. Refactoring & Iteration

- Edge Case Validation: Mentally execute logic against null values, empty arrays, and timeouts before finalizing.
- Boring Code: Aim for code that is predictable, robust, and easy to maintain.

## 5. Interaction

- No Unprompted Follow-Ups: Do not offer to do additional work, ask "would you like me to also..." questions, or suggest next steps unless the user asks for suggestions. End responses once the requested task is done.

## 6. Python Standards

- basedpyright Strict: All Python code must satisfy `basedpyright` in strict mode with zero errors and zero warnings.
- No Unused Returns: Every function's return value must be consumed or explicitly discarded (e.g. assigned to `_`). Never leave a meaningful return value unused at a call site.
- Full Type Coverage: Annotate all function signatures (parameters and return types) and all class attributes. No implicit `Any`.
- No Untyped `Any`: Avoid `Any` unless narrowing from an external/untyped source is unavoidable; narrow it to a concrete type immediately.
- Strict Optional Handling: Never access an attribute or call a method on a value that basedpyright infers as `None`-able without a narrowing check first.

## 7. TypeScript Standards

- No `any`: Never use `any`. Use `unknown` and narrow types when the shape is not immediately certain.
- Interfaces for Data Shapes: Define an `interface` or `type` for every data shape crossing a function boundary; do not pass around untyped objects.
- Strict Mode: Code must compile clean under `strict: true` (or the project's stricter tsconfig) with zero errors.
- No Unused Values: No unused variables, imports, or parameters; no ignored Promise rejections (`.catch` or `await` every promise).
- Narrow Before Use: Never access a property on a value typed as possibly `null`/`undefined` without narrowing first.

## 8. C++ Standards

- Modern C++ (C++17/20+): Prefer the standard library and modern idioms over hand-rolled equivalents (e.g. `std::optional`, `std::variant`, ranges) where available.
- RAII Always: Manage all resources (memory, file handles, locks) via RAII. No raw `new`/`delete`; use smart pointers (`std::unique_ptr`/`std::shared_ptr`) when heap allocation is genuinely needed.
- No Undefined Behavior: Avoid UB-prone patterns: no uninitialized reads, no signed integer overflow, no dangling references, no out-of-bounds access.
- const-Correctness: Mark everything `const` that is not mutated, including member functions and parameters passed by reference.
- Warnings as Errors: Code must build clean with `-Wall -Wextra -Wpedantic` (or the project's equivalent) with zero warnings.

## 9. Go Standards

- Explicit Error Handling: Check every returned `error` immediately; never discard an error with `_` unless the call genuinely cannot fail or the ignore is intentional and obvious from context.
- go vet / staticcheck Clean: Code must pass `go vet` and `staticcheck` with zero findings.
- No Naked Returns in Non-Trivial Functions: Prefer explicit `return` values over naked returns once a function has more than a couple of lines.
- Idiomatic Concurrency: Use channels and `sync` primitives deliberately; every goroutine must have a clear termination condition and no leaked goroutines.
- Minimal Interfaces: Keep interfaces small (prefer single-method interfaces) and defined at the point of use (consumer side), not alongside the implementation.
- gofmt/goimports-Clean: Code must always be formatted with gofmt/goimports.

## 10. Frontend / UI Standards

- Pointer Cursor on Interactive Elements: Every clickable element (`button`, `[role="button"]`, clickable labels, custom controls) must show `cursor: pointer` when enabled. Tailwind v4 and modern browser defaults render buttons with `cursor: default`, so add a single global stylesheet rule (`button:not(:disabled) { cursor: pointer }` plus role/label variants) rather than annotating each element.
- Disabled State Is Visible: A disabled control must look disabled (reduced opacity or muted color) and must not show a pointer cursor.
- Flat Neutral Style: When asked for "the flat style", "the job-alerts style", or a "squared / neutral look", follow the flat neutral style guide imported below: hard corners, neutral grayscale surfaces, borders instead of shadows, color only as state signal.

## 11. PR & Doc Writing Style

- Nest, Don't Cram: One fact per bullet. If a summary line covers multiple sub-facts (an API list, multiple root causes, multiple steps), break them into nested sub-bullets instead of one sentence stuffed with parentheticals.
- Links as Sub-Bullets: Pull external references (issue trackers, upstream fix commits) out of inline parentheses into their own sub-bullet with a markdown link, e.g. `- fixed [here](url)`, rather than `(fixed upstream, see url)`.
- State the Real Reason: Give the actual underlying constraint driving a decision (e.g. "upstream doesn't publish arm64 binaries, maintaining a fork costs CI budget") instead of a vague summary phrase (e.g. "since it's not needed there").
- No Narrative in Summary Bullets: Testing notes and process narration belong in the test plan section, not folded into a summary bullet as prose.

## 12. CI / GitHub Actions

- Always Add Dependabot: Any repository with GitHub Actions workflows must include a `.github/dependabot.yml` enabling the `github-actions` ecosystem so action versions stay updated.

## 13. Commit Messages

- One Line, No Body: A commit message is a single line. If a change needs a paragraph to explain, that belongs in the code, a comment, or the PR description, not the commit.
- Imperative Mood, Lowercase: Start with an imperative verb in lowercase: "add manifest backfill", "fix video download progress", "restore pointer cursor on interactive elements".
- Describe the Outcome, Not the Diff: Say what the change accomplishes ("shorten device menu labels"), never which files moved ("edit DeviceMenu.tsx").
- Optional `summary: specifics` Form: When one line needs a qualifier, use a colon: "fix yt-dlp impersonation: use curl-cffi extra not default".
- No Type Prefixes: Do not use Conventional Commits tags (`feat:`, `fix:`, `chore:`) unless the repository already uses them consistently.
- No Attribution: No `Co-Authored-By`, no tool or assistant signatures, no trailers.
- One Logical Change Per Commit: Group related edits and their tests into a single coherent commit; do not bundle unrelated changes.
- NEVER PUSH ANYTHING

---

@flat-neutral-style.md
