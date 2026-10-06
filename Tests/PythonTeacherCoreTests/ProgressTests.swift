import Foundation
import XCTest
@testable import PythonTeacherCore

final class ProgressTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var store: ProgressStore!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("PythonTeacherProgressTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: false)
        store = ProgressStore(directory: temporaryDirectory.appendingPathComponent("nested/state", isDirectory: true))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectory)
        store = nil
        temporaryDirectory = nil
    }

    private var stateURL: URL {
        store.directory.appendingPathComponent("progress.json")
    }

    private func install(_ data: Data) throws {
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try data.write(to: stateURL)
    }

    private func masteryAttempt(chapter: String = "values", date: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Attempt {
        Attempt(date: date, chapterID: chapter, exerciseID: "\(chapter)-assessment", mode: .assessment,
                code: "answer = 42\n", testsPassed: true, quizCorrect: 3, quizTotal: 3,
                reflection: "I checked equality at the boundary and explained the result.")
    }

    private func practiceAttempt(day: Double = 0, chapter: String = "historic", exercise: String = "exercise", hints: Int = 0, revealed: Bool = false, passed: Bool = true) -> Attempt {
        Attempt(date: Date(timeIntervalSince1970: 1_700_000_000 + day * 86_400), chapterID: chapter,
                exerciseID: exercise, mode: .practice, code: "", testsPassed: passed,
                hintCount: hints, solutionRevealed: revealed)
    }

    func testExperienceCurveEveryBoundaryAndExtremeInputs() {
        XCTAssertEqual([ExperienceRules.practiceXP, ExperienceRules.assessmentXP, ExperienceRules.reviewXP,
                        ExperienceRules.lessonXP, ExperienceRules.focusXP], [100, 300, 25, 25, 50])
        XCTAssertEqual(ExperienceRules.totalXP(forLevel: Int.min), 0)
        XCTAssertEqual(ExperienceRules.totalXP(forLevel: Int.max), Int.max)
        XCTAssertEqual(PlayerProgress(totalXP: Int.min).totalXP, 0)
        for level in Array(0...200) + [1_000, 10_000, 1_000_000, 100_000_000] {
            let threshold = 100 * level + 25 * level * (level - 1)
            XCTAssertEqual(ExperienceRules.totalXP(forLevel: level), threshold)
            let player = PlayerProgress(totalXP: threshold)
            XCTAssertEqual(player.level, level)
            XCTAssertEqual(player.xpIntoLevel, 0)
            XCTAssertFalse(player.rankTitle.isEmpty)
            XCTAssertEqual(player.xpToNextLevel, 100 + 50 * level)
            XCTAssertEqual(player.xpRemaining, player.xpToNextLevel)
            XCTAssertEqual(player.fraction, 0)
            if level > 0 {
                let before = PlayerProgress(totalXP: threshold - 1)
                XCTAssertEqual(before.level, level - 1)
                XCTAssertEqual(before.xpRemaining, 1)
                XCTAssertEqual(before.xpIntoLevel, before.xpToNextLevel - 1)
                XCTAssertEqual(before.fraction, Double(before.xpIntoLevel) / Double(before.xpToNextLevel))
            }
        }
        let maximum = PlayerProgress(totalXP: Int.max)
        XCTAssertEqual(maximum.totalXP, Int.max)
        XCTAssertGreaterThan(maximum.level, 100_000_000)
        XCTAssertLessThan(ExperienceRules.totalXP(forLevel: maximum.level), Int.max)
        XCTAssertEqual(ExperienceRules.totalXP(forLevel: maximum.level + 1), Int.max)
        XCTAssertGreaterThan(maximum.xpRemaining, 0)
        XCTAssertEqual(maximum.xpIntoLevel + maximum.xpRemaining, maximum.xpToNextLevel)
        XCTAssertTrue((0..<1).contains(maximum.fraction))
        XCTAssertEqual(PlayerProgress(totalXP: 257_500).level, 100)
        XCTAssertEqual(PlayerProgress(totalXP: 262_600).level, 101)
        XCTAssertEqual(PlayerProgress(totalXP: 262_599).xpRemaining, 1)
    }

    func testEffortScalesDifficultyAndScopeWithoutOverflow() throws {
        for (difficulty, unitXP): (PracticeDifficulty, Int) in [(.easier, 50), (.similar, 100), (.harder, 150)] {
            for units in [1, 2, 7, 1000] {
                let effort = ExerciseEffort(difficulty: difficulty, scopeUnits: units)
                XCTAssertEqual(effort.practiceXP, unitXP * units)
                XCTAssertEqual(ExperienceRules.completionXP(effort: effort, mode: .practice, solutionRevealed: true), unitXP * units / 2)
                XCTAssertEqual(ExperienceRules.completionXP(effort: effort, mode: .assessment), unitXP * units * 3)
                XCTAssertEqual(ExperienceRules.completionXP(effort: effort, mode: .lesson), 0)
                XCTAssertEqual(try JSONDecoder().decode(ExerciseEffort.self, from: JSONEncoder().encode(effort)), effort)
            }
        }
        XCTAssertEqual(ExerciseEffort(scopeUnits: Int.min).scopeUnits, 1)
        XCTAssertEqual(ExerciseEffort(scopeUnits: Int.max).scopeUnits, 1000)
        for units in [Int.min, -1, 0, 1001, Int.max] {
            let data = try JSONSerialization.data(withJSONObject: ["difficulty": "Harder", "scopeUnits": units])
            XCTAssertThrowsError(try JSONDecoder().decode(ExerciseEffort.self, from: data))
        }
    }

    func testApprovedRecalculationPreservesRewardGatesAndIsIdempotent() throws {
        var state = ProgressState()
        var guided = practiceAttempt(chapter: "values", exercise: "values-label", revealed: true)
        guided.effort = .init()
        state.attempts = [guided, guided,
            practiceAttempt(day: 1, chapter: "values", exercise: "values-label"),
            practiceAttempt(day: 8, chapter: "values", exercise: "values-label"),
            practiceAttempt(chapter: "values", exercise: "values-budget", passed: false),
            practiceAttempt(chapter: "other", exercise: "values-label"), masteryAttempt()]
        let identities = state.attempts.map(\.id)
        let mastered = state.masteredChapterIDs
        state.recalculateExperience()
        XCTAssertEqual(state.rewardPolicyVersion, ExperienceRules.policyVersion)
        XCTAssertEqual(state.experienceEvents.map(\.amount).sorted(), [25, 100, 150, 900])
        XCTAssertEqual(state.attempts.map(\.id), identities)
        XCTAssertEqual(state.masteredChapterIDs, mastered)
        let events = state.experienceEvents
        state.recalculateExperience()
        XCTAssertEqual(state.experienceEvents, events)
        try store.save(state)
        XCTAssertEqual(try store.load().experienceEvents, events)
        XCTAssertEqual(try store.load().rewardPolicyVersion, ExperienceRules.policyVersion)
    }

    func testRecalculationCapsInflatedGeneratedPracticeWithoutDuplicates() throws {
        var state = ProgressState()
        var huge = Curriculum.chapters[0].exercises[0]
        huge.id = "generated-huge"
        huge.effort = ExerciseEffort(difficulty: .harder, scopeUnits: 80, estimated: true)
        var small = huge
        small.id = "generated-small"
        small.effort = ExerciseEffort(difficulty: .harder, scopeUnits: 2, estimated: true)
        state.generatedExercises["ds-aggregation"] = [huge, small]
        func attempt(_ chapter: String, _ exercise: String, _ effort: ExerciseEffort?, day: Double = 0) -> Attempt {
            var value = practiceAttempt(day: day, chapter: chapter, exercise: exercise)
            value.effort = effort
            return value
        }
        state.attempts = [
            attempt("ds-aggregation", "generated-huge", huge.effort), attempt("ds-aggregation", "generated-huge", huge.effort, day: 1),
            attempt("ds-aggregation", "generated-small", small.effort),
            attempt("ds-aggregation", "generated-gone", ExerciseEffort(difficulty: .harder, scopeUnits: 1000, estimated: true)),
            attempt("retired", "generated-lost", ExerciseEffort(scopeUnits: 1000, estimated: true))
        ]
        let identities = state.attempts.map(\.id)
        XCTAssertEqual(state.playerProgress.totalXP, 12_000 + 300 + 150_000 + 100_000)
        XCTAssertEqual(ExperienceRules.historicalGeneratedUnitCap(chapterID: "ds-aggregation"), 5)
        XCTAssertEqual(ExperienceRules.historicalGeneratedUnitCap(chapterID: "retired"), 6)
        state.recalculateExperience()
        XCTAssertEqual(state.generatedExercises["ds-aggregation"]?.map { $0.effort?.scopeUnits }, [5, 2])
        XCTAssertEqual(state.experienceEvents.map(\.amount).sorted(), [300, 600, 750, 750])
        XCTAssertEqual(state.playerProgress.totalXP, 2_400)
        XCTAssertEqual(state.attempts.map(\.id), identities)
        XCTAssertTrue(state.attempts.allSatisfy { $0.effort?.estimated == true })
        let events = state.experienceEvents
        state.recalculateExperience()
        XCTAssertEqual(state.experienceEvents, events)
    }

    func testWeightedEvidencePreservesLegacyAwardsAndSnapshots() throws {
        var state = ProgressState()
        var weighted = practiceAttempt(day: 1, exercise: "weighted", hints: 2)
        weighted.effort = ExerciseEffort(difficulty: .harder, scopeUnits: 3)
        var guided = practiceAttempt(day: 1, exercise: "guided", revealed: true)
        guided.effort = weighted.effort
        var assessment = masteryAttempt()
        assessment.effort = ExerciseEffort(difficulty: .harder, scopeUnits: 4)
        let legacy = practiceAttempt(chapter: "basics", exercise: "basics-name")
        state.attempts = [legacy, weighted, weighted, guided, assessment]
        XCTAssertEqual(state.playerProgress.totalXP, 100 + 450 + 225 + 1800)
        let earned = state.experienceEvents
        state.attempts.reverse()
        XCTAssertEqual(state.experienceEvents, earned)
        var changedExercise = Curriculum.chapters[0].exercises[0]
        changedExercise.id = "weighted"
        changedExercise.effort = ExerciseEffort(difficulty: .easier)
        state.generatedExercises["historic"] = [changedExercise]
        XCTAssertEqual(state.experienceEvents, earned)
        try store.save(state)
        for loaded in [try store.load(), try JSONDecoder().decode(ProgressState.self, from: store.exportData())] {
            XCTAssertEqual(loaded.experienceEvents, earned)
            XCTAssertEqual(loaded.attempts.first { $0.id == weighted.id }?.effort, weighted.effort)
            XCTAssertNil(loaded.attempts.first { $0.id == legacy.id }?.effort)
        }
    }

    func testWeightedRepeatsFailuresAndRecallKeepExistingGates() {
        var state = ProgressState()
        func weighted(_ attempt: Attempt) -> Attempt {
            var value = attempt
            value.effort = ExerciseEffort(difficulty: .harder, scopeUnits: 3)
            return value
        }
        state.attempts = [weighted(practiceAttempt(passed: false)), weighted(practiceAttempt(day: 1)),
                          weighted(practiceAttempt(day: 2)), weighted(practiceAttempt(day: 8)),
                          weighted(practiceAttempt(day: 15, hints: 1)), weighted(practiceAttempt(day: 15, revealed: true)),
                          weighted(practiceAttempt(day: 15, passed: false)), weighted(practiceAttempt(day: 15))]
        XCTAssertEqual(state.experienceEvents.map(\.amount).sorted(), [25, 450])
        XCTAssertTrue(state.masteredChapterIDs.isEmpty)
        var incomplete = masteryAttempt()
        incomplete.effort = ExerciseEffort(difficulty: .harder, scopeUnits: 4)
        incomplete.quizCorrect = 0
        state.attempts.append(incomplete)
        XCTAssertEqual(state.playerProgress.totalXP, 475)
        var legacyState = ProgressState()
        legacyState.attempts = [practiceAttempt(), weighted(practiceAttempt(day: 1)), weighted(practiceAttempt(day: 8))]
        XCTAssertEqual(legacyState.experienceEvents.map(\.amount).sorted(), [25, 100])
    }

    func testMalformedEffortPreservesUnreadableProgress() throws {
        var state = ProgressState()
        state.attempts = [practiceAttempt()]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var attempts = try XCTUnwrap(json["attempts"] as? [[String: Any]])
        attempts[0]["effort"] = ["difficulty": "Harder", "scopeUnits": Int.max]
        json["attempts"] = attempts
        let data = try JSONSerialization.data(withJSONObject: json)
        try install(data)
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(ProgressState()))
        XCTAssertEqual(try Data(contentsOf: stateURL), data)
    }

    func testLegacyExerciseDecodesWithoutEffortAndKeepsFlatReward() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Curriculum.chapters[0].exercises[0])) as? [String: Any])
        json.removeValue(forKey: "effort")
        let exercise = try JSONDecoder().decode(Exercise.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(exercise.effort)
        XCTAssertEqual(ExperienceRules.completionXP(effort: exercise.effort, mode: .practice), 100)
    }

    func testSavedEvidenceContinuesBeyondLevel100WithoutMigration() throws {
        var state = ProgressState()
        state.attempts = (0..<900).map { masteryAttempt(chapter: "historical-\($0)") }
        try store.save(state)
        let loaded = try store.load()
        XCTAssertEqual(loaded.playerProgress.totalXP, 270_000)
        XCTAssertEqual(loaded.playerProgress.level, 102)
        XCTAssertEqual(loaded.playerProgress.xpRemaining, 2_950)
        let exported = try JSONDecoder().decode(ProgressState.self, from: store.exportData())
        XCTAssertEqual(exported.playerProgress, loaded.playerProgress)
        XCTAssertEqual(exported.schemaVersion, 1)
    }

    func testPracticeExperienceCountsHintsAndGuidedWorkWithoutDoubleAwards() {
        var state = ProgressState()
        let hinted = practiceAttempt(hints: 3)
        let guided = practiceAttempt(exercise: "guided", revealed: true)
        state.attempts = [hinted, hinted, guided, guided, practiceAttempt(passed: false),
                          practiceAttempt(day: 1), practiceAttempt(day: 1, exercise: "guided")]
        XCTAssertEqual(state.playerProgress.totalXP, 150)
        XCTAssertEqual(state.completedPracticeCount, 2)
        XCTAssertEqual(state.experienceEvents.filter { $0.title == "Guided practice" }.map(\.amount), [50])
        XCTAssertEqual(Set(state.experienceEvents.map(\.id)).count, 2)
        XCTAssertTrue(state.masteredChapterIDs.isEmpty)
        state.attempts += [practiceAttempt(day: 10, hints: 1), practiceAttempt(day: 10, revealed: true),
                           practiceAttempt(exercise: "generated-new"), practiceAttempt(chapter: "another")]
        XCTAssertEqual(state.playerProgress.totalXP, 350)
        XCTAssertEqual(state.completedPracticeCount, 4)
        XCTAssertFalse(state.isUnlocked("historic", in: Curriculum.chapters))
    }

    func testWeeklyReviewUsesLatestIndependentSuccessAndActivityIdentity() {
        var state = ProgressState()
        state.attempts = [practiceAttempt(), practiceAttempt(day: 6), practiceAttempt(day: 7),
                          practiceAttempt(day: 13.999), practiceAttempt(day: 20.999),
                          practiceAttempt(day: 27.999, hints: 1), practiceAttempt(day: 27.999, revealed: true),
                          practiceAttempt(day: 27.999, passed: false), practiceAttempt(day: 28),
                          practiceAttempt(day: 28, exercise: "generated-new")]
        XCTAssertEqual(state.playerProgress.totalXP, 250)
        XCTAssertEqual(state.experienceEvents.filter { $0.amount == 25 }.count, 2)
        XCTAssertEqual(state.completedPracticeCount, 2)
        let expected = state.experienceEvents
        state.attempts.reverse()
        XCTAssertEqual(state.experienceEvents, expected)
        XCTAssertEqual(expected.map(\.date), expected.map(\.date).sorted(by: >))
    }

    func testAssessmentExperienceRequiresEveryMasteryGateAndWeeklyRecall() {
        let base = masteryAttempt()
        let mutations: [(inout Attempt) -> Void] = [
            { $0.testsPassed = false }, { $0.quizCorrect = 2 }, { $0.quizTotal = 0 },
            { $0.hintCount = 1 }, { $0.solutionRevealed = true }, { $0.reflection = " \n\t " },
            { $0.mode = .lesson }
        ]
        for mutation in mutations {
            var invalid = base
            mutation(&invalid)
            var state = ProgressState()
            state.attempts = [invalid]
            XCTAssertTrue(state.experienceEvents.isEmpty)
        }
        var state = ProgressState()
        state.attempts = [base, base, masteryAttempt(date: base.date.addingTimeInterval(7 * 86_400)),
                          masteryAttempt(date: base.date.addingTimeInterval(8 * 86_400))]
        XCTAssertEqual(state.playerProgress.totalXP, 325)
        XCTAssertEqual(state.completedPracticeCount, 0)
        var otherActivity = masteryAttempt(date: base.date.addingTimeInterval(20 * 86_400))
        otherActivity.exerciseID = "different-assessment"
        state.attempts.append(otherActivity)
        XCTAssertEqual(state.playerProgress.totalXP, 325)
    }

    func testExperienceTiesUseUUIDAndDeduplicateIdenticalAttempts() {
        var earlier = practiceAttempt(revealed: true)
        earlier.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        var later = practiceAttempt()
        later.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var state = ProgressState()
        state.attempts = [later, earlier, later, earlier]
        XCTAssertEqual(state.playerProgress.totalXP, 50)
        let expected = state.experienceEvents
        state.attempts.reverse()
        XCTAssertEqual(state.experienceEvents, expected)
    }

    func testGamificationRoundTripAndExportDeriveHistoryWithoutMutableXP() throws {
        var state = ProgressState()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        state.studySessions = [StudySession(startedAt: start, completedAt: start.addingTimeInterval(1_800))]
        state.activeStudySession = ActiveStudySession(startedAt: start.addingTimeInterval(2_000), elapsed: 120)
        state.lessonCompletions = ["unknown-historical": start]
        state.celebrationEffectsEnabled = false
        state.attempts = [practiceAttempt(), masteryAttempt()]
        XCTAssertEqual(state.completedSessionCount, 1)
        XCTAssertEqual(state.totalFocusMinutes, 25)
        XCTAssertEqual(state.playerProgress.totalXP, 475)
        try store.save(state)
        for loaded in [try store.load(), try JSONDecoder().decode(ProgressState.self, from: store.exportData())] {
            XCTAssertEqual(loaded.studySessions, state.studySessions)
            XCTAssertEqual(loaded.activeStudySession, state.activeStudySession)
            XCTAssertEqual(loaded.lessonCompletions, state.lessonCompletions)
            XCTAssertFalse(loaded.celebrationEffectsEnabled)
            XCTAssertEqual(loaded.experienceEvents, state.experienceEvents)
        }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: store.exportData()) as? [String: Any])
        XCTAssertNil(json["totalXP"])
        let active = try XCTUnwrap(json["activeStudySession"] as? [String: Any])
        XCTAssertEqual(Set(active.keys), ["id", "startedAt", "elapsed"])
    }

    func testLegacyGamificationDefaultsKeepHistoricalExperience() throws {
        var state = ProgressState()
        state.attempts = [practiceAttempt(), masteryAttempt()]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        for key in ["studySessions", "activeStudySession", "lessonCompletions", "celebrationEffectsEnabled"] {
            json.removeValue(forKey: key)
        }
        try install(JSONSerialization.data(withJSONObject: json))
        let loaded = try store.load()
        XCTAssertEqual(loaded.schemaVersion, 1)
        XCTAssertTrue(loaded.studySessions.isEmpty)
        XCTAssertNil(loaded.activeStudySession)
        XCTAssertTrue(loaded.lessonCompletions.isEmpty)
        XCTAssertTrue(loaded.celebrationEffectsEnabled)
        XCTAssertEqual(loaded.playerProgress.totalXP, 400)
        try store.save(loaded)
        XCTAssertEqual(try store.load().playerProgress.totalXP, 400)
    }

    func testMalformedGamificationFieldsAreProtectedFromOverwrite() throws {
        let id = UUID().uuidString
        let session: [String: Any] = ["id": id, "startedAt": 0, "completedAt": 1_500]
        let active: [String: Any] = ["id": id, "startedAt": 0, "elapsed": 10]
        let malformed: [(String, Any)] = [
            ("studySessions", NSNull()), ("studySessions", "bad"), ("studySessions", [[:]]),
            ("studySessions", [["id": id, "startedAt": 2_000, "completedAt": 1_500]]),
            ("studySessions", [session, session]), ("lessonCompletions", NSNull()),
            ("lessonCompletions", []), ("lessonCompletions", ["chapter": "yesterday"]),
            ("celebrationEffectsEnabled", NSNull()), ("celebrationEffectsEnabled", "true"),
            ("activeStudySession", []), ("activeStudySession", ["id": id, "startedAt": 0, "elapsed": -1]),
            ("activeStudySession", ["id": id, "startedAt": 0, "elapsed": 1_501]),
            ("activeStudySession", ["id": id, "startedAt": 0])
        ]
        for (key, value) in malformed {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ProgressState())) as? [String: Any])
            json[key] = value
            let original = try JSONSerialization.data(withJSONObject: json)
            try install(original)
            XCTAssertThrowsError(try store.load(), key)
            XCTAssertThrowsError(try store.save(ProgressState()), key)
            XCTAssertThrowsError(try store.exportData(), key)
            XCTAssertEqual(try Data(contentsOf: stateURL), original)
        }
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ProgressState())) as? [String: Any])
        json["studySessions"] = [session]
        json["activeStudySession"] = active
        XCTAssertThrowsError(try JSONDecoder().decode(ProgressState.self, from: JSONSerialization.data(withJSONObject: json)))
        json["activeStudySession"] = NSNull()
        XCTAssertNil(try JSONDecoder().decode(ProgressState.self, from: JSONSerialization.data(withJSONObject: json)).activeStudySession)
    }

    func testActiveSessionClampsInvalidElapsedAndRejectsNonfinitePersistence() throws {
        for (elapsed, expected) in [(Double.nan, 0.0), (.infinity, 0.0), (-1, 0), (1_501, 1_500), (120, 120)] {
            XCTAssertEqual(ActiveStudySession(elapsed: elapsed).elapsed, expected)
        }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let id = UUID().uuidString
        for elapsed in ["NaN", "Infinity", "-Infinity"] {
            let data = Data("{\"id\":\"\(id)\",\"startedAt\":0,\"elapsed\":\"\(elapsed)\"}".utf8)
            XCTAssertThrowsError(try decoder.decode(ActiveStudySession.self, from: data))
        }
    }

    func testInvalidInMemoryStudyHistoryCannotReplaceSavedState() throws {
        try store.save(ProgressState())
        let original = try Data(contentsOf: stateURL)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let valid = StudySession(startedAt: start, completedAt: start.addingTimeInterval(1_500))
        let mutations: [(inout ProgressState) -> Void] = [
            { $0.studySessions = [valid, valid] },
            { $0.studySessions = [valid]; $0.activeStudySession = ActiveStudySession(id: valid.id, startedAt: start) },
            { $0.studySessions = [StudySession(startedAt: start, completedAt: start.addingTimeInterval(-1))] },
            { $0.studySessions = [StudySession(startedAt: Date(timeIntervalSinceReferenceDate: .nan), completedAt: start)] },
            { $0.studySessions = [StudySession(startedAt: start, completedAt: Date(timeIntervalSinceReferenceDate: .infinity))] },
            { $0.activeStudySession = ActiveStudySession(startedAt: Date(timeIntervalSinceReferenceDate: .infinity)) },
            { $0.lessonCompletions = ["historic": Date(timeIntervalSinceReferenceDate: .nan)] }
        ]
        for mutate in mutations {
            var invalid = ProgressState()
            mutate(&invalid)
            XCTAssertThrowsError(try store.save(invalid))
            XCTAssertEqual(try Data(contentsOf: stateURL), original)
        }
    }

    func testSessionDurationIsFixedDespitePausesAndOnlyCompletedSessionsEarnXP() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = StudySession(startedAt: start, completedAt: start.addingTimeInterval(3_000))
        XCTAssertEqual(StudySession.duration, 1_500)
        var state = ProgressState()
        state.activeStudySession = ActiveStudySession(startedAt: start, elapsed: 1_500)
        XCTAssertEqual(state.playerProgress.totalXP, 0)
        XCTAssertEqual(state.completedSessionCount, 0)
        state.studySessions = [session, session]
        XCTAssertEqual(state.completedSessionCount, 1)
        XCTAssertEqual(state.totalFocusMinutes, 25)
        XCTAssertEqual(state.playerProgress.totalXP, 50)
        var active = ActiveStudySession()
        active.elapsed = .nan
        XCTAssertEqual(active.elapsed, 0)
        active.elapsed = 2_000
        XCTAssertEqual(active.elapsed, 1_500)
        active.elapsed = -5
        XCTAssertEqual(active.elapsed, 0)
    }

    func testNonfiniteSessionAndLessonDatesAreRejectedWhileDecoding() throws {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let id = UUID().uuidString
        for invalid in ["Infinity", "-Infinity", "NaN"] {
            for dateKey in ["startedAt", "completedAt"] {
                var session: [String: Any] = ["id": id, "startedAt": 0, "completedAt": 1_500]
                session[dateKey] = invalid
                XCTAssertThrowsError(try decoder.decode(StudySession.self, from: JSONSerialization.data(withJSONObject: session)))
            }
            let active: [String: Any] = ["id": id, "startedAt": invalid, "elapsed": 0]
            XCTAssertThrowsError(try decoder.decode(ActiveStudySession.self, from: JSONSerialization.data(withJSONObject: active)))
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ProgressState())) as? [String: Any])
            json["lessonCompletions"] = ["historic": invalid]
            XCTAssertThrowsError(try decoder.decode(ProgressState.self, from: JSONSerialization.data(withJSONObject: json)))
        }
    }

    func testDefaultDirectoryIsApplicationSupport() {
        XCTAssertEqual(ProgressStore().directory.standardizedFileURL,
                       FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/PythonTeacher", isDirectory: true).standardizedFileURL)
        XCTAssertEqual(ProgressStore.legacyDirectory.lastPathComponent, "CodingTeacher")
    }

    func testLegacyDirectoryIsMovedWhenCurrentIsMissing() throws {
        let legacy = temporaryDirectory.appendingPathComponent("CodingTeacher", isDirectory: true)
        let current = temporaryDirectory.appendingPathComponent("support/PythonTeacher", isDirectory: true)
        var state = ProgressState()
        state.selectedChapterID = "legacy-chapter"
        try ProgressStore(directory: legacy).save(state)
        let migrated = ProgressStore.migratingLegacyDirectory(from: legacy, to: current)
        XCTAssertEqual(migrated.directory, current)
        XCTAssertEqual(try migrated.load().selectedChapterID, "legacy-chapter")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
    }

    func testLegacyDirectoryNeverReplacesCurrentData() throws {
        let legacy = temporaryDirectory.appendingPathComponent("CodingTeacher", isDirectory: true)
        let current = temporaryDirectory.appendingPathComponent("PythonTeacher", isDirectory: true)
        var old = ProgressState()
        old.selectedChapterID = "legacy-chapter"
        try ProgressStore(directory: legacy).save(old)
        var new = ProgressState()
        new.selectedChapterID = "current-chapter"
        try ProgressStore(directory: current).save(new)
        let migrated = ProgressStore.migratingLegacyDirectory(from: legacy, to: current)
        XCTAssertEqual(try migrated.load().selectedChapterID, "current-chapter")
        XCTAssertEqual(try ProgressStore(directory: legacy).load().selectedChapterID, "legacy-chapter")
    }

    func testLegacyDirectoryIsUsedInPlaceWhenMoveFails() throws {
        let legacy = temporaryDirectory.appendingPathComponent("CodingTeacher", isDirectory: true)
        let blocker = temporaryDirectory.appendingPathComponent("not-a-folder")
        try Data().write(to: blocker)
        try ProgressStore(directory: legacy).save(ProgressState())
        let migrated = ProgressStore.migratingLegacyDirectory(from: legacy, to: blocker.appendingPathComponent("PythonTeacher"))
        XCTAssertEqual(migrated.directory, legacy)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("progress.json").path))
    }

    func testMissingLegacyDirectoryUsesCurrent() {
        let current = temporaryDirectory.appendingPathComponent("PythonTeacher", isDirectory: true)
        let migrated = ProgressStore.migratingLegacyDirectory(from: temporaryDirectory.appendingPathComponent("CodingTeacher"), to: current)
        XCTAssertEqual(migrated.directory, current)
        XCTAssertFalse(FileManager.default.fileExists(atPath: current.path))
    }

    func testMissingStateReturnsDefaultsWithoutCreatingFiles() throws {
        let state = try store.load()
        XCTAssertEqual(state.schemaVersion, 1)
        XCTAssertEqual(state.selectedChapterID, "basics")
        XCTAssertEqual(state.selectedMode, .lesson)
        XCTAssertTrue(state.drafts.isEmpty)
        XCTAssertTrue(state.attempts.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory.path))
        let exported = try JSONDecoder().decode(ProgressState.self, from: store.exportData())
        XCTAssertEqual(exported.selectedChapterID, "basics")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory.path))
    }

    func testRoundTripPreservesEveryStateAndAttemptField() throws {
        var state = ProgressState()
        state.selectedChapterID = "collections"
        state.selectedMode = .assessment
        state.selectedExerciseIDs = ["values": "values-label", "collections": "generated-demo"]
        state.drafts = ["values-label": "name = 'caffè'\n", "collections-assessment": "import json\n"]
        var generated = try XCTUnwrap(Curriculum.chapters.first { $0.id == "collections" }).exercises[0]
        generated.id = "generated-demo"
        generated.title = "Synthetic saved variation"
        state.generatedExercises = ["collections": [generated]]
        state.attempts = [masteryAttempt(), Attempt(
            date: Date(timeIntervalSince1970: 1_700_123_456.125), chapterID: "collections", exerciseID: generated.id,
            mode: .practice, code: "result = {}\n", testsPassed: false, quizCorrect: 1, quizTotal: 3,
            hintCount: 2, solutionRevealed: true, reflection: "Need to preserve duplicate labels.")]
        state.hintCounts = ["generated-demo": 2]
        state.revealedSolutions = ["generated-demo", "values-label"]
        state.unlockedOverrides = ["collections", "reliability"]
        state.quizAnswers = ["collections": ["collections-q1": 0, "collections-q3": 2]]
        state.reflections = ["collections": "Parse text before looking up keys."]
        state.pythonPath = "/opt/homebrew/bin/python3"
        state.model = "test-model"
        state.sessionRequestLimit = 7
        state.teacherConversations = ["values:practice:values-label": [
            TeacherMessage(role: "user", text: "What is a string?"),
            TeacherMessage(role: "assistant", text: "Text enclosed in quotes."),
            TeacherMessage(role: "assistant", text: "Reference solution", includeInContext: false)
        ]]

        try store.save(state)
        let loaded = try ProgressStore(directory: store.directory).load()
        XCTAssertEqual(loaded.schemaVersion, state.schemaVersion)
        XCTAssertEqual(loaded.selectedChapterID, state.selectedChapterID)
        XCTAssertEqual(loaded.selectedMode, state.selectedMode)
        XCTAssertEqual(loaded.selectedExerciseIDs, state.selectedExerciseIDs)
        XCTAssertEqual(loaded.drafts, state.drafts)
        XCTAssertEqual(loaded.generatedExercises, state.generatedExercises)
        XCTAssertEqual(loaded.hintCounts, state.hintCounts)
        XCTAssertEqual(loaded.revealedSolutions, state.revealedSolutions)
        XCTAssertEqual(loaded.unlockedOverrides, state.unlockedOverrides)
        XCTAssertEqual(loaded.quizAnswers, state.quizAnswers)
        XCTAssertEqual(loaded.reflections, state.reflections)
        XCTAssertEqual(loaded.pythonPath, state.pythonPath)
        XCTAssertEqual(loaded.model, state.model)
        XCTAssertEqual(loaded.sessionRequestLimit, state.sessionRequestLimit)
        XCTAssertEqual(loaded.teacherConversations, state.teacherConversations)
        XCTAssertEqual(loaded.attempts.count, state.attempts.count)
        for (actual, expected) in zip(loaded.attempts, state.attempts) {
            XCTAssertEqual(actual.id, expected.id)
            XCTAssertEqual(actual.date, expected.date)
            XCTAssertEqual(actual.chapterID, expected.chapterID)
            XCTAssertEqual(actual.exerciseID, expected.exerciseID)
            XCTAssertEqual(actual.mode, expected.mode)
            XCTAssertEqual(actual.code, expected.code)
            XCTAssertEqual(actual.testsPassed, expected.testsPassed)
            XCTAssertEqual(actual.quizCorrect, expected.quizCorrect)
            XCTAssertEqual(actual.quizTotal, expected.quizTotal)
            XCTAssertEqual(actual.hintCount, expected.hintCount)
            XCTAssertEqual(actual.solutionRevealed, expected.solutionRevealed)
            XCTAssertEqual(actual.reflection, expected.reflection)
        }
        let exported = try JSONDecoder().decode(ProgressState.self, from: store.exportData())
        XCTAssertEqual(exported.drafts, state.drafts)
        XCTAssertEqual(exported.teacherConversations, state.teacherConversations)
        XCTAssertEqual(exported.generatedExercises, state.generatedExercises)
        XCTAssertEqual(exported.attempts.map(\.id), state.attempts.map(\.id))
        XCTAssertEqual(exported.masteredChapterIDs, ["values"])
    }

    func testLegacyProgressWithoutConversationsLoadsAndCanBeSaved() throws {
        var state = ProgressState()
        state.drafts = ["basics:practice:basics-name": "name = 'Mira'\n"]
        state.hintCounts = ["basics:practice:basics-name:builtin": 1]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "teacherConversations")
        try install(JSONSerialization.data(withJSONObject: json))
        let loaded = try store.load()
        XCTAssertTrue(loaded.teacherConversations.isEmpty)
        XCTAssertEqual(loaded.drafts, state.drafts)
        XCTAssertEqual(loaded.hintCounts, state.hintCounts)
        try store.save(loaded)
        XCTAssertEqual(try store.load().drafts, state.drafts)
    }

    func testMalformedConversationsArePreservedRatherThanReset() throws {
        for malformed: Any in [NSNull(), "not a conversation", ["exercise": [["role": "assistant", "text": "Incomplete message"]]]] {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ProgressState())) as? [String: Any])
            json["teacherConversations"] = malformed
            let original = try JSONSerialization.data(withJSONObject: json)
            try install(original)
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try store.save(ProgressState()))
            XCTAssertEqual(try Data(contentsOf: stateURL), original)
        }
    }

    func testSubsequentSaveAtomicallyReplacesValidState() throws {
        try store.save(ProgressState())
        var changed = try store.load()
        changed.drafts["values-budget"] = "total_tokens = 1200\n"
        changed.selectedMode = .practice
        try store.save(changed)
        let loaded = try store.load()
        XCTAssertEqual(loaded.drafts, changed.drafts)
        XCTAssertEqual(loaded.selectedMode, .practice)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.directory.path), ["progress.json"])
    }

    func testMalformedStateThrowsAndIsNeverOverwritten() throws {
        let corrupt = Data("{ not valid JSON: precious unsaved work".utf8)
        try install(corrupt)
        XCTAssertThrowsError(try store.load()) { error in
            guard case ProgressStore.StoreError.malformed = error else {
                return XCTFail("Expected descriptive malformed error, got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("preserved"))
            XCTAssertTrue(error.localizedDescription.contains("progress.json"))
        }
        XCTAssertThrowsError(try store.save(ProgressState()))
        XCTAssertThrowsError(try store.exportData())
        XCTAssertEqual(try Data(contentsOf: stateURL), corrupt)
    }

    func testIncompleteAndWrongTypedStateAreNotTreatedAsDefaults() throws {
        for json in ["{}", "{\"schemaVersion\":1}", "{\"schemaVersion\":\"1\"}", "null", "[]"] {
            let data = Data(json.utf8)
            try install(data)
            XCTAssertThrowsError(try store.load(), json)
            XCTAssertThrowsError(try store.save(ProgressState()), json)
            XCTAssertEqual(try Data(contentsOf: stateURL), data)
        }
    }

    func testUnknownSchemaIsRecognizedBeforeDecodingFieldsAndPreserved() throws {
        for version in [0, 2, 99] {
            let data = Data("{\"schemaVersion\":\(version),\"futureData\":\"preserve me\"}".utf8)
            try install(data)
            XCTAssertThrowsError(try store.load()) { error in
                XCTAssertEqual(error as? ProgressStore.StoreError, .unsupportedSchema(version))
                XCTAssertTrue(error.localizedDescription.contains("not supported"))
            }
            XCTAssertThrowsError(try store.save(ProgressState()))
            XCTAssertThrowsError(try store.exportData())
            XCTAssertEqual(try Data(contentsOf: stateURL), data)
        }
    }

    func testCannotSaveUnsupportedSchemaOrDestroyExistingState() throws {
        try store.save(ProgressState())
        let original = try Data(contentsOf: stateURL)
        var unsupported = ProgressState()
        unsupported.schemaVersion = 2
        XCTAssertThrowsError(try store.save(unsupported)) { error in
            XCTAssertEqual(error as? ProgressStore.StoreError, .unsupportedSchema(2))
        }
        XCTAssertEqual(try Data(contentsOf: stateURL), original)
    }

    func testEncodingFailurePreservesPreviousState() throws {
        try store.save(ProgressState())
        let original = try Data(contentsOf: stateURL)
        var invalid = ProgressState()
        invalid.attempts = [masteryAttempt(date: Date(timeIntervalSince1970: .infinity))]
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertEqual(try Data(contentsOf: stateURL), original)
        XCTAssertTrue(try store.load().attempts.isEmpty)
    }

    func testUnreadableStateIsNotTreatedAsMissing() throws {
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.load()) { error in
            guard case ProgressStore.StoreError.unreadable = error else {
                return XCTFail("Expected unreadable error, got \(error)")
            }
        }
        XCTAssertThrowsError(try store.save(ProgressState()))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: stateURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testMasteryRequiresAllIndependentEvidenceGates() {
        let passing = masteryAttempt()
        XCTAssertTrue(passing.demonstratesMastery)
        let mutations: [(inout Attempt) -> Void] = [
            { $0.mode = .practice },
            { $0.mode = .lesson },
            { $0.testsPassed = false },
            { $0.quizCorrect = 2 },
            { $0.quizCorrect = 0; $0.quizTotal = 0 },
            { $0.quizCorrect = 4 },
            { $0.hintCount = 1 },
            { $0.solutionRevealed = true },
            { $0.reflection = "" },
            { $0.reflection = " \n\t " }
        ]
        for (index, mutate) in mutations.enumerated() {
            var attempt = passing
            mutate(&attempt)
            XCTAssertFalse(attempt.demonstratesMastery, "Mastery gate \(index) was bypassed")
        }
    }

    func testOverridesUnlockButDoNotGrantMasteryOrReviews() {
        var state = ProgressState()
        XCTAssertTrue(state.isUnlocked("basics", in: Curriculum.chapters))
        XCTAssertFalse(state.isUnlocked("values", in: Curriculum.chapters))
        XCTAssertFalse(state.isUnlocked("decisions", in: Curriculum.chapters))
        XCTAssertFalse(state.isUnlocked("unknown", in: Curriculum.chapters))
        state.unlockedOverrides = ["functions", "unknown"]
        XCTAssertTrue(state.isUnlocked("functions", in: Curriculum.chapters))
        XCTAssertFalse(state.isUnlocked("collections", in: Curriculum.chapters))
        XCTAssertFalse(state.isUnlocked("unknown", in: Curriculum.chapters))
        XCTAssertTrue(state.masteredChapterIDs.isEmpty)
        XCTAssertTrue(state.reviewChapterIDs(now: .distantFuture).isEmpty)
        state.attempts = [masteryAttempt()]
        XCTAssertEqual(state.masteredChapterIDs, ["values"])
        XCTAssertTrue(state.isUnlocked("decisions", in: Curriculum.chapters))
        XCTAssertFalse(state.isUnlocked("loops", in: Curriculum.chapters))
    }

    func testBasicsMasteryUnlocksValuesWithoutSkippingAhead() {
        var state = ProgressState()
        state.attempts = [masteryAttempt(chapter: "basics")]
        XCTAssertEqual(state.masteredChapterIDs, ["basics"])
        XCTAssertTrue(state.isUnlocked("values", in: Curriculum.chapters))
        XCTAssertFalse(state.isUnlocked("decisions", in: Curriculum.chapters))
    }

    func testDiamondUnlocksOnlyWhenAllPrerequisitesAreMastered() {
        let chapters = SyntheticCurriculum.diamond
        var state = ProgressState()
        XCTAssertTrue(state.isUnlocked("A", in: chapters), "A chapter without prerequisites is unlocked")
        XCTAssertEqual(["B", "C", "D", "E"].filter { state.isUnlocked($0, in: chapters) }, [])
        XCTAssertEqual(state.missingPrerequisites(for: "D", in: chapters).map(\.id), ["B", "C"])
        XCTAssertEqual(state.missingPrerequisites(for: "A", in: chapters).map(\.id), [])
        state.attempts = [masteryAttempt(chapter: "A")]
        XCTAssertTrue(state.isUnlocked("B", in: chapters))
        XCTAssertTrue(state.isUnlocked("C", in: chapters))
        XCTAssertFalse(state.isUnlocked("D", in: chapters))
        state.attempts.append(masteryAttempt(chapter: "B"))
        XCTAssertFalse(state.isUnlocked("D", in: chapters), "One of two prerequisites is not enough")
        XCTAssertEqual(state.missingPrerequisites(for: "D", in: chapters).map(\.id), ["C"])
        state.attempts.append(masteryAttempt(chapter: "C"))
        XCTAssertTrue(state.isUnlocked("D", in: chapters))
        XCTAssertEqual(state.missingPrerequisites(for: "D", in: chapters).map(\.id), [])
        XCTAssertFalse(state.isUnlocked("E", in: chapters), "Unlocking is not transitive skipping")

        var partial = ProgressState()
        partial.attempts = [masteryAttempt(chapter: "C")]
        XCTAssertFalse(partial.isUnlocked("D", in: chapters))
        partial.unlockedOverrides = ["D"]
        XCTAssertTrue(partial.isUnlocked("D", in: chapters), "Placement override unlocks")
        XCTAssertFalse(partial.masteredChapterIDs.contains("D"))
        XCTAssertFalse(partial.isUnlocked("E", in: chapters), "An override is not mastery")

        var selfMastered = ProgressState()
        selfMastered.attempts = [masteryAttempt(chapter: "D")]
        XCTAssertTrue(selfMastered.isUnlocked("D", in: chapters), "A mastered chapter stays unlocked")
        XCTAssertTrue(selfMastered.isUnlocked("E", in: chapters))
        XCTAssertFalse(selfMastered.isUnlocked("B", in: chapters))
    }

    func testUnknownChaptersAndPrerequisitesFailClosed() {
        let chapters = SyntheticCurriculum.diamond + [SyntheticCurriculum.chapter("X", ["A", "ghost"]), SyntheticCurriculum.chapter("S", ["S"])]
        var state = ProgressState()
        state.attempts = [masteryAttempt(chapter: "A"), masteryAttempt(chapter: "ghost")]
        XCTAssertFalse(state.isUnlocked("X", in: chapters), "A mastered ID outside the supplied chapters does not satisfy a prerequisite")
        XCTAssertEqual(state.missingPrerequisites(for: "X", in: chapters).map(\.id), [])
        XCTAssertEqual(state.unknownPrerequisiteIDs(for: "X", in: chapters), ["ghost"])
        XCTAssertFalse(state.isUnlocked("S", in: chapters), "Self-reference cannot unlock itself")
        XCTAssertEqual(state.unknownPrerequisiteIDs(for: "S", in: chapters), ["S"])
        XCTAssertFalse(state.isUnlocked("ghost", in: chapters))
        XCTAssertFalse(state.isUnlocked("B", in: []))
        state.unlockedOverrides = ["X", "ghost"]
        XCTAssertTrue(state.isUnlocked("X", in: chapters))
        XCTAssertFalse(state.isUnlocked("ghost", in: chapters))
        XCTAssertEqual(state.missingPrerequisites(for: "ghost", in: chapters).map(\.id), [])
    }

    func testSavedLinearFoundationProgressKeepsItsUnlockStateWithoutMigration() throws {
        let foundations = ["basics", "values", "decisions", "loops", "functions", "collections", "reliability"]
        for mastered in 0..<foundations.count {
            var state = ProgressState()
            state.attempts = foundations.prefix(mastered).map { masteryAttempt(chapter: $0) }
            for (index, id) in foundations.enumerated() {
                XCTAssertEqual(state.isUnlocked(id, in: Curriculum.chapters), index <= mastered, "\(mastered) mastered, \(id)")
            }
        }
        var legacy = ProgressState()
        legacy.attempts = [masteryAttempt(chapter: "basics"), masteryAttempt(chapter: "values")]
        legacy.unlockedOverrides = ["collections"]
        try store.save(legacy)
        let loaded = try store.load()
        XCTAssertEqual(loaded.schemaVersion, 1)
        XCTAssertEqual(foundations.filter { loaded.isUnlocked($0, in: Curriculum.chapters) }, ["basics", "values", "decisions", "collections"])
        XCTAssertEqual(loaded.missingPrerequisites(for: "loops", in: Curriculum.chapters).map(\.id), ["decisions"])
        XCTAssertEqual(loaded.missingPrerequisites(for: "reliability", in: Curriculum.chapters).map(\.id), ["collections"])
    }

    func testAssistedPracticeDoesNotPreventLaterIndependentMastery() {
        var state = ProgressState()
        var assisted = masteryAttempt()
        assisted.mode = .practice
        assisted.hintCount = 3
        assisted.solutionRevealed = true
        state.attempts = [assisted]
        XCTAssertTrue(state.masteredChapterIDs.isEmpty)
        state.attempts.append(masteryAttempt())
        XCTAssertEqual(state.masteredChapterIDs, ["values"])
    }

    func testReviewBecomesDueAtExactlySevenDays() {
        let completed = Date(timeIntervalSince1970: 1_700_000_000)
        let week: TimeInterval = 7 * 24 * 60 * 60
        var state = ProgressState()
        state.attempts = [masteryAttempt(date: completed)]
        XCTAssertTrue(state.reviewChapterIDs(now: completed.addingTimeInterval(week - 1)).isEmpty)
        XCTAssertEqual(state.reviewChapterIDs(now: completed.addingTimeInterval(week)), ["values"])
        XCTAssertEqual(state.reviewChapterIDs(now: completed.addingTimeInterval(week + 1)), ["values"])
    }

    func testOnlySuccessfulUnassistedAttemptsPostponeReview() {
        let completed = Date(timeIntervalSince1970: 1_700_000_000)
        let week: TimeInterval = 7 * 24 * 60 * 60
        let recent = completed.addingTimeInterval(week - 60)
        var state = ProgressState()
        state.attempts = [masteryAttempt(date: completed)]
        var hinted = masteryAttempt(date: recent)
        hinted.mode = .practice
        hinted.hintCount = 1
        var revealed = hinted
        revealed.hintCount = 0
        revealed.solutionRevealed = true
        var failed = hinted
        failed.hintCount = 0
        failed.testsPassed = false
        var failedTheory = masteryAttempt(date: recent)
        failedTheory.quizCorrect = 0
        state.attempts += [hinted, revealed, failed, failedTheory]
        XCTAssertEqual(state.reviewChapterIDs(now: completed.addingTimeInterval(week)), ["values"])
        var independentReview = masteryAttempt(date: recent)
        independentReview.mode = .practice
        independentReview.quizCorrect = 0
        independentReview.quizTotal = 0
        state.attempts.append(independentReview)
        XCTAssertTrue(state.reviewChapterIDs(now: completed.addingTimeInterval(week)).isEmpty)
        XCTAssertEqual(state.reviewChapterIDs(now: recent.addingTimeInterval(week)), ["values"])
        XCTAssertEqual(state.masteredChapterIDs, ["values"])
    }
}
