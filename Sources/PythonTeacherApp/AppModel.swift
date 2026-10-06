import AppKit
import PythonTeacherCore
import Combine
import CryptoKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var progress: ProgressState
    @Published var code = "" {
        didSet {
            guard !loading else { return }
            progress.drafts[draftKey] = code
            if isOutputStale { feedback = "Code changed since the last run. The output below belongs to an earlier version; run checks again." }
            scheduleSave()
        }
    }
    @Published var reflection = "" {
        didSet {
            guard !loading else { return }
            progress.reflections[draftKey] = reflection
            scheduleSave()
        }
    }
    @Published var output = "Run your code to see its output here."
    @Published var feedback = ""
    @Published var lastRunCode: String?
    @Published var running = false
    @Published var teacherBusy = false
    @Published private(set) var updatingRewards = false
    @Published private(set) var generationState = PracticeGenerationState.idle
    @Published private(set) var rejectedPractice: RejectedPractice?
    var messages: [TeacherMessage] {
        get { mode == .assessment ? [] : progress.teacherConversations[draftKey] ?? [] }
        set {
            guard mode != .assessment else { return }
            progress.teacherConversations[draftKey] = newValue
            scheduleSave()
        }
    }
    @Published var notice: String?
    @Published var settingsPresented = false
    @Published var hasAPIKey = false
    @Published var requestCount = 0
    @Published var inputTokens = 0
    @Published var outputTokens = 0
    @Published private(set) var focusRunning = false
    @Published private(set) var rewardCelebration: RewardCelebration?
    @Published var storageLocked = false
    @Published var saveStatus = "Saved locally"
    @Published var cloudConsent: Bool {
        didSet { UserDefaults.standard.set(cloudConsent, forKey: "cloudConsent") }
    }

    let chapters: [Chapter]
    let curriculumGraph: CurriculumGraph
    let store: ProgressStore
    let runner = PythonRunner()
    private let teacherClientProvider: (() throws -> TeacherClient)?
    private var loading = false
    private var saveTask: Task<Void, Never>?
    private var workTask: Task<Void, Never>?
    private var teacherRun: TeacherRunEvidence?
    private var focusTimer: AnyCancellable?
    private var sleepObserver: AnyCancellable?
    private var focusLastTick: TimeInterval?
    private var focusLastSaved: TimeInterval = 0
    private let focusNow: () -> Date
    private let focusClock: () -> TimeInterval
    private var celebrationTask: Task<Void, Never>?
    private var celebrationQueue: [RewardCelebration] = []

    init(store: ProgressStore = ProgressStore(), focusNow: @escaping () -> Date = Date.init,
         focusClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         cloudConsent: Bool? = nil, teacherClientProvider: (() throws -> TeacherClient)? = nil,
         chapters: [Chapter] = Curriculum.chapters) {
        precondition(!chapters.isEmpty, "The curriculum must contain at least one chapter.")
        self.chapters = chapters
        self.curriculumGraph = CurriculumGraph(chapters)
        self.teacherClientProvider = teacherClientProvider
        self.store = store
        self.focusNow = focusNow
        self.focusClock = focusClock
        self.cloudConsent = cloudConsent ?? UserDefaults.standard.bool(forKey: "cloudConsent")
        do {
            self.progress = try store.load()
        } catch {
            self.progress = ProgressState()
            self.storageLocked = true
            self.notice = "Saved progress could not be loaded. It has not been overwritten. Export this session if needed, and inspect the data folder. \(error.localizedDescription)"
            self.saveStatus = "Saving blocked: existing data needs recovery"
        }
        if !chapters.contains(where: { $0.id == progress.selectedChapterID }) {
            progress.selectedChapterID = rootChapter.id
        }
        if progress.pythonPath == "/usr/bin/python3" {
            let candidates = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/Applications/Xcode.app/Contents/Developer/usr/bin/python3", "/usr/bin/python3"]
            if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                progress.pythonPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            }
        }
        resetWorkspace()
        flushSave()
        sleepObserver = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.pauseFocusSession() }
    }

    /// Copies preferences saved under the app's former bundle identifier or executable name when none exist yet.
    static func migrateLegacyDefaults(_ defaults: UserDefaults = .standard,
                                      legacyDomains: [String] = ["local.codingteacher.app", "CodingTeacher"]) {
        guard defaults.object(forKey: "cloudConsent") == nil,
              let value = legacyDomains.lazy.compactMap({ defaults.persistentDomain(forName: $0)?["cloudConsent"] }).first
        else { return }
        defaults.set(value, forKey: "cloudConsent")
    }

    var chapter: Chapter { chapters.first { $0.id == progress.selectedChapterID } ?? rootChapter }
    /// The chapter without prerequisites where every learner starts.
    var rootChapter: Chapter {
        curriculumGraph.chapter(CurriculumGraph.rootChapterID) ?? chapters.first { $0.prerequisites.isEmpty } ?? chapters[0]
    }
    /// The current chapter's transitive prerequisites in canonical order (empty when it has none or the graph is invalid).
    var prerequisiteChapters: [Chapter] { curriculumGraph.prerequisiteClosure(of: chapter.id) ?? [] }
    var directPrerequisites: [Chapter] { curriculumGraph.directPrerequisites(of: chapter.id) ?? [] }
    var missingPrerequisites: [Chapter] { missingPrerequisites(for: chapter.id) }
    var mode: LearningMode { progress.selectedMode }
    var exercises: [Exercise] {
        (chapter.exercises + savedLegacyExercises(mode: .practice) + (progress.generatedExercises[chapter.id] ?? []))
            .filter { !Curriculum.isAssessment($0.id, in: chapters) }
    }
    var assessments: [Exercise] { [chapter.assessment] + savedLegacyExercises(mode: .assessment) }
    private var assessmentSelectionKey: String { "\(chapter.id):assessment" }
    var exercise: Exercise {
        if mode == .assessment {
            return assessments.first { $0.id == progress.selectedExerciseIDs[assessmentSelectionKey] }
                ?? savedLegacyExercises(mode: .assessment).first ?? chapter.assessment
        }
        return exercises.first { $0.id == progress.selectedExerciseIDs[chapter.id] } ?? chapter.exercises[0]
    }

    private func savedLegacyExercises(mode: LearningMode) -> [Exercise] {
        Curriculum.legacyExercises(chapterID: chapter.id, mode: mode).filter { exercise in
            let key = "\(chapter.id):\(mode == .assessment ? "assessment" : "practice"):\(exercise.id)"
            return progress.drafts[key] != nil || progress.reflections[key] != nil
                || progress.hintCounts[key] != nil || progress.hintCounts[key + ":builtin"] != nil
                || progress.revealedSolutions.contains(key) || progress.teacherConversations[key] != nil
                || progress.selectedExerciseIDs[chapter.id] == exercise.id
                || progress.selectedExerciseIDs[assessmentSelectionKey] == exercise.id
                || progress.attempts.contains { $0.chapterID == chapter.id && $0.exerciseID == exercise.id && $0.mode == mode }
        }
    }

    var isLegacyExercise: Bool {
        Curriculum.legacyExercises(chapterID: chapter.id, mode: mode == .assessment ? .assessment : .practice)
            .contains { $0.id == exercise.id }
    }
    var completedPracticeExerciseIDs: Set<String> {
        Set(progress.attempts.filter { $0.chapterID == chapter.id && $0.mode == .practice && $0.testsPassed }.map(\.exerciseID))
            .intersection(exercises.map(\.id))
    }

    func exercisePickerTitle(_ exercise: Exercise) -> String {
        completedPracticeExerciseIDs.contains(exercise.id) ? "✓ \(exercise.title)" : exercise.title
    }

    var draftKey: String { "\(chapter.id):\(mode == .assessment ? "assessment" : "practice"):\(exercise.id)" }
    var isBusy: Bool { running || teacherBusy || updatingRewards }
    var isUnlocked: Bool { progress.isUnlocked(chapter.id, in: chapters) }
    var hintCount: Int { max(0, progress.hintCounts[draftKey] ?? 0) }
    var builtInHintCount: Int { min(exercise.hints.count, max(0, progress.hintCounts[draftKey + ":builtin"] ?? 0)) }
    var canShowHint: Bool { builtInHintCount < exercise.hints.count }
    var isOutputStale: Bool { lastRunCode != nil && lastRunCode != code }
    var teacherHistory: [(role: String, text: String)] { messages.filter(\.includeInContext).map { (role: $0.role, text: $0.text) } }
    var solutionRevealed: Bool { progress.revealedSolutions.contains(draftKey) }
    var quizAnswers: [String: Int] { progress.quizAnswers[chapter.id] ?? [:] }
    var masteryCount: Int { progress.masteredChapterIDs.count }
    var reviewIDs: Set<String> { progress.reviewChapterIDs() }
    var currentAttempts: [Attempt] { progress.attempts.filter { $0.chapterID == chapter.id }.sorted { $0.date > $1.date } }

    var needsRewardUpdate: Bool { progress.rewardPolicyVersion < ExperienceRules.policyVersion }

    func upgradeExperience() {
        guard needsRewardUpdate, !isBusy, !storageLocked else { return }
        updatingRewards = true
        feedback = "Updating exercise ratings, applying AI practice caps and recalculating historical XP locally…"
        let generated = progress.generatedExercises
        let path = progress.pythonPath
        workTask = Task {
            defer { updatingRewards = false; workTask = nil }
            do {
                var rated = generated
                for chapterID in generated.keys.sorted() {
                    let exercises = generated[chapterID] ?? []
                    for start in stride(from: 0, to: exercises.count, by: 20) {
                        let batch = Array(exercises[start..<min(start + 20, exercises.count)])
                        let ratings = try await runner.analyzeEffort(exercises: batch, pythonPath: path)
                        for (offset, rating) in ratings.enumerated() {
                            rated[chapterID]?[start + offset].effort = rating
                        }
                    }
                }
                try Task.checkCancellation()
                guard !storageLocked else { return }
                var updated = progress
                let previousXP = progress.playerProgress.totalXP
                updated.generatedExercises = rated
                updated.recalculateExperience()
                try store.save(updated, preservingRewardHistory: true)
                progress = updated
                feedback = "XP ratings updated. Historical XP recalculated: \(previousXP) → \(updated.playerProgress.totalXP). No duplicate completions were awarded."
                if !updated.attempts.isEmpty { notice = feedback }
            } catch {
                feedback = "XP update did not complete. Existing rewards are unchanged. Retry from Player progress. \(error.localizedDescription)"
                notice = feedback
            }
        }
    }

    var exerciseRewardDetails: String {
        guard let effort = exercise.effort else { return "Older exercise awaiting workload analysis. Update XP ratings in Player progress." }
        let amount = ExperienceRules.completionXP(effort: effort, mode: mode)
        return "\(effort.summary). Full completion value: \(amount) XP."
    }

    var exerciseRewardSummary: String {
        let attempts = progress.attempts.filter {
            $0.chapterID == chapter.id && Curriculum.activityID(for: $0.exerciseID) == Curriculum.activityID(for: exercise.id) && $0.mode == mode
        }
        let completed = attempts.contains { mode == .assessment ? $0.demonstratesMastery : $0.testsPassed }
        guard completed else {
            guard exercise.effort != nil else { return "XP rating pending · update in Player progress" }
            let amount = ExperienceRules.completionXP(effort: exercise.effort, mode: mode, solutionRevealed: solutionRevealed)
            let title = mode == .assessment ? "First full assessment pass" : solutionRevealed ? "First guided success" : "First successful practice"
            return "\(title) · +\(amount) XP"
        }
        guard mode == .assessment || (hintCount == 0 && !solutionRevealed),
              let latest = attempts.filter({ $0.testsPassed && $0.hintCount == 0 && !$0.solutionRevealed && (mode != .assessment || $0.demonstratesMastery) }).map(\.date).max() else {
            return "Completion XP earned. Try a new practice for another reward."
        }
        let reviewDate = latest.addingTimeInterval(7 * 24 * 60 * 60)
        return reviewDate <= Date() ? "Recall ready · pass independently for +25 XP" : "Completion XP earned · +25 XP recall available \(reviewDate.formatted(date: .abbreviated, time: .shortened))"
    }

    var focusRemainingSeconds: Int {
        max(0, Int(ceil(1500 - (progress.activeStudySession?.elapsed ?? 0))))
    }

    func startFocusSession() {
        guard progress.activeStudySession == nil, !storageLocked else { return }
        progress.activeStudySession = ActiveStudySession(startedAt: focusNow())
        resumeFocusSession()
    }

    func resumeFocusSession() {
        guard progress.activeStudySession != nil, !focusRunning, !storageLocked else { return }
        focusRunning = true
        focusLastTick = focusClock()
        focusLastSaved = progress.activeStudySession?.elapsed ?? 0
        focusTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.updateFocusSession() }
        updateFocusSession()
        flushSave()
    }

    func updateFocusSession() {
        guard focusRunning, let previous = focusLastTick, var session = progress.activeStudySession else { return }
        let tick = focusClock()
        guard tick.isFinite, tick >= previous else { return }
        focusLastTick = tick
        session.elapsed = min(1500, session.elapsed + tick - previous)
        progress.activeStudySession = session
        if session.elapsed >= 1500 {
            let previousXP = progress.playerProgress.totalXP
            if !progress.studySessions.contains(where: { $0.id == session.id }) {
                progress.studySessions.append(StudySession(id: session.id, startedAt: session.startedAt,
                    completedAt: max(focusNow(), session.startedAt.addingTimeInterval(1500))))
            }
            progress.activeStudySession = nil
            stopFocusTimer()
            celebrateRewards(since: previousXP, title: "Focus session completed")
            flushSave()
        } else if session.elapsed - focusLastSaved >= 15 {
            focusLastSaved = session.elapsed
            flushSave()
        }
    }

    func pauseFocusSession() {
        updateFocusSession()
        stopFocusTimer()
        flushSave()
    }

    func endFocusSession() {
        updateFocusSession()
        stopFocusTimer()
        progress.activeStudySession = nil
        flushSave()
    }

    private func stopFocusTimer() {
        focusRunning = false
        focusLastTick = nil
        focusTimer?.cancel()
        focusTimer = nil
    }

    func completeLesson() {
        guard mode == .lesson, isUnlocked, !storageLocked, progress.lessonCompletions[chapter.id] == nil else { return }
        let previousXP = progress.playerProgress.totalXP
        progress.lessonCompletions[chapter.id] = Date()
        celebrateRewards(since: previousXP, title: "Lesson marked read")
        flushSave()
    }

    func setCelebrationEffectsEnabled(_ enabled: Bool) {
        progress.celebrationEffectsEnabled = enabled
        flushSave()
    }

    private func celebrateRewards(since previousXP: Int, title: String? = nil) {
        let player = progress.playerProgress
        guard player.totalXP > previousXP else { return }
        let reward = RewardCelebration(amount: player.totalXP - previousXP,
            title: title ?? progress.experienceEvents.first?.title ?? "Progress earned",
            previousLevel: PlayerProgress(totalXP: previousXP).level, level: player.level)
        celebrationQueue.append(reward)
        if rewardCelebration == nil { showNextCelebration() }
    }

    func dismissCelebration() {
        celebrationTask?.cancel()
        rewardCelebration = nil
        showNextCelebration()
    }

    private func showNextCelebration() {
        guard !celebrationQueue.isEmpty else { return }
        rewardCelebration = celebrationQueue.removeFirst()
        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            self?.dismissCelebration()
        }
    }

    func selectChapter(_ id: String) {
        guard !isBusy else { return }
        flushSave()
        progress.selectedChapterID = id
        progress.selectedMode = .lesson
        resetWorkspace()
    }

    func selectMode(_ mode: LearningMode) {
        guard !isBusy else { return }
        flushSave()
        progress.selectedMode = mode
        resetWorkspace()
    }

    func selectAssessment(_ id: String) {
        guard !isBusy, assessments.contains(where: { $0.id == id }) else { return }
        flushSave()
        progress.selectedExerciseIDs[assessmentSelectionKey] = id
        progress.selectedMode = .assessment
        resetWorkspace()
    }

    func selectExercise(_ id: String) {
        guard !isBusy, exercises.contains(where: { $0.id == id }) else { return }
        flushSave()
        progress.selectedExerciseIDs[chapter.id] = id
        progress.selectedMode = .practice
        resetWorkspace()
    }

    func isUnlocked(_ chapterID: String) -> Bool { progress.isUnlocked(chapterID, in: chapters) }

    func missingPrerequisites(for chapterID: String) -> [Chapter] {
        progress.missingPrerequisites(for: chapterID, in: chapters)
    }

    /// Plain-language list of a locked chapter's unmastered prerequisites for the chapter browser.
    func requirementSummary(for chapterID: String) -> String {
        let missing = missingPrerequisites(for: chapterID).map(\.title)
        let unknown = progress.unknownPrerequisiteIDs(for: chapterID, in: chapters)
        guard !missing.isEmpty || !unknown.isEmpty else { return "Locked" }
        return "Requires: " + (missing + (unknown.isEmpty ? [] : ["an unavailable chapter"])).joined(separator: " · ")
    }

    var lockedChapterExplanation: String {
        let missing = missingPrerequisites.map(Self.quoted)
        guard !missing.isEmpty else {
            return "This chapter lists a prerequisite that is not available in this curriculum, so it cannot be unlocked automatically. If you already know the material, record a placement override."
        }
        if missing.count == 1 {
            return "Pass the assessment for \(missing[0]) to unlock this chapter. If you already know that material, take its assessment as a placement check."
        }
        return "This chapter builds on several chapters. Pass the assessments for \(Self.list(missing)) to unlock it. If you already know that material, take those assessments as placement checks."
    }

    var overrideButtonTitle: String {
        missingPrerequisites.count > 1 ? "I already know these prerequisites…" : "I already know the prerequisite…"
    }

    var overrideConfirmationTitle: String {
        let missing = missingPrerequisites.map(Self.quoted)
        let subject = missing.isEmpty ? "its prerequisite" : missing.count == 1 ? missing[0] : Self.list(missing)
        return "Study this chapter without mastering \(subject)? This records a placement override, not mastery."
    }

    var teacherLockedMessage: String {
        let missing = missingPrerequisites.map(Self.quoted)
        guard !missing.isEmpty else { return "Record a placement override to start this chapter." }
        return "Master \(Self.list(missing)) or record a placement override to start this chapter."
    }

    static func quoted(_ chapter: Chapter) -> String { "“\(chapter.title)”" }

    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
        }
    }

    func overrideUnlock() {
        progress.unlockedOverrides.insert(chapter.id)
        scheduleSave()
    }

    func setAnswer(_ value: Int, question: String) {
        progress.quizAnswers[chapter.id, default: [:]][question] = value
        scheduleSave()
    }

    func resetDraft() {
        guard !isBusy else { return }
        code = exercise.starterCode
        lastRunCode = nil
        teacherRun = nil
        output = "Run your code to see its output here."
        feedback = "Starter restored. Previous submitted attempts remain in your history. Assistance and solution history is preserved."
    }

    func showHint() {
        guard mode == .practice, !isBusy, isUnlocked, canShowHint else { return }
        let index = builtInHintCount
        progress.hintCounts[draftKey] = hintCount + 1
        progress.hintCounts[draftKey + ":builtin"] = index + 1
        messages.append(TeacherMessage(role: "assistant", text: "Hint \(index + 1)\n\n\(exercise.hints[index])"))
        scheduleSave()
    }

    func revealSolution() {
        guard mode == .practice, !isBusy, isUnlocked else { return }
        progress.revealedSolutions.insert(draftKey)
        messages.append(TeacherMessage(role: "assistant", text: "Reference solution\n\n```python\n\(exercise.referenceSolution)\n```\n\nCompare the reasoning, then try a different exercise independently. This practice is marked as assisted.", includeInContext: false))
        scheduleSave()
    }

    func runCode(test: Bool = false, submit: Bool = false) {
        guard !isBusy, isUnlocked else { return }
        if submit && mode == .assessment {
            guard chapter.quiz.allSatisfy({ quizAnswers[$0.id] != nil }), !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                notice = "Answer every theory question and explain your approach before submitting."
                return
            }
        }
        running = true
        feedback = ""
        output = test || submit ? "Running checks in a restricted Python workspace…" : "Running Python…"
        let snapshot = code
        let exercise = exercise
        let chapter = chapter
        let mode = mode
        let hints = hintCount
        let revealed = solutionRevealed
        let answers = quizAnswers
        let reflection = reflection
        let path = progress.pythonPath
        flushSave()
        workTask = Task {
            defer { running = false; workTask = nil }
            do {
                let result = try await runner.run(code: snapshot, tests: test || submit ? exercise.testCode : nil, pythonPath: path)
                lastRunCode = snapshot
                output = result.output.isEmpty ? "Program finished without printed output." : result.output
                let cancelled = result.cancelled || Task.isCancelled
                teacherRun = TeacherRunEvidence(code: snapshot, operation: test || submit ? "Check solution" : "Run",
                    outcome: cancelled ? "Cancelled" : result.timedOut ? "Timed out" : "Finished",
                    exitCode: result.exitCode, checksPassed: test || submit ? (!cancelled && !result.timedOut && result.passed) : nil,
                    output: result.output)
                if result.cancelled || Task.isCancelled { feedback = "Run cancelled. No attempt recorded."; return }
                if result.timedOut { feedback = "Time limit reached. Check for a loop that never ends." }
                else if test || submit { feedback = result.passed ? "All code checks passed." : "Code checks did not pass. Read the error output, then make one focused change." }
                else { feedback = result.exitCode == 0 ? "Program finished. Run checks to test its behavior." : "Python reported an error. Read the final traceback line first." }
                if submit || (test && mode == .practice) {
                    let correct = chapter.quiz.filter { answers[$0.id] == $0.correctIndex }.count
                    let attempt = Attempt(chapterID: chapter.id, exerciseID: exercise.id, mode: mode, code: snapshot, testsPassed: result.passed, quizCorrect: mode == .assessment ? correct : 0, quizTotal: mode == .assessment ? chapter.quiz.count : 0, hintCount: mode == .assessment ? 0 : hints, solutionRevealed: mode == .assessment ? false : revealed, reflection: reflection, effort: exercise.effort)
                    let previousXP = progress.playerProgress.totalXP
                    let previouslyUnlocked = Set(chapters.map(\.id).filter { progress.isUnlocked($0, in: chapters) })
                    progress.attempts.append(attempt)
                    celebrateRewards(since: previousXP, title: progress.experienceEvents.first { $0.id == "attempt:\(attempt.id.uuidString)" }?.title)
                    if mode == .assessment {
                        feedback += "\nTheory: \(correct)/\(chapter.quiz.count)."
                        if attempt.demonstratesMastery {
                            let newlyUnlocked = chapters.filter { !previouslyUnlocked.contains($0.id) && progress.isUnlocked($0.id, in: chapters) }.map(Self.quoted)
                            feedback += "\nChapter passed. " + (newlyUnlocked.isEmpty ? "" : "Newly unlocked: \(Self.list(newlyUnlocked)). ") + "Your explanation was saved for reflection; it was not automatically scored."
                        } else {
                            feedback += "\nNot passed yet. Practice the gaps, then retry."
                            for question in chapter.quiz where answers[question.id] != question.correctIndex {
                                feedback += "\n\n\(question.prompt)\n\(question.explanation)"
                            }
                        }
                    } else if result.passed {
                        feedback += hints > 0 || revealed ? "\nAssisted practice recorded. Try another problem without hints." : "\nIndependent practice recorded. Explain why it works, then try a variation."
                    }
                    flushSave()
                }
            } catch {
                lastRunCode = nil
                output = Task.isCancelled ? "Execution cancelled." : error.localizedDescription
                teacherRun = TeacherRunEvidence(code: snapshot, operation: test || submit ? "Check solution" : "Run",
                    outcome: Task.isCancelled ? "Cancelled" : "Execution could not complete",
                    exitCode: nil, checksPassed: nil, output: output)
                feedback = Task.isCancelled ? "Run cancelled. No attempt recorded." : "Execution could not complete. Check the error and Python interpreter in Settings. Execution never falls back to an unrestricted process."
            }
        }
    }

    func cancelWork() {
        runner.cancel()
        workTask?.cancel()
    }

    private var teacherContextVersion: TeacherContextVersion {
        TeacherContextVersion(codeFingerprint: SHA256.hash(data: Data(code.utf8)).map { String(format: "%02x", $0) }.joined(), runID: teacherRun?.id)
    }

    private func teacherContext(version: TeacherContextVersion) throws -> String {
        let previous = messages.last { $0.role == "user" && $0.contextVersion != nil }?.contextVersion
        let codeChange = previous.map { $0.codeFingerprint == version.codeFingerprint ? "Unchanged since previous teacher request" : "Changed since previous teacher request" }
            ?? "No previous snapshot available for comparison"
        let runChange = previous.map { $0.runID == version.runID ? "Unchanged since previous teacher request" : teacherRun == nil ? "Previous run evidence cleared" : "New run since previous teacher request" }
            ?? "No previous snapshot available for comparison"
        let runStatus = teacherRun.map { $0.code == code ? "Latest run belongs to current code" : "Latest run belongs to older code; current code has not been run" }
            ?? "No run evidence available in this workspace. Run evidence is cleared on navigation, restart, or restoring the starter. Do not infer a current result from conversation history."
        let snapshot = TeacherWorkspaceSnapshot(capturedAt: Date(), chapterID: chapter.id, chapter: chapter.title,
            directPrerequisites: directPrerequisites.map(\.title), prerequisiteChapters: prerequisiteChapters.map(\.title),
            mode: mode.rawValue, lesson: chapter.lesson, exerciseID: exercise.id, exerciseTitle: exercise.title,
            instructions: exercise.instructions, starterCode: exercise.starterCode, currentCode: code,
            codeChange: codeChange, runChange: runChange, runStatus: runStatus, latestRun: teacherRun,
            hintsUsed: hintCount, solutionRevealed: solutionRevealed)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let context = String(decoding: try encoder.encode(snapshot), as: UTF8.self)
        try TeacherClient.validateContext(context)
        return context
    }

    func askTeacher(_ question: String) {
        guard mode != .assessment, !isBusy, isUnlocked, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let version = teacherContextVersion
        let context: String
        do { context = try teacherContext(version: version) }
        catch { notice = error.localizedDescription; return }
        guard let client = teacherClient() else { return }
        let history = teacherHistory
        let workspaceKey = draftKey
        if mode == .practice { progress.hintCounts[draftKey] = hintCount + 1; scheduleSave() }
        messages.append(TeacherMessage(role: "user", text: question, contextVersion: version))
        teacherBusy = true
        requestCount += 1
        workTask = Task {
            defer { teacherBusy = false; workTask = nil }
            do {
                let reply = try await client.respond(context: context, question: question, history: history)
                try Task.checkCancellation()
                recordUsage(reply)
                guard draftKey == workspaceKey, mode != .assessment, teacherContextVersion == version else {
                    notice = "Your workspace changed while the teacher was replying. The outdated reply was not added. Ask again to send the latest code and output."
                    return
                }
                messages.append(TeacherMessage(role: "assistant", text: reply.text))
            } catch {
                if !Task.isCancelled { notice = error.localizedDescription }
            }
        }
    }

    var canRepairGeneratedPractice: Bool {
        !isBusy && mode != .assessment && isUnlocked && !storageLocked && rejectedPractice?.chapterID == chapter.id
    }

    func generatePractice(options: PracticeGenerationOptions = .init()) {
        generatePractice(options: options, repairing: nil)
    }

    func repairGeneratedPractice() {
        guard canRepairGeneratedPractice, let rejectedPractice else { return }
        generatePractice(options: rejectedPractice.options, repairing: rejectedPractice)
    }

    func copyGenerationReport() {
        guard mode != .assessment, let rejectedPractice else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rejectedPractice.report, forType: .string)
    }

    private func generatePractice(options: PracticeGenerationOptions, repairing: RejectedPractice?) {
        guard mode != .assessment, !isBusy, isUnlocked, !storageLocked else { return }
        let selectedExercise = repairing?.selectedExercise ?? exercise
        guard (try? options.coverageTopics(for: chapter, selectedExercise: selectedExercise, curriculum: chapters)) != nil,
              options.scenario.count <= 400 else {
            generationState = .failed("Choose valid coverage and a scenario of at most 400 characters.")
            notice = generationState.message
            return
        }
        guard let client = teacherClient() else {
            generationState = .failed(notice ?? "Configure the AI teacher in Settings before generating practice.")
            return
        }
        notice = nil
        teacherBusy = true
        generationState = .requesting
        requestCount += 1
        let chapter = chapter
        let modelName = progress.model
        if repairing == nil { rejectedPractice = nil }
        let recentExercises = exercises
        let curriculum = chapters
        let path = progress.pythonPath
        func rejection(_ generated: Exercise, stage: String, result: RunResult) -> AppError {
            let temporary = FileManager.default.temporaryDirectory
            let diagnostic = String(result.output
                .replacingOccurrences(of: temporary.resolvingSymlinksInPath().path, with: "<temporary>")
                .replacingOccurrences(of: temporary.path, with: "<temporary>")
                .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~").suffix(6000))
            let reason = result.timedOut ? "Local Python execution exceeded its eight-second limit."
                : result.passed ? "The starter already passes all checks."
                : String(diagnostic.split(whereSeparator: \.isNewline).last.map(String.init)?.prefix(240) ?? "No Python diagnostic was returned.")
            let feedback = "\(stage) validation. Exit code: \(result.exitCode). Timed out: \(result.timedOut).\n\(reason)\n\n\(diagnostic)"
            rejectedPractice = RejectedPractice(chapterID: chapter.id, chapterTitle: chapter.title, model: modelName,
                options: options, selectedExercise: selectedExercise,
                repair: GeneratedExerciseRepair(exercise: generated, validationFeedback: feedback))
            return .message("Generated \(stage.lowercased()) rejected: \(reason) Open Validation details for the report, or explicitly request Repair with AI. Your existing work is unchanged.")
        }
        feedback = "Creating practice: \(options.coverageLabel) · \(options.difficulty.rawValue) · \(options.style.rawValue)… It will only be added after its reference solution passes and its starter fails the checks."
        workTask = Task {
            defer { teacherBusy = false; workTask = nil }
            do {
                try Task.checkCancellation()
                let (candidate, reply) = try await client.generate(chapter: chapter, options: options, selectedExercise: selectedExercise, previousExercises: recentExercises, repair: repairing?.repair, curriculum: curriculum) { [weak self] characters in
                    await self?.recordGenerationProgress(characters)
                }
                var generated = candidate
                recordUsage(reply)
                try Task.checkCancellation()
                generationState = .validating
                feedback = "Validating the generated exercise…"
                let reference = try await runner.run(code: generated.referenceSolution, tests: generated.testCode, pythonPath: path)
                try Task.checkCancellation()
                guard !reference.cancelled else { throw CancellationError() }
                guard reference.passed, !reference.timedOut else {
                    throw rejection(generated, stage: "Reference solution", result: reference)
                }
                let starter = try await runner.run(code: generated.starterCode, tests: generated.testCode, pythonPath: path)
                try Task.checkCancellation()
                guard !starter.cancelled else { throw CancellationError() }
                guard !starter.passed, !starter.timedOut else {
                    throw rejection(generated, stage: "Starter", result: starter)
                }
                generated.effort = try await runner.analyzeEffort(exercises: [generated], pythonPath: path).first?
                    .capped(at: ExperienceRules.generatedUnitCap(scope: options.scope, chapter: chapter))
                try Task.checkCancellation()
                var updated = progress
                updated.generatedExercises[chapter.id, default: []].append(generated)
                updated.selectedExerciseIDs[chapter.id] = generated.id
                updated.selectedChapterID = chapter.id
                updated.selectedMode = .practice
                try store.save(updated)
                progress = updated
                resetWorkspace()
                rejectedPractice = nil
                generationState = .ready(chapterID: chapter.id, exerciseID: generated.id, title: generated.title)
                feedback = "New AI-generated practice ready. Runtime validation passed, but AI exercises can still contain ambiguous requirements. Report a problem by asking the teacher or switch to a reviewed exercise."
            } catch {
                let cancelled = Task.isCancelled || error is CancellationError
                generationState = cancelled ? .cancelled : .failed(error.localizedDescription)
                feedback = generationState.message ?? ""
                if !cancelled { notice = feedback }
            }
        }
    }

    private func recordGenerationProgress(_ characters: Int) {
        guard !Task.isCancelled, generationState.isInProgress else { return }
        generationState = .receiving(characters: characters)
    }

    func openGeneratedPractice() {
        guard !isBusy, case let .ready(chapterID, exerciseID, _) = generationState else { return }
        selectChapter(chapterID)
        selectExercise(exerciseID)
    }

    func dismissGenerationStatus() {
        guard !generationState.isInProgress else { return }
        generationState = .idle
        rejectedPractice = nil
    }

    func saveSettings(provider: TeacherProvider, pythonPath: String, model: String, requestLimit: Int, apiKey: String) {
        guard !isBusy else { return }
        do {
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try KeychainStore.provider(provider).save(apiKey)
                hasAPIKey = true
            }
            progress.pythonPath = pythonPath.trimmingCharacters(in: .whitespacesAndNewlines)
            progress.provider = provider
            progress.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
            progress.sessionRequestLimit = max(1, min(requestLimit, 100))
            flushSave()
            settingsPresented = false
        } catch { notice = error.localizedDescription }
    }

    func checkKeyStatus(for provider: TeacherProvider) {
        do { hasAPIKey = try KeychainStore.provider(provider).load()?.isEmpty == false }
        catch { notice = error.localizedDescription }
    }

    func removeKey(for provider: TeacherProvider) {
        do { try KeychainStore.provider(provider).remove(); hasAPIKey = false }
        catch { notice = error.localizedDescription }
    }

    func exportCode() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(exercise.id).py"
        panel.allowedContentTypes = [UTType(filenameExtension: "py") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try code.write(to: url, atomically: true, encoding: .utf8) }
        catch { notice = error.localizedDescription }
    }

    func exportProgress() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "python-teacher-backup.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(progress).write(to: url, options: .atomic)
        } catch { notice = error.localizedDescription }
    }

    func showDataFolder() {
        NSWorkspace.shared.open(store.directory)
    }

    func flushSave() {
        saveTask?.cancel()
        guard !storageLocked else { return }
        do { try store.save(progress); saveStatus = "Saved locally" }
        catch { saveStatus = "Save failed"; notice = "Could not save progress: \(error.localizedDescription)" }
    }

    private func scheduleSave() {
        guard !storageLocked else { return }
        saveStatus = "Saving…"
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            flushSave()
        }
    }

    private func loadDraft() {
        loading = true
        let legacyAttempt = isLegacyExercise ? currentAttempts.first {
            $0.exerciseID == exercise.id && $0.mode == (mode == .assessment ? .assessment : .practice)
        } : nil
        code = progress.drafts[draftKey] ?? legacyAttempt?.code ?? exercise.starterCode
        reflection = progress.reflections[draftKey] ?? legacyAttempt?.reflection ?? ""
        loading = false
    }

    private func resetWorkspace() {
        loadDraft()
        lastRunCode = nil
        teacherRun = nil
        output = "Run your code to see its output here."
        feedback = ""
        if mode != .assessment, progress.teacherConversations[draftKey] == nil, builtInHintCount > 0 {
            messages = Array(exercise.hints.prefix(builtInHintCount).enumerated()).map {
                TeacherMessage(role: "assistant", text: "Hint \($0.offset + 1)\n\n\($0.element)")
            }
        }
        scheduleSave()
    }

    private func teacherClient() -> TeacherClient? {
        guard cloudConsent else {
            notice = "Enable cloud teacher access in Settings first. Relevant lesson content, your current code, output, and messages will be sent to \(progress.provider.name). Never include confidential information."
            settingsPresented = true
            return nil
        }
        guard requestCount < progress.sessionRequestLimit else {
            notice = "This app session's AI request limit has been reached. You can continue offline or adjust the limit in Settings. Requests may incur API charges even if validation fails."
            return nil
        }
        do {
            if let teacherClientProvider { return try teacherClientProvider() }
            guard let key = try KeychainStore.provider(progress.provider).load(), !key.isEmpty else { throw TeacherError.missingKey }
            hasAPIKey = true
            return TeacherClient(apiKey: key, model: progress.model, provider: progress.provider)
        } catch { notice = error.localizedDescription; return nil }
    }

    private func recordUsage(_ reply: TeacherReply) {
        inputTokens += reply.inputTokens
        outputTokens += reply.outputTokens
    }
}

