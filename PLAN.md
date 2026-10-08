# Python Teacher — Build Plan

## Goal

Build a personal, native macOS learning workspace that helps the learner become independently comfortable writing Python. Optimize for daily 20–30 minute sessions, practical AI-adjacent examples using synthetic data, and demonstrated understanding rather than completion counts.

## Completion target for this build

A launchable Mac application with a native code editor, a reviewed foundational Python curriculum, on-demand practice variations when an OpenAI key is configured, local execution and tests, graduated hints, coding-plus-theory assessments, progression, review reminders, saved work, and an optional OpenAI teacher. Existing lessons and execution work without an API key. No cloud account or app backend. Practice generation has no curriculum-count limit, but API charges and a configurable per-launch request cap apply.

## Learning repertoire overhaul — approved roadmap, 2026-10-08

### Delivery policy and branch dependencies

The user approved starting the review proposal with documentation first, parallel implementation where file ownership is independent, and validation between phases. This is a staged overhaul, not one unreviewable change. The checklist below is the source of truth for the entire proposal; unchecked work is not delivered.

- Current delivery branch: `feature/debugging-foundations`, based on `18f3f73` (`feature/readable-learning-panel`). This base is three commits ahead of `develop`, including the multi-provider and readable-panel work. Preserve that dependency for the eventual merge to `develop`.
- Create a new type-prefixed branch for each subsequent delivery slice. Do not implement on or merge into `develop` during this work. The initial Phase 1A pass did not commit, push, replace the package, or restart the running app. In the follow-up, the user requested packaging, checkpoint/push, and a new Phase 1B branch; package replacement was explicitly confirmed. Checkpoint/push and the branch transition must complete before Phase 1B implementation.
- Parallel workers own distinct files; one integration owner owns shared models, catalog contracts, docs, and cross-cutting validation. Independent review follows implementation.
- Every slice records its exact tests, failures, skips, native rendering evidence, and unverified manual/live behavior before the next slice starts. Known baseline failures are not silently waived or hidden by weaker assertions.
- Preserve saved drafts, activity/section IDs, assessment history, mastered chapters, existing effort ratings, and reward policy. New exercises receive new IDs. Do not retroactively revoke mastery or recalculate historical rewards.
- Keep all additions offline-first, Python 3.9-compatible, standard-library-only, and within the existing fail-closed sandbox. No new package environment or network access is approved by this roadmap.

### Baseline and review findings

- [x] Review all foundation and advanced/data chapters, default exercises, prerequisites, assessment/review rules, runner, editor, generated practice, and project briefs.
- [x] Focused baseline: `swift test --filter 'PythonTeacherCoreTests|MarkdownDocumentTests'` on the reviewed source: **191 passed, zero failures, zero skips**. References, starters, and standalone lesson blocks executed in the restricted runner. No live API or hands-on GUI claims.
- [x] Fresh full-suite baseline before implementation: `swift test` at `18f3f73`, **264 tests; 257 passed, seven failed tests / 18 assertions; no skips**. All failures are the documented editor-height assertion at `AppModelTests.swift:2177`: assessment theory, expanded instructions, gamification minimum-size, native workspace modes, passing-solution effects, saved incomplete exercise, and window reward effects. Log: `shell-1cd730`. This is the comparison baseline, not a green full suite.
- Findings: debugging guidance exists but is scattered; one reviewed repair task identifies its own defect; exactly three reviewed exercises per chapter restrict variety; early fixed-input checks provide limited transfer evidence; AI-generated projects are not an offline capstone bank. The prerequisite graph and executable curriculum checks are strengths to retain.
- Review corrections: decision-boundary teaching is intentionally ordinary practice, not a missing troubleshooting role. `###` advice remains part of its parent section, not a broken role mapping. Do not promote headings or renumber sections merely for Debug-format generation. `sum`/`min`/`max`, `split`/`join`, aliasing, and default-argument guidance already exist at different points; improve placement and practice rather than claiming they are absent.

### Phase 1A — debugging foundations (current slice)

Goal: learners can read a failure, navigate to their code, apply a repeatable investigation method, and practise diagnosis without an API key.

- [x] Add bounded structured execution diagnostics: exception type/message, learner/check/runner origin, learner frames, syntax-error location, and original text fallback. Diagnostics are supplementary evidence, never a replacement for the completion/exit/assertion contract.
- [x] Add a compact local failure card and explicit Go to line action. Keep original output available. Never navigate stale diagnostics into edited code or navigate check/harness lines into the learner editor. Clear transient diagnostics on navigation/reset/relaunch/setup failures.
- [x] Add offline error-category guidance in Learn/Practice. Assessment receives neutral location/error data only, no new coaching, solution help, or access to grader internals. This does not approve interactive assessment debugging.
- [x] Add two short learning units within existing headings: **Understanding errors** in basics, and **Debugging systematically** after function fundamentals. Use `###` subheadings so `#`/`##` section IDs remain unchanged. Teach syntax/runtime/logic failures, annotated traceback reading, expected-vs-observed behavior, a small reproduction, one hypothesis/change, and regression checks. Introduce each probe/tool before asking for it.
- [x] Add **12 reviewed offline labs**: basics 2, values 2, decisions 2, loops 2, functions 2, collections 1, reliability 1. Mix diagnosis, prediction, boundaries, first divergence, missing/premature returns, data shape, and validation of later records. Preserve all existing exercises unchanged; later labs give symptoms/contracts rather than revealing the defect.
- [x] Represent intentional starter failure types explicitly for reviewed syntax/runtime labs. Legacy/generated exercises without this metadata retain their existing contract. Replace the universal three-exercise test quota with minimum/content coverage checks; do not loosen reference correctness or prerequisite checks.
- [x] Add regression tests for diagnostics, stale source, editor selection/undo/Unicode, no assessment coaching, legacy decoding, lab references/starters, plausible wrong repairs, taught syntax, and heading/ID stability.
- [x] Validate focused suites, full `swift test`, native failure-card rendering at default/minimum sizes, and `git diff --check`; review source and record exact outcomes below. Full-suite failures match the measured baseline; this is not a green full suite. Hands-on usability is a separate outstanding check.

### Phase 1B — readable checks and safe experiments (next branch after 1A gate)

- [ ] Define authored named-check metadata with cases such as empty input/exact threshold, expected/actual values, and passed/failed/not-reached states. Start with reviewed checks; do not guess meaning from arbitrary assertions or evaluate operands twice.
- [ ] Keep early teaching syntax unchanged while enabling multiple app-owned input fixtures. Add a scratch-input/testing workflow that does not require altering and restoring fixed input lines, and cannot award completion from an experiment.
- [ ] Distinguish authored logic-error, runtime-error, and syntax-error activities. Tighten generated Debug validation to prove its declared failure category, not merely any non-timeout failure; use mocked requests and local execution, not paid calls.
- [ ] Verify checker semantics, input isolation, setup failures, fail-fast/dependent checks, raw-output fallback, and assessment disclosure boundaries. Prove plausible wrong solutions fail while equivalent correct solutions pass.

### Phase 2 — independent problem solving and assessment evidence

- [ ] Replace a fixed exercise quota with authored skill/form coverage: predict, complete, write, diagnose, counterexample, transfer. Keep short tasks short; avoid requiring every form in every chapter.
- [ ] Gradually reduce scaffolding in later activities while preserving precise input/output contracts, exact examples, and beginner explanations.
- [ ] Add problem decomposition, naming, refactoring without behavior changes, documentation literacy, useful comments/docstrings, and maintenance/change-request exercises.
- [ ] Add reviewed offline milestone projects based on existing briefs: foundation gradebook; CSV cleanup/report with rejected-row reasons; class-based library/ledger with regression tests; two-table report with join validation and interpretation. Recognize the existing reliability assessment as a small integrated task, not a missing feature.
- [ ] Introduce separately checkable milestones plus an integration check; prevent repeated milestone checks from duplicating completion XP.
- [ ] Add assessment/question banks and fresh authored variants that measure transfer without withholding helpful feedback. Before functions, use supported input fixtures rather than requiring untaught function syntax.
- [ ] Use structured reflection prompts without claiming that word counts, keywords, or AI judgments measure mastery. Preserve independent assessment rules and historical passes.
- [ ] Mutation-test reviewed checkers with likely mistakes: hardcoded results where generalization is required, off-by-one boundaries, premature return, ignored later data, and input mutation.
- [ ] Improve review scheduling from a single chapter-level seven-day reminder toward specific skill/activity retrieval with expanding intervals and concrete deep links. Keep effort rewards distinct from mastery and avoid punitive streaks.
- [ ] Gate: curriculum/graph/markdown/progress tests; compatibility fixtures; project milestone and assessment isolation tests; representative native screenshots and a documented manual learning walkthrough.

### Phase 3 — execution visualization

- [ ] Spike restricted-runner tracing before committing to an implementation. Preserve isolation and resource limits; no networking or unrestricted subprocess fallback.
- [ ] Add bounded recorded execution replay for Learn/Practice: highlighted source, safe variable snapshots/differences, call context, next/previous recorded step, and loop navigation. Backward inspection does not reverse side effects.
- [ ] Bound event count, bytes, nesting, cyclic values, and running time; avoid invoking learner-defined representation/property code for inspection; preserve useful partial evidence on limits and cancellation.
- [ ] Never trace grader internals; label source freshness and keep trace sessions distinct from completion checks. Explicitly decide assessment availability before adding any assessment affordance.
- [ ] Gate: sandbox spike, tracing semantic-equivalence tests, timeout/flood/cancellation cases, Unicode/source navigation, accessibility and native rendering, manual trace walkthrough.
- [ ] Evaluate live breakpoints and step into/over/out only after replay usability evidence. Persistent command channels and paused-time budgets require their own design/validation slice. Arbitrary expression evaluation, variable mutation, remote debugging, and a full IDE remain out of initial scope.

### Phase 4 — repertoire and path refinements

- [ ] Consolidate names/scope/mutation practice: rebinding vs mutation, aliasing, shallow/nested copies, mutable defaults. Move common text processing earlier after lists; cover split/join, replacement, prefix/suffix tests, and structured parsing.
- [ ] Strengthen early lightweight test design after functions while retaining later class-based unittest. Separate basic type hints from functions-as-values/closures/decorators/caching; evaluate smaller units for files/modules/dates and statistics/sampling without breaking old IDs or mastery gates.
- [ ] Add practical scripts/modules, supplied-argument argparse exercises, logging, and an explicit bridge to running exported code outside the app. Multi-file work needs a separately tested workspace/import contract. Track Git and environment literacy as part of this bridge, without granting learner subprocess access.
- [ ] Strengthen data interpretation: sampling bias, leakage, missing-data policy, duplicate join keys, reproducibility, and reporting limitations. Add late-track project objectives for testing, generators, decorators, statistics, and aggregation rather than relying only on early briefs.
- [ ] Teach simple algorithmic reasoning and measurement: list vs set lookup, repeated work, cost intuition, and profiling/timing before optimizing.
- [ ] Run a content-precision pass, including hashability vs immutability and tuples containing unhashable members.
- [ ] Later optional extensions: recursion, regular expressions, SQLite (sandbox/interpreter probe first), richer data structures. HTTP/API and LLM-evaluation teaching remain a later scoped proposal; do not quietly enable network access.
- [ ] Gate each content slice with prerequisites, standalone examples, checker mutation cases, Python 3.9 compatibility, stable saved-work fixtures, and offline availability.

