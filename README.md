# Python Teacher

A native macOS workspace for learning Python from scratch, built with SwiftUI and AppKit. Python Teacher combines short lessons, a code editor, restricted local Python execution, and evidence-based assessments, with an optional AI teacher (OpenAI, Anthropic, Google or xAI) for explanations and additional practice.

The goal is independent understanding, not simply completing exercises. The built-in course works without an API key, an app account, or an application backend. Python is the language you learn; Swift is the language used to build the app.

## Quick start

You need a Mac with **macOS 14 or later**.

**1. Install the tools** (one time). Open Terminal and run:

```sh
xcode-select --install   # Apple's Swift compiler (skip if you have Xcode)
```

Then install Python 3 from [python.org](https://www.python.org/downloads/macos/) or with `brew install python`.

**2. Get the code:**

```sh
git clone https://github.com/Stgrgtt/python-teacher.git
cd python-teacher
```

**3. Build and open the app:**

```sh
bash scripts/package-app.sh
open "dist/Python Teacher.app"
```

That's it. You can drag `dist/Python Teacher.app` into your Applications folder. An app you build on your own Mac opens without any Gatekeeper warnings.

For quick development runs, `swift run PythonTeacher` also works.

## Share the app with friends

Run:

```sh
bash scripts/share-app.sh
```

This makes `dist/Python-Teacher-<version>-macOS.zip`. It needs the full Xcode app, not just Command Line Tools, because it builds for both Mac chip types. It contains a universal app that runs on both Apple Silicon and Intel Macs, plus a `HOW TO OPEN.txt` guide. Send your friends that zip.

### Opening an app someone shared with you

The app is **not signed with an Apple Developer ID**, so macOS blocks it the first time. You only have to do this once:

1. Unzip it and move **Python Teacher.app** to **Applications**.
2. Double-click it. When macOS says it can't verify the app, click **Done**.
3. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to "Python Teacher was blocked".
4. Confirm with your password or Touch ID.

If you prefer Terminal, this removes the download flag:

```sh
xattr -dr com.apple.quarantine "/Applications/Python Teacher.app"
```

Friends also need Python 3 installed (see Quick start, step 1). The other option is for them to build it themselves with the Quick start steps; nothing gets blocked that way.

> Why the warning? Without a paid Apple Developer account, the app gets a free local "ad-hoc" signature. That is enough to run on Apple Silicon, but Apple can't notarize it. Getting rid of the warning entirely needs a Developer ID certificate and notarization.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Your first session](#your-first-session)
- [Curriculum and progression](#curriculum-and-progression)
- [Optional AI teacher](#optional-ai-teacher)
- [Privacy, saved work, and backups](#privacy-saved-work-and-backups)
- [Python execution and safety](#python-execution-and-safety)
- [Development and testing](#development-and-testing)
- [Troubleshooting](#troubleshooting)
- [Scope and limitations](#scope-and-limitations)

## Features

- **Beginner-first lessons:** explanations of unfamiliar syntax, small standalone examples, numbered exercise steps, and exact expected results.
- **Three learning modes:** Learn, Practice, and Assessment, with the editor and output visible in each mode.
- **Native editing:** Python syntax highlighting, line numbers, indentation, undo/redo, and incremental find, backed by an AppKit text editor. Click in the code editor and use **⌘F** to search, **⌘G / ⇧⌘G** for the next/previous match, **⌘E** to use selected text as the search term, and **Escape** to close the find bar. These commands are also available under **Edit → Find**.
- **Local feedback and debugging aids:** run code, check behavior, inspect a structured failure card and original traceback, jump to a fresh learner-code error line, and cancel execution without leaving the workspace. Learn/Practice include offline error-category guidance; assessment cards provide neutral type/location information only.
- **Graduated assistance:** built-in practice hints and an explicit reference-solution reveal, with assistance recorded separately from independent work.
- **Optional AI teaching:** contextual explanations and generated practice, including objective-driven projects that focus on the current chapter and use its prerequisite chapters as a toolkit.
- **Resumable work:** separate exercise drafts, saved attempts, reflections, and per-exercise teacher conversations.
- **Daily study tools:** a 25-minute focus timer, seven-day review reminders, Python file export, and learning-data backups.

## Requirements

| Requirement | Details |
| --- | --- |
| macOS | macOS 14 or later (Apple Silicon or Intel). |
| Swift toolchain | Only needed to build: Swift 5.9 or later from Xcode or Command Line Tools. |
| Python | An installed Python 3. It is not bundled with the app. Python 3.9, 3.10, and 3.12 have been checked. |
| Restricted execution | `/usr/bin/sandbox-exec` must be available (it is on standard macOS). There is no unrestricted fallback. |
| AI provider access | Optional: an OpenAI, Anthropic, Google (Gemini) or xAI (Grok) API key, used only for the AI teacher and generated practice. API charges may apply. |

There are no third-party Swift dependencies, and built-in exercises need no `pip` packages. To check your tools: `swift --version`, `xcode-select -p`, `python3 --version`. If your Python on `PATH` is a shim (pyenv, etc.), choose the real executable in the app's Settings.

After rebuilding, quit and reopen the app to load the new version.

## Your first session

1. Open Python Teacher. New learning stores begin at **1. Your first Python steps**.
2. Open **Settings…** with `Command+,`. Under **Python execution**, check the interpreter, use **Verify restricted execution**, and save any changes with **Save settings**.
3. Read the lesson in **Learn**, then choose **Start hands-on practice**.
4. Read the exercise's goal, starting-code guidance, numbered tasks, and expected result. Edit the supplied `main.py` draft rather than replacing it blindly.
5. Use **Run** to execute the code and see printed output. Use **Check solution** in Practice to test the required variables, return values, and behavior. Printing the expected answer alone is not necessarily a solution.
6. Read the last traceback line when something fails, make one focused change, and check again. Built-in hints are available without an API key; revealing the reference marks that practice as assisted.
7. When ready, switch to **Assessment**, complete the coding task, answer all three theory questions, write an explanation, and choose **Submit assessment**.

In the **Practice** exercise picker, **✓** marks exercises with a recorded passing **Check solution**, including guided solutions. A chapter completion count appears below the picker. Failed checks, plain Run, and generation alone do not count. The mark records past completion, not whether your current edited draft passes or whether the chapter is mastered; it survives navigation and relaunch.

The **Chapters** popover provides chapter navigation, mastery status, and review links. Resize the left instruction panel as needed. Learn and Practice share the selected practice draft and conversation; Assessment uses its own draft and does not show or send that conversation.

### Reading a failure

A failure card distinguishes **Your code**, **Checks**, and **Python runner**. For learner errors, it shows the error category, a bounded message and the learner's call frames. **Go to line** selects the relevant line without editing your code or changing undo history. Navigation is disabled after editing until you run the current code again; changing exercises or restoring the starter clears the diagnostic.

Learn/Practice add a short offline explanation of common error categories. Assessment cards omit this coaching and the diagnostic message, while the original output remains available as before. Check/harness locations never navigate into your editor. Diagnostics are supplementary: they do not award completion or replace executable checks. If a run times out, is cancelled, or cannot supply a structured diagnostic, use its original output/status.

These are error-reading tools, not a live debugger: breakpoints, interactive variable inspection and execution replay are future phases.

### Named checks and scratch inputs

Four reviewed debugging labs now include named, multi-input checks: **a closed room opens**, **entry at the boundary**, **find the first wrong total**, and **stop at the target**, in Decisions and Loops.

- **Check solution** runs authored cases in fresh restricted workspaces, showing **Passed**, **Failed**, or **Not reached**, with expandable expected/actual values. It stops at the first unsuccessful case. Every named case **and the original exercise checks** must pass for completion; the overall result is shown separately from the named-case count.
- **Scratch inputs…** in the output header opens declared input fields in unlocked Learn/Practice activities that support them. Enter a small Python literal such as `13`, `False`, or `[4, 0, 2]`, then choose **Run experiment**. Expressions and function calls are rejected. The original input assignment lines must stay unchanged in the editor.
- An experiment uses your temporary inputs and displays output plus observations of the exercise's result variables. It does **not** change the saved draft, record an attempt, award XP, or complete an exercise. **Run** still uses the editor's original inputs; **Check solution** uses the authored case bank, not your scratch fields.
- **Reset inputs** restores the declared defaults. Scratch fields and run evidence are workspace-local and reset on navigation, starter restoration, or relaunch. Editing code or scratch inputs makes earlier experiment evidence stale and disables its Go to line action.
- Experiments and named-case detail are unavailable during assessments. Other exercises retain their existing check behavior. When you ask the optional teacher, the snapshot identifies experiments and their exact input overrides; successful experimentation is never represented as passing a solution check.

Named plans have bounded case/input counts and a shared eight-second execution budget. They support declared, unique, simple input assignments—not arbitrary rewrites or multi-file projects. The remaining repertoire and execution-replay work stays tracked in PLAN.md.

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Command+1` | Learn |
| `Command+2` | Practice |
| `Command+3` | Assessment |
| `Command+R` | Run code |
| `Command+Shift+R` | Check solution in Practice |
| `Command+,` | Settings |

The **Learning** menu also offers exports for the current Python file and a learning backup. Use **Stop** to cancel active work.

## Curriculum and progression

The built-in course contains **17 chapters, 63 reviewed practice exercises, 17 coding assessments and 51 theory questions**. Seven foundation chapters form a shared starting path; later chapters branch into Core Python II, Software craft and Data science. Every runnable lesson code block runs independently in the restricted runner; intentionally broken illustrations are displayed as text.

The foundations include **12 offline debugging/prediction labs**, appended after the original exercises. Basics teaches **Understanding errors**, and Functions teaches **Debugging systematically**, within their existing lesson sections. Labs cover syntax repair, overwritten values, expression predictions, decision priorities and boundaries, loop traces, return values, minimal counterexamples, optional dictionary fields, and validation of later records. Existing activities, assessments, prerequisites, saved drafts, and mastery history are unchanged. Early fixed-input labs check the supplied example, not every possible input; recording a correct prediction alone does not establish a general algorithm.

| Chapter | Focus |
| --- | --- |
| 1. Your first Python steps | Names, numbers, text, assignment, and printed output |
| 2. Values and expressions | Calculations, strings, methods, and formatting |
| 3. Decisions and boundaries | Conditions, branching, and precise boundary behavior |
| 4. Loops and accumulators | Processing sequences and building results incrementally |
| 5. Functions and contracts | Parameters, return values, and reusable behavior |
| 6. Collections and JSON | Structured records and JSON data |
| 7. Validation and a small analysis tool | Rejecting invalid data and testing useful behavior |

After the foundations:

| Track | Chapters and prerequisites |
| --- | --- |
| Core Python II | **Iteration patterns** follows Validation; **Files, modules, and dates** and **Classes and objects** each follow Iteration |
| Software craft | **Inheritance and class design** and **Iterators and generators** follow Classes; **Testing with unittest** requires both Classes and Files; **Type hints and decorators** requires Inheritance and Generators |
| Data science | **Cleaning tabular data** follows Files; **Descriptive statistics and sampling** follows Cleaning; **Aggregating, joining and reporting tables** requires Statistics and Classes |

Classes are introduced after iteration, with `class`, `__init__`, `self`, methods, object state, dataclasses and custom exceptions. The data-science path currently uses only Python's standard library for CSV cleaning, statistics, sampling, grouping, joins and reports. **NumPy, pandas and plotting are planned but not yet available.**

The Chapters browser presents the prerequisite graph as grouped, scrollable tracks, with missing prerequisites listed for locked chapters; it is not a graphical node-and-edge map.

### What counts as mastery?

A chapter is mastered only when an assessment attempt:

- Passes fresh executable code checks.
- Answers every theory question correctly.
- Has no recorded hints or revealed solution.
- Includes a nonempty written explanation.

The explanation is saved for reflection, **not automatically scored**. Passing code checks demonstrates the tested behavior, not complete understanding or protection against hardcoded answers. AI claims never determine progress.

Chapters form a prerequisite tree grouped into tracks (Foundations, Core Python II, Software craft, Data science). A chapter unlocks once **all** of its prerequisites are mastered; the Chapters browser and locked-chapter panel name any missing prerequisites. A manual prerequisite override is available for placement, but does not grant mastery or review credit. Earlier assisted practice does not prevent a later independent assessment pass. Restoring starter code does not erase assistance or submitted attempts.

During assessments, in-app teacher assistance, hints, reference solutions, and AI generation are disabled. Documentation is allowed. Each chapter has one current fixed assessment and three fixed theory questions, reused on retakes.

Saved work on the original score-band, deployment-decision, retry-schedule and prompt-preview activities remains available as a **legacy** version with its original requirements. Revised tasks have separate drafts and assistance history; completing both versions does not award completion XP twice. An assessment-version picker appears when you have saved legacy assessment work. Historical attempts and mastery are preserved, and legacy assessments remain excluded from AI assistance.

A mastered chapter becomes due for review seven days after its latest successful unassisted practice or qualifying assessment attempt.

### Player progress and focus sessions

Player XP recognizes study effort separately from mastery. The player-progress panel shows levels, lifetime milestones, and recent rewards. **XP and levels never unlock chapters or replace assessment requirements.**

| Activity | XP |
| --- | --- |
| First successful completion of a practice exercise | 50 / 100 / 150 per workload unit for Easier / Similar / Harder; hints are allowed |
| First successful practice after revealing its reference | Half that exercise's completion reward |
| First independently passed assessment for a chapter | Three times that task's practice value |
| Marking a lesson read | 25, once per lesson; self-reported |
| Qualifying independent successful retake after at least seven days | 25 |
| Completing a 25-minute focus session | 50 |

Difficulty is relative to the current chapter. Reviewed exercises have authored ratings for the required stages. For generated exercises, requested lesson coverage (or the selected task's workload) sets a minimum. Restricted local Python analyzes the starter/reference syntax trees without executing their contents: changed result bindings count as work units, and each function contributes one unit per two changed assignment/return/raise statements, rounded up. Supplied unchanged statements and formatting do not add work. The larger of this estimate and the coverage minimum determines workload, while the chosen difficulty is preserved. A variation requiring two result calculations can therefore earn more than its one-result source. **Generated workload is capped at the chapter's reviewed assessment workload; projects may earn one more unit.** A project requests one unit per focus section plus one for integration. This keeps a single AI exercise comparable to a hard reviewed exercise, rather than letting broad coverage or a long provider-written reference outweigh whole chapters. Learner code length, time spent, and AI-awarded points never determine XP. The generation dialog shows the reward range; the finished exercise shows its exact reward and whether its rating is estimated.

Pacing: the 12 added debugging/prediction labs provide 1,600 available first-completion XP in addition to the earlier reviewed course. Existing awards and historical progress are unchanged. Early levels arrive within the first chapter; each further level costs 100 + 50 × level XP.

For example, saving a learner name earns 50 XP, cleaning and reporting a label earns 300 XP, and repairing the latency summary earns 450 XP. Revealing the reference halves those rewards.

**Historical recalculation:** the approved v2 update runs once on launch, rating older generated exercises and updating past attempt ratings. If difficulty was never saved, the local estimate uses constants, operations, control-flow nesting and exception handling; it is a heuristic, not a measurement of actual learner effort. Existing totals and levels can change, but attempt IDs, drafts, mastery, assistance history and duplicate-completion protections remain intact. A `progress-before-xp-v2-<UUID>.json` backup is saved beside `progress.json` before replacement. If analysis or saving fails, prior rewards remain unchanged; use **Update XP ratings** in Player progress to retry after resolving the displayed error. Missing exercises retain their last known rewards. No cloud request is needed.

**v3 generated-practice cap:** a second approved one-time update applies the generated-workload cap to saved AI exercises and their attempt snapshots. Saved exercises did not record their requested scope, so they receive the more generous cumulative cap (assessment workload + 1; now the project cap). Missing generated exercises keep their last known reward, also within that cap. Reviewed exercise ratings, attempt IDs and source code, mastery and duplicate protections are unchanged. A `progress-before-xp-v3-<UUID>.json` backup is written first.

Immediate repeated submissions do not repeatedly award completion XP. Levels start at 0 and have no gameplay cap, with increasing XP requirements. Breaks do not cost XP and there are no streak penalties. Celebration effects can be disabled in the player-progress panel; system Reduce Motion is respected.

Focus sessions support pause/resume and saved progress. After reopening the app, resume when ready; paused and closed-app time do not count. Ending early does not award session XP or add to completed-session totals, but preserves previously earned rewards.

## Optional AI teacher

Cloud access is opt-in. To enable it:

1. Open **Settings…**.
2. Under **AI teacher**, choose a **Provider**.
3. Enable **Allow relevant learning content to be sent to** the chosen provider. Switching to a different provider turns this off until you enable it again for that provider.
4. Enter that provider's API key in the secure field. Do not put it in source code, a `.env` file, learner code, or chat. Each provider's key is a separate Keychain item, so switching providers does not delete the others.
5. Enter a model available to your API account that supports **structured outputs**. Switching provider fills in its default; any model identifier can be entered without rebuilding.
6. Set the request limit and choose **Save settings**.

| Provider | API used | Default model | Key from |
|---|---|---|---|
| OpenAI | Responses API (`store: false`) | `gpt-4.1-mini` | platform.openai.com |
| Anthropic | Messages API with `output_config` structured outputs | `claude-sonnet-5-5` | platform.claude.com |
| Google | Gemini OpenAI-compatible Chat Completions | `gemini-3.8-flash` | aistudio.google.com |
| xAI | Chat Completions | `grok-4.7` | console.x.ai |

The same teaching instructions, workspace snapshot, generation prompt and JSON schema are sent to every provider, and every generated exercise goes through the same local validation. Only the wire format differs. The default models for Anthropic, Google and xAI may reason before answering, and those tokens count against the output limit. Those providers therefore receive an extra 8,000 output tokens on top of the app's normal limit.

The teacher is instructed to explain unfamiliar syntax, use small different examples, and ask guiding questions instead of writing complete solutions. Practice includes shortcuts such as **Explain this task simply**, **Help me read the error**, and **Check my reasoning**. Teaching instructions are not a guarantee that every model response will be correct or pedagogically appropriate.

Every question sends a fresh workspace snapshot **after** the older conversation: the complete current editor code, selected lesson/exercise and starter, changes since the previous request, and the latest available run with its exact source code, output, operation and outcome. You do not need to paste code or errors into chat. Edits keep the previous diagnostic available but explicitly label it as belonging to older code; a normal Run is never presented as a passed solution check. Execution evidence clears on navigation, restoring the starter, or restarting the app, and the teacher is told when no result is available. Compact change metadata survives relaunch with the conversation. The snapshot is captured when you ask, not continuously streamed; an outdated reply is discarded if the draft changes while waiting. Workspace snapshots over 256,000 UTF-8 bytes are rejected with an explanation before sending or recording assistance, rather than silently cutting off code. Output retains the runner's existing 64 KiB capture limit.

Open **New with AI…** to configure a challenge before sending a request:

- **Coverage:** selected exercise concepts, every practice section of the current chapter (the default), or a **Project**. Whole-chapter options do not depend on which exercise is selected. Lesson sections have authored roles. **Overview** sections (orientation without new technique) are sent as background but never required. **Troubleshooting** sections (common mistakes and debugging advice) are required only with the *Debug broken code* format. The format never changes the reward.
- **Project:** a small working program built toward a clear objective in 3–5 connected milestones. Pick an app-owned brief (for example a vending machine, library checkout desk, parking garage or shop sales report) or describe your own objective in the scenario field. Briefs appear once you reach their earliest suitable chapter and adapt to later chapters; a vending machine becomes a class in *Classes*, for example. Choose 1–3 **focus** sections from the current chapter: only these, plus a final integration milestone, are required coverage. The prerequisite closure is an allowed **toolkit**, not a checklist. The current chapter and its direct prerequisites are sent as full lessons; earlier toolkit chapters are sent as section titles, so prompts stay bounded as the curriculum grows.
- **Difficulty:** easier, similar, or harder than the current chapter's reviewed exercises—not relative to the selected or most recently generated exercise. Easier adds guidance and simpler reasoning without removing requested content. Broad coverage can still mean more steps.
- **Format:** write code, complete starter code, or debug runnable but logically broken code. Each format works with every coverage and difficulty choice.
- **Optional scenario:** describe a synthetic/public theme, up to 400 characters (for a project with your own objective, this is the objective and is required). It is sent to the selected AI provider as untrusted theme data; never include private data.

The generator receives the current lesson in full. It also receives every prerequisite chapter as a compact toolkit of section titles (projects also get the direct prerequisites' full lessons), any app-authored chapter generation notes (for example, how *Testing with unittest* checks your own tests against buggy implementations), and a Python 3.9 compatibility rule. It also gets all current reviewed practice instructions for difficulty calibration, and bounded task excerpts from the eight most recent exercises in the current chapter to discourage repeats beyond title changes. Fresh generation does not include learner drafts, existing reference solutions, tests, or assessment content. An explicitly confirmed repair sends the rejected AI candidate and its validation evidence as described below. Broad requests may take more tokens and cost more. Your existing draft is preserved.

Before generated practice is added, the app validates its structured format and a nonempty coverage entry for every requested lesson section, runs its reference solution successfully, and confirms its starter does not pass. **Debug broken code** additionally requires a normal nonzero exit with a checks-origin `AssertionError`: the starter must run and produce a result the supplied checks reject, rather than fail on syntax, an undefined name, a learner-owned assertion, or another runtime exception. Reviewed syntax/runtime repair labs are separate and retain their intentional error categories. Generated exercises cannot supply app-owned named plans or starter-error metadata. Grading also requires every assertion site to execute. The generated coverage plan is saved in the Check section for inspection. These checks do not independently prove semantic coverage, novelty, difficulty, unambiguous requirements, complete tests, or use of only taught concepts. If a generated exercise is confusing, switch to a reviewed exercise.

After submitting, watch the status beside **New with AI…**: it distinguishes waiting for the AI provider, receiving streamed exercise text (a character count, not a percentage), and local validation, and offers cancellation. Generation uses streaming with a five-minute network inactivity timeout and a ten-minute overall transfer limit; teacher chat retains its 90-second request timeout. These network budgets do not change the restricted Python runner's eight-second limit. Partial streamed exercises are never added, and raw streamed code/reference solutions are not displayed. A successful exercise is saved immediately, selected in the chapter's exercise picker, and identified in an **Added to Practice** message with an **Open exercise** button. Failed requests, rejected exercises, and save failures explicitly say **No exercise was added**, with a persistent reason and an alert for request/validation/save errors. Switching exercises does not erase this status; dismiss it when finished. There are no automatic paid retries.

### When a generated exercise fails validation

The error now includes the Python failure reason rather than only “reference solution did not pass.” **Validation details…** opens a copyable report with the rejected AI task, reference, starter, checks and bounded execution output; temporary/home-directory roots are anonymized. It contains the rejected exercise's answer, not your current draft or API key. The report is held in memory, not added to learning progress; it is cleared on dismissal, a fresh generation, successful repair, or app restart. Earlier discarded failures cannot be recovered.

**Repair with AI…** asks for confirmation before sending one additional request containing that rejected candidate and its error. It reuses the original coverage/difficulty/format and asks the model to preserve the task while correcting the inconsistency, not remove checks to force a pass. The result must pass the same restricted validation pipeline before it is saved. Repairs count toward the request cap, may incur charges, and are unavailable during assessments or from a different chapter. There are no automatic repair loops.

The generator is explicitly told that the runner executes reference code first, then test code in its namespace, without pytest/unittest discovery. Every assertion site must run. For example, an expected-exception check must assert a flag after `try`/`except`, rather than skip an `assert False` when the expected exception occurs. These instructions reduce runner incompatibilities but do not guarantee that model-written solutions or tests are correct.

### Usage and cost

- The default cap is **20 requests per app launch**, configurable from 1 to 100.
- Attempted API calls count toward the cap, including failed, cancelled, or rejected generations, which may still incur charges.
- Settings displays request counts and provider-reported input/output token usage.
- Counts reset when the app restarts. This is **not a monetary spending limit**; manage billing separately in your provider account.
- Removing the saved key or leaving cloud access disabled does not prevent offline learning.

## Privacy, saved work, and backups

### Local storage

Learning state is stored as versioned JSON at:

```text
~/Library/Application Support/PythonTeacher/progress.json
```

It contains drafts, selected exercises, attempts, generated exercises and their reference solutions, assistance history, quiz answers, reflections, teacher conversations, lesson check-ins, focus-session history and active-session progress, celebration preferences, and interpreter/model settings. Saves are atomic. Conversations persist per exercise across navigation and relaunch; chats discarded by older versions cannot be recovered.

API credentials are stored separately in **macOS Keychain**, not in the progress file or exports. Cloud consent is stored in macOS preferences. Treat progress files and backups as private learning data: they contain your code and conversations, and are not encrypted by the application.

### What goes to the AI provider?

When you use cloud features, relevant lesson/exercise context, current code, recent output, conversation, or generation context is sent to the provider selected in Settings, and only that provider. OpenAI requests use `store: false`, which does **not** override OpenAI's retention policies. Anthropic, Google and xAI requests have no equivalent flag in the APIs used, so their own retention policies apply. Explicitly revealed reference solutions are excluded from teacher conversation context. The teacher has no tools and cannot directly edit learner code, run commands, or award progress.

Use synthetic or public data only. Do not paste confidential work, financial records, credentials, or other sensitive material into learning content. Python subprocesses receive a minimal environment without inherited API credentials.

### Export and restore

- **Export current Python file…** saves the current editor draft as a `.py` file.
- **Export backup…** in Settings, or **Export learning backup…** in the Learning menu, exports learning state as JSON, without the API key.
- **Open data folder** in Settings opens the local storage directory.

There is no in-app backup import or cloud sync. To restore manually, quit the app, preserve a separate copy of the existing `progress.json`, and place a known-good compatible backup at that path before reopening. Restoring replaces the active learning state; keep both copies until you have checked the result. Keychain credentials are not restored from a learning backup.

If saved data is unreadable, malformed, or uses an unsupported schema, the app preserves it instead of silently overwriting it with defaults. Automatic saving is blocked when initial loading fails. Export any work from that session separately before closing, preserve the original file, and recover from a compatible backup.

## Python execution and safety

Each run uses a fresh temporary workspace with a deny-default macOS sandbox. The runner permits required interpreter/system reads and workspace access while restricting network access, child processes, and unrelated file access. Learner and test source files are protected from writes. Files created by a run are temporary and cleaned up afterward; use explicit exports to keep editor code.

| Safeguard | Default behavior |
| --- | --- |
| Time limit | Eight seconds per execution |
| Captured output | Approximately 64 KiB, then truncated |
| Individual file size | At most 8 MiB |
| Open file descriptors | At most 64 |
| Core dumps | Disabled |
| Python flags | `-I -B -S -u`: isolated mode, no bytecode writes, no automatic `site` import, unbuffered output |
| Missing restrictions | Execution stops; no unrestricted fallback |

Use an absolute path to a real Python executable, not a shell wrapper or pyenv shim. The app searches common Homebrew, Xcode, and system locations. Supported framework launchers are resolved to the actual executable without relaxing subprocess restrictions.

This is a safeguard for personal learning, **not a hardened service for hostile code**. There is no aggregate disk or memory quota. `sandbox-exec` is deprecated and may require replacement on future macOS versions. Do not weaken restrictions to work around interpreter compatibility problems.

## Development and testing

### Repository layout

```text
Package.swift                  Swift package products and targets
Sources/PythonTeacherApp/      SwiftUI views, AppKit editor, app state, Keychain
Sources/PythonTeacherCore/     Curriculum, models, persistence, runner, API client
Tests/PythonTeacherAppTests/   App state, native editor, and rendering tests
Tests/PythonTeacherCoreTests/  Curriculum, progress, runner, and provider tests
scripts/                      App packaging, shareable zip, bundle metadata, icon generation
AGENTS.md                     Project conventions and verification guidance
PLAN.md                       Implementation status, evidence, and future work
HISTORY.md                    Summary of development before the repository restart
```

`PythonTeacherCore` is a library product. `PythonTeacher` is the executable product, implemented by the `PythonTeacherApp` target. `AppModel` coordinates the UI with the core services; the core owns curriculum content, progression rules, local persistence, restricted execution, and AI provider request handling (`TeacherProvider`, `TeacherClient`).

### Verification commands

Run the full suite:

```sh
swift test
```

Run focused suites:

```sh
swift test --filter CurriculumTests
swift test --filter ProgressTests
swift test --filter PythonRunnerTests
swift test --filter TeacherClientTests
swift test --filter AppModelTests
```

Choose an interpreter for runner compatibility tests by replacing the example path with an installed binary:

```sh
PYTHON_TEACHER_TEST_PYTHON=/absolute/path/to/python3 swift test --filter PythonRunnerTests
```

The same variable is used by executable curriculum tests. Some tests skip when Python or sandbox creation is unavailable; check skipped-test counts before treating a run as execution verification.

Capture native workspace screenshots to an output directory:

```sh
PYTHON_TEACHER_UI_SNAPSHOTS_DIR="$PWD/.build/ui-snapshots" swift test --filter AppModelTests
```

Rendering tests exercise all learning modes at default and minimum window sizes without Accessibility automation. Tests use temporary learning stores and mocked provider requests; they do not require a live API key or validate live teaching quality. Native input tests are not a substitute for hands-on testing with a physical keyboard and the user's input source.

When changing curriculum content, keep existing chapter/exercise IDs and saved draft interfaces stable. Every lesson code block must run standalone in the restricted runner; reviewed reference solutions must pass and starters must fail their checks. Follow [AGENTS.md](AGENTS.md) and keep [PLAN.md](PLAN.md) current with verification evidence.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Swift build fails because tools or SDK are missing | Check `swift --version` and `xcode-select -p`. Install a compatible Apple toolchain and macOS SDK. |
| Python is rejected or cannot be located | Choose an absolute path to the actual Python 3 binary in Settings, not a shim or script. Use **Verify restricted execution**, then save the setting. |
| Sandbox creation fails | Check that `/usr/bin/sandbox-exec` is available and allowed in the current environment. Try a compatible local interpreter; do not disable restrictions or introduce an unrestricted fallback. |
| A run times out or output is truncated | Look for infinite loops or excessive printing. Runs have time/output limits; narrow the example and retry. |
| `Run` finishes but the exercise is not passed | Use **Check solution** in Practice. Inspect required variable names, return values, types, and edge cases; printed output alone may not satisfy checks. |
| Assessment will not submit or unlock dependent chapters | Answer all theory questions and provide an explanation, then submit. All code checks and theory answers must pass together. |
| Output says it belongs to a previous code version | Run or check the current code again. Assessment submission always executes fresh checks. |
| Teacher access is unavailable | Check the selected provider, cloud consent, that provider's saved key, model access, and the per-launch cap. HTTP 401 indicates a rejected key (Google reports invalid keys as HTTP 400); 403 indicates access restrictions; 429 indicates a provider rate/account usage limit. A model that does not support structured outputs can fail generation while chat still works. |
| Generated exercise is rejected | Format or executable validation failed. Existing exercises remain unchanged; retry a variation or use reviewed practice. |
| Saving is blocked | Preserve the existing progress file and export current-session work separately. Recover a compatible backup with the app closed; do not delete the only copy of saved work. |
| A shared app "can't be opened" or "is damaged" | It is unsigned by Apple. Use **Open Anyway** in Privacy & Security, or run `xattr -dr com.apple.quarantine` on the app (see [Share the app with friends](#share-the-app-with-friends)). |
| A rebuilt app still behaves like the older version | Quit and reopen `dist/Python Teacher.app`. Rebuilds may also trigger macOS Keychain authorization prompts. |

## Scope and limitations

This is a personal foundation-learning app, not a full IDE or a complete programming curriculum. It currently has no terminal, live debugger or execution replay, language server, third-party Python package workflow, multi-file project explorer, cloud sync, or support for other learning languages. Interactive terminal input is not part of the exercise workflow.

The learning-repertoire overhaul is tracked in [PLAN.md](PLAN.md) with a validation gate between delivery slices: debugging foundations; readable checks and scratch experiments; varied offline practice, projects and assessment banks; execution replay; and broader software-craft/data skills. Debugging foundations (Phase 1A) were checkpointed on `feature/debugging-foundations`. Readable checks and safe experiments (Phase 1B) are implemented and automatically validated on the stacked `feature/readable-checks` branch, based on `9e5e9f5`, for later integration into `develop`; hands-on packaged-app acceptance remains pending. Unchecked roadmap items are planned, not shipped. Managed NumPy/pandas/matplotlib support still needs separate approval of the package-environment security change.

Further directions include HTTP APIs, dependency management, Git, multi-file projects, LLM evaluation, and distribution signing/notarization. These are not included implicitly in the debugging work.

See [PLAN.md](PLAN.md) for dated implementation and verification records. Live teaching/generation quality and live API compatibility for every provider, personal Keychain credential setup, and hands-on keyboard-layout behavior remain explicitly unverified by the automated suite.

## How it was built

This app was built with AI coding agents, directed and reviewed by the repository owner. [AGENTS.md](AGENTS.md) holds the standing instructions given to the agents, and [PLAN.md](PLAN.md) is their running work and verification log.