private struct TeacherRunEvidence: Encodable {
    let id = UUID()
    let completedAt = Date()
    let code: String
    let operation: String
    let outcome: String
    let exitCode: Int32?
    let checksPassed: Bool?
    let output: String
}

private struct TeacherWorkspaceSnapshot: Encodable {
    let capturedAt: Date
    let chapterID: String
    let chapter: String
    let directPrerequisites: [String]
    let prerequisiteChapters: [String]
    let mode: String
    let lesson: String
    let exerciseID: String
    let exerciseTitle: String
    let instructions: String
    let starterCode: String
    let currentCode: String
    let codeChange: String
    let runChange: String
    let runStatus: String
    let latestRun: TeacherRunEvidence?
    let hintsUsed: Int
    let solutionRevealed: Bool
}

struct RejectedPractice: Sendable {
    let chapterID: String
    let chapterTitle: String
    let model: String
    let options: PracticeGenerationOptions
    let selectedExercise: Exercise
    let repair: GeneratedExerciseRepair

    var report: String {
        """
        Rejected AI exercise — not added to practice
        Chapter: \(chapterTitle)
        Model: \(model)
        Coverage: \(options.coverageLabel)
        Difficulty: \(options.difficulty.rawValue)
        Format: \(options.style.rawValue)

        Validation evidence:
        \(repair.validationFeedback)

        Generated task: \(repair.exercise.title)
        \(repair.exercise.instructions)

        Generated starter:
        \(repair.exercise.starterCode)

        Generated reference (contains the rejected exercise's answer):
        \(repair.exercise.referenceSolution)

        Generated checks:
        \(repair.exercise.testCode)
        """
    }
}

