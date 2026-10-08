import Foundation
import XCTest
@testable import PythonTeacherCore

final class PracticeProfileTests: XCTestCase {
    private let addedIDs: Set<String> = [
        "basics-transfer-delivery-note", "values-transfer-workshop-cost", "decisions-transfer-library-entry",
        "loops-transfer-water-log", "functions-transfer-ticket-total", "functions-refactor-batch-cost",
        "collections-transfer-stock-report", "collections-maintenance-label-counts", "reliability-transfer-gradebook"
    ]

    private var reviewed: [Exercise] { Curriculum.chapters.flatMap(\.exercises) }
    private var original: [Exercise] { reviewed.filter { !addedIDs.contains($0.id) } }

    private func validLinks(_ profile: PracticeProfile, chapterID: String, graph: CurriculumGraph = Curriculum.graph) -> Bool {
        guard profile.isWellFormed, let closure = graph.closureIncludingSelf(of: chapterID) else { return false }
        let taught = Set(closure.flatMap(\.lessonSections).filter { $0.role != .overview }.map { $0.topic.id })
        return Set(profile.skillIDs).isSubset(of: taught)
    }

    func testAll72ReviewedActivitiesHaveWellFormedTaughtProfiles() throws {
        XCTAssertEqual(reviewed.count, 72)
        XCTAssertEqual(original.count, 63)
        XCTAssertEqual(Set(reviewed.map(\.id)).intersection(addedIDs), addedIDs)
        for chapter in Curriculum.chapters {
            for exercise in chapter.exercises {
                let profile = try XCTUnwrap(exercise.practiceProfile, exercise.id)
                XCTAssertTrue(profile.isWellFormed, exercise.id)
                XCTAssertTrue(validLinks(profile, chapterID: chapter.id), exercise.id)
                XCTAssertEqual(Set(profile.skillIDs).count, profile.skillIDs.count, exercise.id)
                XCTAssertTrue(profile.skillIDs.contains { $0.hasPrefix(chapter.id + "-section-") }, exercise.id)
                if !addedIDs.contains(exercise.id) {
                    XCTAssertTrue((1...3).contains(profile.skillIDs.count), exercise.id)
                }
            }
        }
    }

    func testReflectionPromptsAreBoundedDistinctActivityQuestions() throws {
        var baselinePrompts = Set<String>()
        for exercise in reviewed {
            let profile = try XCTUnwrap(exercise.practiceProfile, exercise.id)
            XCTAssertTrue((1...3).contains(profile.reflectionPrompts.count), exercise.id)
            XCTAssertEqual(Set(profile.reflectionPrompts).count, profile.reflectionPrompts.count, exercise.id)
            for prompt in profile.reflectionPrompts {
                XCTAssertFalse(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, exercise.id)
                XCTAssertGreaterThan(prompt.count, 20, exercise.id)
                XCTAssertLessThanOrEqual(prompt.count, 400, exercise.id)
                XCTAssertNotEqual(prompt, "What did you learn?", exercise.id)
                if !addedIDs.contains(exercise.id) {
                    XCTAssertTrue(baselinePrompts.insert(prompt).inserted, "Repeated generic prompt: \(exercise.id)")
                }
            }
        }
        let activityAnchors = [
            "basics-name": "learner_name", "values-budget": "token", "decisions-quota": "quota",
            "loops-filter": "excess_tokens", "functions-batches": "batches_needed", "collections-json": "payload",
            "reliability-summary": "latency", "iteration-leaderboard": "leaderboard", "files-notes": "note",
            "classes-budget": "budget", "inheritance-chat-card": "chat-card", "testing-cost-errors": "cost",
            "generators-countdown": "Countdown", "typing-decorators-scalers": "scaler",
            "ds-cleaning-missing": "score", "ds-statistics-summary": "spread", "ds-aggregation-pivot": "token_pivot"
        ]
        for (id, anchor) in activityAnchors {
            let profile = try XCTUnwrap(reviewed.first { $0.id == id }?.practiceProfile, id)
            XCTAssertTrue(profile.reflectionPrompts.joined(separator: " ").contains(anchor), id)
        }
    }

