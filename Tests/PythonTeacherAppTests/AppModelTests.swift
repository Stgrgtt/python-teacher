import AppKit
import Carbon
import PythonTeacherCore
import SwiftUI
import XCTest
@testable import PythonTeacherApp

private final class GenerationURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, payload) = try Self.handler!(request)
            let streaming = request.value(forHTTPHeaderField: "Accept") == "text/event-stream"
            var data = payload
            if streaming, let value = try? JSONSerialization.jsonObject(with: payload) as? [String: Any], value["status"] != nil {
                let event: [String: Any] = ["type": "response.completed", "response": value]
                data = Data("data: {\"type\":\"response.output_text.delta\",\"delta\":\"{\"}\n\ndata: ".utf8) + (try JSONSerialization.data(withJSONObject: event)) + Data("\n\n".utf8)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": streaming ? "text/event-stream" : "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class AppModelTests: XCTestCase {
    private var directory: URL!
    private var model: AppModel!

    @MainActor
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("PythonTeacherAppTests-\(UUID().uuidString)")
        model = AppModel(store: ProgressStore(directory: directory))
    }

    @MainActor
    override func tearDown() async throws {
        model.cancelWork()
        model.flushSave()
        model = nil
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    @MainActor
    func testLegacyCloudConsentIsCopiedOnlyWhenUnset() throws {
        let id = UUID().uuidString
        let currentDomain = "PythonTeacherTests-current-\(id)", legacyDomain = "PythonTeacherTests-legacy-\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: currentDomain))
        defer {
            defaults.removePersistentDomain(forName: currentDomain)
            defaults.removePersistentDomain(forName: legacyDomain)
        }
        AppModel.migrateLegacyDefaults(defaults, legacyDomains: [legacyDomain])
        XCTAssertNil(defaults.object(forKey: "cloudConsent"))
        defaults.setPersistentDomain(["cloudConsent": true], forName: legacyDomain)
        AppModel.migrateLegacyDefaults(defaults, legacyDomains: ["missing-\(id)", legacyDomain])
        XCTAssertTrue(defaults.bool(forKey: "cloudConsent"))
        defaults.set(false, forKey: "cloudConsent")
        AppModel.migrateLegacyDefaults(defaults, legacyDomains: [legacyDomain])
        XCTAssertFalse(defaults.bool(forKey: "cloudConsent"))
    }

    func testLegacyKeychainItemMovesOnlyWhenCurrentIsMissing() throws {
        let id = UUID().uuidString
        let keychain = KeychainStore(service: "local.pythonteacher.tests.current.\(id)", legacyService: "local.pythonteacher.tests.legacy.\(id)")
        let legacy = KeychainStore(service: keychain.legacyService)
        defer {
            try? keychain.remove()
            try? legacy.remove()
        }
        do { try legacy.save("synthetic-legacy-value") } catch { throw XCTSkip("Keychain unavailable: \(error.localizedDescription)") }
        try keychain.migrateLegacyItem()
        XCTAssertEqual(try keychain.load(), "synthetic-legacy-value")
        XCTAssertNil(try legacy.load())
        try legacy.save("synthetic-stale-value")
        try keychain.migrateLegacyItem()
        XCTAssertEqual(try keychain.load(), "synthetic-legacy-value")
        XCTAssertEqual(try legacy.load(), "synthetic-stale-value")
    }

    func testEachProviderHasItsOwnKeychainItemAndOpenAIKeepsItsService() {
        XCTAssertEqual(KeychainStore.provider(.openAI).service, KeychainStore().service)
        let services = TeacherProvider.allCases.map { KeychainStore.provider($0).service }
        XCTAssertEqual(Set(services).count, TeacherProvider.allCases.count)
        XCTAssertTrue(services.allSatisfy { $0.hasPrefix("local.pythonteacher.") })
    }

    @MainActor
    func testLegacyFoundationDraftsRelaunchWithOriginalRequirementsAndEvidence() async throws {
        let fixtures: [(String, String, LearningMode, String)] = [
            ("decisions", "decisions-bands", .practice, "scores = [-0.1, 0.0, 0.59, 0.6, 1.0, 1.1]\nlabels = []\nfor score in scores:\n    if score < 0 or score > 1:\n        labels.append('invalid')\n    elif score >= 0.6:\n        labels.append('pass')\n    else:\n        labels.append('retry')\n"),
            ("decisions", "decisions-assessment", .assessment, "cases = [(True, 0.99), (False, 0.9), (False, 0.899), (False, 0.0)]\nactions = []\nfor has_sensitive_data, quality in cases:\n    if has_sensitive_data:\n        actions.append('hold')\n    elif quality >= 0.9:\n        actions.append('release')\n    else:\n        actions.append('revise')\n"),
            ("loops", "loops-retries", .practice, "retry_count = 4\nbase_seconds = 2\ndelays = []\ntotal_wait = 0\nfor retry_number in range(retry_count):\n    delay = base_seconds * (2 ** retry_number)\n    delays.append(delay)\n    total_wait += delay\n"),
            ("functions", "functions-preview", .practice, "def preview(text, max_chars):\n    if len(text) <= max_chars:\n        return text\n    return text[:max_chars] + '...'\n")
        ]
        for (chapterID, exerciseID, mode, source) in fixtures {
            var saved = ProgressState()
            saved.rewardPolicyVersion = ExperienceRules.policyVersion
            saved.pythonPath = model.progress.pythonPath
            saved.selectedChapterID = chapterID
            saved.selectedMode = mode
            saved.selectedExerciseIDs[chapterID] = exerciseID
            saved.unlockedOverrides.insert(chapterID)
            let key = "\(chapterID):\(mode == .assessment ? "assessment" : "practice"):\(exerciseID)"
            saved.drafts[key] = source
            saved.reflections[key] = "My original reasoning"
            saved.hintCounts[key] = mode == .practice ? 2 : 0
            if mode == .practice { saved.revealedSolutions.insert(key) }
            saved.teacherConversations[key] = [TeacherMessage(role: "assistant", text: "Original conversation")]
            saved.attempts = [Attempt(chapterID: chapterID, exerciseID: exerciseID, mode: mode, code: source,
                testsPassed: true, quizCorrect: 3, quizTotal: 3, reflection: "Original evidence", effort: .init(scopeUnits: 2))]
            try model.store.save(saved)
            let restored = AppModel(store: model.store)
            XCTAssertEqual(restored.exercise.id, exerciseID)
            XCTAssertEqual(restored.code, source)
            XCTAssertEqual(restored.reflection, saved.reflections[key])
            XCTAssertEqual(restored.hintCount, saved.hintCounts[key])
            XCTAssertEqual(restored.solutionRevealed, mode == .practice)
            XCTAssertEqual(restored.progress.playerProgress, saved.playerProgress)
            XCTAssertEqual(restored.progress.masteredChapterIDs, saved.masteredChapterIDs)
            XCTAssertEqual(restored.progress.attempts.map(\.id), saved.attempts.map(\.id))
            let result = try await PythonRunner().run(code: restored.code, tests: restored.exercise.testCode, pythonPath: saved.pythonPath)
            XCTAssertTrue(result.passed, "\(exerciseID): \(result.output)")
            if mode == .assessment {
                restored.showHint()
                restored.revealSolution()
                restored.askTeacher("Explain this assessment")
                restored.generatePractice()
                XCTAssertTrue(restored.messages.isEmpty)
                XCTAssertEqual(restored.requestCount, 0)
            } else {
                XCTAssertEqual(restored.messages, saved.teacherConversations[key])
                restored.selectExercise(exerciseID + "-v2")
                XCTAssertEqual(restored.exercise.id, exerciseID + "-v2")
                XCTAssertEqual(restored.code, restored.exercise.starterCode)
                XCTAssertEqual(restored.hintCount, 0)
                XCTAssertFalse(restored.solutionRevealed)
                XCTAssertTrue(restored.messages.isEmpty)
                XCTAssertTrue(restored.exerciseRewardSummary.contains("Completion XP earned"))
                restored.code = "Separate revised draft"
                restored.selectExercise(exerciseID)
                XCTAssertEqual(restored.code, source)
                XCTAssertEqual(restored.hintCount, 2)
                XCTAssertTrue(restored.solutionRevealed)
                XCTAssertEqual(restored.messages, saved.teacherConversations[key])
            }
            restored.flushSave()
            let reloaded = AppModel(store: model.store)
            XCTAssertEqual(reloaded.code, source)
            XCTAssertEqual(reloaded.exercise.id, exerciseID)
            XCTAssertEqual(reloaded.progress.teacherConversations[key], saved.teacherConversations[key])
            reloaded.flushSave()
        }
    }

    @MainActor
    func testLegacySelectorsSeparateDraftsAndRecoverHistoryWithoutExposingAssessments() throws {
        model.selectChapter("decisions")
        model.overrideUnlock()
        XCTAssertFalse(model.exercises.contains { $0.id == "decisions-bands" })
        XCTAssertEqual(model.assessments.map(\.id), ["decisions-assessment-v2"])
        let legacy = try XCTUnwrap(Curriculum.legacyExercises(chapterID: "decisions", mode: .assessment).first)
        model.progress.attempts.append(Attempt(chapterID: "decisions", exerciseID: legacy.id, mode: .assessment,
            code: legacy.referenceSolution, testsPassed: true, quizCorrect: 3, quizTotal: 3, reflection: "Saved explanation", effort: legacy.effort))
        let originalXP = model.progress.playerProgress.totalXP
        let originalID = model.progress.attempts[0].id
        model.selectMode(.assessment)
        XCTAssertEqual(model.exercise.id, legacy.id)
        XCTAssertEqual(model.code, legacy.referenceSolution, "history without a draft is recoverable")
        XCTAssertEqual(model.reflection, "Saved explanation")
        model.selectAssessment("decisions-assessment-v2")
        XCTAssertEqual(model.code, model.chapter.assessment.starterCode)
        XCTAssertTrue(model.exerciseRewardSummary.contains("Completion XP earned"))
        model.code = "revised draft"
        model.flushSave()
        let restored = AppModel(store: model.store)
        XCTAssertEqual(restored.exercise.id, "decisions-assessment-v2")
        XCTAssertEqual(restored.code, "revised draft")
        restored.selectAssessment(legacy.id)
        XCTAssertEqual(restored.code, legacy.referenceSolution)
        restored.selectExercise(legacy.id)
        XCTAssertEqual(restored.mode, .assessment, "legacy assessment cannot be selected as practice")
        XCTAssertFalse(restored.exercises.contains { $0.id == legacy.id })
        XCTAssertEqual(restored.progress.playerProgress.totalXP, originalXP)
        XCTAssertEqual(restored.progress.attempts[0].id, originalID)
        XCTAssertEqual(restored.progress.attempts[0].code, legacy.referenceSolution)
        XCTAssertEqual(restored.progress.masteredChapterIDs, ["decisions"])
        restored.flushSave()
    }

    @MainActor
    func testFocusSessionPausesResumesAndCompletesExactlyOnce() throws {
        var uptime: TimeInterval = 100
        let now = Date()
        let timerModel = AppModel(store: ProgressStore(directory: directory), focusNow: { now.addingTimeInterval(uptime - 100) }, focusClock: { uptime })
        timerModel.startFocusSession()
        let id = try XCTUnwrap(timerModel.progress.activeStudySession?.id)
        timerModel.startFocusSession()
        XCTAssertEqual(timerModel.progress.activeStudySession?.id, id)
        uptime += 600
        timerModel.updateFocusSession()
        XCTAssertEqual(timerModel.focusRemainingSeconds, 900)
        timerModel.pauseFocusSession()
        uptime += 3600
        timerModel.updateFocusSession()
        XCTAssertEqual(timerModel.focusRemainingSeconds, 900)
        timerModel.resumeFocusSession()
        uptime += 899
        timerModel.updateFocusSession()
        XCTAssertTrue(timerModel.progress.studySessions.isEmpty)
        uptime += 1
        timerModel.updateFocusSession()
        XCTAssertEqual(timerModel.progress.completedSessionCount, 1)
        XCTAssertEqual(timerModel.progress.totalFocusMinutes, 25)
        XCTAssertEqual(timerModel.progress.playerProgress.totalXP, 50)
        XCTAssertEqual(timerModel.rewardCelebration?.amount, 50)
        XCTAssertNil(timerModel.progress.activeStudySession)
        XCTAssertFalse(timerModel.focusRunning)
        timerModel.updateFocusSession()
        timerModel.endFocusSession()
        XCTAssertEqual(timerModel.progress.completedSessionCount, 1)
        XCTAssertEqual(try timerModel.store.load().studySessions.map(\.id), [id])
    }

    @MainActor
    func testFocusRelaunchRestoresPausedWithoutCreditingOfflineTime() throws {
        var uptime: TimeInterval = 0
        let timerModel = AppModel(store: ProgressStore(directory: directory), focusClock: { uptime })
        timerModel.startFocusSession()
        uptime = 400
        timerModel.updateFocusSession()
        timerModel.pauseFocusSession()
        let reloaded = AppModel(store: timerModel.store, focusClock: { uptime })
        XCTAssertFalse(reloaded.focusRunning)
        XCTAssertEqual(reloaded.focusRemainingSeconds, 1100)
        uptime += 100_000
        reloaded.updateFocusSession()
        XCTAssertEqual(reloaded.focusRemainingSeconds, 1100)
        XCTAssertEqual(reloaded.progress.completedSessionCount, 0)
        reloaded.endFocusSession()
        XCTAssertNil(try reloaded.store.load().activeStudySession)
        XCTAssertEqual(reloaded.progress.playerProgress.totalXP, 0)
    }

    @MainActor
    func testFocusEarlyEndAndBackwardClockCannotAwardXP() {
        var uptime: TimeInterval = 500
        let timerModel = AppModel(store: ProgressStore(directory: directory), focusClock: { uptime })
        timerModel.startFocusSession()
        uptime = 499
        timerModel.updateFocusSession()
        XCTAssertEqual(timerModel.focusRemainingSeconds, 1500)
        uptime = 510
        timerModel.endFocusSession()
        XCTAssertNil(timerModel.progress.activeStudySession)
        XCTAssertEqual(timerModel.progress.completedSessionCount, 0)
        XCTAssertEqual(timerModel.progress.playerProgress.totalXP, 0)
        XCTAssertNil(timerModel.rewardCelebration)
    }

    @MainActor
    func testLessonRewardIsExplicitUniqueAndNotMastery() throws {
        XCTAssertEqual(model.progress.playerProgress.level, 0)
        model.selectMode(.practice)
        model.completeLesson()
        XCTAssertTrue(model.progress.lessonCompletions.isEmpty)
        model.selectMode(.lesson)
        model.completeLesson()
        model.completeLesson()
        XCTAssertEqual(model.progress.playerProgress.totalXP, 25)
        XCTAssertEqual(model.rewardCelebration?.amount, 25)
        XCTAssertTrue(model.progress.masteredChapterIDs.isEmpty)
        model.selectChapter(model.chapters[1].id)
        model.completeLesson()
        XCTAssertEqual(model.progress.lessonCompletions.count, 1)
        let reloaded = AppModel(store: model.store)
        XCTAssertEqual(reloaded.progress.playerProgress.totalXP, 25)
        XCTAssertNil(reloaded.rewardCelebration)
        reloaded.setCelebrationEffectsEnabled(false)
        XCTAssertFalse(try model.store.load().celebrationEffectsEnabled)
    }

    @MainActor
    func testXPUpgradeRecalculatesOldAndInheritedRatingsOnceWithoutLosingEvidence() async throws {
        var legacy = Exercise(id: "generated-legacy", title: "Two results", instructions: "Synthetic task",
            starterCode: "value = 4\ntotal = 0\nremaining = 0", referenceSolution: "value = 4\ntotal = value + 2\nremaining = total - 1",
            testCode: "assert total == 6\nassert remaining == 5", hints: [])
        model.progress.generatedExercises["basics"] = [legacy]
        legacy.id = "generated-inherited"
        legacy.effort = .init()
        model.progress.generatedExercises["basics"]?.append(legacy)
        model.progress.attempts = [
            Attempt(chapterID: "basics", exerciseID: "basics-name", mode: .practice, code: "name = 'Mira'", testsPassed: true),
            Attempt(chapterID: "basics", exerciseID: "generated-legacy", mode: .practice, code: "saved learner evidence", testsPassed: true),
            Attempt(chapterID: "basics", exerciseID: "generated-inherited", mode: .practice, code: "saved guided evidence", testsPassed: true, solutionRevealed: true, effort: .init()),
            Attempt(chapterID: "basics", exerciseID: "missing", mode: .practice, code: "missing task evidence", testsPassed: true)
        ]
        let original = model.progress.attempts
        XCTAssertEqual(model.progress.playerProgress.totalXP, 350)
        model.selectExercise("generated-legacy")
        model.flushSave()
        model.upgradeExperience()
        model.code = "draft edited during local analysis"
        try await waitForRewardUpdate()
        XCTAssertEqual(model.progress.playerProgress.totalXP, 450)
        XCTAssertEqual(model.progress.generatedExercises["basics"]?.map { $0.effort?.scopeUnits }, [2, 2])
        XCTAssertFalse(model.needsRewardUpdate)
        XCTAssertTrue(model.exerciseRewardDetails.contains("200 XP"))
        XCTAssertTrue(model.exerciseRewardDetails.contains("estimated"))
        XCTAssertEqual(model.progress.attempts.map(\.id), original.map(\.id))
        XCTAssertEqual(model.progress.attempts.map(\.code), original.map(\.code))
        XCTAssertEqual(model.progress.masteredChapterIDs, [])
        XCTAssertNil(model.rewardCelebration)
        XCTAssertEqual(model.code, "draft edited during local analysis")
        let data = try model.store.exportData()
        let backups = try FileManager.default.contentsOfDirectory(at: model.store.directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("progress-before-xp-v\(ExperienceRules.policyVersion)-") }
        XCTAssertEqual(backups.count, 1)
        let backup = try JSONDecoder().decode(ProgressState.self, from: Data(contentsOf: XCTUnwrap(backups.first)))
        XCTAssertEqual(backup.playerProgress.totalXP, 350)
        XCTAssertEqual(backup.attempts.map(\.id), original.map(\.id))
        model.upgradeExperience()
        XCTAssertFalse(model.updatingRewards)
        XCTAssertEqual(try model.store.exportData(), data)
        let restored = AppModel(store: model.store)
        XCTAssertEqual(restored.progress.playerProgress.totalXP, 450)
        XCTAssertEqual(restored.exercise.id, "generated-legacy")
        XCTAssertEqual(restored.code, model.code)
        XCTAssertFalse(restored.needsRewardUpdate)
    }

    @MainActor
    func testXPUpgradeFailureAndCancellationLeaveSavedProgressUnchanged() async throws {
        var exercise = model.exercise
        exercise.id = "generated-unrated"
        exercise.effort = nil
        exercise.referenceSolution = "def :"
        model.progress.generatedExercises["basics"] = [exercise]
        model.selectExercise(exercise.id)
        XCTAssertEqual(model.exerciseRewardSummary, "XP rating pending · update in Player progress")
        model.flushSave()
        let before = try model.store.exportData()
        model.upgradeExperience()
        try await waitForRewardUpdate()
        XCTAssertTrue(model.needsRewardUpdate)
        XCTAssertEqual(try model.store.exportData(), before)
        XCTAssertTrue(model.notice?.contains("XP update did not complete") == true)
        model.upgradeExperience()
        model.cancelWork()
        try await waitForRewardUpdate()
        XCTAssertEqual(try model.store.exportData(), before)
        model.storageLocked = true
        model.upgradeExperience()
        XCTAssertFalse(model.updatingRewards)
    }

    @MainActor
    private func waitForRewardUpdate() async throws {
        let deadline = Date().addingTimeInterval(15)
        while model.updatingRewards && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(model.updatingRewards, "XP update exceeded test deadline")
    }

    @MainActor
    func testExerciseRewardsVaryWithReviewedWorkload() {
        model.selectExercise("basics-name")
        XCTAssertEqual(model.exerciseRewardSummary, "First successful practice · +50 XP")
        model.selectExercise("basics-total")
        XCTAssertEqual(model.exerciseRewardSummary, "First successful practice · +100 XP")
        model.selectChapter("values")
        model.overrideUnlock()
        model.selectExercise("values-label")
        XCTAssertEqual(model.exerciseRewardSummary, "First successful practice · +300 XP")
        model.revealSolution()
        XCTAssertEqual(model.exerciseRewardSummary, "First guided success · +150 XP")
        model.selectChapter("reliability")
        model.selectMode(.assessment)
        XCTAssertEqual(model.exerciseRewardSummary, "First full assessment pass · +1800 XP")
    }

    @MainActor
    func testGuidedWeightedRewardMatchesPreviewAndPersists() async throws {
        model.selectChapter("values")
        model.overrideUnlock()
        model.selectExercise("values-label")
        model.revealSolution()
        XCTAssertEqual(model.exerciseRewardSummary, "First guided success · +150 XP")
        model.code = model.exercise.referenceSolution
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertEqual(model.progress.playerProgress.totalXP, 150)
        XCTAssertEqual(model.rewardCelebration?.amount, 150)
        XCTAssertEqual(model.progress.attempts.last?.effort, model.exercise.effort)
        let restored = AppModel(store: model.store)
        XCTAssertEqual(restored.progress.playerProgress.totalXP, 150)
        XCTAssertNil(restored.rewardCelebration)
        XCTAssertTrue(restored.exerciseRewardSummary.hasPrefix("Completion XP earned"))
        XCTAssertTrue(restored.progress.masteredChapterIDs.isEmpty)
    }

    @MainActor
    func testPracticeRewardsPersistWithoutDuplicateCelebrations() async throws {
        model.selectExercise("basics-total")
        XCTAssertEqual(model.exerciseRewardSummary, "First successful practice · +100 XP")
        model.code = model.exercise.referenceSolution
        model.runCode()
        try await waitForRun()
        XCTAssertEqual(model.progress.playerProgress.totalXP, 0)
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertEqual(model.progress.playerProgress.totalXP, 100)
        XCTAssertEqual(model.progress.playerProgress.level, 1)
        XCTAssertTrue(model.rewardCelebration?.leveledUp == true)
        XCTAssertTrue(model.exerciseRewardSummary.hasPrefix("Completion XP earned"))
        model.dismissCelebration()
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertEqual(model.progress.playerProgress.totalXP, 100)
        XCTAssertNil(model.rewardCelebration)
        XCTAssertEqual(try model.store.load().playerProgress.totalXP, 100)
        XCTAssertTrue(model.progress.masteredChapterIDs.isEmpty)
    }

    @MainActor
    func testFocusTimerAutomaticallyRecordsCompletionWithoutOpenPopover() async throws {
        var uptime: TimeInterval = 0
        let timerModel = AppModel(store: ProgressStore(directory: directory), focusClock: { uptime })
        timerModel.startFocusSession()
        uptime = 1500
        let deadline = Date().addingTimeInterval(3)
        while timerModel.focusRunning && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertFalse(timerModel.focusRunning)
        XCTAssertEqual(timerModel.progress.completedSessionCount, 1)
        XCTAssertEqual(try timerModel.store.load().playerProgress.totalXP, 50)
        timerModel.endFocusSession()
    }

    @MainActor
    func testFocusCheckpointSleepAndResumePersistWithoutAwardingBreaks() async throws {
        var uptime: TimeInterval = 0
        let timerModel = AppModel(store: ProgressStore(directory: directory), focusClock: { uptime })
        timerModel.startFocusSession()
        uptime = 16
        timerModel.updateFocusSession()
        XCTAssertEqual(try timerModel.store.load().activeStudySession?.elapsed, 16)
        uptime = 20
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertFalse(timerModel.focusRunning)
        XCTAssertEqual(try timerModel.store.load().activeStudySession?.elapsed, 20)
        uptime += 86_400
        timerModel.updateFocusSession()
        XCTAssertEqual(timerModel.focusRemainingSeconds, 1480)
        timerModel.resumeFocusSession()
        uptime += 1480
        timerModel.endFocusSession()
        XCTAssertEqual(timerModel.progress.completedSessionCount, 1)
    }

    @MainActor
    func testSimultaneousRewardsQueueAndFocusCannotUnlockChapters() {
        var uptime: TimeInterval = 0
        let timerModel = AppModel(store: ProgressStore(directory: directory), focusClock: { uptime })
        timerModel.completeLesson()
        timerModel.startFocusSession()
        uptime += 1500
        timerModel.updateFocusSession()
        XCTAssertEqual(timerModel.rewardCelebration?.amount, 25)
        timerModel.dismissCelebration()
        XCTAssertEqual(timerModel.rewardCelebration?.amount, 50)
        timerModel.dismissCelebration()
        XCTAssertNil(timerModel.rewardCelebration)
        XCTAssertEqual(timerModel.progress.playerProgress.totalXP, 75)
        XCTAssertFalse(timerModel.progress.isUnlocked(timerModel.chapters[1].id, in: timerModel.chapters))
    }

    @MainActor
    func testGamificationViewsRenderAtMinimumSizeAndWithReducedMotion() async throws {
        _ = NSApplication.shared
        model.progress.attempts = [Attempt(chapterID: "basics", exerciseID: "first", mode: .practice, code: "", testsPassed: true)]
        model.completeLesson()
        model.startFocusSession()
        model.pauseFocusSession()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: WorkspaceView(forceReducedMotion: true).environmentObject(model))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        for mode in LearningMode.allCases {
            model.selectMode(mode)
            try await Task.sleep(for: .milliseconds(150))
            hosting.layoutSubtreeIfNeeded()
            XCTAssertEqual(hosting.frame.width, 1080, accuracy: 1)
            XCTAssertEqual(hosting.frame.height, 740, accuracy: 1)
            try assertCodingArea(in: hosting)
            try saveSnapshot(of: hosting, name: "reward-minimum-\(mode.rawValue.lowercased())")
        }
        model.endFocusSession()
    }

    func testRewardEffectsScaleUpAndRespectMotionPreferences() {
        let xp = RewardEffectStyle(leveledUp: false)
        let level = RewardEffectStyle(leveledUp: true)
        XCTAssertGreaterThan(xp.particleCount, 0)
        XCTAssertGreaterThan(level.particleCount, xp.particleCount * 2)
        XCTAssertGreaterThan(level.spread, xp.spread)
        XCTAssertGreaterThan(level.duration, xp.duration)
        XCTAssertLessThan(level.duration, 4)
        for enabled in [false, true] {
            for reduced in [false, true] {
                for forced in [false, true] {
                    XCTAssertEqual(RewardEffectStyle.allowsMotion(effectsEnabled: enabled, reduceMotion: reduced, forced: forced), enabled && !reduced && !forced)
                }
            }
        }
    }

    @MainActor
    func testWindowRewardEffectsRenderWithoutChangingEditorGeometry() async throws {
        _ = NSApplication.shared
        model.selectMode(.practice)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        for leveledUp in [false, true] {
            for phase in [0.2, 0.5, 1.0] {
                let root = WorkspaceView().environmentObject(model).overlay {
                    RewardEffectsFrame(progress: phase, origin: CGPoint(x: 905, y: 32), style: RewardEffectStyle(leveledUp: leveledUp))
                }
                let hosting = NSHostingView(rootView: root)
                window.contentView = hosting
                window.orderFront(nil)
                try await Task.sleep(for: .milliseconds(150))
                hosting.layoutSubtreeIfNeeded()
                XCTAssertEqual(hosting.frame.width, 1080, accuracy: 1)
                XCTAssertEqual(hosting.frame.height, 740, accuracy: 1)
                try assertCodingArea(in: hosting)
                try saveSnapshot(of: hosting, name: "effect-\(leveledUp ? "level" : "xp")-\(Int(phase * 100))")
            }
        }
    }

    @MainActor
    func testPassingSolutionTriggersLiveWindowEffectsAndKeepsEditorInteractive() async throws {
        _ = NSApplication.shared
        model.selectExercise("basics-total")
        let hosting = NSHostingView(rootView: WorkspaceView().environmentObject(model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        model.code = model.exercise.referenceSolution
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertTrue(model.rewardCelebration?.leveledUp == true)
        try await Task.sleep(for: .milliseconds(600))
        hosting.layoutSubtreeIfNeeded()
        try assertCodingArea(in: hosting)
        try saveSnapshot(of: hosting, name: "live-solution-level-up")
        func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }
        let editor = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? PythonTextView }.first)
        XCTAssertTrue(window.makeFirstResponder(editor))
        let parent = try XCTUnwrap(hosting.superview)
        let point = parent.convert(CGPoint(x: editor.bounds.midX, y: min(100, editor.bounds.midY)), from: editor)
        let hit = try XCTUnwrap(hosting.hitTest(point))
        let scroll = try XCTUnwrap(editor.enclosingScrollView)
        XCTAssertTrue(hit === editor || hit.isDescendant(of: scroll))
        try await Task.sleep(for: .seconds(3))
        try saveSnapshot(of: hosting, name: "live-solution-effects-finished")
    }

    @MainActor
    func testProgressFocusAndCelebrationDetailRendering() async throws {
        _ = NSApplication.shared
        model.progress.studySessions = (0..<5).map { index in
            let start = Date().addingTimeInterval(Double(index - 6) * 3600)
            return StudySession(startedAt: start, completedAt: start.addingTimeInterval(1500))
        }
        model.completeLesson()
        model.startFocusSession()
        model.pauseFocusSession()
        let reward = RewardCelebration(amount: 100, title: "Practice completed", previousLevel: 0, level: 1)
        XCTAssertEqual(reward.accessibilityAnnouncement, "Practice completed, plus 100 XP. Player level 1 reached.")
        let cases: [(String, AnyView, NSSize)] = [
            ("player-progress", AnyView(PlayerProgressView().environmentObject(model)), NSSize(width: 410, height: 620)),
            ("focus-paused", AnyView(FocusSessionView().environmentObject(model)), NSSize(width: 390, height: 540)),
            ("celebration-reduced-motion", AnyView(RewardCelebrationView(reward: reward, forceReducedMotion: true)), NSSize(width: 280, height: 40)),
            ("celebration-effects-off", AnyView(RewardCelebrationView(reward: reward, effectsEnabled: false)), NSSize(width: 280, height: 40))
        ]
        for (name, view, size) in cases {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
            window.contentView = hosting
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(150))
            hosting.layoutSubtreeIfNeeded()
            XCTAssertEqual(hosting.frame.width, size.width, accuracy: 1)
            XCTAssertEqual(hosting.frame.height, size.height, accuracy: 1)
            try saveSnapshot(of: hosting, name: name)
            window.close()
        }
        model.endFocusSession()
    }

    @MainActor
    func testNewLearnerStartsWithPythonBasics() {
        XCTAssertEqual(model.chapter.id, "basics")
        XCTAssertEqual(model.mode, .lesson)
        XCTAssertTrue(model.isUnlocked)
        XCTAssertTrue(model.progress.masteredChapterIDs.isEmpty)
    }

    @MainActor
    func testExistingValuesWorkSurvivesNewIntroductoryChapter() throws {
        model.flushSave()
        var existing = ProgressState()
        existing.selectedChapterID = "values"
        existing.selectedMode = .practice
        existing.selectedExerciseIDs["values"] = "values-label"
        let key = "values:practice:values-label"
        existing.drafts[key] = "raw_label = '  ORBIT Eval  '\nclean_label = raw_label.strip()\n"
        existing.hintCounts[key] = 1
        existing.reflections[key] = "Learning to remove spaces."
        existing.attempts = [Attempt(chapterID: "values", exerciseID: "values-label", mode: .practice, code: existing.drafts[key]!, testsPassed: false, hintCount: 1, reflection: existing.reflections[key]!)]
        try ProgressStore(directory: directory).save(existing)
        let reloaded = AppModel(store: ProgressStore(directory: directory))
        XCTAssertEqual(reloaded.chapter.id, "values")
        XCTAssertEqual(reloaded.exercise.id, "values-label")
        XCTAssertEqual(reloaded.code, existing.drafts[key])
        XCTAssertEqual(reloaded.hintCount, 1)
        reloaded.selectChapter("basics")
        XCTAssertTrue(reloaded.isUnlocked)
        XCTAssertEqual(reloaded.mode, .lesson)
        reloaded.flushSave()
        let saved = try ProgressStore(directory: directory).load()
        XCTAssertEqual(saved.drafts[key], existing.drafts[key])
        XCTAssertEqual(saved.reflections[key], existing.reflections[key])
        XCTAssertEqual(saved.hintCounts[key], 1)
        XCTAssertEqual(saved.attempts.map(\.id), existing.attempts.map(\.id))
        XCTAssertTrue(saved.masteredChapterIDs.isEmpty)
    }

    @MainActor
    func testDraftsResumeSeparatelyForPracticeAndAssessment() throws {
        model.selectMode(.practice)
        model.code = "practice_draft = 17"
        model.reflection = "My practice reasoning"
        model.selectMode(.assessment)
        model.code = "assessment_draft = 42"
        model.reflection = "My assessment reasoning"
        model.selectMode(.practice)
        XCTAssertEqual(model.code, "practice_draft = 17")
        XCTAssertEqual(model.reflection, "My practice reasoning")
        model.flushSave()
        let reloaded = AppModel(store: ProgressStore(directory: directory))
        XCTAssertEqual(reloaded.code, "practice_draft = 17")
        reloaded.selectMode(.assessment)
        XCTAssertEqual(reloaded.code, "assessment_draft = 42")
        XCTAssertEqual(reloaded.reflection, "My assessment reasoning")
        reloaded.flushSave()
    }

    @MainActor
    func testHintsAndSolutionAreDisabledDuringAssessment() {
        model.selectMode(.assessment)
        model.showHint()
        model.revealSolution()
        model.askTeacher("Tell me the answer")
        for scope in PracticeScope.allCases {
            for difficulty in PracticeDifficulty.allCases {
                for style in PracticeStyle.allCases {
                    model.generatePractice(options: .init(scope: scope, difficulty: difficulty, style: style))
                }
            }
        }
        XCTAssertEqual(model.hintCount, 0)
        XCTAssertFalse(model.solutionRevealed)
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertEqual(model.requestCount, 0)
        XCTAssertFalse(model.teacherBusy)
    }

    @MainActor
    func testMixedChallengeScopeContainsOnlyPrerequisiteClosure() {
        XCTAssertTrue(model.prerequisiteChapters.isEmpty)
        for chapter in model.chapters {
            model.selectChapter(chapter.id)
            XCTAssertEqual(model.prerequisiteChapters.map(\.id), Curriculum.graph.prerequisiteClosure(of: chapter.id)?.map(\.id), chapter.id)
            XCTAssertEqual(Set(model.directPrerequisites.map(\.id)), Set(chapter.prerequisites), chapter.id)
            XCTAssertEqual(model.directPrerequisites.count, chapter.prerequisites.count, chapter.id)
        }
    }

    @MainActor
    func testProjectRequiresAnObjective() {
        model.selectMode(.practice)
        let draft = model.code
        model.generatePractice(options: .init(scope: .project))
        model.generatePractice(options: .init(scope: .project, projectBriefID: "project-vending-machine"))
        XCTAssertFalse(model.teacherBusy)
        XCTAssertEqual(model.requestCount, 0)
        XCTAssertTrue(model.progress.generatedExercises.isEmpty)
        XCTAssertEqual(model.code, draft)
        XCTAssertFalse(model.settingsPresented)
    }

    @MainActor
    func testGeneratorGuardsPreserveDraftWithoutCloudAccess() {
        model.selectMode(.practice)
        model.code = "my_draft = 17"
        model.storageLocked = true
        model.generatePractice()
        model.storageLocked = false
        model.running = true
        model.generatePractice()
        model.running = false
        model.generatePractice(options: .init(scenario: String(repeating: "x", count: 401)))
        XCTAssertEqual(model.code, "my_draft = 17")
        model.selectChapter("values")
        let lockedDraft = model.code
        model.generatePractice()
        XCTAssertEqual(model.code, lockedDraft)
        XCTAssertFalse(model.teacherBusy)
        XCTAssertEqual(model.requestCount, 0)
        XCTAssertTrue(model.progress.generatedExercises.isEmpty)
        XCTAssertFalse(model.settingsPresented)
    }

    @MainActor
    func testGeneratedVariationWorkIsCappedAtChapterAssessmentWorkload() async throws {
        let session = generationSession()
        defer { session.invalidateAndCancel() }
        GenerationURLProtocol.handler = { _ in
            try self.generationResponse(reference: "boxes = 5\nused = 2\ntotal = boxes + used\nremaining = total - used",
                starter: "boxes = 5\nused = 2\ntotal = 0\nremaining = 0",
                tests: "assert total == 7\nassert remaining == 5", coverage: ["selected-exercise": "Calculate total and remaining."])
        }
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        }
        model.selectExercise("basics-total")
        model.generatePractice(options: .init(scope: .selectedExercise))
        try await waitForGeneration()
        XCTAssertEqual(model.chapter.assessment.effort?.scopeUnits, 1)
        XCTAssertEqual(model.exercise.effort?.scopeUnits, 1, "two locally estimated units are capped at the basics assessment workload")
        XCTAssertEqual(model.exerciseRewardSummary, "First successful practice · +100 XP")
        model.code = model.exercise.referenceSolution
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertEqual(model.rewardCelebration?.amount, 100)
        XCTAssertEqual(try model.store.load().playerProgress.totalXP, 100)
    }

    @MainActor
    func testGeneratedPracticeIsImmediatelySavedAndSelected() async throws {
        let session = generationSession()
        defer { session.invalidateAndCancel() }
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        }
        model.selectMode(.practice)
        let previousID = model.exercise.id
        let previousDraftKey = model.draftKey
        model.code = "saved_draft = 17"
        var states: [PracticeGenerationState] = []
        let observation = model.$generationState.sink { states.append($0) }
        defer { observation.cancel() }
        model.generatePractice()
        try await waitForGeneration()
        XCTAssertTrue(states.contains(.receiving(characters: 1)))
        XCTAssertTrue(states.contains(.validating))
        let generated = try XCTUnwrap(model.progress.generatedExercises[model.chapter.id]?.last)
        XCTAssertEqual(model.exercise.id, generated.id)
        let expectedXP = min(model.chapter.practiceTopics.count, ExperienceRules.generatedUnitCap(scope: .currentChapter, chapter: model.chapter)) * 100
        XCTAssertEqual(generated.effort?.practiceXP, expectedXP)
        XCTAssertEqual(model.exerciseRewardSummary, "First successful practice · +\(expectedXP) XP")
        XCTAssertNotEqual(model.exercise.id, previousID)
        XCTAssertEqual(model.mode, .practice)
        XCTAssertEqual(model.code, generated.starterCode)
        XCTAssertEqual(model.progress.drafts[previousDraftKey], "saved_draft = 17")
        XCTAssertEqual(model.requestCount, 1)
        XCTAssertTrue(model.progress.attempts.isEmpty)
        XCTAssertFalse(model.completedPracticeExerciseIDs.contains(generated.id))
        XCTAssertEqual(model.generationState, .ready(chapterID: model.chapter.id, exerciseID: generated.id, title: generated.title))
        let saved = try model.store.load()
        XCTAssertEqual(saved.generatedExercises[model.chapter.id]?.last, generated)
        XCTAssertEqual(saved.selectedExerciseIDs[model.chapter.id], generated.id)
        let restored = AppModel(store: model.store)
        XCTAssertEqual(restored.exercise, generated)
        model.selectExercise(previousID)
        XCTAssertEqual(model.code, "saved_draft = 17")
        model.selectChapter("values")
        model.openGeneratedPractice()
        XCTAssertEqual(model.chapter.id, "basics")
        XCTAssertEqual(model.exercise, generated)
        model.code = generated.referenceSolution
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertTrue(model.completedPracticeExerciseIDs.contains(generated.id))
        XCTAssertTrue(model.exercisePickerTitle(generated).hasPrefix("✓ "))
        XCTAssertEqual(model.progress.playerProgress.totalXP, expectedXP)
        XCTAssertEqual(model.rewardCelebration?.amount, expectedXP)
        XCTAssertEqual(try model.store.load().playerProgress.totalXP, expectedXP)
    }

    @MainActor
    func testRejectedGenerationShowsAnExplicitNoticeAndPreservesDraft() async throws {
        for (reference, starter, status) in [("total = 2", "total = 0", 200), ("total = 3", "total = 3", 200), ("total = 3", "total = 0", 500)] {
            let session = generationSession(reference: reference, starter: starter, status: status)
            model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
                TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
            }
            model.selectMode(.practice)
            model.code = "my_original_draft = 23"
            let exerciseID = model.exercise.id
            model.generatePractice()
            try await waitForGeneration()
            XCTAssertTrue(model.progress.generatedExercises.isEmpty)
            XCTAssertEqual(model.exercise.id, exerciseID)
            XCTAssertEqual(model.code, "my_original_draft = 23")
            XCTAssertNotNil(model.notice, "Generation rejection must not be hidden only in the output panel")
            if reference == "total = 2" {
                XCTAssertTrue(model.notice?.contains("AssertionError") == true, "Show the actual rejection reason")
            }
            XCTAssertTrue(model.generationState.message?.hasPrefix("No exercise was added.") == true)
            let status = model.generationState
            model.selectMode(.lesson)
            model.selectMode(.practice)
            XCTAssertEqual(model.generationState, status)
            XCTAssertEqual(model.requestCount, 1)
            model.flushSave()
            session.invalidateAndCancel()
        }
    }

    @MainActor
    func testRejectedPracticeCanBeExplicitlyRepairedButIsNeverAutomaticallyRetried() async throws {
        let session = generationSession()
        defer { session.invalidateAndCancel() }
        var requests = 0
        GenerationURLProtocol.handler = { _ in
            requests += 1
            return try self.generationResponse(reference: requests < 3 ? "total = 2" : "total = 3")
        }
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        }
        model.selectMode(.practice)
        model.code = "private_draft_marker = 17"
        let originalKey = model.draftKey
        let originalID = model.exercise.id
        let options = PracticeGenerationOptions(difficulty: .easier, style: .complete, scenario: "Synthetic garden")
        model.generatePractice(options: options)
        try await waitForGeneration()
        XCTAssertEqual(requests, 1)
        let rejected = try XCTUnwrap(model.rejectedPractice)
        XCTAssertEqual(rejected.options, options)
        XCTAssertEqual(rejected.selectedExercise.id, originalID)
        XCTAssertTrue(rejected.repair.validationFeedback.contains("AssertionError"))
        XCTAssertTrue(rejected.report.contains("total = 2"))
        XCTAssertFalse(rejected.report.contains("private_draft_marker"))
        XCTAssertFalse(rejected.report.contains("test-not-a-real-key"))
        XCTAssertFalse(rejected.report.contains(FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path))
        XCTAssertTrue(model.canRepairGeneratedPractice)
        model.selectMode(.assessment)
        model.repairGeneratedPractice()
        XCTAssertFalse(model.canRepairGeneratedPractice)
        model.selectChapter("values")
        model.repairGeneratedPractice()
        XCTAssertFalse(model.canRepairGeneratedPractice)
        XCTAssertEqual(requests, 1)
        model.selectChapter("basics")
        model.selectMode(.practice)
        model.requestCount = model.progress.sessionRequestLimit
        model.repairGeneratedPractice()
        XCTAssertEqual(requests, 1)
        model.requestCount = 1
        model.notice = nil
        model.selectExercise(model.chapter.exercises[1].id)
        model.repairGeneratedPractice()
        try await waitForGeneration()
        XCTAssertEqual(requests, 2)
        XCTAssertTrue(model.progress.generatedExercises.isEmpty)
        XCTAssertNotNil(model.rejectedPractice)
        XCTAssertEqual(model.rejectedPractice?.selectedExercise.id, originalID)
        model.repairGeneratedPractice()
        try await waitForGeneration()
        XCTAssertEqual(requests, 3)
        XCTAssertEqual(model.requestCount, 3)
        XCTAssertNil(model.rejectedPractice)
        XCTAssertEqual(model.progress.generatedExercises[model.chapter.id]?.count, 1)
        XCTAssertTrue(model.exercise.id.hasPrefix("generated-"))
        XCTAssertEqual(model.progress.drafts[originalKey], "private_draft_marker = 17")
        XCTAssertEqual(try model.store.load().generatedExercises[model.chapter.id]?.count, 1)
    }

    @MainActor
    func testSkippedAssertionDiagnosticsRemainAvailableForInspection() async throws {
        let session = generationSession(reference: "total = 3", tests: "assert total == 3\nif False:\n    assert False\n")
        defer { session.invalidateAndCancel() }
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        }
        model.selectMode(.practice)
        model.generatePractice()
        try await waitForGeneration()
        let rejected = try XCTUnwrap(model.rejectedPractice)
        XCTAssertTrue(model.notice?.contains("Tests skipped assertions") == true)
        XCTAssertTrue(rejected.repair.validationFeedback.contains("executed 1 of 2 assertion sites"))
        XCTAssertTrue(model.progress.generatedExercises.isEmpty)
        model.notice = nil
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: WorkspaceView().environmentObject(model))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(200))
        try saveSnapshot(of: hosting, name: "rejected-reference-diagnostics-actions")
        let details = NSHostingView(rootView: GenerationValidationDetailsView(rejected: rejected).environmentObject(model))
        window.contentView = details
        try await Task.sleep(for: .milliseconds(200))
        try saveSnapshot(of: details, name: "rejected-reference-validation-details")
        model.dismissGenerationStatus()
        XCTAssertNil(model.rejectedPractice)
        XCTAssertFalse(model.canRepairGeneratedPractice)
    }

    @MainActor
    func testGenerationNetworkTimeoutPreservesDraftAndDoesNotRetry() async throws {
        let session = generationSession()
        defer { session.invalidateAndCancel() }
        var requests = 0
        GenerationURLProtocol.handler = { _ in
            requests += 1
            throw URLError(.timedOut)
        }
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        }
        model.selectMode(.practice)
        model.code = "saved_work = 42"
        let original = model.exercise
        model.generatePractice()
        try await waitForGeneration()
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(model.requestCount, 1)
        XCTAssertEqual(model.exercise, original)
        XCTAssertEqual(model.code, "saved_work = 42")
        XCTAssertTrue(model.progress.generatedExercises.isEmpty)
        XCTAssertTrue(model.notice?.contains("before Python validation") == true)
        XCTAssertTrue(model.generationState.message?.contains("No automatic retry") == true)
        XCTAssertFalse(model.generationState.isInProgress)
    }

    @MainActor
    func testGenerationCancellationDoesNotAddAnExercise() async throws {
        let session = generationSession()
        defer { session.invalidateAndCancel() }
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        }
        model.selectMode(.practice)
        let draft = model.code
        model.generatePractice()
        XCTAssertEqual(model.generationState, .requesting)
        model.dismissGenerationStatus()
        XCTAssertEqual(model.generationState, .requesting)
        model.cancelWork()
        try await waitForGeneration()
        XCTAssertEqual(model.generationState, .cancelled)
        XCTAssertTrue(model.progress.generatedExercises.isEmpty)
        XCTAssertEqual(model.code, draft)
        XCTAssertNil(model.notice)
        model.dismissGenerationStatus()
        XCTAssertEqual(model.generationState, .idle)
    }

    @MainActor
    func testGenerationDoesNotReportSuccessWhenProgressCannotBeSaved() async throws {
        let session = generationSession()
        defer { session.invalidateAndCancel() }
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        }
        model.selectMode(.practice)
        let original = model.exercise
        let file = directory.appendingPathComponent("progress.json")
        let unreadable = Data("synthetic unreadable progress".utf8)
        try unreadable.write(to: file)
        model.generatePractice()
        try await waitForGeneration()
        XCTAssertTrue(model.progress.generatedExercises.isEmpty)
        XCTAssertEqual(model.exercise, original)
        XCTAssertTrue(model.generationState.message?.contains("No exercise was added") == true)
        XCTAssertNotNil(model.notice)
        XCTAssertEqual(try Data(contentsOf: file), unreadable)
    }

    @MainActor
    func testExerciseCompletionCheckmarksUsePassingPracticeHistory() throws {
        model.selectMode(.practice)
        let chapterID = model.chapter.id
        let first = model.exercises[0]
        let second = model.exercises[1]
        var generated = first
        generated.id = "generated-completion-synthetic"
        generated.title = "Synthetic completed practice"
        model.progress.generatedExercises[chapterID] = [generated]
        model.progress.attempts = [
            Attempt(chapterID: chapterID, exerciseID: first.id, mode: .practice, code: "", testsPassed: false),
            Attempt(chapterID: chapterID, exerciseID: first.id, mode: .assessment, code: "", testsPassed: true),
            Attempt(chapterID: chapterID, exerciseID: first.id, mode: .lesson, code: "", testsPassed: true),
            Attempt(chapterID: "values", exerciseID: first.id, mode: .practice, code: "", testsPassed: true)
        ]
        XCTAssertTrue(model.completedPracticeExerciseIDs.isEmpty)
        XCTAssertEqual(model.exercisePickerTitle(first), first.title)
        model.progress.attempts += [
            Attempt(chapterID: chapterID, exerciseID: first.id, mode: .practice, code: first.referenceSolution, testsPassed: true, hintCount: 1),
            Attempt(chapterID: chapterID, exerciseID: generated.id, mode: .practice, code: generated.referenceSolution, testsPassed: true, solutionRevealed: true),
            Attempt(chapterID: chapterID, exerciseID: first.id, mode: .practice, code: "later failed draft", testsPassed: false),
            Attempt(chapterID: chapterID, exerciseID: "missing-exercise", mode: .practice, code: "", testsPassed: true)
        ]
        XCTAssertEqual(model.completedPracticeExerciseIDs, [first.id, generated.id])
        XCTAssertEqual(model.exercisePickerTitle(first), "✓ \(first.title)")
        XCTAssertEqual(model.exercisePickerTitle(generated), "✓ \(generated.title)")
        XCTAssertEqual(model.exercisePickerTitle(second), second.title)
        model.code = "new_unchecked_draft = 1"
        model.flushSave()
        let restored = AppModel(store: model.store)
        XCTAssertEqual(restored.completedPracticeExerciseIDs, [first.id, generated.id])
        restored.selectChapter("values")
        XCTAssertTrue(restored.completedPracticeExerciseIDs.isEmpty)
    }

    @MainActor
    private func waitForGeneration() async throws {
        let deadline = Date().addingTimeInterval(15)
        while model.teacherBusy && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(model.teacherBusy, "Generation exceeded test deadline")
    }

    private func generationSession(reference: String = "total = 3", starter: String = "total = 0", tests: String = "assert total == 3", status: Int = 200) -> URLSession {
        GenerationURLProtocol.handler = { _ in
            try self.generationResponse(reference: reference, starter: starter, tests: tests, status: status)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GenerationURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func generationResponse(reference: String, starter: String = "total = 0", tests: String = "assert total == 3", status: Int = 200, coverage: [String: String]? = nil) throws -> (Int, Data) {
        let instructions = ["Goal": "Save a synthetic total.", "Starting code": "Replace the zero placeholder.",
                            "Your task": "1. Save integer 3 in total.", "Expected result": "total is integer 3.", "Check": "The checks read total."]
        let payload: [String: Any] = ["title": "Synthetic generated total", "instructions": instructions,
            "starterCode": starter, "referenceSolution": reference, "testCode": tests, "hints": ["a", "b", "c"],
            "coverage": coverage ?? Dictionary(uniqueKeysWithValues: Curriculum.chapters[0].practiceTopics.map { ($0.id, "Step 1: check total.") })]
        let text = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
        let response: [String: Any] = ["status": "completed", "output": [["type": "message", "content": [["type": "output_text", "text": text]]]]]
        return (status, try JSONSerialization.data(withJSONObject: response))
    }

    @MainActor
    func testGeneratorDialogSubmissionAndRequestLimitFeedback() async throws {
        _ = NSApplication.shared
        let session = generationSession()
        defer { session.invalidateAndCancel() }
        for allowed in [false, true] {
            model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
                TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
            }
            model.selectMode(.practice)
            let reviewed = model.exercise
            model.progress.attempts = [Attempt(chapterID: model.chapter.id, exerciseID: reviewed.id, mode: .practice, code: reviewed.referenceSolution, testsPassed: true)]
            model.requestCount = allowed ? 0 : model.progress.sessionRequestLimit
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: WorkspaceView().environmentObject(model))
            window.contentView = hosting
            window.makeKeyAndOrderFront(nil)
            defer {
                if let sheet = window.attachedSheet { window.endSheet(sheet) }
                window.close()
            }
            try await Task.sleep(for: .milliseconds(200))
            func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
            let buttons = descendants(hosting).compactMap { $0 as? NSButton }
            let pickerIndex = try XCTUnwrap(buttons.firstIndex { $0 is NSPopUpButton })
            buttons[pickerIndex + 1].performClick(nil)
            try await Task.sleep(for: .milliseconds(300))
            let sheet = try XCTUnwrap(window.attachedSheet)
            let content = try XCTUnwrap(sheet.contentView)
            let submit = try XCTUnwrap(descendants(content).compactMap { $0 as? NSButton }.last)
            submit.performClick(nil)
            try await Task.sleep(for: .milliseconds(500))
            try await waitForGeneration()
            if allowed {
                let generated = try XCTUnwrap(model.progress.generatedExercises[model.chapter.id]?.last)
                XCTAssertEqual(model.exercise, generated)
                XCTAssertEqual(model.requestCount, 1)
                XCTAssertEqual(try model.store.load().generatedExercises[model.chapter.id]?.last, generated)
                XCTAssertEqual(model.generationState, .ready(chapterID: model.chapter.id, exerciseID: generated.id, title: generated.title))
                try await Task.sleep(for: .milliseconds(200))
                let picker = try XCTUnwrap(descendants(hosting).compactMap { $0 as? NSPopUpButton }.first)
                XCTAssertEqual(picker.title, generated.title)
                XCTAssertTrue(picker.itemTitles.contains("✓ \(reviewed.title)"))
                XCTAssertTrue(picker.itemTitles.contains(generated.title))
                try saveSnapshot(of: hosting, name: "generation-ready-and-completed-picker")
            } else {
                XCTAssertNotNil(model.notice)
                XCTAssertTrue(model.generationState.message?.contains("No exercise was added") == true)
                XCTAssertEqual(model.requestCount, model.progress.sessionRequestLimit)
                model.notice = nil
                try await Task.sleep(for: .milliseconds(200))
                try saveSnapshot(of: hosting, name: "generation-failed-visible-status")
            }
        }
    }

    @MainActor
    func testPracticeGeneratorRendersCoverageAndDifficultyChoices() async throws {
        _ = NSApplication.shared
        model.selectMode(.practice)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 590), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        for (name, chapterID, options) in [
            ("first-chapter", "basics", PracticeGenerationOptions()),
            ("selected-exercise", "values", .init(scope: .selectedExercise, difficulty: .harder, style: .debug)),
            ("project-easier", "reliability", .init(scope: .project, difficulty: .easier, style: .complete, projectBriefID: "project-vending-machine")),
            ("project-own-objective", "basics", .init(scope: .project, scenario: "A synthetic recipe scaler"))
        ] {
            model.selectChapter(chapterID)
            if !model.isUnlocked { model.overrideUnlock() }
            let draft = model.code
            let hosting = NSHostingView(rootView: PracticeGeneratorView(options: .constant(options)) { _ in
                XCTFail("Rendering must not start generation")
            }.environmentObject(model))
            window.contentView = hosting
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(150))
            hosting.layoutSubtreeIfNeeded()
            XCTAssertLessThanOrEqual(hosting.frame.height, 740)
            XCTAssertLessThanOrEqual(hosting.frame.width, 1080)
            XCTAssertGreaterThan(hosting.frame.height, 500)
            XCTAssertEqual(model.code, draft)
            XCTAssertEqual(model.requestCount, 0)
            try saveSnapshot(of: hosting, name: "generator-\(name)")
        }
    }

    @MainActor
    func testPracticeAssistanceSurvivesResetAndNavigation() {
        model.selectMode(.practice)
        model.showHint()
        model.revealSolution()
        model.code = "changed = True"
        model.resetDraft()
        XCTAssertEqual(model.hintCount, 1)
        XCTAssertTrue(model.solutionRevealed)
        XCTAssertEqual(model.code, model.exercise.starterCode)
        let id = model.exercise.id
        model.selectExercise(model.exercises[1].id)
        XCTAssertEqual(model.hintCount, 0)
        XCTAssertFalse(model.solutionRevealed)
        model.selectExercise(id)
        XCTAssertEqual(model.hintCount, 1)
        XCTAssertTrue(model.solutionRevealed)
    }

    @MainActor
    func testLockedChapterCannotRunOrReceiveHints() {
        model.selectChapter(model.chapters[1].id)
        model.selectMode(.practice)
        XCTAssertFalse(model.isUnlocked)
        model.runCode()
        model.showHint()
        XCTAssertFalse(model.running)
        XCTAssertTrue(model.messages.isEmpty)
        model.overrideUnlock()
        XCTAssertTrue(model.isUnlocked)
        XCTAssertFalse(model.progress.masteredChapterIDs.contains(model.chapter.id))
    }

    private static func syntheticChapter(_ id: String, _ title: String, _ prerequisites: [String] = [], track: ChapterTrack = .foundations) -> Chapter {
        let exercise = Exercise(id: "\(id)-practice", title: "\(title) practice", instructions: "Goal:\nSynthetic practice.",
                                starterCode: "result = None", referenceSolution: "result = 1", testCode: "assert result == 1",
                                hints: ["a", "b", "c"], effort: ExerciseEffort(scopeUnits: 1))
        var assessment = exercise
        assessment.id = "\(id)-assessment"
        assessment.title = "\(title) assessment"
        return Chapter(id: id, title: title, subtitle: "Synthetic subtitle for \(title.lowercased())", track: track, prerequisites: prerequisites,
                       lesson: "# \(title)\nSynthetic lesson.\n", exercises: [exercise], assessment: assessment, quiz: [])
    }

    /// D requires B and C, both of which require A.
    private static let diamond = [syntheticChapter("A", "Synthetic A"), syntheticChapter("B", "Synthetic B", ["A"]),
                                  syntheticChapter("C", "Synthetic C", ["A"]), syntheticChapter("D", "Synthetic D", ["B", "C"])]

    /// Roughly 25 synthetic chapters across every track, shaped like the planned curriculum tree.
    private static let syntheticTree: [Chapter] = {
        let foundations = ["basics", "values", "decisions", "loops", "functions", "collections", "reliability"]
        var chapters = foundations.enumerated().map { index, id in
            syntheticChapter(id, "\(index + 1). Synthetic \(id)", index == 0 ? [] : [foundations[index - 1]])
        }
        let branches: [(String, String, [String], ChapterTrack)] = [
            ("iteration", "Iteration patterns", ["reliability"], .corePython),
            ("files", "Files and modules", ["iteration"], .corePython),
            ("classes", "Classes and objects", ["iteration"], .corePython),
            ("inheritance", "Inheritance", ["classes"], .softwareCraft),
            ("testing", "Testing with unittest", ["classes"], .softwareCraft),
            ("generators", "Iterators and generators", ["classes"], .softwareCraft),
            ("typing-decorators", "Typing and decorators", ["inheritance", "generators"], .softwareCraft),
            ("ds-cleaning", "Cleaning tabular data", ["files"], .dataScience),
            ("ds-statistics", "Descriptive statistics", ["ds-cleaning"], .dataScience),
            ("ds-aggregation", "Grouping and aggregation", ["ds-statistics", "classes"], .dataScience),
            ("numpy", "NumPy arrays", ["ds-aggregation"], .dataScience),
            ("pandas", "pandas DataFrames", ["numpy"], .dataScience),
            ("pandas-groupby", "pandas grouping", ["pandas"], .dataScience),
            ("plotting", "Plotting results", ["pandas-groupby", "testing"], .dataScience),
            ("ds-project-a", "Synthetic project A", ["plotting"], .dataScience),
            ("ds-project-b", "Synthetic project B", ["ds-project-a", "typing-decorators"], .dataScience),
            ("craft-review", "Synthetic craft review", ["testing", "typing-decorators"], .softwareCraft),
            ("core-review", "Synthetic core review", ["files", "classes"], .corePython),
        ]
        chapters += branches.map { syntheticChapter($0.0, $0.1, $0.2, track: $0.3) }
        return chapters
    }()

    private func masteryAttempt(_ chapterID: String) -> Attempt {
        Attempt(chapterID: chapterID, exerciseID: "\(chapterID)-assessment", mode: .assessment, code: "result = 1",
                testsPassed: true, quizCorrect: 1, quizTotal: 1, reflection: "Synthetic explanation.")
    }

    @MainActor
    func testLockedChapterNamesEveryMissingPrerequisite() throws {
        let diamond = AppModel(store: ProgressStore(directory: directory.appendingPathComponent("diamond")), chapters: Self.diamond)
        XCTAssertEqual(diamond.chapter.id, "A", "A curriculum without basics starts at its only root")
        XCTAssertTrue(diamond.isUnlocked)
        diamond.selectChapter("D")
        XCTAssertFalse(diamond.isUnlocked)
        XCTAssertEqual(diamond.missingPrerequisites.map(\.id), ["B", "C"])
        XCTAssertEqual(diamond.prerequisiteChapters.map(\.id), ["A", "B", "C"])
        XCTAssertEqual(diamond.requirementSummary(for: "D"), "Requires: Synthetic B · Synthetic C")
        XCTAssertEqual(diamond.requirementSummary(for: "B"), "Requires: Synthetic A")
        XCTAssertEqual(diamond.lockedChapterExplanation, "This chapter builds on several chapters. Pass the assessments for “Synthetic B” and “Synthetic C” to unlock it. If you already know that material, take those assessments as placement checks.")
        XCTAssertEqual(diamond.overrideButtonTitle, "I already know these prerequisites…")
        XCTAssertEqual(diamond.overrideConfirmationTitle, "Study this chapter without mastering “Synthetic B” and “Synthetic C”? This records a placement override, not mastery.")
        XCTAssertEqual(diamond.teacherLockedMessage, "Master “Synthetic B” and “Synthetic C” or record a placement override to start this chapter.")
        diamond.progress.attempts = [masteryAttempt("A"), masteryAttempt("B")]
        XCTAssertFalse(diamond.isUnlocked, "One of two prerequisites does not unlock")
        XCTAssertEqual(diamond.missingPrerequisites.map(\.id), ["C"])
        XCTAssertEqual(diamond.lockedChapterExplanation, "Pass the assessment for “Synthetic C” to unlock this chapter. If you already know that material, take its assessment as a placement check.")
        XCTAssertEqual(diamond.overrideButtonTitle, "I already know the prerequisite…")
        XCTAssertEqual(diamond.overrideConfirmationTitle, "Study this chapter without mastering “Synthetic C”? This records a placement override, not mastery.")
        diamond.progress.attempts.append(masteryAttempt("C"))
        XCTAssertTrue(diamond.isUnlocked)
        XCTAssertTrue(diamond.missingPrerequisites.isEmpty)
        XCTAssertEqual(AppModel.list(["A", "B", "C"]), "A, B, and C")

        model.selectChapter("decisions")
        let values = try XCTUnwrap(Curriculum.graph.chapter("values"))
        XCTAssertFalse(model.isUnlocked)
        XCTAssertEqual(model.missingPrerequisites.map(\.id), ["values"])
        XCTAssertEqual(model.requirementSummary(for: "decisions"), "Requires: \(values.title)")
        XCTAssertTrue(model.lockedChapterExplanation.contains("Pass the assessment for “\(values.title)”"))
        XCTAssertTrue(model.teacherLockedMessage.contains(values.title))
        model.overrideUnlock()
        XCTAssertTrue(model.isUnlocked)
        XCTAssertFalse(model.progress.masteredChapterIDs.contains("decisions"))
    }

    @MainActor
    func testTeacherSnapshotNamesExplicitPrerequisites() async throws {
        var snapshots: [[String: Any]] = []
        let session = mockTeacherSession { snapshots.append($0) }
        defer { session.invalidateAndCancel() }
        model.selectMode(.practice)
        model.askTeacher("Where do I start?")
        try await waitForGeneration()
        XCTAssertEqual(snapshots.last?["directPrerequisites"] as? [String], [])
        XCTAssertEqual(snapshots.last?["prerequisiteChapters"] as? [String], [])
        model.selectChapter("decisions")
        model.overrideUnlock()
        model.selectMode(.practice)
        model.askTeacher("Which chapters can I rely on?")
        try await waitForGeneration()
        let expected = try XCTUnwrap(Curriculum.graph.prerequisiteClosure(of: "decisions")).map(\.title)
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.last?["directPrerequisites"] as? [String], [try XCTUnwrap(Curriculum.graph.chapter("values")).title])
        XCTAssertEqual(snapshots.last?["prerequisiteChapters"] as? [String], expected)
        XCTAssertEqual(expected.count, 2)
    }

    @MainActor
    func testChapterBrowserGroupsTracksAndExplainsLockedChapters() async throws {
        _ = NSApplication.shared
        let tree = AppModel(store: ProgressStore(directory: directory.appendingPathComponent("tree")), chapters: Self.syntheticTree)
        XCTAssertGreaterThanOrEqual(tree.chapters.count, 25)
        XCTAssertEqual(CurriculumGraph(Self.syntheticTree).validationIssues(), [])
        tree.progress.attempts = ["basics", "values", "decisions"].map(masteryAttempt)
        tree.progress.unlockedOverrides = ["classes"]
        let sections = ChapterBrowserView.sections(for: tree.chapters)
        XCTAssertEqual(sections.map(\.track), ChapterTrack.allCases)
        XCTAssertEqual(sections.flatMap(\.entries).count, tree.chapters.count)
        XCTAssertEqual(sections[0].entries.map(\.number), Array(1...7))
        XCTAssertEqual(sections[1].entries.map(\.chapter.id), ["iteration", "files", "classes", "core-review"])
        XCTAssertEqual(sections[1].entries.last?.number, 25, "Numbers follow canonical order, not position within a track")
        XCTAssertEqual(tree.requirementSummary(for: "typing-decorators"), "Requires: Inheritance · Iterators and generators")
        XCTAssertEqual(tree.requirementSummary(for: "functions"), "Requires: 4. Synthetic loops")
        XCTAssertTrue(tree.isUnlocked("loops"))
        XCTAssertTrue(tree.isUnlocked("classes"))
        XCTAssertFalse(tree.isUnlocked("inheritance"), "An override does not satisfy dependents")
        for (name, model, height) in [("chapter-browser-tree", tree, 580.0), ("chapter-browser-tree-tall", tree, 1700.0), ("chapter-browser-curriculum", model!, 580.0)] {
            let hosting = NSHostingView(rootView: ChapterBrowserView().environmentObject(model)
                .frame(width: 310, height: height).background(Color(nsColor: .windowBackgroundColor)))
            hosting.frame = NSRect(x: 0, y: 0, width: 310, height: height)
            let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(250))
            hosting.layoutSubtreeIfNeeded()
            XCTAssertEqual(hosting.frame.width, 310, accuracy: 1)
            XCTAssertEqual(hosting.frame.height, height, accuracy: 1)
            try saveSnapshot(of: hosting, name: name)
            window.close()
        }
        let diamond = AppModel(store: ProgressStore(directory: directory.appendingPathComponent("diamond-ui")), chapters: Self.diamond)
        diamond.selectChapter("D")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1380, height: 900), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: WorkspaceView().environmentObject(diamond))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(350))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertFalse(diamond.isUnlocked)
        try saveSnapshot(of: hosting, name: "locked-multiple-prerequisites")
    }

    @MainActor
    func testIncompleteAssessmentCannotSubmit() {
        model.selectMode(.assessment)
        model.code = model.exercise.referenceSolution
        model.runCode(test: true, submit: true)
        XCTAssertFalse(model.running)
        XCTAssertTrue(model.progress.attempts.isEmpty)
        XCTAssertNotNil(model.notice)
    }

    @MainActor
    func testPassingAssessmentUnlocksNextChapterAndPersistsEvidence() async throws {
        model.selectMode(.assessment)
        model.code = model.exercise.referenceSolution
        model.reflection = "I compute each requested value from the supplied inputs, then check the resulting types and values."
        for question in model.chapter.quiz { model.setAnswer(question.correctIndex, question: question.id) }
        let chapterID = model.chapter.id
        model.runCode(test: true, submit: true)
        try await waitForRun()
        XCTAssertTrue(model.progress.masteredChapterIDs.contains(chapterID), model.output + model.feedback)
        XCTAssertTrue(model.progress.isUnlocked(model.chapters[1].id, in: model.chapters))
        XCTAssertTrue(model.feedback.contains("Chapter passed. Newly unlocked: “\(model.chapters[1].title)”."), model.feedback)
        XCTAssertFalse(model.feedback.contains("The next chapter is unlocked"))
        let attempt = try XCTUnwrap(model.progress.attempts.last)
        XCTAssertTrue(attempt.demonstratesMastery)
        XCTAssertEqual(attempt.code, model.code)
        let stored = try ProgressStore(directory: directory).load()
        XCTAssertTrue(stored.masteredChapterIDs.contains(chapterID))
        XCTAssertEqual(stored.playerProgress.totalXP, 300)
        XCTAssertEqual(model.rewardCelebration?.amount, 300)
        model.dismissCelebration()
        model.runCode(test: true, submit: true)
        try await waitForRun()
        XCTAssertEqual(model.progress.playerProgress.totalXP, 300)
        XCTAssertNil(model.rewardCelebration)
    }

    @MainActor
    func testWrongTheoryDoesNotGrantMasteryEvenWhenCodePasses() async throws {
        model.selectMode(.assessment)
        model.code = model.exercise.referenceSolution
        model.reflection = "This is my independent explanation."
        for question in model.chapter.quiz { model.setAnswer((question.correctIndex + 1) % question.options.count, question: question.id) }
        model.runCode(test: true, submit: true)
        try await waitForRun()
        XCTAssertTrue(model.progress.attempts.last?.testsPassed == true, model.output)
        XCTAssertTrue(model.progress.masteredChapterIDs.isEmpty)
        XCTAssertTrue(model.feedback.contains("Not passed yet"))
        XCTAssertEqual(model.progress.playerProgress.totalXP, 0)
        XCTAssertNil(model.rewardCelebration)
    }

    @MainActor
    func testRunDiagnosticTracksFailuresEditsAndSuccessfulReruns() async throws {
        model.selectMode(.practice)
        model.code = "print(missing_name)\n"
        model.runCode()
        try await waitForRun()
        let diagnostic = try XCTUnwrap(model.lastRunDiagnostic)
        XCTAssertEqual(diagnostic.exceptionType, "NameError")
        XCTAssertEqual(diagnostic.origin, .learner)
        XCTAssertEqual(model.diagnosticLine, 1)
        XCTAssertNotNil(model.diagnosticGuidance)
        XCTAssertTrue(model.output.contains("NameError"))
        model.revealDiagnosticLine()
        let first = try XCTUnwrap(model.editorRevealRequest)
        model.revealDiagnosticLine()
        XCTAssertNotEqual(model.editorRevealRequest?.id, first.id)
        XCTAssertEqual(first.sourceIdentity, model.draftKey)
        XCTAssertEqual(first.source, model.lastRunCode)
        model.code = "print('fixed')\n"
        XCTAssertTrue(model.isOutputStale)
        XCTAssertEqual(model.lastRunDiagnostic, diagnostic)
        XCTAssertNil(model.editorRevealRequest)
        XCTAssertNil(model.diagnosticLine)
        XCTAssertNil(model.diagnosticGuidance)
        let staleCard = RunFailureCard(diagnostic: diagnostic, assessment: false, stale: true,
                                       guidance: "outdated guidance", navigableLine: nil, reveal: {})
        XCTAssertNil(staleCard.displayedGuidance)
        XCTAssertNotNil(staleCard.displayedMessage)
        model.revealDiagnosticLine()
        XCTAssertNil(model.editorRevealRequest)
        model.runCode()
        XCTAssertNil(model.lastRunDiagnostic)
        try await waitForRun()
        XCTAssertNil(model.lastRunDiagnostic)
        XCTAssertFalse(model.isOutputStale)
        XCTAssertEqual(model.output.trimmingCharacters(in: .whitespacesAndNewlines), "fixed")
        model.code = "raise ValueError('synthetic failure')\n"
        model.runCode()
        try await waitForRun()
        XCTAssertEqual(model.lastRunDiagnostic?.exceptionType, "ValueError")
        XCTAssertEqual(model.lastRunCode, model.code)
    }

    @MainActor
    func testRunDiagnosticClearsOnResetNavigationAndRelaunch() throws {
        func seed() {
            model.lastRunCode = model.code
            model.lastRunDiagnostic = RunDiagnostic(exceptionType: "NameError", message: "synthetic", origin: .learner,
                                                     frames: [.init(line: 1, function: "<module>")])
            model.revealDiagnosticLine()
            XCTAssertNotNil(model.editorRevealRequest)
        }
        func assertCleared() {
            XCTAssertNil(model.lastRunDiagnostic)
            XCTAssertNil(model.lastRunCode)
            XCTAssertNil(model.editorRevealRequest)
        }
        seed()
        model.resetDraft()
        assertCleared()
        seed()
        model.selectMode(.practice)
        assertCleared()
        seed()
        model.selectExercise(model.exercises[1].id)
        assertCleared()
        seed()
        model.selectChapter("basics")
        assertCleared()
        seed()
        model.flushSave()
        let restored = AppModel(store: model.store)
        XCTAssertEqual(restored.code, model.code)
        XCTAssertNil(restored.lastRunDiagnostic)
        XCTAssertNil(restored.lastRunCode)
        XCTAssertNil(restored.editorRevealRequest)
        restored.flushSave()
    }

    @MainActor
    func testRunDiagnosticClearsOnInterpreterSetupFailure() async throws {
        model.lastRunCode = model.code
        model.lastRunDiagnostic = RunDiagnostic(exceptionType: "SyntaxError", message: "synthetic", origin: .learner,
                                                 frames: [.init(line: 1, function: "<module>")])
        model.revealDiagnosticLine()
        model.progress.pythonPath = "/nonexistent/python-teacher-test-python"
        model.runCode()
        try await waitForRun()
        XCTAssertNil(model.lastRunDiagnostic)
        XCTAssertNil(model.lastRunCode)
        XCTAssertNil(model.editorRevealRequest)
        XCTAssertNil(model.diagnosticGuidance)
        XCTAssertNil(model.diagnosticLine)
        XCTAssertFalse(model.output.isEmpty)
        XCTAssertTrue(model.feedback.contains("Execution could not complete"))
    }

    @MainActor
    func testDiagnosticGuidanceIsLocalFreshAndNeverShownInAssessments() {
        let types = ["SyntaxError", "IndentationError", "TabError", "NameError", "UnboundLocalError", "TypeError",
                     "ValueError", "IndexError", "KeyError", "AttributeError", "ZeroDivisionError", "AssertionError", "RuntimeError"]
        for mode in LearningMode.allCases {
            model.selectMode(mode)
            model.code = "print('synthetic')\n"
            model.lastRunCode = model.code
            for type in types {
                let diagnostic = RunDiagnostic(exceptionType: type, message: "synthetic exception message", origin: .learner,
                                               frames: [.init(line: 1, function: "<module>")])
                model.lastRunDiagnostic = diagnostic
                XCTAssertEqual(model.diagnosticGuidance == nil, mode == .assessment, type)
                XCTAssertEqual(model.diagnosticLine, 1)
                let card = RunFailureCard(diagnostic: diagnostic, assessment: mode == .assessment, stale: false,
                                          guidance: "must not appear in assessment", navigableLine: 1, reveal: {})
                XCTAssertEqual(card.displayedGuidance == nil, mode == .assessment)
                XCTAssertEqual(card.displayedMessage == nil, mode == .assessment)
            }
        }
        model.selectMode(.practice)
        model.code = "print('synthetic')\n"
        model.lastRunCode = model.code
        for origin in [RunDiagnostic.Origin.checks, .runner] {
            model.lastRunDiagnostic = RunDiagnostic(exceptionType: "AssertionError", message: "synthetic", origin: origin,
                                                     frames: [.init(line: 1, function: "<module>")])
            XCTAssertNil(model.diagnosticGuidance)
            XCTAssertNil(model.diagnosticLine)
            model.revealDiagnosticLine()
            XCTAssertNil(model.editorRevealRequest)
        }
        for line in [0, -1, 3, Int.max] {
            model.lastRunDiagnostic = RunDiagnostic(exceptionType: "NameError", message: "synthetic", origin: .learner,
                                                     frames: [.init(line: line, function: "<module>")])
            XCTAssertNil(model.diagnosticLine)
        }
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertEqual(model.hintCount, 0)
        XCTAssertEqual(model.requestCount, 0)
    }

    @MainActor
    func testEditsAfterPassingDoNotReuseStaleResults() async throws {
        model.selectMode(.practice)
        model.code = model.exercise.referenceSolution
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertTrue(model.progress.attempts.last?.testsPassed == true, model.output)
        model.code = model.exercise.starterCode
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertFalse(try XCTUnwrap(model.progress.attempts.last).testsPassed)
        XCTAssertEqual(model.progress.attempts.count, 2)
    }

    @MainActor
    func testRestoringStarterClearsRunEvidence() async throws {
        model.selectMode(.practice)
        model.code = model.exercise.referenceSolution
        model.runCode(test: true)
        try await waitForRun()
        XCTAssertNotNil(model.lastRunCode)
        XCTAssertFalse(model.isOutputStale)
        model.code += "\nprint('changed')"
        XCTAssertTrue(model.isOutputStale)
        XCTAssertTrue(model.feedback.contains("earlier version"))
        model.resetDraft()
        XCTAssertNil(model.lastRunCode)
        XCTAssertFalse(model.isOutputStale)
        XCTAssertFalse(model.output.contains("Tests passed"))
    }

    @MainActor
    func testHintLadderStopsAndSurvivesNavigationWithoutDuplicates() {
        model.selectMode(.practice)
        for _ in 0..<10 { model.showHint() }
        XCTAssertEqual(model.builtInHintCount, 3)
        XCTAssertEqual(model.hintCount, 3)
        XCTAssertEqual(model.messages.count, 3)
        XCTAssertFalse(model.canShowHint)
        model.selectMode(.lesson)
        model.selectMode(.practice)
        XCTAssertEqual(model.messages.count, 3)
        model.showHint()
        XCTAssertEqual(model.messages.count, 3)
        XCTAssertEqual(model.hintCount, 3)
    }

    @MainActor
    func testTeacherReceivesWholeCurrentCodeAndKeepsOlderRunDiagnosticsAfterEditing() async throws {
        let session = generationSession()
        defer { session.invalidateAndCancel() }
        model = AppModel(store: model.store, cloudConsent: true, teacherClientProvider: {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        })
        model.selectMode(.practice)
        model.code = "raise ValueError('synthetic_old_error')"
        model.runCode()
        try await waitForRun()
        XCTAssertTrue(model.output.contains("synthetic_old_error"), model.output)
        let currentCode = String(repeating: "value = 1\n", count: 2000) + "latest_tail = 'é'"
        model.code = currentCode
        GenerationURLProtocol.handler = { request in
            let input = try self.teacherRequestInput(request)
            let context = input.map { $0["content"] ?? "" }.joined(separator: "\n")
            XCTAssertTrue(context.contains("latest_tail"), "Do not silently cut off the editor after 16,000 characters")
            XCTAssertTrue(context.contains("synthetic_old_error"), "Retain the diagnostic with its older source version")
            let content = try XCTUnwrap(input.dropLast().last?["content"])
            let json = try XCTUnwrap(content.split(separator: "\n", maxSplits: 1).last)
            let snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            XCTAssertEqual(snapshot["currentCode"] as? String, currentCode)
            XCTAssertEqual(snapshot["runStatus"] as? String, "Latest run belongs to older code; current code has not been run")
            let run = try XCTUnwrap(snapshot["latestRun"] as? [String: Any])
            XCTAssertEqual(run["code"] as? String, "raise ValueError('synthetic_old_error')")
            return self.teacherResponse()
        }
        model.askTeacher("Can you see the change?")
        try await waitForGeneration()
        XCTAssertEqual(model.messages.last?.role, "assistant")
    }

    @MainActor
    func testTeacherSnapshotsTrackEditsRerunsChecksAndClearedEvidence() async throws {
        var snapshots: [[String: Any]] = []
        let session = mockTeacherSession { snapshots.append($0) }
        defer { session.invalidateAndCancel() }
        model.selectMode(.practice)
        model.code = "print('start_marker' + 'x' * 7000 + 'end_marker')"
        func ask() async throws {
            model.askTeacher("What about now?")
            try await waitForGeneration()
            XCTAssertNil(model.notice)
        }
        try await ask()
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.last?["currentCode"] as? String, model.code)
        XCTAssertNil(snapshots.last?["latestRun"])
        XCTAssertEqual(snapshots.last?["codeChange"] as? String, "No previous snapshot available for comparison")
        XCTAssertEqual(snapshots.last?["mode"] as? String, "Practice")
        XCTAssertEqual(snapshots.last?["exerciseID"] as? String, model.exercise.id)
        XCTAssertEqual(snapshots.last?["starterCode"] as? String, model.exercise.starterCode)
        XCTAssertNil(snapshots.last?["referenceSolution"])
        XCTAssertNil(snapshots.last?["testCode"])
        model.runCode()
        try await waitForRun()
        try await ask()
        var run = try XCTUnwrap(snapshots.last?["latestRun"] as? [String: Any])
        XCTAssertEqual(run["code"] as? String, model.code)
        XCTAssertEqual(run["output"] as? String, model.output)
        XCTAssertTrue((run["output"] as? String)?.hasPrefix("start_marker") == true)
        XCTAssertTrue((run["output"] as? String)?.contains("end_marker") == true)
        XCTAssertEqual(run["operation"] as? String, "Run")
        XCTAssertEqual(run["exitCode"] as? Int, 0)
        XCTAssertNil(run["checksPassed"])
        XCTAssertEqual(snapshots.last?["codeChange"] as? String, "Unchanged since previous teacher request")
        XCTAssertEqual(snapshots.last?["runChange"] as? String, "New run since previous teacher request")
        let firstRunID = run["id"] as? String
        try await ask()
        XCTAssertEqual(snapshots.last?["runChange"] as? String, "Unchanged since previous teacher request")
        model.runCode()
        try await waitForRun()
        try await ask()
        run = try XCTUnwrap(snapshots.last?["latestRun"] as? [String: Any])
        XCTAssertNotEqual(run["id"] as? String, firstRunID)
        XCTAssertEqual(snapshots.last?["runChange"] as? String, "New run since previous teacher request")
        model.code = "raise ValueError('new_error_marker')"
        try await ask()
        XCTAssertEqual(snapshots.last?["codeChange"] as? String, "Changed since previous teacher request")
        XCTAssertEqual(snapshots.last?["runStatus"] as? String, "Latest run belongs to older code; current code has not been run")
        model.runCode()
        try await waitForRun()
        try await ask()
        run = try XCTUnwrap(snapshots.last?["latestRun"] as? [String: Any])
        XCTAssertTrue((run["output"] as? String)?.contains("new_error_marker") == true)
        XCTAssertEqual(run["code"] as? String, model.code)
        XCTAssertNotEqual(run["exitCode"] as? Int, 0)
        XCTAssertEqual(snapshots.last?["runStatus"] as? String, "Latest run belongs to current code")
        model.code = model.exercise.referenceSolution
        model.runCode(test: true)
        try await waitForRun()
        try await ask()
        run = try XCTUnwrap(snapshots.last?["latestRun"] as? [String: Any])
        XCTAssertEqual(run["operation"] as? String, "Check solution")
        XCTAssertEqual(run["checksPassed"] as? Bool, true)
        model.code = model.exercise.starterCode
        model.runCode(test: true)
        try await waitForRun()
        try await ask()
        run = try XCTUnwrap(snapshots.last?["latestRun"] as? [String: Any])
        XCTAssertEqual(run["checksPassed"] as? Bool, false)
        model.resetDraft()
        try await ask()
        XCTAssertNil(snapshots.last?["latestRun"])
        XCTAssertEqual(snapshots.last?["runChange"] as? String, "Previous run evidence cleared")
    }

    @MainActor
    func testTeacherSnapshotVersionsSurviveRelaunchAndStayExerciseScoped() async throws {
        var snapshots: [[String: Any]] = []
        let session = mockTeacherSession { snapshots.append($0) }
        defer { session.invalidateAndCancel() }
        model.selectMode(.practice)
        let exerciseID = model.exercise.id
        model.code = "print('saved_code')"
        model.runCode()
        try await waitForRun()
        model.askTeacher("First question")
        try await waitForGeneration()
        let version = try XCTUnwrap(model.messages.first?.contextVersion)
        model.code = "print('edited_before_restart')"
        model.flushSave()
        model = AppModel(store: model.store, cloudConsent: true, teacherClientProvider: {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        })
        XCTAssertEqual(model.messages.first?.contextVersion, version)
        model.askTeacher("After restart")
        try await waitForGeneration()
        XCTAssertEqual(snapshots.last?["currentCode"] as? String, "print('edited_before_restart')")
        XCTAssertEqual(snapshots.last?["codeChange"] as? String, "Changed since previous teacher request")
        XCTAssertEqual(snapshots.last?["runChange"] as? String, "Previous run evidence cleared")
        XCTAssertNil(snapshots.last?["latestRun"])
        model.selectMode(.lesson)
        model.askTeacher("In the lesson")
        try await waitForGeneration()
        XCTAssertEqual(snapshots.last?["mode"] as? String, "Learn")
        XCTAssertEqual(snapshots.last?["codeChange"] as? String, "Unchanged since previous teacher request")
        model.selectExercise(model.exercises[1].id)
        model.askTeacher("Other exercise")
        try await waitForGeneration()
        XCTAssertEqual(snapshots.last?["codeChange"] as? String, "No previous snapshot available for comparison")
        model.selectExercise(exerciseID)
        model.askTeacher("Back again")
        try await waitForGeneration()
        XCTAssertEqual(snapshots.last?["codeChange"] as? String, "Unchanged since previous teacher request")
        let count = snapshots.count
        model.selectMode(.assessment)
        model.askTeacher("Do not send assessment code")
        XCTAssertEqual(snapshots.count, count)
        XCTAssertFalse(model.teacherBusy)
    }

    @MainActor
    func testTeacherSnapshotReportsRunnerSetupFailureInsteadOfReusingSuccess() async throws {
        var snapshots: [[String: Any]] = []
        let session = mockTeacherSession { snapshots.append($0) }
        defer { session.invalidateAndCancel() }
        model.selectMode(.practice)
        model.code = "print('old_success')"
        model.runCode()
        try await waitForRun()
        model.progress.pythonPath = "/missing/synthetic/python3"
        model.runCode(test: true)
        try await waitForRun()
        model.askTeacher("What failed?")
        try await waitForGeneration()
        let run = try XCTUnwrap(snapshots.last?["latestRun"] as? [String: Any])
        XCTAssertEqual(run["outcome"] as? String, "Execution could not complete")
        XCTAssertEqual(run["output"] as? String, model.output)
        XCTAssertEqual(run["code"] as? String, model.code)
        XCTAssertNil(run["checksPassed"])
        XCTAssertNil(run["exitCode"])
    }

    @MainActor
    func testTeacherOversizedContextDoesNotSendTruncatedCodeOrRecordAssistance() {
        let session = mockTeacherSession { _ in XCTFail("Oversized context must not reach the provider") }
        defer { session.invalidateAndCancel() }
        model.selectMode(.practice)
        model.code = String(repeating: "é", count: 140_000)
        model.askTeacher("Read everything")
        XCTAssertTrue(model.notice?.contains("No request was sent") == true)
        XCTAssertEqual(model.requestCount, 0)
        XCTAssertEqual(model.hintCount, 0)
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertFalse(model.teacherBusy)
        XCTAssertEqual(model.code.count, 140_000)
    }

    @MainActor
    func testTeacherDoesNotAppendReplyForDraftChangedDuringRequest() async throws {
        let session = mockTeacherSession { _ in }
        defer { session.invalidateAndCancel() }
        model.askTeacher("Inspect this code")
        model.code = "changed_while_waiting = 1"
        try await waitForGeneration()
        XCTAssertEqual(model.messages.map(\.role), ["user"])
        XCTAssertTrue(model.notice?.contains("outdated reply was not added") == true)
        XCTAssertEqual(model.requestCount, 1)
    }

    @MainActor
    private func mockTeacherSession(onSnapshot: @escaping ([String: Any]) -> Void) -> URLSession {
        let session = generationSession()
        GenerationURLProtocol.handler = { request in
            let input = try self.teacherRequestInput(request)
            let content = try XCTUnwrap(input.dropLast().last?["content"])
            let json = try XCTUnwrap(content.split(separator: "\n", maxSplits: 1).last)
            let snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            onSnapshot(snapshot)
            return self.teacherResponse()
        }
        model = AppModel(store: model.store, cloudConsent: true, teacherClientProvider: {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        })
        return session
    }

    private func teacherRequestInput(_ request: URLRequest) throws -> [[String: String]] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(body["input"] as? [[String: String]])
    }

    private func teacherResponse() -> (Int, Data) {
        (200, Data("{\"status\":\"completed\",\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"Inspect the current expression.\"}]}]}".utf8))
    }

    @MainActor
    func testTeacherRequestsDoNotSkipBuiltInHintsAndSolutionsAreNotSentInHistory() {
        model.selectMode(.practice)
        model.progress.hintCounts[model.draftKey] = 2
        model.showHint()
        XCTAssertEqual(model.builtInHintCount, 1)
        XCTAssertEqual(model.hintCount, 3)
        XCTAssertTrue(model.messages[0].text.hasPrefix("Hint 1"))
        model.revealSolution()
        XCTAssertEqual(model.messages.count, 2)
        XCTAssertEqual(model.teacherHistory.count, 1)
        XCTAssertFalse(model.teacherHistory.contains { $0.text.contains("Reference solution") })
    }

    @MainActor
    func testTeacherConversationsSurviveExerciseModeChapterChangesAndRelaunch() throws {
        model.selectMode(.practice)
        let firstID = model.exercise.id
        model.messages.append(TeacherMessage(role: "user", text: "What does print mean?"))
        model.messages.append(TeacherMessage(role: "assistant", text: "It displays a value."))
        model.showHint()
        model.revealSolution()
        let firstMessages = model.messages
        let history = model.teacherHistory.map(\.text)
        let secondID = model.exercises[1].id
        model.selectExercise(secondID)
        XCTAssertTrue(model.messages.isEmpty)
        model.messages.append(TeacherMessage(role: "user", text: "Explain the second task."))
        let secondMessages = model.messages
        model.selectExercise(firstID)
        XCTAssertEqual(model.messages.map(\.id), firstMessages.map(\.id))
        model.selectMode(.lesson)
        XCTAssertEqual(model.messages.map(\.id), firstMessages.map(\.id))
        model.selectMode(.assessment)
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertTrue(model.teacherHistory.isEmpty)
        model.selectChapter("values")
        XCTAssertTrue(model.messages.isEmpty)
        model.selectChapter("basics")
        XCTAssertEqual(model.messages.map(\.id), firstMessages.map(\.id))
        model.resetDraft()
        model.flushSave()
        let reloaded = AppModel(store: ProgressStore(directory: directory))
        XCTAssertEqual(reloaded.messages.map(\.id), firstMessages.map(\.id))
        XCTAssertEqual(reloaded.messages.map(\.text), firstMessages.map(\.text))
        XCTAssertEqual(reloaded.teacherHistory.map(\.text), history)
        XCTAssertFalse(reloaded.teacherHistory.contains { $0.text.contains("Reference solution") })
        reloaded.selectExercise(secondID)
        XCTAssertEqual(reloaded.messages.map(\.id), secondMessages.map(\.id))
        reloaded.flushSave()
    }

    @MainActor
    func testTeacherMessagesAutosaveWithoutNavigation() async throws {
        model.messages.append(TeacherMessage(role: "user", text: "What is a string?"))
        model.messages.append(TeacherMessage(role: "assistant", text: "A string is text."))
        try await Task.sleep(for: .milliseconds(750))
        let reloaded = AppModel(store: ProgressStore(directory: directory))
        XCTAssertEqual(reloaded.messages.map(\.id), model.messages.map(\.id))
        XCTAssertEqual(reloaded.messages.map(\.text), model.messages.map(\.text))
        reloaded.flushSave()
    }

    @MainActor
    func testHighlightingDoesNotMutateTextStorageOrComposition() throws {
        _ = NSApplication.shared
        var code = "label = \nprint(label)\n"
        let coordinator = CodeEditor(text: Binding(get: { code }, set: { code = $0 })).makeCoordinator()
        let editor = PythonTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        editor.isRichText = false
        editor.string = code
        editor.setSelectedRange(NSRange(location: 8, length: 0))
        editor.setMarkedText("\"", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        let storage = try XCTUnwrap(editor.textStorage)
        let original = NSAttributedString(attributedString: storage)
        let selection = editor.selectedRange()
        let markedRange = editor.markedRange()
        coordinator.highlight(editor)
        XCTAssertTrue(storage.isEqual(to: original), "Highlighting must not edit the backing text storage")
        XCTAssertEqual(editor.selectedRange(), selection)
        XCTAssertEqual(editor.markedRange(), markedRange)
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        XCTAssertEqual(code, "label = \nprint(label)\n", "Uncommitted input must not round-trip through SwiftUI")
        editor.insertText("\"", replacementRange: editor.markedRange())
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        XCTAssertEqual(code, "label = \"\nprint(label)\n")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 9, length: 0))
    }

    @MainActor
    func testLegacyHintsAreRestoredOnlyOnceIntoConversation() {
        let key = model.draftKey
        model.progress.hintCounts[key + ":builtin"] = 2
        model.selectMode(.practice)
        let messages = model.messages
        XCTAssertEqual(messages.count, 2)
        model.selectMode(.lesson)
        model.selectMode(.practice)
        XCTAssertEqual(model.messages, messages)
        model.flushSave()
        let reloaded = AppModel(store: ProgressStore(directory: directory))
        XCTAssertEqual(reloaded.messages, messages)
        reloaded.flushSave()
    }

    @MainActor
    func testSyntaxColorsAreTemporaryAndPreserveSelection() throws {
        _ = NSApplication.shared
        let code = "print(42)\n"
        let coordinator = CodeEditor(text: .constant(code)).makeCoordinator()
        let editor = PythonTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        editor.string = code
        editor.setSelectedRange(NSRange(location: 2, length: 3))
        let storage = try XCTUnwrap(editor.textStorage)
        let original = NSAttributedString(attributedString: storage)
        coordinator.highlight(editor)
        XCTAssertTrue(storage.isEqual(to: original))
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 2, length: 3))
        XCTAssertEqual(editor.layoutManager?.temporaryAttribute(.foregroundColor, atCharacterIndex: 0, effectiveRange: nil) as? NSColor, .systemTeal)
        XCTAssertEqual(editor.layoutManager?.temporaryAttribute(.foregroundColor, atCharacterIndex: 6, effectiveRange: nil) as? NSColor, .systemOrange)
    }

    @MainActor
    func testInternationalDeadQuoteKeysResolveWithoutAFollowingSpace() throws {
        _ = NSApplication.shared
        let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.USInternational-PC"] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
        let source = try XCTUnwrap(sources.first)
        for (flags, expected) in [(NSEvent.ModifierFlags.shift, "\""), (NSEvent.ModifierFlags(), "'")] {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                                     timestamp: 0, windowNumber: 0, context: nil, characters: "",
                                                     charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(kVK_ANSI_Quote)))
            XCTAssertEqual(PythonTextView.literalQuote(for: event, inputSource: source), expected)
        }
        for flags: NSEvent.ModifierFlags in [.command, .control, .option] {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                                     timestamp: 0, windowNumber: 0, context: nil, characters: "\"",
                                                     charactersIgnoringModifiers: "\"", isARepeat: false, keyCode: UInt16(kVK_ANSI_Quote)))
            XCTAssertNil(PythonTextView.literalQuote(for: event, inputSource: source))
        }
        let accent = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                  timestamp: 0, windowNumber: 0, context: nil, characters: "",
                                                  charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(kVK_ANSI_Grave)))
        XCTAssertNil(PythonTextView.literalQuote(for: accent, inputSource: source))
    }

    @MainActor
    func testTeacherChatShiftReturnInsertsNewlineAtSelectionAndReturnSubmits() async throws {
        _ = NSApplication.shared
        model.requestCount = model.progress.sessionRequestLimit
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 740), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: TeacherPanel().environmentObject(model))
        window.contentView = hosting
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(150))
        while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) {
            NSApp.sendEvent(event)
        }
        func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }
        let field = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? NSTextField }.first { $0.isEditable })
        XCTAssertTrue(window.makeFirstResponder(field))
        let editor = try XCTUnwrap(window.firstResponder as? NSTextView)
        editor.insertText("First line replace second line", replacementRange: NSRange(location: 0, length: 0))
        editor.setSelectedRange(NSRange(location: 10, length: 9))
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .shift,
                                                 timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\r",
                                                 charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: UInt16(kVK_Return)))
        window.sendEvent(event)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(editor.string, "First line\nsecond line")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 11, length: 0))
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertNil(model.notice)
        editor.insertText("More detail\n", replacementRange: editor.selectedRange())
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(field.stringValue, "First line\nMore detail\nsecond line")
        let submit = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                  timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\r",
                                                  charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: UInt16(kVK_Return)))
        window.sendEvent(submit)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(field.stringValue, "")
        XCTAssertNotNil(model.notice)
        XCTAssertEqual(model.requestCount, model.progress.sessionRequestLimit)
        model.notice = nil
        XCTAssertTrue(window.makeFirstResponder(field))
        window.sendEvent(submit)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(model.notice)
    }

    @MainActor
    func testHostedEditorQuoteTypingCompositionAndUndoKeepCaretInPlace() async throws {
        _ = NSApplication.shared
        model.code = "label = \nprint(label)\n"
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: CodeEditor(text: Binding(get: { self.model.code }, set: { self.model.code = $0 })))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }
        let editor = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? PythonTextView }.first)
        window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 8, length: 0))
        let undo = try XCTUnwrap(editor.undoManager)
        undo.beginUndoGrouping()
        for character in "\"hello\"" {
            let text = String(character)
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                     timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: text,
                                                     charactersIgnoringModifiers: text, isARepeat: false, keyCode: 0))
            editor.keyDown(with: event)
        }
        undo.endUndoGrouping()
        XCTAssertEqual(editor.string, "label = \"hello\"\nprint(label)\n")
        XCTAssertEqual(model.code, editor.string)
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 15, length: 0))
        undo.undo()
        XCTAssertEqual(editor.string, "label = \nprint(label)\n")
        XCTAssertEqual(model.code, editor.string)
        undo.redo()
        XCTAssertEqual(editor.string, "label = \"hello\"\nprint(label)\n")
        editor.setSelectedRange(NSRange(location: 9, length: 5))
        editor.setMarkedText("é", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        hosting.rootView = CodeEditor(text: Binding(get: { self.model.code }, set: { self.model.code = $0 }))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(editor.hasMarkedText())
        XCTAssertEqual(editor.string, "label = \"é\"\nprint(label)\n")
        XCTAssertEqual(model.code, "label = \"hello\"\nprint(label)\n")
        editor.insertText("é", replacementRange: editor.markedRange())
        XCTAssertEqual(model.code, "label = \"é\"\nprint(label)\n")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 10, length: 0))
    }

    func testEditorRevealLineRangesUseUTF16AndHandleBlankFinalAndInvalidLines() {
        let source = "name = '𐐀e\u{301}'\r\n\r\nprint(name)\n"
        let firstLength = "name = '𐐀e\u{301}'".utf16.count
        XCTAssertEqual(EditorRevealRequest.lineRange(1, in: source), NSRange(location: 0, length: firstLength))
        XCTAssertEqual(EditorRevealRequest.lineRange(2, in: source), NSRange(location: firstLength + 2, length: 0))
        XCTAssertEqual(EditorRevealRequest.lineRange(3, in: source), NSRange(location: firstLength + 4, length: 11))
        XCTAssertEqual(EditorRevealRequest.lineRange(4, in: source), NSRange(location: source.utf16.count, length: 0))
        XCTAssertEqual(EditorRevealRequest.lineRange(1, in: ""), NSRange(location: 0, length: 0))
        XCTAssertNil(EditorRevealRequest.lineRange(2, in: ""))
        XCTAssertEqual(EditorRevealRequest.lineRange(2, in: "a\rb"), NSRange(location: 2, length: 1))
        XCTAssertEqual(EditorRevealRequest.lineRange(1, in: "a\u{2028}b"), NSRange(location: 0, length: 3))
        for line in [-1, 0, 5, Int.max] { XCTAssertNil(EditorRevealRequest.lineRange(line, in: source)) }
    }

    @MainActor
    func testHostedEditorExplicitRevealRepeatsScrollsAndPreservesTextAndUndo() async throws {
        _ = NSApplication.shared
        let original = "name = '𐐀café'\n\n" + String(repeating: "print(name)\n", count: 100)
        model.code = original
        let binding = Binding(get: { self.model.code }, set: { self.model.code = $0 })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: CodeEditor(text: binding, sourceIdentity: "draft"))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        func descendants(of view: NSView) -> [NSView] { view.subviews.flatMap { [$0] + descendants(of: $0) } }
        let editor = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? PythonTextView }.first)
        XCTAssertTrue(window.makeFirstResponder(editor))
        let undo = try XCTUnwrap(editor.undoManager)
        undo.beginUndoGrouping()
        editor.insertText("print('final')", replacementRange: NSRange(location: original.utf16.count, length: 0))
        undo.endUndoGrouping()
        let source = model.code
        XCTAssertTrue(undo.canUndo)
        XCTAssertTrue(window.makeFirstResponder(window))
        let responder = window.firstResponder
        hosting.rootView = CodeEditor(text: binding, sourceIdentity: "draft")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(window.firstResponder === responder, "Ordinary updates must not focus the editor")
        let storage = try XCTUnwrap(editor.textStorage)
        let originalStorage = NSAttributedString(attributedString: storage)
        let lastRange = try XCTUnwrap(EditorRevealRequest.lineRange(103, in: source))
        var previousID: UUID?
        for _ in 0..<2 {
            editor.setSelectedRange(NSRange(location: 0, length: 0))
            editor.scrollRangeToVisible(editor.selectedRange())
            let request = EditorRevealRequest(sourceIdentity: "draft", source: source, line: 103)
            XCTAssertNotEqual(request.id, previousID)
            previousID = request.id
            hosting.rootView = CodeEditor(text: binding, sourceIdentity: "draft", revealRequest: request)
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(editor.selectedRange(), lastRange)
            XCTAssertTrue(window.firstResponder === editor)
            let layout = try XCTUnwrap(editor.layoutManager)
            let container = try XCTUnwrap(editor.textContainer)
            let rect = layout.boundingRect(forGlyphRange: layout.glyphRange(forCharacterRange: lastRange, actualCharacterRange: nil), in: container)
                .offsetBy(dx: editor.textContainerOrigin.x, dy: editor.textContainerOrigin.y)
            XCTAssertTrue(editor.visibleRect.intersects(rect))
            editor.setSelectedRange(NSRange(location: 0, length: 0))
            hosting.rootView = CodeEditor(text: binding, sourceIdentity: "draft", revealRequest: request)
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 0), "A consumed request must not replay on updates")
        }
        for line in [1, 2, 103] {
            hosting.rootView = CodeEditor(text: binding, sourceIdentity: "draft",
                                          revealRequest: EditorRevealRequest(sourceIdentity: "draft", source: source, line: line))
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(editor.selectedRange(), EditorRevealRequest.lineRange(line, in: source))
        }
        for request in [EditorRevealRequest(sourceIdentity: "draft", source: source, line: 0),
                        EditorRevealRequest(sourceIdentity: "draft", source: source, line: Int.max),
                        EditorRevealRequest(sourceIdentity: "old-draft", source: source, line: 1),
                        EditorRevealRequest(sourceIdentity: "draft", source: original, line: 1)] {
            let selection = editor.selectedRange()
            hosting.rootView = CodeEditor(text: binding, sourceIdentity: "draft", revealRequest: request)
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(editor.selectedRange(), selection)
        }
        XCTAssertTrue(storage.isEqual(to: originalStorage))
        XCTAssertEqual(editor.string, source)
        XCTAssertEqual(model.code, source)
        XCTAssertFalse(undo.canRedo)
        undo.undo()
        XCTAssertEqual(editor.string, original, "Reveal must neither add undo entries nor erase existing undo")
        XCTAssertEqual(model.code, original)
        hosting.rootView = CodeEditor(text: binding, sourceIdentity: "draft",
                                      revealRequest: EditorRevealRequest(sourceIdentity: "draft", source: original, line: 103))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(editor.selectedRange(), NSRange(location: original.utf16.count, length: 0))
        XCTAssertTrue(undo.canRedo)
        undo.redo()
        XCTAssertEqual(editor.string, source)
    }

    @MainActor
    func testEditorRevealPreservesMarkedTextAndNeverDefersItsJump() throws {
        _ = NSApplication.shared
        var code = "label = \nprint(label)\n"
        let binding = Binding(get: { code }, set: { code = $0 })
        let request = EditorRevealRequest(sourceIdentity: "draft", source: code, line: 2)
        let coordinator = CodeEditor(text: binding, sourceIdentity: "draft", revealRequest: request).makeCoordinator()
        let editor = PythonTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        editor.string = code
        editor.setSelectedRange(NSRange(location: 8, length: 0))
        editor.setMarkedText("é", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        let storage = try XCTUnwrap(editor.textStorage)
        let before = NSAttributedString(attributedString: storage)
        let selection = editor.selectedRange()
        let marked = editor.markedRange()
        coordinator.reveal(in: editor)
        XCTAssertTrue(storage.isEqual(to: before))
        XCTAssertEqual(editor.markedRange(), marked)
        XCTAssertEqual(editor.selectedRange(), selection)
        editor.insertText("", replacementRange: editor.markedRange())
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertEqual(editor.string, code)
        coordinator.reveal(in: editor)
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 0))
    }

    @MainActor
    func testHostedEditorFindCommandsNavigateWithoutChangingDraft() async throws {
        _ = NSApplication.shared
        let original = "title = 'café'\n" + String(repeating: "print(title)\n", count: 100) + "result = title\n"
        model.code = original
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: CodeEditor(text: Binding(get: { self.model.code }, set: { self.model.code = $0 })))
        window.contentView = hosting
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(150))
        while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) {
            NSApp.sendEvent(event)
        }
        func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }
        let editor = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? PythonTextView }.first)
        let scroll = try XCTUnwrap(editor.enclosingScrollView)
        XCTAssertTrue(window.makeFirstResponder(editor))
        for _ in 0..<10 where NSApp.keyWindow !== window {
            try await Task.sleep(for: .milliseconds(100))
            while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
            window.makeKeyAndOrderFront(nil)
        }
        let keyWindow = try XCTUnwrap(NSApp.keyWindow)
        XCTAssertTrue(keyWindow === window)
        XCTAssertTrue(CodeEditorFindCommands.perform(.showFindInterface))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(scroll.isFindBarVisible)
        XCTAssertNotNil(scroll.findBarView)
        XCTAssertFalse(window.firstResponder === editor, "Find should focus its search field")
        let fieldEditor = try XCTUnwrap(window.firstResponder as? NSTextView)
        fieldEditor.insertText("title", replacementRange: NSRange(location: 0, length: fieldEditor.string.utf16.count))
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(CodeEditorFindCommands.perform(.nextMatch), "Find next must work while the search field is focused")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(window.makeFirstResponder(editor))
        XCTAssertEqual((editor.string as NSString).substring(with: editor.selectedRange()), "title")
        editor.setSelectedRange(NSRange(location: 0, length: 5))
        XCTAssertTrue(CodeEditorFindCommands.perform(.setSearchString))
        XCTAssertTrue(CodeEditorFindCommands.perform(.nextMatch))
        let second = (original as NSString).range(of: "title", options: [], range: NSRange(location: 5, length: original.utf16.count - 5))
        XCTAssertEqual(editor.selectedRange(), second)
        XCTAssertTrue(CodeEditorFindCommands.perform(.previousMatch))
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 5))
        XCTAssertTrue(CodeEditorFindCommands.perform(.previousMatch))
        let last = (original as NSString).range(of: "title", options: .backwards)
        XCTAssertEqual(editor.selectedRange(), last, "Search should wrap to the end of long code")
        let layout = try XCTUnwrap(editor.layoutManager)
        let container = try XCTUnwrap(editor.textContainer)
        let matchRect = layout.boundingRect(forGlyphRange: layout.glyphRange(forCharacterRange: last, actualCharacterRange: nil), in: container)
            .offsetBy(dx: editor.textContainerOrigin.x, dy: editor.textContainerOrigin.y)
        XCTAssertTrue(editor.visibleRect.intersects(matchRect), "An offscreen match must scroll into view")
        XCTAssertTrue(CodeEditorFindCommands.perform(.nextMatch))
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 5))
        editor.isEditable = false
        XCTAssertTrue(CodeEditorFindCommands.perform(.nextMatch))
        XCTAssertEqual(editor.selectedRange(), second, "Read-only code must remain searchable")
        XCTAssertTrue(editor.isIncrementalSearchingEnabled)
        for query in ["café", "no_such_variable_837", ""] {
            XCTAssertTrue(CodeEditorFindCommands.perform(.showFindInterface))
            let searchEditor = try XCTUnwrap(window.firstResponder as? NSTextView)
            XCTAssertFalse(searchEditor === editor)
            searchEditor.insertText(query, replacementRange: NSRange(location: 0, length: searchEditor.string.utf16.count))
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertTrue(CodeEditorFindCommands.perform(.nextMatch))
            if query == "café" {
                XCTAssertTrue(window.makeFirstResponder(editor))
                XCTAssertEqual(editor.selectedRange(), (original as NSString).range(of: query))
            }
            XCTAssertEqual(editor.string, original)
        }
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                  timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
                                                  charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: UInt16(kVK_Escape)))
        window.sendEvent(escape)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(scroll.isFindBarVisible)
        XCTAssertTrue(window.firstResponder === editor, "Escape should return focus to the code")
        XCTAssertEqual(editor.string, original)
        XCTAssertEqual(model.code, original)
        XCTAssertFalse(editor.undoManager?.canUndo ?? false, "Searching must not create text edits")
    }

    @MainActor
    func testNativeEditorIndentationUndoAndEmptyRulerRendering() {
        _ = NSApplication.shared
        let editor = PythonTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        editor.isRichText = false
        editor.allowsUndo = true
        editor.string = "if True:"
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        editor.insertNewline(nil)
        XCTAssertEqual(editor.string, "if True:\n    ")
        editor.insertTab(nil)
        XCTAssertEqual(editor.string, "if True:\n        ")
        editor.string = ""
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scroll.documentView = editor
        let ruler = LineNumberRuler(textView: editor, scrollView: scroll)
        let image = NSImage(size: NSSize(width: 48, height: 300))
        image.lockFocus()
        ruler.drawHashMarksAndLabels(in: NSRect(x: 0, y: 0, width: 48, height: 300))
        image.unlockFocus()
    }

    @MainActor
    func testNativeFailureCardsRenderAtDefaultAndMinimumSizesWithoutShrinkingEditor() async throws {
        _ = NSApplication.shared
        for size in [NSSize(width: 1380, height: 900), NSSize(width: 1080, height: 740)] {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: WorkspaceView().environmentObject(model))
            window.contentView = hosting
            window.orderFront(nil)
            defer { window.close() }
            func descendants(of view: NSView) -> [NSView] { view.subviews.flatMap { [$0] + descendants(of: $0) } }
            for mode in LearningMode.allCases {
                model.selectMode(mode)
                model.code = "def read_count():\n    return int('not a number')\n\nread_count()\n"
                try await Task.sleep(for: .milliseconds(200))
                hosting.layoutSubtreeIfNeeded()
                let editor = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? PythonTextView }.first)
                let scroll = try XCTUnwrap(editor.enclosingScrollView)
                let baselineHeight = scroll.frame.height
                let baselineWidth = scroll.frame.width
                model.lastRunCode = model.code
                model.lastRunDiagnostic = RunDiagnostic(exceptionType: "ValueError", message: "invalid literal for int() with base 10: 'not a number'",
                                                         origin: .learner, frames: [.init(line: 4, function: "<module>"), .init(line: 2, function: "read_count")])
                model.output = "Traceback (most recent call last):\n  File \"main.py\", line 4, in <module>\n    read_count()\n  File \"main.py\", line 2, in read_count\n    return int('not a number')\nValueError: invalid literal for int() with base 10: 'not a number'"
                let originalOutput = model.output
                let selection = editor.selectedRange()
                try await Task.sleep(for: .milliseconds(200))
                hosting.layoutSubtreeIfNeeded()
                XCTAssertEqual(scroll.frame.height, baselineHeight, accuracy: 1, "The supplementary card must not take height from the editor")
                XCTAssertEqual(scroll.frame.width, baselineWidth, accuracy: 1)
                XCTAssertEqual(editor.selectedRange(), selection, "Receiving diagnostics must not navigate automatically")
                XCTAssertEqual(model.output, originalOutput)
                let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, Int(size.width))
                XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, Int(size.height))
                let name = "failure-\(mode.rawValue.lowercased())-\(Int(size.width))"
                try saveSnapshot(of: hosting, name: name)
                if mode == .practice {
                    model.code += "\n"
                    try await Task.sleep(for: .milliseconds(150))
                    hosting.layoutSubtreeIfNeeded()
                    XCTAssertNil(model.diagnosticLine)
                    XCTAssertNil(model.diagnosticGuidance)
                    XCTAssertEqual(model.output, originalOutput)
                    XCTAssertEqual(scroll.frame.height, baselineHeight, accuracy: 1)
                    try saveSnapshot(of: hosting, name: name + "-stale")
                }
            }
        }
    }

    @MainActor
    func testNativeWorkspaceRendersEveryLearningMode() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1380, height: 900), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: WorkspaceView().environmentObject(model))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        for mode in LearningMode.allCases {
            model.selectMode(mode)
            try await Task.sleep(for: .milliseconds(350))
            hosting.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(hosting.frame.width, 1000)
            XCTAssertGreaterThan(hosting.frame.height, 700)
            try assertCodingArea(in: hosting)
            try saveSnapshot(of: hosting, name: mode.rawValue.lowercased())
        }
    }

    @MainActor
    func testExpandedInstructionsRenderAtMinimumWindowSize() async throws {
        _ = NSApplication.shared
        model.selectChapter("values")
        model.overrideUnlock()
        model.selectExercise("values-label")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: WorkspaceView().environmentObject(model))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        for mode in LearningMode.allCases {
            model.selectMode(mode)
            try await Task.sleep(for: .milliseconds(350))
            hosting.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            XCTAssertEqual(hosting.frame.width, 1080, accuracy: 1)
            XCTAssertEqual(hosting.frame.height, 740, accuracy: 1)
            XCTAssertTrue(model.exercise.instructions.contains("Your task:"))
            try assertCodingArea(in: hosting)
            try saveSnapshot(of: hosting, name: "minimum-\(mode.rawValue.lowercased())")
        }
    }

    @MainActor
    func testSavedIncompleteExerciseRemainsAvailableWithoutChangingItsDraft() async throws {
        _ = NSApplication.shared
        var exercise = model.exercise
        exercise.id = "generated-incomplete-synthetic"
        exercise.title = "Incomplete synthetic JSON example"
        exercise.instructions = "Goal:\nCount synthetic records.\n\nStarting code:\n`json.dumps({\"b\": 1})` returns `'{"
        model.progress.generatedExercises[model.chapter.id] = [exercise]
        model.selectMode(.practice)
        model.selectExercise(exercise.id)
        model.code = "total = 2"
        model.flushSave()
        let restored = AppModel(store: model.store)
        XCTAssertEqual(restored.exercise, exercise)
        XCTAssertEqual(restored.code, "total = 2")
        XCTAssertFalse(restored.exercise.hasRequiredInstructionSections)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: WorkspaceView().environmentObject(restored))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(350))
        hosting.layoutSubtreeIfNeeded()
        try assertCodingArea(in: hosting)
        try saveSnapshot(of: hosting, name: "incomplete-generated-instructions")
        XCTAssertEqual(try model.store.load().generatedExercises[model.chapter.id], [exercise])
    }

    @MainActor
    func testAssessmentTheoryTabRendersExecutionErrors() async throws {
        _ = NSApplication.shared
        model.selectMode(.assessment)
        model.output = "Traceback: synthetic assessment error"
        model.feedback = "Code checks did not pass."
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1380, height: 900), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: WorkspaceView(assessmentTab: 1).environmentObject(model))
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(350))
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        XCTAssertGreaterThan(bitmap.pixelsWide, 1000)
        XCTAssertGreaterThan(bitmap.pixelsHigh, 700)
        try assertCodingArea(in: hosting)
    }

    @MainActor
    func testCancellationDoesNotRecordAnAttempt() async throws {
        model.selectMode(.practice)
        model.code = "while True:\n    pass"
        model.runCode(test: true)
        try await Task.sleep(for: .milliseconds(150))
        model.cancelWork()
        try await waitForRun()
        XCTAssertTrue(model.progress.attempts.isEmpty)
        XCTAssertTrue(model.feedback.contains("cancelled"), model.feedback)
    }

    @MainActor
    private func saveSnapshot(of hosting: NSView, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["PYTHON_TEACHER_UI_SNAPSHOTS_DIR"] else { return }
        let destination = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: destination.appendingPathComponent("\(name).png"))
    }

    @MainActor
    private func assertCodingArea(in hosting: NSView) throws {
        func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }
        let editor = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? PythonTextView }.first)
        let scroll = try XCTUnwrap(editor.enclosingScrollView)
        let frame = hosting.convert(scroll.bounds, from: scroll)
        XCTAssertGreaterThanOrEqual(frame.minX, 300)
        XCTAssertLessThan(frame.minX, hosting.bounds.width / 2)
        XCTAssertGreaterThanOrEqual(frame.width, 400)
        XCTAssertGreaterThan(frame.height, hosting.bounds.height * 0.45)
        let topInset = hosting.isFlipped ? frame.minY : hosting.bounds.height - frame.maxY
        XCTAssertLessThan(topInset, 150)
    }

    @MainActor
    private func waitForRun() async throws {
        let deadline = Date().addingTimeInterval(15)
        while model.running && Date() < deadline { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertFalse(model.running, "Runner exceeded test deadline")
    }
}