### Separate approval / manual gates

- [ ] Managed hash-pinned NumPy/pandas/matplotlib environment and image output: retain the existing separate security-model approval requirement (original curriculum phases 6–7 below). Then implement numpy/pandas/groupby/plotting content and visualization literacy.
- [ ] Hands-on packaged-app learning/debugging walkthrough, keyboard and VoiceOver behavior, and readability at minimum window size. Native test renders alone do not close this gate.
- [ ] Live provider generation/teaching quality: optional explicit live validation, never inferred from mocks. Core curriculum/debugging must remain useful without it.

### Phase 1A implementation evidence

**Implemented and automated/native-render validated on `feature/debugging-foundations`, 2026-10-08. Manual packaged-app acceptance remains pending.** Four implementation workers owned runner, UI, early content, and later content; two independent read-only reviewers checked diagnostics/UI and all new curriculum material. Shared model/tests/docs and integration stayed with the integration owner. No commits, pushes, merges, personal-progress changes, package replacement, or running-app restart were performed.

Delivered:
- `RunDiagnostic` adds bounded exception metadata to `RunResult`; a nonce-framed JSON payload is parsed separately from the 64 KiB raw-output limit. Payloads are capped at 16 KiB, 32 learner frames, and bounded names/messages. Success, timeout and cancellation do not invent error diagnostics. Check diagnostics do not expose checker source/locals, and supplementary data never controls grading. Sandbox permissions, completion authority, and assertion-site enforcement are unchanged.
- Native failure cards distinguish learner/check/runner errors and retain the original output. Fresh learner locations can select/scroll the code without modifying text or undo. Source/draft identity, bounds and IME composition guard navigation. Re-clicking creates a fresh request; rejected composition-time requests do not jump later unexpectedly. Assessment cards omit coaching and diagnostic messages, retaining neutral type/location data.
- The two teaching units and twelve appended labs bring reviewed practice from **51 to 63**, while chapters/assessments/theory questions remain **17/17/51**. Existing `#`/`##` headings, original activity contracts, prerequisites and assessments remain unchanged. Optional `expectedStarterError` metadata permits the reviewed syntax/key-error starters without weakening other starter checks or legacy decoding. New authored lab awards total **1,600 available first-completion XP**; historical rewards and policy remain unchanged.

| Chapter | Added lab IDs |
| --- | --- |
| basics | `basics-debug-quote`, `basics-debug-saved-total` |
| values | `values-debug-clean-label`, `values-predict-token-total` |
| decisions | `decisions-debug-priority`, `decisions-debug-entry-boundary` |
| loops | `loops-debug-running-total`, `loops-predict-threshold` |
| functions | `functions-debug-return`, `functions-predict-counterexample` |
| collections | `collections-debug-optional-field` |
| reliability | `reliability-debug-later-record` |

Verification:
- Initial focused run: **71 tests, one failure** in the new mutation test's expected exception category. The checker correctly rejected a two-record-only validation repair with `TypeError`; the regression now explicitly expects that error rather than weakening the exercise checker. All eight new native UI tests and 39 then-current runner tests passed in that run.
- Reproduced a lone-CR location bug with a failing test, fixed universal-newline counting (LF/CRLF/CR), and verified the regression passed. Independently reviewed and reproduced overbroad path redaction obscuring the division operator; narrowed redaction and verified that useful operator/relative text survives while absolute path tokens are redacted. Raw tracebacks remain unchanged. The final integrated run includes both regressions.
- Full `swift test`, with synthetic native screenshots enabled: **288 tests; 281 passed, seven failed tests / 18 assertions, zero skips** (`shell-194e87`). All **198 core tests**, all **9 Markdown tests**, and all **24 newly added tests** passed. The failures are exactly the same seven editor-height tests with the same numeric assertions as baseline, now at `AppModelTests.swift:2489`. Existing geometry assertions were not relaxed.
- Python 3.9.6 was used by the default curriculum/runner tests. Alternate compatibility command: `PYTHON_TEACHER_TEST_PYTHON=/opt/homebrew/bin/python3 swift test --filter 'CurriculumTests|CurriculumGraphTests|PythonRunnerTests'`, Python **3.14.3**: **111 passed, zero failures, zero skips** (`shell-5feff6`). All current lesson examples and reviewed references/starters pass their respective executable contracts, including the intentional SyntaxError line-2 case.
- Regenerated the failure-card rendering test in a user-approved temporary directory after ignore rules prevented image reads under `.build`: **one test passed** (`shell-b3952c`). Visually inspected all eight PNGs in `/tmp/python-teacher-phase1a-snapshots`: Learn/Practice/Assessment at 1380×900 and 1080×740, plus stale Practice at both sizes. Cards and stale/assessment states are readable; the raw output may require scrolling at minimum size. The automated comparison confirms unchanged editor dimensions. These are synthetic native renders, not hands-on packaged-app interaction.
- `swift build -c release`: passed (`shell-9a5928`); the packaged app was not replaced or relaunched. `git diff --check`: passed.

Follow-up packaging / checkpoint request:
- [x] After explicit confirmation to replace `dist/Python Teacher.app`, ran `bash scripts/package-app.sh`: release build, arm64 app packaging, and ad-hoc signature verification passed (`shell-926a0d`). Independent `codesign --verify --deep --strict --verbose=2 "dist/Python Teacher.app"` also passed. The app was not launched or restarted; manual testing is for the user.
- [ ] Preserve Phase 1A in a commit and push `feature/debugging-foundations`. Blocked on checkpoint ownership: the user's no-attribution requirement conflicts with the environment's required attribution for agent-created commits. A user-created local commit preserves the requested artifact policy; push and branch transition can follow once it exists. No commit or push has been performed.
- [ ] Create `feature/readable-checks` from the preserved Phase 1A checkpoint and implement Phase 1B. Do not carry uncommitted Phase 1A changes into a nominally separate delivery branch.

Remaining / next checkpoint:
- **Phase 1B is not started.** Next work is authored named checks, safe scratch inputs/multiple fixtures, and failure-category validation for generated Debug practice, on a new feature branch after preserving this checkpoint. Phases 2–4 remain explicitly unchecked above.
- Early fixed-input decisions labs still accept some partial repairs (for example, dropping the approval condition while the supplied approval is true). Instructions state that one case does not prove the whole rule; multi-input fixture support and checker mutations are tracked in Phase 1B/2, not claimed delivered here.
- Known editor-layout baseline failures, manual keyboard/VoiceOver/packaged-app acceptance, live provider behavior, and the separately approved package-environment work remain outstanding. No live API request or real learning-data migration was used for verification.

## Status (earlier delivered revisions)

**Latest integrated verification — 2026-10-05:** Full `swift test` after the saved-draft compatibility fix: **226 tests, 219 passed**; the same seven documented editor-layout tests failed with 18 assertions. All **156 core tests** passed. Curriculum suite with Homebrew Python 3.14: **47 passed, zero failures**. No live API or hands-on packaged-app verification was performed. Release packaging/signature evidence is recorded below.

**Current revision — multiple AI providers, 2026-10-06, branch `feature/multi-provider-teacher`:** the teacher and generator now work with OpenAI, Anthropic, Google (Gemini) or xAI (Grok), chosen in Settings.
- `TeacherProvider` (Core) defines each provider's name, default model, endpoint and key console. `ProgressState.provider` is saved next to `model`. Older progress files without the field decode as OpenAI and keep their model. An unrecognized value is treated as unreadable and preserved.
- `TeacherClient(apiKey:model:provider:session:)` sends identical instructions, snapshot, prompt and JSON schema to every provider. The wire formats are:
  - OpenAI: Responses API, unchanged, still with `store: false`.
  - Anthropic: Messages API with an `x-api-key` header, `output_config.format` structured outputs, user-first merged turns, and SSE `message_*`/`content_block_delta` events. Only an `end_turn` stop is accepted.
  - Google and xAI: OpenAI-compatible Chat Completions with `response_format: json_schema` and `stream_options.include_usage`. Only a `stop` finish reason is accepted, at `[DONE]` or at stream close.
- Non-OpenAI providers get 8,000 extra output tokens because their default models reason. Truncation, refusals, error events and missing completion are rejected for every provider, just as for OpenAI.
- Each provider has its own Keychain item (`local.pythonteacher.<provider>`). The OpenAI item keeps its original service name, so existing keys keep working.
- Picking a different provider in Settings clears cloud consent until the learner enables it again for that provider. UI text and errors name the selected provider or stay provider-neutral.
- Verification: targeted `TeacherClientTests|ProgressTests` plus the Keychain-service test passed, **88/88**. Full `swift test` ran **255 tests**, with 18 failures. All 18 are the seven documented editor-layout tests, and the same seven fail on the baseline without these changes.
- New mocked tests cover request shape, headers, streaming, usage and rejection paths for each provider, plus legacy progress decoding.
- **Live API calls to any provider, including whether Gemini's compatibility layer and Anthropic accept the strict exercise schema, are unverified.** The Settings picker has not been exercised by hand.

**Previous revision — whole-chapter generation adjusted to the expanded curriculum, 2026-10-05, branch `ai-projects`:** a review of all 17 chapters found five problems:
- Every heading was mandatory coverage, including orientation openers and "Common mistakes" lists.
- Prerequisite knowledge was named only by chapter title.
- The generator didn't know the testing chapter's mutation-checking pattern.
- There was no Python 3.9 rule.
- Large chapters had an 8,000-token output budget.