    func testAuthoredFormsReflectTheExistingWorkAndDemonstrateDiversity() throws {
        let expected: [String: PracticeForm] = [
            "basics-name": .complete, "values-budget": .write, "decisions-route": .write,
            "loops-total": .write, "functions-rate": .write, "classes-results": .complete,
            "inheritance-chat-card": .complete, "testing-latency-bands": .complete,
            "generators-countdown": .complete, "typing-decorators-record": .complete,
            "basics-debug-quote": .debug, "basics-debug-saved-total": .debug,
            "values-debug-clean-label": .debug, "values-predict-token-total": .predict,
            "decisions-debug-priority": .debug, "decisions-debug-entry-boundary": .debug,
            "loops-debug-running-total": .debug, "loops-predict-threshold": .predict,
            "functions-debug-return": .debug, "functions-predict-counterexample": .counterexample,
            "collections-debug-optional-field": .debug, "reliability-debug-later-record": .debug,
            "reliability-summary": .debug
        ]
        for (id, form) in expected {
            XCTAssertEqual(try XCTUnwrap(reviewed.first { $0.id == id }?.practiceProfile, id).form, form, id)
        }
        XCTAssertEqual(Set(original.compactMap { $0.practiceProfile?.form }), [.write, .complete, .predict, .debug, .counterexample])
        XCTAssertEqual(Set(original.compactMap { $0.practiceProfile?.scaffolding }), [.guided, .light])
        for id in addedIDs {
            let profile = try XCTUnwrap(reviewed.first { $0.id == id }?.practiceProfile, id)
            let expectedForm: PracticeForm = id == "functions-refactor-batch-cost" ? .refactor
                : id == "collections-maintenance-label-counts" ? .maintenance : .transfer
            XCTAssertEqual(profile.form, expectedForm, id)
        }
        XCTAssertGreaterThan(Set(reviewed.compactMap { $0.practiceProfile?.scaffolding }).count, 1)
        XCTAssertFalse(reviewed.contains { $0.practiceProfile?.form == .project })
    }