enum PracticeGenerationState: Equatable {
    case idle, requesting, validating, cancelled
    case ready(chapterID: String, exerciseID: String, title: String)
    case receiving(characters: Int)
    case failed(String)

    var isInProgress: Bool {
        switch self {
        case .requesting, .receiving, .validating: return true
        default: return false
        }
    }

    var message: String? {
        switch self {
        case .idle: return nil
        case .requesting: return "Waiting for the AI provider to start your challenge… Broad exercises can take several minutes. You can cancel at any time."
        case .receiving(let characters): return "Receiving your exercise from the AI provider… \(characters) characters received. It will be added only after the complete response passes validation."
        case .validating: return "Checking the generated reference and starter before adding the exercise…"
        case .cancelled: return "Generation cancelled. No exercise was added."
        case .ready(_, _, let title): return "Added to Practice: \(title). Saved in the exercise picker."
        case .failed(let reason): return "No exercise was added. \(reason)"
        }
    }
}

struct RewardCelebration: Identifiable {
    let id = UUID()
    let amount: Int
    let title: String
    let previousLevel: Int
    let level: Int
    var leveledUp: Bool { level > previousLevel }
    var accessibilityAnnouncement: String {
        "\(title), plus \(amount) XP." + (leveledUp ? " Player level \(level) reached." : "")
    }
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let text) = self { return text }
        return nil
    }
}