Fixes:
- `Chapter.sectionRoles` marks headings `.overview` (context only) or `.troubleshooting` (required only for *Debug broken code*). Section IDs stay positional, and whole-chapter XP uses the format-independent practice count.
- Three parallel subagents classified the curriculum: 11 overview sections and 8 troubleshooting sections out of 109 headings, each read in full and recorded in its track's tests.
- Every generation scope now lists the prerequisite closure as toolkit section titles, names the current lesson's context-only sections (including non-focus sections in projects), adds app-authored `generationNotes`, and requires Python 3.9-compatible code.
- Generation notes were added for testing (swap implementations through `__globals__`, then run the learner's TestCase quietly against correct and buggy versions), files, generators, typing-decorators, ds-statistics and ds-aggregation.
- Whole-chapter requests now allow 12,000 output tokens.

An independent read-only review subagent found no bugs. It confirmed that the testing notes match the reviewed testCode and the runner's shared `runpy` namespace. Three of its nits were fixed: the `files` working-folder wording, non-focus context in projects, and checklist wording. Verification: full `swift test` ran **242 tests**, and all 18 failures were the seven documented editor-layout tests. Live model output for the new notes and roles is unverified.

**Previous revision — objective-driven AI projects, 2026-10-05, branch `ai-projects` (stacked on `reward-balance-review`):** **Project** coverage replaces "Current + all prerequisite chapters", which sent every lesson in the closure as mandatory coverage and grew with the curriculum (about 12 chapters for `ds-aggregation`). A project has an objective from the 12 synthetic `ProjectBrief.catalog` briefs, each gated by an earliest chapter in the prerequisite closure, or the learner's own objective (non-blank, untrusted, at most 400 characters). The learner picks 1–3 current-chapter focus sections, and the coverage key `project-integration` asks for the final connecting milestone. The prompt requests 3–5 tested milestones and treats the closure as an allowed toolkit rather than required coverage. Full lessons are sent only for the current chapter and its direct prerequisites; other toolkit chapters are sent as section titles. XP uses one unit per focus section plus one for integration, with the former cumulative cap (assessment + 1) renamed to the project cap. Saved exercises and the v3 historical cap are unchanged; `PracticeScope` was never persisted. This is milestone option A: one exercise with staged instructions and one test block. Separately run, per-milestone tests (option B) are a possible follow-up. Verification: full `swift test` ran **230 tests**. All 18 failures were the seven documented editor-layout tests. The new catalog, focus/objective validation, normalization, prompt and toolkit tests pass. Generator snapshots for a catalog brief (`reliability`) and an own objective (`basics`) were inspected. Live model output quality, and whether toolkit section titles keep the model within taught syntax, are unverified.

**Previous revision — reward balance review and generated-practice cap (policy v3), 2026-10-05, branch `reward-balance-review`:** an economy audit found that AI-generated practice was uncapped. A single cumulative Harder exercise could earn 12,000 XP from coverage alone, up to 150,000 XP from the structural estimate of a provider-written reference, versus 33,825 XP for the whole reviewed curriculum (level 35). Following the user's choices, generated workload is now capped at the chapter assessment's scope units (+1 for cumulative). Guided practice stays at 50% and the level curve is unchanged. A one-time approved v3 recalculation applies the cumulative cap to saved generated exercises and generated attempt snapshots, with a `progress-before-xp-v3-*` backup; reviewed ratings are untouched. The generator dialog shows the reward range. Verification: full `swift test` ran 227 tests; the only failures beyond the seven documented editor-layout tests (18 assertions) were two TeacherClient tests that still asserted uncapped units. After updating those, the targeted core suites passed **157/157**. The packaged app was not relaunched, and migration of the user's personal data is unverified.

**Previous revision — curriculum tree and expanded learning paths, 2026-10-05:** phases 1–5 are implemented, with 17 chapters across four tracks on `curriculum-tree`. Eight implementation agents, two independent curriculum reviewers, two review-fix agents and one compatibility agent contributed. Original foundation activities remain available for saved work; incompatible revised tasks have separate IDs and shared completion/review XP identity. Phases 6–7 await separate approval of the package-environment security change.

**Previous revision — current teacher workspace awareness, 2026-09-27:** send complete request-time editor snapshots after older chat, retain run diagnostics with their exact source and freshness, and persist compact change markers across requests/relaunch. All 43 focused tests pass. Full verification passes 165 of 172 tests; the same seven documented editor-layout failures remain (18 assertions). Live model response quality remains unverified.

**Previous revision — native code-editor search, 2026-09-25:** connect the existing AppKit find bar to Edit → Find and standard search shortcuts, with incremental matching and no learner-code generation or learning-policy changes. All seven targeted editor/input tests pass. Full verification passes 156 of 163 tests, with the same seven documented editor-height layout failures (18 assertions). Release packaging and ad-hoc signature verification passed. Hands-on use of the packaged menu/shortcuts remains unverified; the running app was not restarted.

**Previous revision — actual-work estimates and approved historical XP recalculation, 2026-09-25:** correct the legacy flat-reward fallback and inherited workload of generated variations. A one-time on-launch update rates saved exercises, backs up progress and recalculates existing rewards as explicitly requested by the user. New variations account for additional starter/reference work. All 48 targeted release-mode tests pass; full verification passes 155 of 162 tests, with the same seven documented editor-height layout failures (18 assertions). Personal-data migration awaits restarting the rebuilt app.

**Previous revision — proportional exercise XP, 2026-09-23:** reviewed and newly generated exercises now earn XP proportional to app-owned difficulty and workload ratings. Historical XP, mastery gates, and repeat-award protections are preserved. All 78 targeted tests pass; full verification passes 149 of 156 tests, with seven previously documented editor-height layout failures (18 assertions). Release packaging/signature verification passed; the running app was not restarted.

**Validation evidence and explicit repair, 2026-09-23:** generator instructions now explain the runner's strict assertion/execution contract; rejected candidates retain inspectable evidence and can be explicitly repaired with one additional AI request. Sixty-eight targeted provider/runner/application tests pass. The user's earlier discarded rejection and live model repair quality remain unverified; prior editor-layout test failures remain documented below.

**Uncapped levels and expanded reward effects complete — built and locally verified on 2026-09-22.** The full suite passed 113 tests, including 40 application tests. Levels continue past 100 with increasing costs; XP gains trigger a bottom-to-top green window-edge sweep, level-bar pulse and confetti, with a larger level-up burst. Prior XP, mastery gates, session history and accessibility preferences are preserved. Native screenshots of actual passing-solution effects, deterministic animation stages and cleared effects were inspected. Release packaging and ad-hoc signature verification passed. The earlier gamification implementation received UX/Design-agent code-review approval; this effects revision was verified with tests and screenshot inspection. This revision was not relaunched over the user's running session. Live OpenAI quality, personal Keychain setup, physical keyboard/VoiceOver use, and hands-on animation feel remain explicitly unverified.

| Workstream | Status | Delivered / acceptance evidence |
| --- | --- | --- |
| Architecture and project setup | Complete | Swift Package; native app, core library, two test targets; reproducible ad-hoc-signed app packaging and generated icon |
| Curriculum | Phases 1–5 complete; libraries/plotting pending | 17 chapters across Foundations, Core Python II, Software craft and Data science; 51 current reviewed practice exercises, 17 current coding assessments and 51 conceptual questions; legacy contracts preserved separately for saved work |
| Learning state | Complete | Versioned atomic JSON persistence, separate resumable drafts, attempts and assistance history, mastery gates, placement overrides, seven-day review queue; corrupt data is preserved |
| Python execution | Complete | Actual interpreter resolution, deny-default macOS sandbox, cancellation, eight-second timeout, bounded output, per-file/descriptor limits, isolated workspace and grading evidence |
| Native workspace | Complete | Collapsed chapter browser; resizable left Learn, Practice and Assessment instructions; central editor/output visible in every mode, including assessment theory; syntax highlighting, line numbers, indentation, undo and find; right teacher panel |
| AI teacher | Implemented; live verification pending | Keychain storage, configurable OpenAI Responses model, guiding-question instruction, no tools or automatic edits, usage reporting and request cap; HTTP behavior tested with mocks |
| Generated practice | Implemented; live verification pending | Strict structured generation, including mixed current/earlier chapter challenges; reference must pass, starter must fail, every assertion site must execute; existing persistence and reviewed offline alternatives preserved |
| Assessments | Complete | No in-app teacher assistance; all code checks and theory questions required; written reflection saved, not automatically scored; results and progression recorded |
| Daily use | Complete | Saved 25-minute focus sessions, pause/resume, lifetime totals/history, study routine, review reminders, restore/resume, Python export, progress backup, settings and interpreter verification |
| Player progression | Complete | Levels starting at 0 with no gameplay cap and increasing costs; evidence-derived practice/assessment/recall XP, self-reported lesson rewards, session XP, lifetime milestones, motion-optional celebrations and VoiceOver announcements; no changes to mastery gates |
| Verification | Integrated tests run; known layout failures remain | 226 tests: 219 passed; seven known editor-layout tests fail with 18 assertions. All 156 core tests pass; Homebrew curriculum suite: 47 passed. Live API and final manual UX unverified |
| Handoff | Complete | App left running; launch/setup instructions, verification evidence and limitations recorded below |

## Rename to Python Teacher — 2026-10-06, branch `chore/rename-python-teacher`

**Done:** the app, package, products, targets, source/test folders and modules are renamed from Coding Teacher / `CodingTeacher*` to Python Teacher / `PythonTeacher*`. The rename also covers the executable, bundle ID (`local.pythonteacher.app`), the `dist/Python Teacher.app` bundle, the `dist/Python-Teacher-<version>-macOS.zip` share zip, the backup filename, runner sentinels, and the test variables `PYTHON_TEACHER_TEST_PYTHON` and `PYTHON_TEACHER_UI_SNAPSHOTS_DIR`. Dated evidence entries below keep the names that were in use when they were recorded. On launch, the app migrates data saved under the old name and never overwrites current data:
- `~/Library/Application Support/CodingTeacher` is moved to `PythonTeacher` only when the new folder is missing. If the move fails, the old folder is used in place.
- The Keychain key under `local.codingteacher.openai` is copied to `local.pythonteacher.openai` only when no current key exists. The old item is deleted only after the copy is saved.
- `cloudConsent` is copied from the `local.codingteacher.app` or `CodingTeacher` defaults domains only when it is unset.

**Verification evidence:** full `swift test`: **248 tests; the only 18 failures are the seven documented editor-layout tests**. Six new migration tests pass. They cover the folder move, never replacing current data, falling back in place when the move fails, a missing legacy folder, consent copying, and moving a synthetic Keychain item. `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed, and the bundle ID is `local.pythonteacher.app`. `git diff --check`: passed. **Not verified:** migrating the user's real progress, Keychain item and consent on first launch of the renamed app. macOS may ask once for permission to read the old Keychain item.

## Shareable app package — 2026-10-05, branch `feature/shareable-app-package`

**Done:** `scripts/package-app.sh --universal` builds an arm64+x86_64 release. It now recreates the bundle from scratch each run. `scripts/share-app.sh` stages the universal ad-hoc-signed app with `HOW TO OPEN.txt`, strips extended attributes, re-verifies the signature, and writes `dist/Coding-Teacher-<version>-macOS.zip`. README now starts with a simple Quick start (build/run), sharing steps, and Gatekeeper workarounds for unsigned apps. AGENTS.md documents the branch-prefix convention.

**Verification evidence:** universal release build succeeded (Xcode, Swift 6.0). The zip holds 11 entries with no `__MACOSX`/AppleDouble files. After `ditto -x`, `codesign --verify --strict` reports valid, `Signature=adhoc`, and `lipo` shows `x86_64 arm64`. With a quarantine attribute added, `spctl --assess` rejects the app, as expected for a bundle without Developer ID or notarization. Default `package-app.sh` still produces a verified arm64 bundle. **Not verified:** the Open Anyway flow and the app launching on another Mac, including Intel hardware.

## Curriculum tree and expanded learning paths — started 2026-10-05

Review findings: the seven foundation chapters are a single linear chain; classes, `while`, `enumerate`/`zip`, deliberate comprehensions, files/modules, `unittest`, generators, typing/decorators and any data-science tooling are never taught. Lists and `for` are introduced inside `decisions`, before the loops chapter. User decisions: reorder foundation content (stable IDs), unlock a chapter only when **all** prerequisites are mastered, plan Core Python II, Software craft and Data science branches, and include NumPy/pandas/plotting later via a separately approved package environment.

### Phases

- [x] Scaffolding: `ChapterTrack` and `Chapter.prerequisites` (defaults keep the existing initializer source-compatible); foundation chain expressed as explicit prerequisites; curriculum helpers usable from per-chapter files in `Sources/PythonTeacherCore/Chapters/`; `CurriculumTests` no longer hardcodes the chapter list or totals beyond the foundations order.
- [x] Phase 1 — tree infrastructure: all-prerequisites unlock rule; cumulative generation over the prerequisite closure in canonical order; teacher/generator prompts name explicit prerequisites; scrollable chapter browser grouped by track with missing-prerequisite explanations; graph validation tests (single root, known IDs, acyclic, canonical order is topological). Existing mastery/overrides keep working with no migration. This is a prerequisite graph presented as grouped tracks, not a graphical node-and-edge canvas.
- [x] Phase 2 — foundation reorder with saved-draft compatibility. Lists/`for` moved from current `decisions` into `loops`; `while`/`break`/`continue` taught in `loops`; default/keyword arguments in `functions`; tuples and sets taught explicitly in `collections`; comprehensions deferred until `iteration`. Revised `decisions-bands`, `decisions-assessment`, `loops-retries` and `functions-preview` use explicit `-v2` IDs. The original IDs retain their original requirements/ratings and remain selectable when legacy saved work exists. Drafts, assistance, conversations and attempts are not rewritten. Both variants share completion/review reward identity, and legacy assessments stay excluded from AI practice.
- [x] Phase 3 — Core Python II chapters: `iteration`, `files`, `classes`.
- [x] Phase 4 — Software craft chapters: `inheritance`, `testing`, `generators`, `typing-decorators`. Testing requires both classes and files.
- [x] Phase 5 — Data science (standard library) chapters: `ds-cleaning`, `ds-statistics`, `ds-aggregation`.
- [ ] Phase 6 — app-managed, hash-pinned NumPy/pandas/matplotlib environment readable by the sandbox. **Requires separate user approval before work starts** (security-model change).
- [ ] Phase 7 — `numpy`, `pandas`, `pandas-groupby`, `plotting` chapters and image output.

### Integrated review and verification evidence

- [x] Merge all eight implementation branches in topological chapter order. Replace integration-test assumptions that the last chapter includes the entire curriculum, that new chapters remain at the list end, or that direct prerequisites have declaration order rather than canonical order.
- [x] Two read-only reviewers audit prerequisites, standalone examples, stated requirements and Python 3.9 compatibility. Follow-up fixes explain multi-argument `print`, dictionary-key iteration, list slicing/negative indexing, attributes versus methods, filtered set comprehensions, datetime aliases, `io.StringIO`, `abs` and scientific notation; align the cleaning example with normalized output and disclose mutation-testing requirements.
- [x] Testing checks report a clear assertion if the supplied implementation is renamed; restricted-runner regressions cover all four testing activities. No runner permissions, package dependencies, progress schema or personal learning data were changed.
- [x] Full integrated `swift test` after review fixes: **219 tests, 212 passed, 7 failed tests / 18 assertions**; all **151 core tests** passed, including all reviewed references, failing starters and standalone lesson blocks. The seven failures are the previously documented editor-height tests: assessment theory, expanded instructions, gamification, native workspace, passing-solution effects, saved incomplete exercise and window effects. Log: `/tmp/ct-final.log`. One earlier concurrent run also had a native key-window activation failure; the final run did not reproduce it.
- [x] `CODING_TEACHER_TEST_PYTHON=/opt/homebrew/bin/python3 swift test --filter CurriculumTests`: **43 passed, zero failures**, using Python 3.14. The default restricted curriculum run uses system Python 3.9. The data-cleaning/statistics agent also verified its chapter suite on Python 3.12.
- [x] `bash scripts/package-app.sh`: release build and local ad-hoc signature verification passed. Independent `codesign --verify --deep --strict --verbose=2 "dist/Coding Teacher.app"`: passed. `git diff --check HEAD~12`: passed. The running app was not restarted.
- [x] Infrastructure agent rendered and inspected chapter-browser screenshots with a synthetic 25-chapter graph, missing-prerequisite panel and generation dialog in `/tmp/coding-teacher-tree-ui`. After final integration, reran `AppModelTests/testChapterBrowserGroupsTracksAndExplainsLockedChapters` with snapshot capture: **1 passed**. Inspected the refreshed `chapter-browser-curriculum.png` (17 real chapters, default size) and `chapter-browser-tree-tall.png` (synthetic stress graph, all four tracks). This verifies native rendering, not hands-on scrolling or final packaged-app interaction.
- [x] Foundation compatibility follow-up: failing regressions reproduced four mismatched old draft contracts. Restore those original definitions outside the new teaching path, version only the incompatible replacements, recover saved attempts without rewriting source, and expose legacy selections only for existing saved work. Add legacy-assessment exclusion and XP/review deduplication regressions. No progress schema or reward-policy version change.
- [x] Final full `swift test` after compatibility: **226 tests, 219 passed, 7 failed tests / 18 assertions**, all in the same editor-height checks; **156 core tests passed**. Final Homebrew curriculum run: **47 tests passed**. No skips. Full-run tool log: `shell-e776d4`; Homebrew run: `shell-8ea81a`.
- [x] Rebuilt `dist/Coding Teacher.app` after the compatibility fix with `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed. `git diff --check` passed. No app restart, live API call or personal-progress migration was performed.
- [ ] Live provider response quality and hands-on final packaged-app interaction remain unverified. No real API requests were made.

### Syllabus contract

Authors may only require concepts taught in a chapter's transitive prerequisites or in the chapter itself. Everything must run on Python 3.9 (`/usr/bin/python3`): no `match`, no runtime `X | Y` unions, no `statistics.correlation`/`linear_regression`, no 3.10+ dataclass options, no `zip(strict=)`.

| Chapter ID | Track | Prerequisites | Teaches |
| --- | --- | --- | --- |
| basics | foundations | — | Variables, numbers/strings, arithmetic, joining text, `print`, editor workflow (unchanged) |
| values | foundations | basics | Methods, chaining, f-strings, `len`, rates/units, `//`, `%`, rounding up (unchanged) |
| decisions | foundations | values | `if`/`elif`/`else`, comparisons, Booleans, `and`/`or`/`not`, boundaries — **no lists or loops** |
| loops | foundations | decisions | Lists (literal, index, `len`, `append`), `for`, accumulators, `range`, `while`, `break`/`continue`, tracing |
| functions | foundations | loops | `def`/`return`/`None`, contracts, purity, slices, `assert`, default and keyword arguments |
| collections | foundations | functions | Dictionaries and `.get`, JSON, tuples (creation, indexing, basic unpacking), sets, `sorted` with `key`/`lambda` |
| reliability | foundations | collections | Type checks/`isinstance`, `try`/`except`/`raise ValueError`, `math.isfinite`, format validation, tests as evidence |
| iteration | corePython | reliability | `enumerate`, `zip`, unpacking in `for`, list/dict/set comprehensions with conditions, `any`/`all`, `sum`/`min`/`max` with `key`, nested lists |
| files | corePython | iteration | `import`/`from … import`/`as`, `pathlib.Path`, `with open`, modes and `encoding`, reading lines, `csv` reader/`DictReader`/`DictWriter`, `FileNotFoundError`, `datetime.date`/`timedelta`, `if __name__ == "__main__"` |
| classes | corePython | iteration | `class`, instances, `__init__`, `self`, attributes, methods, `__repr__`, `__eq__`, class vs instance attributes, aliasing/mutation, `@dataclass` (defaults, `field(default_factory=…)`), custom exception classes |
| inheritance | softwareCraft | classes | Subclasses, `super().__init__`, overriding, `isinstance` with hierarchies, `@property`, `abc.ABC`/`@abstractmethod`, composition vs inheritance |
| testing | softwareCraft | classes, files | `unittest.TestCase`, `assertEqual`/`assertRaises`/`assertAlmostEqual`, `setUp`, running a suite programmatically, boundary-focused test design, tests that catch buggy implementations |
| generators | softwareCraft | classes | `iter`/`next`, `StopIteration`, iterator classes, `yield`, generator expressions, laziness, `itertools` (`islice`, `count`, `chain`, `groupby`) |
| typing-decorators | softwareCraft | inheritance, generators | Type hints (`List`/`Dict`/`Optional` from `typing` or built-in generics with `from __future__ import annotations`), functions as values, closures, `*args`/`**kwargs`, decorators, `functools.wraps`, `functools.lru_cache` |
| ds-cleaning | dataScience | files | Tables as lists of dicts, `csv.DictReader` over `io.StringIO`/files, type conversion, missing markers, normalization, de-duplication, cleaning reports, writing cleaned CSV |
| ds-statistics | dataScience | ds-cleaning | `statistics` (`mean`, `median`, `mode`, `stdev`, `pstdev`, `quantiles`), IQR outliers, z-scores, hand-computed correlation, seeded `random.Random` sampling, train/test splits |
| ds-aggregation | dataScience | ds-statistics, classes | `collections.Counter`/`defaultdict`, group-by and multi-key grouping, joining tables by key, pivot summaries, top-n, dataclass records, f-string format specs for reports |

New chapters live in `Sources/PythonTeacherCore/Chapters/<Name>.swift` as `extension Curriculum`, pass `effort:` explicitly, and are registered in `Curriculum.chapters` in a topological order. New chapter titles have no numeric prefix.

## Readable learning panel and reading settings — 2026-10-06

- [x] Move the seven foundation chapters from `Curriculum.swift` into per-chapter files under `Chapters/` (no content change; curriculum tests green before any rewrite).
- [x] Replace the paragraph-only renderer with a block-based `MarkdownContent`: `#`/`##`/`###` headings, bullet and numbered lists (numbered steps as badges), `> **Label:**` callouts (key idea, tip, watch out, note), syntax-highlighted Python samples with Copy, ```` ```text ```` output boxes, styled inline code, and exercise sections (`Goal:` … `Check:`) presented as distinct cards. Lessons, instructions, teacher replies and generated exercises share it. The editor and samples share `PythonSyntax`.
- [x] Lessons default to "One part at a time": split at `##` headings, with part progress, a contents menu, Back/Next (⌥⌘←/→), and the read check-in and practice prompts on the final part. "Whole lesson" restores the continuous view. The instruction panel is wider (ideal 420pt, max 640pt), and reward details sit in a disclosure under the exercise title.
- [x] Settings → Reading & appearance (UserDefaults, device-local, not progress data): lesson text 85–160%, interface text 85–130% (all app `appFont` styles), reading font (System/Serif/Rounded), line spacing, lesson layout, code font size 11–22pt (editor, ruler, output, samples), live preview and Restore defaults.
- [x] Rewrite all 17 chapters' lessons and all 68 exercise/assessment instructions for paced reading: short paragraphs, `###` steps, concept → example → output → explanation, one action per numbered step, Starting code as keep/replace bullets, and exact expected results. `#`/`##` headings, IDs, starter/reference/test code, efforts, quizzes, section roles and generation notes are unchanged, and every lesson Python block is byte-identical. Hints received inline-code formatting only. Each agent's chapter tests passed in an isolated copy before merge.
- [x] The generation prompt asks for the same light Markdown in section bodies (identical for all providers).
- [x] `swift test --filter MarkdownDocumentTests`: **9 passed**, covering block parsing, section grouping, callout kinds, lesson-part splitting, inline-code styling, highlighting, clamped preferences, a parse check over every curriculum lesson/instruction (balanced fences, five ordered sections), and lesson/settings rendering at default and large serif sizes.
- [x] Full `swift test`: **264 tests executed, 18 failures**, all the documented editor-height assertion (`AppModelTests.swift:2177`). A pristine `649009e` checkout reproduces the identical 18 failures on this machine. All curriculum tests (which run every lesson block, reference and starter in the restricted runner) passed.
- Snapshots were inspected for Learn, Practice and Assessment at default and minimum window sizes, a lesson part, and the settings section. Hands-on interaction (slider feel, keyboard navigation, VoiceOver) is not claimed as verified.

## Current teacher workspace awareness — 2026-09-27

- [x] Reproduce silent 16,000-character code truncation, dropped diagnostics after editing, and stale-history ordering with two failing request regressions (eight assertions). Confirm the editor binding already updates the application model synchronously for committed edits; no continuous cloud streaming or automatic requests are required.
- [x] Capture a fresh structured workspace snapshot for every question: chapter, mode, lesson, exercise identity/instructions/starter, full current code, assistance state, and latest available run. Place it after bounded conversation history, before the current question. Explicitly instruct the teacher to use this snapshot over old conversation claims, inspect visible edits directly, and never ask for code/output already supplied.
- [x] Retain runner-bounded output rather than silently taking only its last 6,000 characters. Associate every completed/cancelled/failed run with an ID, timestamp, exact source, operation, exit status, and check outcome. Edits retain older diagnostics but mark them stale. A successful normal Run does not claim solution checks passed. Setup failures replace earlier success evidence; navigation/reset/relaunch explicitly report unavailable run evidence rather than reusing chat as a result.
- [x] Save optional per-request SHA-256 code fingerprints and run IDs with user messages, preserving compatibility with older conversations and existing draft keys. Distinguish changed/unchanged code and new/unchanged/cleared run evidence, including reruns of identical code. Do not duplicate full code in saved chat metadata. Discard an outdated response if its workspace/draft changes while awaiting it; no automatic paid retries.
- [x] Reject complete JSON snapshots above 256,000 UTF-8 bytes before recording assistance, adding messages, or sending a request. Do not silently shorten the workspace. Preserve assessment blocking, cloud consent, request limits, reference-solution history exclusion, tool-free teaching, and restricted execution. Update the teacher-panel explanation, README and project guidance.
- [x] `swift test --filter 'TeacherClientTests|AppModelTests/testTeacher(Snapshot|Snapshots|Receives|Oversized|DoesNot|Conversations|Requests|Messages)|AppModelTests/testRestoringStarter'`: **43 tests passed**. Nine new regressions cover complete long/Unicode code, full captured output, stale/current diagnostics, same-code reruns, passing/failing checks, setup failures, restart/navigation comparisons, legacy metadata, assessment blocking, oversized rejection, outdated replies and provider message ordering. Tests use synthetic temporary stores, restricted Python execution and mocked HTTP, not a live API key.
- [x] Full `swift test`: **172 tests executed; all 107 core tests and 58 application tests passed; seven previously documented editor-height layout tests failed with 18 assertions**. The failures remain in assessment theory, expanded instructions, gamification/minimum-size rendering, workspace modes, live reward effects, saved incomplete instructions and deterministic effect rendering. No geometry assertions were changed. The native chat Shift+Return test failed in an initial focused run but passed unchanged in the full suite; hands-on keyboard behavior is not claimed as verified.
- [x] `bash scripts/package-app.sh`: release build and local ad-hoc signature verification passed. `git diff --check`: passed. Quit and reopen the rebuilt package to load the new request context; the running app was not restarted.

No live API calls, personal-progress edits, app restart, commit or push were performed. The teacher now receives the verified current request payload; live model adherence and hands-on packaged-app behavior remain unverified.

## Native code-editor search — 2026-09-25

- [x] Trace the missing shortcut to an enabled native find bar with no app-menu commands. Add Edit → Find with Find (⌘F), next/previous match (⌘G / ⇧⌘G), and use selection for find (⌘E), using tagged AppKit text-finder actions through the responder chain. Enable incremental matching; retain native Escape dismissal and focus restoration. Search works in read-only code and does not generate, correct or grade learner code.
- [x] Add a hosted native regression covering search-field focus, next/previous actions from the find field and editor, selection-based search, wraparound across 100 lines, offscreen-match visibility, Unicode queries, missing/empty queries, read-only search, Escape, unchanged bound drafts and no added undo operations. Use a bounded activation/event-drain wait; incremental matches commit to the editor selection when the search field loses focus. Existing syntax/composition, literal-quote, indentation/undo and chat-input tests remain unchanged.
- [x] `swift test --filter 'AppModelTests/(testHostedEditor|testHighlighting|testSyntaxColors|testInternationalDeadQuote|testNativeEditor|testTeacherChatShiftReturn)'`: **seven tests passed, zero failures**. Tests exercise the native command handlers and a synthesized Escape event, not the packaged SwiftUI menu or physical Command-key shortcuts.
- [x] Full `swift test`: **163 tests executed; all 104 core tests and 52 application tests passed; seven previously documented editor-height layout tests failed with 18 assertions**. Failures remain in assessment theory, expanded instructions, gamification/minimum-size rendering, workspace modes, live reward effects, saved incomplete instructions and deterministic effect rendering. No geometry assertions were changed.
- [x] `bash scripts/package-app.sh`: release build and local ad-hoc signature verification passed. `git diff --check`: passed. Quit and reopen the rebuilt package to load the Find commands.

The app has not been restarted and personal progress has not been changed. Further learning-safe editor improvements are recommendations only, not included in this revision.

## Actual-work estimates and historical XP recalculation — 2026-09-25

- [x] Investigate the reported unchanged 100-XP awards without modifying personal progress. Confirm the running package was the updated build, that most saved attempts lacked ratings, and that a newly generated two-result task inherited Similar/one unit. A separate whole-chapter generated task already had five units. Release-mode reproduction verified that reviewed rewards were not universally fixed at 100. Reproduce under-rewarding a two-result selected variation with four failing integration assertions before the fix.
- [x] Obtain explicit user approval to **recalculate past rewards too**, superseding the previous preserve-historical-XP decision. Add reward policy v2 with a guarded, one-time application-launch upgrade and an explicit retry in Player progress. Apply authored reviewed ratings and locally analyzed generated ratings to matching historical attempt snapshots; preserve IDs, code, dates, assistance, mastery, review timing and deduplication. Missing exercises keep their last known rewards. Ordinary XP reads remain evidence-derived and do not perform migrations.
- [x] Analyze generated starter/reference ASTs as data in the existing restricted runner, without executing their contents. Count changed result bindings and grouped function assignment/return/raise work, discount unchanged supplied statements, and take the maximum of this estimate and existing requested coverage. Preserve saved requested difficulty; infer Easier/Similar/Harder from constants, operations, control-flow nesting and exception handling only when absent. Label generated ratings as estimates. Do not score learner code length, inspect credentials, send cloud requests or change the sandbox. Batch historical analysis and retain finite runner limits.
- [x] Before replacement, preserve the previous progress file as `progress-before-xp-v2-<UUID>.json` beside the store. Save the migrated state atomically only after all analysis succeeds. Keep current drafts and focus/session changes made during analysis; cancellation, invalid analysis, storage locks and unreadable stores leave prior rewards intact. Record the policy version to prevent repeated repricing. No migration celebration or synthetic completion is added.
- [x] Show rating details and full completion value directly under the exercise reward, rather than only in a tooltip. Unrated pending tasks explicitly request an XP update instead of promising 100 XP. Generation previews now say **at least** and explain that additional generated work can increase the final reward. Update README and AGENTS guidance. Inspect native practice and generation-preview screenshots at `/tmp/coding-teacher-xp-recalculation-ui`.
- [x] Initial focused verification: **seven tests passed** for real generated checks/reward persistence, approved recalculation, AST analysis, idempotency, failure and cancellation. Full `CODING_TEACHER_UI_SNAPSHOTS_DIR=/tmp/coding-teacher-xp-recalculation-ui swift test`: **162 tests executed; all 104 core tests and 51 application tests passed; seven previously documented editor-height layout tests failed with 18 assertions**. No assertions were weakened.
- [x] Final release-mode verification after the explicit pending-rating UI change: `swift test -c release --filter 'ProgressTests|PythonRunnerTests/testEffort|AppModelTests/(testXPUpgrade|testGeneratedVariation|testExerciseRewards|testGeneratedPractice|testGuidedWeighted|testPracticeRewards|testPracticeGeneratorRenders|testProgressFocus)'`: **48 tests passed, zero failures**. Include backup contents, preserved learner drafts/evidence, successful relaunch, no duplicate migration, greater rewards for extra work, unchanged requested difficulty, and source parsed without execution.

- [x] `bash scripts/package-app.sh`: release build and local ad-hoc signature verification passed. `git diff --check`: passed.

The running app was not restarted and personal progress was not migrated during development. Quit and reopen the rebuilt package to run the approved update; it reports the previous and recalculated totals. Inferred ratings are structural heuristics, not verified semantic difficulty or actual learner time. Live API behavior, hands-on UI interaction and migration of the user's complete store remain unverified.

## Proportional exercise XP — 2026-09-23

- [x] Reproduce flat rewards with a failing application regression (four assertions), then replace fixed new-completion awards with difficulty × workload. Practice pays 50 / 100 / 150 XP per unit for Easier / Similar / Harder relative to the chapter; assessments pay three times the task's practice value. Add explicit authored ratings for all 28 reviewed exercises/assessments, based on required work rather than code length. Examples: learner name 50 XP, label report 300 XP, latency repair 450 XP, final assessment 1800 XP.
- [x] Derive generated ratings locally from the requested difficulty and coverage. Whole-chapter/cumulative tasks count requested lesson sections; selected-exercise variations preserve the target's workload, including broad generated targets, without compounding difficulty. Write/complete/debug formats do not independently change rewards. Provider responses cannot choose XP. Existing reference-pass/starter-fail validation remains required before saving generated exercises; semantic coverage remains unverified.
- [x] Persist optional effort metadata with exercises and snapshot it on new attempts. Derive XP from saved attempt evidence, not mutable totals or current curriculum lookups. Historical attempts and older generated exercises lacking ratings retain their flat rewards. Keep schema 1, exercise IDs, drafts, guided half-rewards, hint allowance, mastery gates, first-completion deduplication, fixed 25-XP seven-day recall, lesson/session awards, and uncapped levels. Bound workload arithmetic and reject invalid saved ratings without overwriting unreadable progress.
- [x] Show actual completion rewards in the workspace and preview generated rewards before the request. Add rating details to the reward tooltip, explain scaling and legacy behavior in player progress, and update README/project guidance. Inspect native screenshots of first-chapter and cumulative generation previews and the player-progress panel at `/tmp/coding-teacher-weighted-xp-ui`; scrollable content remains in its existing scroll views. Hands-on scrolling/VoiceOver interaction was not tested.
- [x] Targeted command: `swift test --filter 'ProgressTests|CurriculumTests|TeacherClientTests|AppModelTests/(testExerciseRewards|testGuidedWeighted|testPracticeRewards|testGeneratedPracticeIsImmediately)'`: **78 tests passed, zero failures**. Cover difficulty/scope scaling, all 27 generation option combinations, recursive selected variations, metadata round trips, historical totals, invalid data preservation, failure/retry/recall gates, real guided checks, generated completion rewards, persistence and celebration amounts. Existing level-up tests now select the 100-XP fruit-total task rather than the newly 50-XP name task; geometry assertions are unchanged.
- [x] Full `CODING_TEACHER_UI_SNAPSHOTS_DIR=/tmp/coding-teacher-weighted-xp-ui swift test`: **156 tests executed; all 101 core tests and 48 application tests passed; seven existing application layout tests failed with 18 editor-height assertions**. Failures match the previously documented geometry issue in assessment theory, expanded instructions, gamification/minimum-size rendering, workspace modes, live reward effects, saved incomplete instructions and deterministic effect rendering. All new XP tests, generation-dialog rendering, and player-progress detail rendering pass. No layout assertions were weakened or unrelated layout behavior changed.
- [x] `bash scripts/package-app.sh`: release build and local ad-hoc signature verification passed. `git diff --check`: passed. Quit and reopen `dist/Coding Teacher.app` to load proportional rewards.

No live API calls, personal-progress edits, restart, commit or push were performed. The workload ratings are explicit reward policy, not a claim to measure actual learner time or independently certify AI difficulty/coverage.

## Reference-validation diagnostics and explicit repair — 2026-09-23

- [x] Reproduce a runner/generator contract mismatch with a real restricted-run test: a valid function that raises the expected exception fails when its test skips `assert False` inside `try`. The equivalent flag assertion after `try`/`except` passes. Confirm that the prompt omitted the requirement for every assertion site to execute; add failing prompt/diagnostic regression assertions before fixing them. The user's specific rejected code was discarded by the previous version, so its exact failure cannot be reconstructed or claimed to match this example.
- [x] Teach the generator the actual execution contract: complete standalone reference, shared test namespace, no imports of learner files or pytest/unittest discovery, called helpers, all assertion sites executed, compatible expected-exception checks, useful assertion messages, float tolerance and the unchanged eight-second limit. Require reconciliation of instructions/examples/reference/checks. Remove the conflicting fixed 10–20-minute size instruction for broad coverage. Do not weaken or modify the runner, sandbox or assertion-coverage rules.
- [x] Preserve rejected generated candidates and bounded validation evidence in memory. Surface the actual final error or local timeout/starter-already-passing reason, and offer a copyable Validation details report containing generated artifacts, not the learner draft or API key. Anonymize temporary/home roots in execution output. Keep rejected candidates out of saved practice and clear them on fresh generation, dismissal, success or restart; reports warn that they include the rejected answer.
- [x] Add **Repair with AI…** with explicit confirmation of one additional potentially charged request. Reuse the original chapter/scope/difficulty/format/selected target; send the rejected candidate plus its validation evidence as untrusted data. Instruct the model to preserve requirements rather than remove checks. Validate reference and starter again before atomic save. Guard assessments, chapter mismatch, busy/storage states, cloud consent and request limits. Never retry or repair automatically.
- [x] `CODING_TEACHER_UI_SNAPSHOTS_DIR=/tmp/coding-teacher-validation-ui swift test --filter 'TeacherClientTests|PythonRunnerTests|AppModelTests/(testGeneratedPractice|testRejected|testSkippedAssertion|testGeneration|testGenerator|testExerciseCompletion|testHintsAndSolutionAreDisabledDuringAssessment)'`: **68 tests passed, zero failures** (30 provider, all 27 runner, 11 application). Cover failed repair remaining rejected, successful explicit repair, request counting and guards, preserved drafts and selection, repair context/assessment exclusion, actionable skipped-assertion reports and anonymized paths. Inspect minimum-size failure actions and the copyable diagnostic view. Native rendering and model-level repair calls were tested; hands-on confirmation/clipboard interaction and live repair quality were not.
- [x] `bash scripts/package-app.sh`: release build and local ad-hoc signature verification passed. `git diff --check`: passed. Quit and reopen `dist/Coding Teacher.app` to load validation details and explicit repair.

No live API request, personal-progress edit, restart, commit or push was performed. The prior full-suite layout failures remain documented; the full suite was not repeated for this targeted revision. The old generic error does not identify the user's exact code failure. A future rejection can now be inspected and explicitly repaired rather than losing the evidence and blindly generating another task.

## Generation network timeout and streaming — 2026-09-23

- [x] Trace the reported “request timed out” message to the network path, distinct from restricted Python validation. Identify the unchanged 90-second request timeout and buffered full-response transport despite the larger generation output budget. Reproduce this policy mismatch with a failing test (three assertions). The screenshot identifies a transport timeout but does not establish the exact provider/network cause or elapsed time.
- [x] Stream exercise generation using Responses API server-sent events. Use a dedicated ephemeral, uncached session configured for a 300-second inactivity timeout and a 600-second total transfer budget; keep chat requests at 90 seconds. Preserve `store: false`, strict structured output, current coverage/difficulty choices, credentials handling, and the Python runner's eight-second fail-closed limit. Do not enable provider background storage or automatic paid retries.
- [x] Parse bounded SSE incrementally across chunk boundaries, including CRLF and keep-alives. Bound lines/events to 1 MB and total stream input to 4 MB; retain existing exercise/code limits. Only accept a `response.completed` event whose response passes existing completion/refusal/format validation. Reject failed/refused/incomplete/malformed streams and EOF without completion, even if received text resembles valid exercise JSON. Cancel the underlying transport on exit.
- [x] Publish throttled received-character progress without displaying partial instructions, starter code or reference solutions. Keep cancellation active while waiting/receiving. Translate timeouts before headers and after partial output into generation-specific messages distinguishing network failure from Python validation, preserving drafts and explaining that no automatic retry occurred and provider charges may still apply.
- [x] Targeted verification: **36 tests passed, zero failures** (28 provider, eight application). Include delayed/chunked Unicode streaming, progress before completion, mid-stream cancellation, partial-stream timeout, incomplete EOF, refusal/failure/malformed/oversized input, separate chat/generation timeout settings, no retries, and native dialog-to-stream-to-restricted-validation-to-save flow. Network timing is simulated and timeout configuration is asserted; tests do not wait for real five-/ten-minute deadlines. The full suite was not rerun for this transport-only revision; its previously documented baseline layout failures remain unresolved.
- [x] `bash scripts/package-app.sh`: release build and local ad-hoc signature verification passed. `git diff --check`: passed. Quit and reopen `dist/Coding Teacher.app` to load the streaming transport.

No live API call or personal-progress edit was made, and the running app was not restarted. The new transport and budget address the implementation's timeout mismatch; successful live generation on the user's connection/model still needs confirmation.

## Generation discoverability and completed exercise markers — 2026-09-23

- [x] Exercise the actual native New with AI and Generate buttons, not just render the dialog. Submission reaches the model; the original flow hid generation/validation errors only in the output panel and reported success before its debounced save. Reproduce missing immediate persistence and missing error notices with two failing integration tests (six assertions) before the fix. This does not establish which failure occurred in the user's specific live request.
- [x] Add persistent requesting, validating, ready, failed and cancelled states next to the exercise picker. Keep Cancel usable while busy. Explicitly say **No exercise was added** on failure; surface request/validation/save failures as alerts as well. Preserve status across exercise navigation and provide **Open exercise** after success. Write the validated exercise and selection atomically before reporting success; preserve the old draft, avoid adding rejected results, and do not overwrite newly unreadable progress. No automatic paid retries.
- [x] Derive completion markers from saved passing practice attempts. Show **✓** in the native exercise picker and a completed/total count. Include reviewed/generated exercises and assisted passes; exclude failed checks, plain Run, lessons, assessments, unrelated chapters and missing exercises. A later edit or failed retry does not erase past completion; it does not imply the current draft passes or grant chapter mastery. No schema migration or mutable completion counters.
- [x] Add injectable initial cloud consent/client construction for credential-free application integration tests while retaining consent and request-limit guards. Use mocked HTTP responses and the real restricted Python runner to verify generation, validation, immediate save, automatic selection, reopen/relaunch, completion after Check solution, invalid reference, already-passing starter, HTTP rejection, cancellation and unreadable-store preservation.
- [x] Targeted generation/completion checks: **seven tests passed, zero failures**. Native button submission tests verify both a blocked request and an accepted exercise, including actual picker item titles and completion marks. Inspect minimum-size screenshots at `/tmp/coding-teacher-generation-flow-ui/generation-ready-and-completed-picker.png` and `generation-failed-visible-status.png`.
- [x] Full `swift test`: **134 tests executed; all 84 core tests and 43 application tests passed; seven existing layout tests failed with 18 assertions**. These are the editor/output split-height failures reproduced on the clean baseline during the prior revision. Shift+Enter passed on this run. All new tests pass; no layout assertions were weakened.
- [x] `bash scripts/package-app.sh`: release build and local ad-hoc signature verification passed. `git diff --check`: passed. The packaged app is updated; quit and reopen `dist/Coding Teacher.app` to load this revision.

No live API requests, personal-progress edits, commit, push or restart were performed. The exact cause of the user's previous attempt and live provider quality remain unverified; a failed generation will now leave an explicit, visible reason instead of appearing to vanish.

## Flexible practice generation — 2026-09-23

- [x] Reproduce the narrow generation behavior with a failing provider regression: mixed requests only required one current and one earlier concept, used only the first reviewed exercise as an example, and explicitly asked for one small learning goal.
- [x] Replace the ambiguous menu with a native challenge dialog. Independently choose selected-exercise / whole-current-chapter / current-plus-all-earlier coverage, easier / similar / harder chapter-relative difficulty, and write / complete / debug format. Default to whole chapter, similar difficulty and write code. Add a bounded optional synthetic scenario, preview of requested lesson sections, and token-cost/coverage caveats. Keep choices during the workspace session and disable cumulative coverage on the first chapter.
- [x] Derive broad coverage from every Learn heading and supply the full lessons in canonical curriculum order. Calibrate difficulty from all three current reviewed exercises, never the selected/generated exercise. Require full coverage even for easier requests; allow connected stages instead of shrinking the task. Supply bounded task excerpts from eight recent current-chapter exercises to discourage superficial repeats. Do not send learner drafts, solutions, tests, future lessons or assessments.
- [x] Require a strict, complete nonblank coverage map in provider responses and preserve its explanations in the saved Check section, labeled as AI-described rather than independently verified. Preserve the existing five required instruction sections, local exercise IDs and draft interfaces, reference-pass/starter-fail execution checks, fail-closed runner, storage protection, cancellation and assessment guards. Permit up to 24,000 assembled instruction characters for broad tasks, retaining the 80,000-byte payload and existing code/hint bounds; use output budgets of 8,000 tokens for focused/chapter requests and 12,000 for cumulative requests. No paid retries.
- [x] Mock all 27 scope/difficulty/format combinations, validate every curriculum prefix and lesson heading, reject incomplete/extra coverage and invalid scopes, check recent-task context and untrusted scenario bounds, and round-trip saved coverage. Render and inspect first-chapter, selected-exercise debugging and easier cumulative dialog screenshots at `/tmp/coding-teacher-generator-ui`. New generator/guard tests pass without cloud credentials.
- [x] Full snapshot-enabled `swift test`: **127 tests executed; all 83 core tests and 36 application tests passed; eight existing application tests failed with 22 assertions**. Failures concern editor/output split geometry and native Shift+Enter behavior. Reproduce identical geometry and Shift+Enter failures in a clean detached checkout of baseline `de76a67` (two representative tests, seven assertions); remove the temporary worktree afterward. Do not weaken those tests or alter unrelated editor/chat behavior to claim a green suite.
- [x] Final targeted verification: **26 tests passed, zero failures**, including 20 provider tests, one curriculum-coverage test and five application tests. Command: `swift test --filter 'TeacherClientTests|CurriculumTests/testGenerationCoverage|AppModelTests/(testPracticeGenerator|testGeneratorGuards|testMixedChallenge|testHintsAndSolutionAreDisabledDuringAssessment)'`. `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed. `git diff --check`: passed. Quit and reopen `dist/Coding Teacher.app` to use the new generator.

Live OpenAI coverage, novelty and difficulty quality are not verified. A complete model-supplied checklist plus executable tests is not proof that every concept was practiced correctly. No personal learning data was edited, no live API calls were made, and the user's app was not restarted.

## Generated exercise completeness — 2026-09-23

- [x] Confirm the reported exercise's saved instructions end mid-JSON example; this is missing stored content, not a clipped SwiftUI view. Reproduce acceptance of a synthetic truncated instruction string inside otherwise valid exercise JSON with a failing regression test before the fix.
- [x] Replace the provider's single free-form instruction string with a strict object requiring Goal, Starting code, Your task, Expected result, and Check. Reject missing/blank sections and assemble all five into the existing saved string format without truncating content. Preserve exercise IDs, drafts, storage compatibility, size limits, and executable reference/starter validation.
- [x] Reject explicitly incomplete message items even when the provider's outer response claims completion. Test this rejection before and after the fix. Do not silently retry paid requests or save partial exercises.
- [x] Warn when an existing generated exercise lacks the required nonempty sections. Recognize plain/Markdown headings and the reviewed curriculum's Examples heading. Preserve incomplete saved records and drafts; direct the learner to a new variation or reviewed exercise rather than inventing missing text.
- [x] `CODING_TEACHER_UI_SNAPSHOTS_DIR=/tmp/coding-teacher-instructions-ui swift test`: **120 passed, zero failures** (42 application, 78 core). Inspect the incomplete-exercise warning at the minimum window size. After adding one more mocked end-to-end generation rejection test and clarifying the prompt, `swift test --filter TeacherClientTests`: **16 passed, zero failures**.
- [x] `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed. `git diff --check`: passed.

No live API calls or personal-progress edits were made, and the running app was not restarted. Validation enforces required sections and response completion, not semantic completeness of every model-written sentence or requirement. Missing text in previously saved exercises cannot be recovered from those records. Quit and reopen `dist/Coding Teacher.app` to use the updated generation rules and warning.

## Chat keyboard input — 2026-09-22

- [x] Make Shift+Enter insert a newline through the native field editor, preserving cursor/selection behavior. Wire Enter to Ask teacher, reject empty/busy submissions, and add a shortcut tooltip.
- [x] Reproduce the missing newline with a hosted native keyboard test before the fix. Verify selection replacement, caret position, continued multiline editing, Enter submission, and empty-input rejection. Exhaust the test model's request allowance to prevent live API access.
- [x] `swift test`: **114 passed, zero failures** (41 application, 73 core). `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed. `git diff --check`: passed.

The packaged app is updated without restarting the user's session. Quit and reopen `dist/Coding Teacher.app` to use the fix. Keyboard coverage uses synthetic native events; physical-keyboard verification remains a manual check.

## Uncapped levels and expanded reward effects — 2026-09-22

- [x] Remove the level-100 gameplay cap and all max-level UI. Preserve the existing quadratic total-XP curve and every previously earned level; next-level costs continue increasing by 50 XP per level. Use integer binary search and checked threshold arithmetic, including near `Int.max`, rather than a bounded level scan. The storage representation remains finite machine integers, not arbitrary-precision XP.
- [x] Add a green glowing perimeter sweep starting at the bottom center, traveling up both window edges and meeting at the top. Add a pulse around the actual level-bar anchor and deterministic scattered confetti: 36 particles over 1.8 seconds for ordinary XP, 110 particles over 2.8 seconds with wider spread and more colors for level-ups. Remove the decoration after the animation; keep text feedback and VoiceOver announcements available.
- [x] Make all full-window decoration non-interactive and hidden from accessibility navigation. Honor both Reduce Motion and the saved effects toggle; do not move the editor or controls. Existing failed/duplicate-check reward rules remain unchanged.
- [x] Expand the formerly capped regression test to cover every boundary through 200, much higher levels, the 100-to-101 transition and integer-limit arithmetic. Add persistence/export coverage beyond level 100, effect intensity/accessibility rules, deterministic native animation stages and a real restricted-run passing-solution celebration with editor hit-testing. The revised level test failed against the old cap before implementation and passed afterward.
- [x] `CODING_TEACHER_UI_SNAPSHOTS_DIR=/tmp/coding-teacher-effects-ui swift test`: **113 passed, zero failures/skips** (40 application, 73 core). Inspect ordinary XP and level-up captures, the actual successful-check animation and its cleared state at the minimum window size. A native hit-test initially used local instead of superview coordinates; fixing the test coordinate conversion confirmed the overlay does not intercept editor input.
- [x] `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed. `git diff --check`: passed. No live API calls, personal-progress edits, app restart, commit or push were performed for this revision. Hands-on animation feel and actual VoiceOver use remain manual checks.

## Player progression and saved focus sessions — 2026-09-22

- [x] Commit and push the pre-feature application checkpoint to `origin/main`: `6c8a5ca` (`Preserve the working native Python learning app`). Feature changes remain local for review.
- [x] Initially add a single effort-based player level starting at 0, capped at 100 (cap removed in the revision above). Reaching level L requires `100*L + 25*L*(L-1)` total XP; the next level costs `100 + 50*L`. Level 100 requires 257,500 XP and is a long-term goal beyond the fixed foundation curriculum. Effort-neutral rank names do not claim Python expertise.
- [x] Derive XP deterministically from saved evidence: first passing practice +100 (hints welcome), or +50 after viewing its reference; first fully passed chapter assessment +300; lesson explicitly marked read +25 once; independent successful retake +25 after seven days since that activity's latest independent success; completed 25-minute focus session +50. Earlier successful attempts count automatically; raw runs, failed checks, incomplete assessments, and duplicate submissions do not award XP. XP never unlocks chapters or changes mastery.
- [x] Persist completed focus sessions with IDs and dates, lifetime count and completed-session minutes, and unfinished elapsed time. Add start/pause/resume/end-early confirmation. Use monotonic elapsed time, automatic completion independent of open popovers, pause on system sleep and normal quit, 15-second checkpoints, and paused restoration after relaunch. Paused/closed-app time does not count. Abrupt termination can lose up to one checkpoint interval; partial sessions do not count toward completed totals. Previously unsaved timer activity cannot be recovered.
- [x] Keep schema-1 compatibility and strict malformed-data preservation. Store histories rather than mutable XP totals; reject invalid/duplicate session records and preserve existing drafts, conversations, attempts and backups.
- [x] Add compact level and focus controls, per-exercise reward eligibility, scrollable progress/session detail, recent XP, lifetime milestones, animated progress and a finite level-up star burst. Keep a fixed header reward slot, queued dismissible feedback, VoiceOver announcements, Reduce Motion support and a persisted effects toggle. No sounds, streak penalties, XP decay, or assessment assistance.
- [x] Obtain UX-agent recommendations and independent Design-agent review. Fix all three design blockers: skill-implying rank titles, missing reward announcements, and possible header movement. Both reviewers explicitly approved the final code; their review was static, not hands-on or pixel-level image inspection.
- [x] `CODING_TEACHER_UI_SNAPSHOTS_DIR=/tmp/coding-teacher-gamification-ui swift test`: **109 passed, zero failures/skips** (37 application, 72 core). Added 22 tests covering curve boundaries, evidence/dedup/recall rules, migration/malformed data, timer lifecycle and automatic completion, queued rewards, native detail views and minimum-size reward states. Initial rendering checks exposed a test-only 64-versus-40-point celebration-height expectation; corrected to the actual compact component height and reran the entire suite successfully.
- [x] Inspect native screenshots of the minimum-size practice/assessment workspace, progress and paused-focus detail, and reduced-motion celebration. Preserve existing editor geometry in all learning modes. `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed. `git diff --check`: passed.

No live API calls were made, no personal learning data was edited, and the user's app was not restarted. Native rendering and injected-clock tests do not establish real-world 25-minute/sleep behavior or hands-on VoiceOver/animation quality; these remain manual checks. Quit and reopen `dist/Coding Teacher.app` to try the packaged revision. Open the level badge for rewards and history, or Focus for saved study sessions.

## Project README — 2026-09-22

- [x] Add a comprehensive README covering prerequisites, development and packaged launch, first-session workflow, curriculum, mastery and player progress, optional AI setup/costs, privacy, backups/recovery, restricted execution, architecture, test commands, troubleshooting, and limitations.
- [x] Cross-check documented behavior against package metadata, packaging scripts, application/core code, and tests. Preserve the distinction between automated verification and unverified live API/manual behavior.
- [x] `swift build` and `bash -n scripts/package-app.sh` passed. Packaging and GUI launch were not repeated for this documentation-only task.
- [x] `swift test` rerun: **104 passed, zero failures**. Documentation review and whitespace checks passed. The initial run encountered concurrently edited XP/study-session tests before their model types were available; the rerun passed after those changes became available. Unrelated implementation changes were left untouched.

## Editor input and exercise conversations — 2026-09-22

- [x] Replace full-document text-storage formatting on each keystroke with layout-only syntax colors. Leave marked text alone during macOS composition and avoid round-tripping uncommitted text through SwiftUI. Give each exercise draft its own native editor identity.
- [x] Insert plain single/double quotes directly in the code editor. Resolve unmodified/Shift quote dead keys using the current keyboard layout without waiting for a space; preserve Option accents, shortcuts, and other composition behavior.
- [x] Persist teacher questions, replies, hints, and revealed references per exercise, sharing the thread between Learn and Practice. Restore threads across exercise/chapter/tab navigation and app relaunch. Keep assessment assistance unavailable and revealed references excluded from teacher request history.
- [x] Preserve existing schema-1 saves without conversations, restoring previously shown built-in hints once. Keep malformed conversation data protected rather than silently resetting it. Include conversations in local progress backups.
- [x] Add nine regression tests covering conversation navigation/relaunch/autosave, legacy hints, non-mutating syntax colors, composition and caret handling, hosted quote typing and undo/redo, US International-PC dead-quote mapping, legacy progress migration, and malformed conversation preservation. Extend state/export roundtrip coverage.
- [x] `swift test`: **87 passed, zero failures/skips** (27 application tests, 60 core tests). `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed.

No live API calls were made, no personal learning data was edited, and the running app was not restarted. Native input tests use synthetic events and composition calls; physical-keyboard testing with the user's active input source remains pending. Quit and reopen `dist/Coding Teacher.app` to try the fixes. Conversations discarded by older app versions cannot be recovered; new conversations are saved locally with exercise progress.

## Workspace and mixed-chapter revision — 2026-09-15

- [x] Collapse chapter navigation into a Chapters popover, retaining mastery status, locked chapters, review links, and backup export.
- [x] Move Learn, Practice and Assessment content into a resizable left panel. Keep the central editor and output visible in every mode, including assessment theory; Learn edits the existing practice draft. Retain the right teacher panel and assessment assistance restrictions.
- [x] Add **New with AI → Combine this with previous chapters**. Supply the current lesson and all earlier curriculum lessons, request one coherent challenge using a current concept plus at least one earlier concept, and exclude future lessons and assessment content. Disable the option for the first chapter and guard the backend before cloud access. Keep existing runtime validation, saved interfaces, and curriculum IDs unchanged.
- [x] Add provider coverage for mixed lesson context, ordinary generation, and rejection of current/future chapter context; add model coverage for earlier-chapter selection and first-chapter/assessment guards.
- [x] Verify native editor geometry in all three modes at 1380×900 and 1080×740, plus editor visibility during assessment theory. Inspect default/minimum screenshots, including long values-chapter instructions; remove redundant visible picker labels to preserve space.
- [x] `swift test`: **78 passed, zero failures/skips** (20 application tests, 58 core tests). `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed.

No live API calls were made. Combining concepts and avoiding untaught material are generation instructions, not semantic guarantees from executable validation. Hands-on popover/menu interaction and live challenge quality remain pending user review. The packaged app was rebuilt without restarting the user's session; quit and reopen `dist/Coding Teacher.app` to try this revision.

## Beginner teaching revision — 2026-09-10

- [x] Review first-session feedback: the original lesson assumed method/f-string knowledge and compact task descriptions were hard to follow.
- [x] Add a zero-knowledge first chapter; explain new Python syntax with small worked examples before requiring it. Seven chapters now contain 21 practice exercises, seven independent assessments, 21 theory questions, and 26 standalone lesson examples.
- [x] Rewrite all 28 reviewed coding tasks into goals, supplied inputs/placeholders, numbered tasks, expected results, and checking instructions. Assessment instructions name the correct Submit assessment action; assessment hint arrays are empty.
- [x] Update teacher/generation instructions to assume no Python knowledge, explain unfamiliar syntax, and avoid untaught concepts even in harder variations. Add a practice-only “Explain this task simply” action.
- [x] Make the instruction pane resizable instead of limiting it to 180 points; preserve existing curriculum IDs and saved work; direct new learning stores to the basics chapter.
- [x] Verify all lesson examples, reference solutions, failing starters, progression/persistence, provider mocks, and native rendering; rebuild the packaged application. `swift test`: **74 passed, zero failures/skips**. All 28 references pass, all 28 starters fail assertions, and all 26 lesson examples execute in the restricted runner. Native rendering includes longer task instructions at the 1080×740 minimum window size. `bash scripts/package-app.sh`: release build and ad-hoc signature verification passed.

New stores begin at basics. Existing saved chapter selection, drafts, reflections, assistance history, and attempts remain intact; existing unmastered values work now has basics as its prerequisite, without granting artificial mastery. After quitting and reopening the packaged app, choose **1. Your first Python steps** in the sidebar. The running user session was not interrupted.

Live AI teaching quality and hands-on usability of this revision remain unverified until the user tries it. Previously saved AI-generated exercises retain their original wording; the new generation rules apply to future requests.

## Architecture decisions

- SwiftUI app shell with AppKit NSTextView editor. No third-party Swift dependencies.
- Python is the learning language; Swift is only the implementation language.
- Core module owns curriculum, state, runner, and provider client; app module owns native presentation, orchestration, and Keychain access.
- Local JSON state at `~/Library/Application Support/PythonTeacher/progress.json`. API keys are never stored there or included in exports.
- OpenAI Responses API, with `store: false` and a strict schema for generated exercises. Provider retention policies still apply.
- Teacher/exercise generation cannot directly modify progress, edit learner code, or run application commands.
- Python restrictions fail closed; no unrestricted fallback. The runner is a personal-learning safeguard, not a hardened hostile-code platform.
- Default interpreter is discovered from common Mac installation paths. Python framework launchers are resolved to the actual executable so child-process restrictions stay intact.
- Backup exports use the same versioned JSON format as saved progress. This release exports backups; restoration is manual, with the app closed and the existing file preserved.

## Build and launch

From the repository root:

```sh
swift test
bash scripts/package-app.sh
open "dist/Python Teacher.app"
```

For development, `swift run PythonTeacher` also works. The bundled app is recommended for a normal Dock/window experience.

The application is built for macOS 14 or later and uses an installed Python 3 interpreter. This machine has Xcode and several compatible Python installations; no global package installation or security-setting changes were required.

## First session

1. Open Python Teacher. The first chapter is available immediately, without an API key.
2. In Settings, use **Verify restricted execution** if you want to check the selected Python interpreter.
3. Read the first lesson, choose **Start hands-on practice**, edit `main.py`, and use **Check solution**.
4. Use built-in hints only when needed. Restoring starter code does not erase assistance history.
5. To enable personalized teaching and new exercises, opt in to cloud access and enter an OpenAI API key in Settings. The key is stored in macOS Keychain. Never paste it into chat or source files.
6. For an assessment, complete the code, all three theory questions, and a written explanation. Submit to run fresh checks; old passing results are never reused.
7. If the basics are familiar, use the assessment as a placement check. A manual unlock override is available but is not counted as mastery.

## Verification log

- Environment inspection: passed. Apple Silicon, Xcode, Swift 6, Python available.
- Full suite: **67 tests passed, zero failures/skips**. After the final settings/alert presentation refinement, all **15 application tests passed again**.
- Curriculum: all 24 reference solutions pass; all 24 starters fail assertions; all six lesson examples execute in the restricted runner.
- Runner: sandbox denial tests cover network, subprocess/fork/exec, outside-workspace reads/writes, and modifying learner/test files. Tests cover early exit, fake success output, missing/skipped assertions, cancellation/reuse, output flooding, invalid UTF-8 and closed pipes.
- Resource safeguards: eight-second default timeout, approximately 64 KiB captured output, 8 MiB maximum per file, 64 open descriptors, no core dumps. Resource tests also passed on pyenv Python 3.10 and Homebrew Python 3.12. No aggregate disk or memory quota is claimed.
- Compatibility: runner tests passed on Xcode Python 3.9, pyenv Python 3.10.12, and Homebrew Python 3.12.7; application tests also exercised its automatically selected Homebrew interpreter.
- Persistence: missing/corrupt/unsupported/unreadable state, roundtrip, atomic replacement, export and mastery/review rules tested.
- Application: draft isolation/resume, independent assessment completion, wrong-theory rejection, stale-result prevention, assistance tracking, solution-history filtering and native editor/rendering tested.
- Provider: mocked requests verify endpoint, auth headers, storage opt-out, no tools, strict generation schema, response parsing, refusals, incomplete output and HTTP failures. No real API call or charge initiated.
- Release packaging: final release build, app icon generation and ad-hoc signature verification passed. `open "dist/Python Teacher.app"` succeeded; macOS NSRunningApplication confirmed `isFinishedLaunching = true` and `isTerminated = false`.
- Native UI: automated AppKit/SwiftUI rendering tests passed. A hands-on visual/accessibility check is still required; generated screenshots could not be inspected through the tool's ignore filter.
- Live OpenAI / Keychain credential roundtrip: not performed; user setup required.

## Known limitations and deliberate scope choices

- This release covers 17 chapters from first-ever Python assignments through Core Python II, Software craft and standard-library data science. NumPy, pandas and plotting remain planned, not delivered; their package environment requires separate approval. The path browser groups the prerequisite graph into tracks rather than drawing connecting edges.
- Each chapter has one current fixed, reviewed assessment and three fixed conceptual questions. Retakes reuse them. Saved legacy decisions assessments retain their original coding contract through a version selector; this is compatibility support, not a randomized assessment bank. Expanded equivalent test banks are a later milestone.
- Written explanations are saved but not automatically scored. Passing tests demonstrates behavior for those cases, not complete understanding or proof against hardcoding.
- AI guidance relies on teaching instructions and can be imperfect. Generated tests are runtime-validated, not independently proven complete or pedagogically correct. Switch to reviewed exercises if generated requirements seem inconsistent.
- The request cap counts attempted calls, including failed or rejected generations, because these may still incur charges. Counts reset at app launch; this is not a monetary spending limit.
- Chat is persisted locally per exercise, alongside drafts, progress, generated exercises, assistance counts and attempts. Learn and Practice share the selected exercise's conversation; assessment mode never displays or sends that history. Chats discarded by older versions cannot be recovered.
- Learner files created during execution are temporary and cleaned up after each run. Only editor drafts/attempts and explicit exports persist.
- Standard library only in the runner (`-I -B -S -u`); no terminal, network access, third-party packages, multi-file project explorer, or debugger yet.
- `sandbox-exec` is a deprecated macOS mechanism and may need replacement for future OS versions. Sophisticated malicious code is outside this personal tool's threat model. There is no total disk or memory quota.
- The app is locally ad-hoc signed, not Developer-ID signed or notarized. Rebuilds may cause Keychain authorization prompts.

## Later milestones — not part of this build's completion target

- Extended course: real HTTP APIs, virtual environments/dependencies, Git, multi-file projects, LLM evaluation, and an independent capstone.
- Agent-based teacher provider via ACP after validating permissions and non-solving behavior.
- Full debugger, language server, project explorer, and accessibility/UI refinement based on hands-on use.
- More sophisticated spaced repetition and calibrated equivalent assessment banks.
- Developer-ID signing/notarization, cloud sync, multiple languages, and public product features.

## User involvement

Implementation proceeds autonomously. User intervention is needed only for OS/tool approval prompts, adding a personal API key, authenticated live API verification if desired, and hands-on usability feedback. No key should be pasted into chat. Destructive operations and security-policy changes require specific confirmation.
