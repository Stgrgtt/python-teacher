# Development history

This repository was restarted from a single snapshot commit on 2026-10-06. This file summarizes the work recorded in the earlier history (2026-09-22 to 2026-10-06), in chronological order. Until the final rename, the app was called **Coding Teacher**.

## 2026-09-22 — Initial app

- **Preserve the working native Python learning app.** First snapshot of the SwiftUI/AppKit macOS app: Swift package with app and core targets, curriculum, code editor, app model, restricted Python runner, local persistence, OpenAI teacher client, project guidance (`AGENTS.md`) and implementation plan (`PLAN.md`).
- **Added README.** Full user and developer documentation.
- **Reward learning effort and preserve focus-session progress.** Player XP derived from saved learning evidence (never a mutable counter), uncapped levels, accessible celebration effects, and saved focus sessions, all kept separate from chapter mastery. Multiline teacher chat input. Tests cover progression, persistence, rewards and keyboard behavior.

## 2026-09-30 — AI practice and teacher context

- **Align AI practice, rewards, and teacher guidance with learner work.** Configurable streamed practice generation with validation evidence and an explicit repair step; workload-based XP with a backed-up one-time historical recalculation; native in-editor search; fresh request-time workspace snapshots for the teacher. Verified with `swift build` and `git diff --check`; 165 of 172 tests passed, with seven known editor-layout failures documented.

## 2026-10-05 — Curriculum tree

Curriculum work happened on parallel branches that were merged into a `curriculum-tree` integration branch, resolving conflicts in the curriculum registry.

- **Chapter graph scaffolding and curriculum tree plan.** Chapters gained a track and explicit prerequisites so new branches could be written in separate files and unlocked by their full prerequisite set.
- **Reorder foundation teaching so each chapter requires only taught concepts.** Decisions, loops, functions and collections were restructured so no chapter relies on syntax introduced later (lists before `for`, new `while`/`break`/`continue` sections, default and keyword arguments, tuples, sets, lambdas). Exercise IDs and order were unchanged; a new test guards the teaching order.
- **Unlock and scope chapters by prerequisite graph instead of linear order.** New `CurriculumGraph` validates a single `basics` root, known IDs, no cycles and topological order, and computes transitive prerequisite closures. Chapters unlock only when all prerequisites are mastered, failing closed for unknown or misordered prerequisites. Practice generation, prompts and teacher snapshots are scoped to the prerequisite closure; the chapter browser groups chapters by track and explains missing prerequisites.
- **Core Python II chapters:**
  - *Classes*: objects, `__init__`, `self`, methods, `__repr__`/`__eq__`, class vs instance attributes, aliasing, `@dataclass`, custom exceptions.
  - *Iteration*: `enumerate`, `zip`, unpacking, comprehensions, `any`/`all`, key-based `min`/`max`, nested lists.
  - *Files*: imports, `pathlib`, `with open`, modes and encodings, `csv`, `FileNotFoundError`, `datetime`, the `__main__` guard.
- **Data-science chapters (standard library only):**
  - *Cleaning*: tables as lists of dicts, CSV parsing, type conversion, missing markers, normalization, de-duplication, cleaning reports.
  - *Statistics*: summaries, sample vs population spread, quantiles/IQR outliers, z-scores, hand-computed Pearson correlation, seeded train/test splits, verified identical on Python 3.9, 3.12 and 3.14.
  - *Aggregation*: `Counter`, `defaultdict`, tuple keys, joins with unmatched rows, zero-filled pivots, tie-safe top-n, dataclass records and formatted reports.
- **Software-craft chapters:**
  - *Generators*: iterators, `yield`, generator expressions, laziness, bounded `itertools`.
  - *Typing and decorators*: Python 3.9-safe type hints, closures, `*args`/`**kwargs`, decorators, `functools.wraps`, `lru_cache`.
  - *Inheritance*: subclassing, abstract classes, properties, composition.
  - *Testing*: `unittest`, where the learner's tests must catch deliberately buggy implementations.
- **Adapt integration tests to the branching chapter tree.**
- **Review fixes.** Lessons now explain syntax that later chapters already used (multi-value `print`, negative indexing and slicing, dictionary iteration, `Path` attributes vs methods, `import datetime as dt`). The testing chapter now lists files as a prerequisite and explains `io.StringIO`. Testing exercises give a clear error if the supplied function is renamed. Statistics explains `abs()` and scientific notation.
- **Preserve saved work when foundation exercise contracts change.** Original activities are kept as legacy versions for existing drafts and history. Revised tasks get versioned IDs and share completion identity through explicit aliases, and assessments stay hidden from AI. Merged to `main` as PR #1 ("Major update to learning repertoire").
- **Cap AI-generated practice XP at the chapter assessment workload.** Stops a single broad generated exercise from outweighing the reviewed curriculum. Saved generated rewards were recalculated once under reward policy v3, after backing up progress. PR #2.
- **Replace cumulative AI practice with objective-driven projects.** A project pairs a catalog or learner-written objective with 1–3 focus sections from the current chapter plus a final integration milestone, and uses the prerequisite closure as its allowed toolkit. Only the current chapter and its direct prerequisites are sent as full lessons. The former cumulative cap became the project cap.
- **Adjust whole-chapter AI practice to the expanded curriculum.** Section roles mark overview headings as context only and troubleshooting headings as required only for the Debug format. Every generation scope sends prerequisite section titles, a Python 3.9 rule, and app-authored chapter generation notes. Whole-chapter requests got the same 12,000-token budget as projects. PRs #3 and #4.
- **Add a shareable universal app zip and simplify build instructions.** `scripts/share-app.sh` builds a universal (arm64 + x86_64) ad-hoc-signed app plus opening instructions for recipients without a Developer ID build. Branch naming conventions were documented. PRs #5 and #6.

## 2026-10-06 — Disclosure and rename

- **Disclose that the app was built with AI coding agents.** README section explaining how the code was produced and where the project instructions and work log live.
- **Point clone instructions at the renamed `python-teacher` repository.**
- **Rename the app from Coding Teacher to Python Teacher.** The package, targets, modules, bundle ID, artifacts and test variables use the new name. On launch, saved progress, the stored API key and cloud consent are migrated from the old identifiers without overwriting current data.
- **Repository restart.** History was condensed into this file, and the project continues from a single snapshot commit.