    func testEnumsAndEveryAuthoredProfileRoundTripThroughCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for form in PracticeForm.allCases {
            XCTAssertEqual(try decoder.decode(PracticeForm.self, from: encoder.encode(form)), form)
            XCTAssertFalse(form.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        for scaffolding in PracticeScaffolding.allCases {
            XCTAssertEqual(try decoder.decode(PracticeScaffolding.self, from: encoder.encode(scaffolding)), scaffolding)
            XCTAssertFalse(scaffolding.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        for exercise in reviewed {
            let profile = try XCTUnwrap(exercise.practiceProfile, exercise.id)
            XCTAssertEqual(try decoder.decode(PracticeProfile.self, from: encoder.encode(profile)), profile, exercise.id)
            XCTAssertEqual(try decoder.decode(Exercise.self, from: encoder.encode(exercise)), exercise, exercise.id)
        }
    }

    func testProfileStructuralValidationRejectsMalformedDescriptors() {
        func profile(_ skills: [String] = ["basics-section-2"], _ prompts: [String] = ["How is a saved name different from its text?"]) -> PracticeProfile {
            .init(form: .write, scaffolding: .guided, skillIDs: skills, reflectionPrompts: prompts)
        }
        XCTAssertTrue(profile().isWellFormed)
        XCTAssertTrue(profile((1...8).map { "basics-section-\($0)" }, ["One?", "Two?", String(repeating: "x", count: 400)]).isWellFormed)
        for skills in [[], ["basics-section-2", "basics-section-2"], ["basics-section-0"], ["basics-section--1"], ["basics-section-01"], ["basics"], ["basics-section-2\n"], (1...9).map { "basics-section-\($0)" }] {
            XCTAssertFalse(profile(skills).isWellFormed, "\(skills)")
        }
        for prompts in [[], [" "], ["\n\t"], ["Same?", "Same?"], ["One?", "Two?", "Three?", "Four?"], [String(repeating: "x", count: 401)]] {
            XCTAssertFalse(profile(["basics-section-2"], prompts).isWellFormed, "\(prompts)")
        }
    }

    func testLinkValidationRejectsUntaughtOverviewAndUnrelatedBranchSections() {
        func profile(_ skills: [String]) -> PracticeProfile {
            .init(form: .write, scaffolding: .light, skillIDs: skills, reflectionPrompts: ["Which input would exercise this contract's boundary?"])
        }
        XCTAssertTrue(validLinks(profile(["functions-section-1", "values-section-6"]), chapterID: "functions"))
        XCTAssertTrue(validLinks(profile(["functions-section-5"]), chapterID: "functions"))
        XCTAssertFalse(validLinks(profile(["basics-section-1"]), chapterID: "basics"))
        XCTAssertFalse(validLinks(profile(["functions-section-3"]), chapterID: "functions"))
        XCTAssertFalse(validLinks(profile(["functions-section-99"]), chapterID: "functions"))
        XCTAssertFalse(validLinks(profile(["missing-section-2"]), chapterID: "functions"))
        XCTAssertFalse(validLinks(profile(["values-section-5"]), chapterID: "basics"))
        XCTAssertFalse(validLinks(profile(["files-section-4"]), chapterID: "classes"))
        XCTAssertFalse(validLinks(profile(["testing-section-2"]), chapterID: "generators"))
        XCTAssertFalse(validLinks(profile(["basics-section-2", "basics-section-2"]), chapterID: "basics"))
        XCTAssertFalse(validLinks(profile(["basics-section-2"]), chapterID: "missing"))
        XCTAssertFalse(validLinks(profile(["basics-section-2"]), chapterID: "basics", graph: CurriculumGraph([])))
    }

    func testAssessmentsLegacyAndUnprofiledGeneratedWorkRemainAbsent() throws {
        for chapter in Curriculum.chapters {
            XCTAssertNil(chapter.assessment.practiceProfile, chapter.assessment.id)
            for mode: LearningMode in [.practice, .assessment] {
                for exercise in Curriculum.legacyExercises(chapterID: chapter.id, mode: mode) {
                    XCTAssertNil(exercise.practiceProfile, exercise.id)
                }
            }
        }
        let generated = Exercise(id: "generated-profile-absence", title: "Synthetic task", instructions: "Synthetic contract",
                                 starterCode: "value = 0\n", referenceSolution: "value = 1\n", testCode: "assert value == 1\n", hints: [])
        XCTAssertNil(generated.practiceProfile)
        XCTAssertNil(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(generated)).practiceProfile)
        let current = try XCTUnwrap(reviewed.first)
        var oldJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        oldJSON.removeValue(forKey: "practiceProfile")
        let oldSaved = try JSONDecoder().decode(Exercise.self, from: JSONSerialization.data(withJSONObject: oldJSON))
        XCTAssertEqual(oldSaved.id, current.id)
        XCTAssertNil(oldSaved.practiceProfile, "Decoding old work must not silently backfill the authored catalog")
        XCTAssertNil(Curriculum.exercise("unknown-practice", "", "", "", "", "", []).practiceProfile)
    }

    func testExplicitHelperProfileTakesPrecedenceOverBaselineCatalog() throws {
        let explicit = PracticeProfile(form: .transfer, scaffolding: .independent, skillIDs: ["basics-section-4"],
                                       reflectionPrompts: ["How would a changed delivery name affect your note?"])
        let id = "basics-name"
        let baseline = Curriculum.exercise(id, "", "", "", "", "", [])
        XCTAssertEqual(baseline.practiceProfile?.form, .complete)
        let overridden = Curriculum.exercise(id, "", "", "", "", "", [], practiceProfile: explicit)
        XCTAssertEqual(overridden.practiceProfile, explicit)
        XCTAssertEqual(overridden.effort, baseline.effort)
        for newID in addedIDs {
            XCTAssertNil(Curriculum.exercise(newID, "", "", "", "", "", []).practiceProfile, newID)
            XCTAssertEqual(Curriculum.exercise(newID, "", "", "", "", "", [], practiceProfile: explicit).practiceProfile, explicit, newID)
        }
    }

    func testOriginal63ReviewedEffortRatingsAreUnchanged() throws {
        let expected: [String: ExerciseEffort] = [
            "basics-name": .init(difficulty: .easier), "basics-total": .init(), "basics-message": .init(),
            "basics-debug-quote": .init(difficulty: .easier), "basics-debug-saved-total": .init(difficulty: .easier),
            "values-budget": .init(scopeUnits: 2), "values-label": .init(scopeUnits: 3),
            "values-batches": .init(difficulty: .harder, scopeUnits: 2), "values-debug-clean-label": .init(difficulty: .easier),
            "values-predict-token-total": .init(scopeUnits: 2),
            "decisions-route": .init(), "decisions-quota": .init(scopeUnits: 2), "decisions-bands-v2": .init(scopeUnits: 2),
            "decisions-debug-priority": .init(), "decisions-debug-entry-boundary": .init(difficulty: .easier),
            "loops-total": .init(difficulty: .harder, scopeUnits: 2), "loops-filter": .init(scopeUnits: 2),
            "loops-retries-v2": .init(difficulty: .harder, scopeUnits: 2), "loops-debug-running-total": .init(scopeUnits: 2),
            "loops-predict-threshold": .init(scopeUnits: 2),
            "functions-batches": .init(), "functions-rate": .init(scopeUnits: 2), "functions-preview-v2": .init(scopeUnits: 2),
            "functions-debug-return": .init(), "functions-predict-counterexample": .init(scopeUnits: 2),
            "collections-count": .init(), "collections-json": .init(scopeUnits: 2),
            "collections-rank": .init(difficulty: .harder, scopeUnits: 2), "collections-debug-optional-field": .init(scopeUnits: 2),
            "reliability-score": .init(difficulty: .harder, scopeUnits: 2), "reliability-parse": .init(scopeUnits: 2),
            "reliability-summary": .init(difficulty: .harder, scopeUnits: 3), "reliability-debug-later-record": .init(scopeUnits: 2),
            "iteration-leaderboard": .init(scopeUnits: 2), "iteration-index": .init(scopeUnits: 3),
            "iteration-grid": .init(difficulty: .harder, scopeUnits: 3),
            "files-notes": .init(scopeUnits: 3), "files-csv": .init(scopeUnits: 2), "files-dates": .init(difficulty: .harder, scopeUnits: 3),
            "classes-budget": .init(scopeUnits: 3), "classes-results": .init(scopeUnits: 4), "classes-dataset": .init(scopeUnits: 4),
            "inheritance-chat-card": .init(scopeUnits: 2), "inheritance-token-properties": .init(scopeUnits: 2),
            "inheritance-scorers": .init(difficulty: .harder, scopeUnits: 3),
            "testing-latency-bands": .init(scopeUnits: 2), "testing-cost-errors": .init(scopeUnits: 3),
            "testing-budget-setup": .init(difficulty: .harder, scopeUnits: 3),
            "generators-countdown": .init(scopeUnits: 2), "generators-ids": .init(scopeUnits: 2),
            "generators-stream": .init(difficulty: .harder, scopeUnits: 2),
            "typing-decorators-scalers": .init(scopeUnits: 2), "typing-decorators-flexible": .init(scopeUnits: 3),
            "typing-decorators-record": .init(difficulty: .harder, scopeUnits: 3),
            "ds-cleaning-load": .init(scopeUnits: 2), "ds-cleaning-missing": .init(scopeUnits: 2), "ds-cleaning-dedupe": .init(scopeUnits: 3),
            "ds-statistics-summary": .init(scopeUnits: 3), "ds-statistics-outliers": .init(scopeUnits: 2),
            "ds-statistics-correlation": .init(difficulty: .harder, scopeUnits: 3),
            "ds-aggregation-top-labels": .init(scopeUnits: 2), "ds-aggregation-pivot": .init(scopeUnits: 3),
            "ds-aggregation-join": .init(difficulty: .harder, scopeUnits: 3)
        ]
        XCTAssertEqual(expected.count, 63)
        XCTAssertEqual(Set(original.map(\.id)), Set(expected.keys))
        for exercise in original {
            XCTAssertEqual(exercise.effort, try XCTUnwrap(expected[exercise.id]), exercise.id)
        }
    }

    func testPracticeDescriptorsDoNotSupplyProgressOrIndependentEvidence() throws {
        let chapter = try XCTUnwrap(Curriculum.graph.chapter("functions"))
        var exercise = try XCTUnwrap(chapter.exercises.first { $0.id == "functions-batches" })
        let attempt = Attempt(date: Date(timeIntervalSince1970: 1_700_000_000), chapterID: chapter.id, exerciseID: exercise.id,
                              mode: .practice, code: exercise.referenceSolution, testsPassed: true, hintCount: 2,
                              solutionRevealed: true, reflection: "I checked zero batches.", effort: exercise.effort)
        var state = ProgressState()
        state.attempts = [attempt]
        state.reflections[exercise.id] = attempt.reflection
        state.hintCounts[exercise.id] = 2
        state.revealedSolutions = [exercise.id]
        let events = state.experienceEvents
        let options = PracticeGenerationOptions(scope: .selectedExercise)
        let effort = try ExperienceRules.generatedEffort(options: options, chapter: chapter, selectedExercise: exercise)
        for form in PracticeForm.allCases {
            for scaffolding in PracticeScaffolding.allCases {
                exercise.practiceProfile = .init(form: form, scaffolding: scaffolding, skillIDs: ["functions-section-1"],
                                                 reflectionPrompts: ["Which batch-size boundary did you check?"])
                state.generatedExercises[chapter.id] = [exercise]
                XCTAssertEqual(state.experienceEvents, events)
                XCTAssertEqual(state.completedPracticeCount, 1)
                XCTAssertTrue(state.masteredChapterIDs.isEmpty)
                XCTAssertEqual(state.playerProgress.totalXP, (exercise.effort?.practiceXP ?? 0) / 2)
                XCTAssertEqual(state.attempts[0].hintCount, 2)
                XCTAssertTrue(state.attempts[0].solutionRevealed)
                XCTAssertEqual(state.reflections[exercise.id], attempt.reflection)
                XCTAssertEqual(state.hintCounts[exercise.id], 2)
                XCTAssertEqual(state.revealedSolutions, [exercise.id])
                XCTAssertEqual(try ExperienceRules.generatedEffort(options: options, chapter: chapter, selectedExercise: exercise), effort)
                var withoutEvidence = state
                withoutEvidence.attempts = []
                XCTAssertEqual(withoutEvidence.completedPracticeCount, 0)
                XCTAssertEqual(withoutEvidence.playerProgress.totalXP, 0)
                XCTAssertTrue(withoutEvidence.masteredChapterIDs.isEmpty)
            }
        }
        exercise.practiceProfile = nil
        state.generatedExercises[chapter.id] = [exercise]
        XCTAssertEqual(state.experienceEvents, events)
        XCTAssertEqual(ExperienceRules.policyVersion, 3)
    }
}
