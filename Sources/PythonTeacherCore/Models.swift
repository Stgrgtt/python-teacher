import Foundation

public enum LearningMode: String, Codable, CaseIterable, Sendable {
    case lesson = "Learn"
    case practice = "Practice"
    case assessment = "Assessment"
}

public enum PracticeScope: String, CaseIterable, Sendable {
    case selectedExercise = "Selected exercise"
    case currentChapter = "Whole current chapter"
    case project = "Project"

    public var explanation: String {
        switch self {
        case .selectedExercise: return "Practice the concepts in the selected exercise, not the whole chapter."
        case .currentChapter: return "Cover all Learn sections in the current chapter, regardless of which exercise is selected."
        case .project: return "Build a small working program toward a clear objective in connected milestones. Your 1–3 focus sections from this chapter are required; earlier chapters are a toolkit you may use, not a checklist."
        }
    }
}

public enum PracticeDifficulty: String, Codable, CaseIterable, Sendable {
    case easier = "Easier"
    case similar = "Similar"
    case harder = "Harder"

    public var explanation: String {
        switch self {
        case .easier: return "More guidance, simpler data and explicit intermediate steps. Keep all requested coverage."
        case .similar: return "Match the reasoning and guidance of the chapter's reviewed practice. Keep all requested coverage."
        case .harder: return "Less scaffolding, more connected reasoning and boundary cases, but no untaught syntax. Keep all requested coverage."
        }
    }
}

public enum PracticeStyle: String, CaseIterable, Sendable {
    case write = "Write code"
    case complete = "Complete starter code"
    case debug = "Debug broken code"

    public func acceptsStarterFailure(_ result: RunResult) -> Bool {
        guard !result.passed, !result.timedOut, !result.cancelled else { return false }
        return self != .debug || (result.exitCode > 0 && result.diagnostic?.exceptionType == "AssertionError" && result.diagnostic?.origin == .checks)
    }

    public var guidance: String {
        switch self {
        case .write: return "Supply inputs and minimal result or function placeholders; the learner writes the logic."
        case .complete: return "Supply a partially implemented structure with clearly identified editable placeholders; leave meaningful work for every requested topic."
        case .debug: return "Supply runnable but logically incorrect code, not syntax errors. Explain the intended behavior and editable lines without revealing the fixes. Include meaningful diagnosis or repair work across the requested topics."
        }
    }
}

public struct PracticeTopic: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
}

public struct PracticeGenerationOptions: Equatable, Sendable {
    public var scope: PracticeScope
    public var difficulty: PracticeDifficulty
    public var style: PracticeStyle
    public var scenario: String
    /// Catalog brief for project scope; `nil` means the learner's own objective, written in `scenario`.
    public var projectBriefID: String?
    /// Current-chapter lesson sections a project must exercise. Empty selects the first sections.
    public var focusTopicIDs: [String]

    public static let maximumProjectFocus = 3
    public static let projectIntegrationTopicID = "project-integration"

    public init(scope: PracticeScope = .currentChapter, difficulty: PracticeDifficulty = .similar,
                style: PracticeStyle = .write, scenario: String = "", projectBriefID: String? = nil, focusTopicIDs: [String] = []) {
        self.scope = scope
        self.difficulty = difficulty
        self.style = style
        self.scenario = scenario
        self.projectBriefID = projectBriefID
        self.focusTopicIDs = focusTopicIDs
    }

    public var coverageLabel: String {
        guard scope == .project else { return scope.rawValue }
        return "\(scope.rawValue) · \(ProjectBrief.catalog.first { $0.id == projectBriefID }?.title ?? "Your own objective")"
    }

    /// Lessons in scope, in canonical order with the current chapter last. Project scope is the current
    /// chapter's transitive prerequisite closure plus the chapter itself, used as an allowed toolkit rather
    /// than mandatory coverage; it fails closed on unknown or misordered prerequisites.
    public func chapters(for chapter: Chapter, curriculum: [Chapter] = Curriculum.chapters) throws -> [Chapter] {
        let graph = CurriculumGraph(curriculum)
        guard let current = graph.chapter(chapter.id) else { throw TeacherError.invalidChapterContext }
        guard scope == .project else { return [current] }
        guard let scoped = graph.closureIncludingSelf(of: current.id) else { throw TeacherError.invalidChapterContext }
        return scoped
    }

    /// The selected catalog brief, or `nil` for the learner's own objective. Fails closed when the brief is
    /// unknown or needs a chapter outside the current chapter's prerequisite closure.
    public func projectBrief(for chapter: Chapter, curriculum: [Chapter] = Curriculum.chapters) throws -> ProjectBrief? {
        guard let projectBriefID else { return nil }
        guard let brief = ProjectBrief.available(for: chapter, curriculum: curriculum).first(where: { $0.id == projectBriefID }) else {
            throw TeacherError.invalidChapterContext
        }
        return brief
    }

    public func projectFocusIDs(for chapter: Chapter) -> [String] {
        let topics = chapter.practiceTopics(for: style).map(\.id)
        let chosen = topics.filter(focusTopicIDs.contains)
        return chosen.isEmpty ? Array(topics.prefix(Self.maximumProjectFocus)) : chosen
    }

    /// Keeps project choices valid after the learner changes chapter: drops focus sections from other
    /// chapters and replaces a brief the chapter cannot support with the first available one.
    public mutating func normalizeProject(for chapter: Chapter, curriculum: [Chapter] = Curriculum.chapters) {
        let topics = Set(chapter.practiceTopics(for: style).map(\.id))
        focusTopicIDs = focusTopicIDs.filter(topics.contains)
        let briefs = ProjectBrief.available(for: chapter, curriculum: curriculum)
        if let projectBriefID, briefs.contains(where: { $0.id == projectBriefID }) { return }
        if projectBriefID != nil || scenario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            projectBriefID = briefs.first?.id
        }
    }

    public func coverageTopics(for chapter: Chapter, selectedExercise: Exercise?, curriculum: [Chapter] = Curriculum.chapters) throws -> [PracticeTopic] {
        let chapters = try chapters(for: chapter, curriculum: curriculum)
        switch scope {
        case .selectedExercise:
            guard let selectedExercise,
                  !Curriculum.isAssessment(selectedExercise.id, in: curriculum) else {
                throw TeacherError.invalidChapterContext
            }
            return [PracticeTopic(id: "selected-exercise", title: selectedExercise.title)]
        case .currentChapter:
            return chapters.flatMap { $0.practiceTopics(for: style) }
        case .project:
            guard let current = chapters.last else { throw TeacherError.invalidChapterContext }
            let brief = try projectBrief(for: current, curriculum: curriculum)
            let known = Set(current.practiceTopics(for: style).map(\.id))
            guard brief != nil || !scenario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  focusTopicIDs.count <= Self.maximumProjectFocus, Set(focusTopicIDs).count == focusTopicIDs.count,
                  focusTopicIDs.allSatisfy(known.contains) else {
                throw TeacherError.invalidChapterContext
            }
            let focus = Set(projectFocusIDs(for: current))
            guard !focus.isEmpty else { throw TeacherError.invalidChapterContext }
            return current.practiceTopics(for: style).filter { focus.contains($0.id) }
                + [PracticeTopic(id: Self.projectIntegrationTopicID, title: "Project integration: \(brief?.title ?? "your objective")")]
        }
    }
}

public struct ExerciseEffort: Codable, Equatable, Sendable {
    public let difficulty: PracticeDifficulty
    public let scopeUnits: Int
    public let estimated: Bool

    public init(difficulty: PracticeDifficulty = .similar, scopeUnits: Int = 1, estimated: Bool = false) {
        self.difficulty = difficulty
        self.scopeUnits = min(1000, max(1, scopeUnits))
        self.estimated = estimated
    }

    public var practiceXP: Int {
        let unitXP: Int
        switch difficulty {
        case .easier: unitXP = 50
        case .similar: unitXP = 100
        case .harder: unitXP = 150
        }
        return unitXP * scopeUnits
    }

    public func capped(at units: Int) -> ExerciseEffort {
        ExerciseEffort(difficulty: difficulty, scopeUnits: min(scopeUnits, units), estimated: estimated)
    }

    public var summary: String {
        "\(difficulty.rawValue) · \(scopeUnits) workload \(scopeUnits == 1 ? "unit" : "units")" + (estimated ? " · estimated" : " · reviewed")
    }

    private enum CodingKeys: String, CodingKey { case difficulty, scopeUnits, estimated }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        difficulty = try values.decode(PracticeDifficulty.self, forKey: .difficulty)
        scopeUnits = try values.decode(Int.self, forKey: .scopeUnits)
        estimated = try values.decodeIfPresent(Bool.self, forKey: .estimated) ?? false
        guard (1...1000).contains(scopeUnits) else {
            throw DecodingError.dataCorruptedError(forKey: .scopeUnits, in: values, debugDescription: "Invalid exercise workload.")
        }
    }
}

public struct ExerciseInput: Codable, Equatable, Sendable {
    public let name: String
    public let defaultLiteral: String

    public init(name: String, defaultLiteral: String) {
        self.name = name
        self.defaultLiteral = defaultLiteral
    }
}

public struct NamedCheck: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let inputs: [String: String]
    public let target: String
    public let expectedLiteral: String

    public init(id: String, title: String, inputs: [String: String] = [:], target: String, expectedLiteral: String) {
        self.id = id
        self.title = title
        self.inputs = inputs
        self.target = target
        self.expectedLiteral = expectedLiteral
    }
}

public enum CheckPlanError: LocalizedError, Sendable {
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let reason): return "The input experiment or named checks could not start: \(reason)"
        }
    }
}

public struct AuthoredCheckPlan: Codable, Equatable, Sendable {
    public let inputs: [ExerciseInput]
    public let checks: [NamedCheck]
    public static let maximumChecks = 16
    public static let maximumInputs = 8
    public static let maximumLiteralBytes = 2_048

    public init(inputs: [ExerciseInput], checks: [NamedCheck]) {
        self.inputs = inputs
        self.checks = checks
    }

    public func validate(overrides: [String: String] = [:]) throws {
        let keywords: Set<String> = ["False", "None", "True", "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"]
        func identifier(_ value: String) -> Bool {
            !value.hasPrefix("__") && !keywords.contains(value)
                && value.range(of: #"\A[A-Za-z_][A-Za-z0-9_]{0,63}\z"#, options: .regularExpression) != nil
        }
        func literal(_ value: String) -> Bool {
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= Self.maximumLiteralBytes
        }
        let names = Set(inputs.map(\.name))
        guard inputs.count <= Self.maximumInputs, names.count == inputs.count,
              inputs.allSatisfy({ identifier($0.name) && literal($0.defaultLiteral) }),
              !checks.isEmpty, checks.count <= Self.maximumChecks,
              Set(checks.map(\.id)).count == checks.count,
              checks.allSatisfy({ check in
                  check.id.range(of: #"\A[A-Za-z0-9][A-Za-z0-9_-]{0,79}\z"#, options: .regularExpression) != nil
                      && !check.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && check.title.utf8.count <= 160
                      && check.title.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
                      && identifier(check.target) && literal(check.expectedLiteral)
                      && Set(check.inputs.keys).isSubset(of: names) && check.inputs.values.allSatisfy(literal)
              }), Set(overrides.keys).isSubset(of: names), overrides.values.allSatisfy(literal) else {
            throw CheckPlanError.invalid("Use a bounded authored plan with unique case IDs, declared input names, and nonempty literal values.")
        }
    }
}

public enum RunCheckStatus: String, Codable, Sendable {
    case passed, failed, notReached
}

public struct CheckOutcome: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let status: RunCheckStatus
    public let expected: String?
    public let actual: String?
    public let detail: String?

    public init(id: String, title: String, status: RunCheckStatus, expected: String? = nil, actual: String? = nil, detail: String? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.expected = expected
        self.actual = actual
        self.detail = detail
    }
}

public enum PracticeForm: String, Codable, CaseIterable, Sendable {
    case write, complete, predict, debug, counterexample, transfer, refactor, maintenance, project

    public var title: String {
        switch self {
        case .write: return "Write code"
        case .complete: return "Complete code"
        case .predict: return "Predict behavior"
        case .debug: return "Diagnose and repair"
        case .counterexample: return "Find a counterexample"
        case .transfer: return "Apply in a new context"
        case .refactor: return "Refactor"
        case .maintenance: return "Change a requirement"
        case .project: return "Build a project"
        }
    }
}

public enum PracticeScaffolding: String, Codable, CaseIterable, Sendable {
    case guided, light, independent

    public var title: String {
        switch self {
        case .guided: return "Step-by-step guidance"
        case .light: return "Some structure supplied"
        case .independent: return "Choose your approach"
        }
    }
}

public struct PracticeProfile: Codable, Equatable, Sendable {
    public let form: PracticeForm
    public let scaffolding: PracticeScaffolding
    public let skillIDs: [String]
    public let reflectionPrompts: [String]

    public init(form: PracticeForm, scaffolding: PracticeScaffolding, skillIDs: [String], reflectionPrompts: [String]) {
        self.form = form
        self.scaffolding = scaffolding
        self.skillIDs = skillIDs
        self.reflectionPrompts = reflectionPrompts
    }

    public var isWellFormed: Bool {
        (1...8).contains(skillIDs.count) && Set(skillIDs).count == skillIDs.count
            && skillIDs.allSatisfy { $0.utf8.count <= 96 && $0.range(of: #"\A[a-z][a-z0-9-]*-section-[1-9][0-9]*\z"#, options: .regularExpression) != nil }
            && (1...3).contains(reflectionPrompts.count) && Set(reflectionPrompts).count == reflectionPrompts.count
            && reflectionPrompts.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 400 }
    }
}

public struct Exercise: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var instructions: String
    public var starterCode: String
    public var referenceSolution: String
    public var testCode: String
    public var hints: [String]
    public var effort: ExerciseEffort?
    public var expectedStarterError: String?
    public var checkPlan: AuthoredCheckPlan?
    public var practiceProfile: PracticeProfile?

    static let instructionSectionTitles = ["Goal", "Starting code", "Your task", "Expected result", "Check"]

    public var hasRequiredInstructionSections: Bool {
        let pattern = "(?m)^[ \\t]*(?:#{1,6}[ \\t]+)?\\*{0,2}(Goal|Starting code|Your task|Expected results?|Examples|Check)\\*{0,2}:\\*{0,2}[ \\t]*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let text = instructions as NSString
        let matches = regex.matches(in: instructions, range: NSRange(location: 0, length: text.length))
        let titles = matches.map { match in
            let title = text.substring(with: match.range(at: 1))
            return title == "Examples" || title == "Expected results" ? "Expected result" : title
        }
        guard titles == Self.instructionSectionTitles else { return false }
        return matches.enumerated().allSatisfy { index, match in
            let start = NSMaxRange(match.range)
            let end = index + 1 < matches.count ? matches[index + 1].range.location : text.length
            return !text.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public init(id: String, title: String, instructions: String, starterCode: String, referenceSolution: String, testCode: String, hints: [String], effort: ExerciseEffort? = nil, expectedStarterError: String? = nil, checkPlan: AuthoredCheckPlan? = nil, practiceProfile: PracticeProfile? = nil) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.starterCode = starterCode
        self.referenceSolution = referenceSolution
        self.testCode = testCode
        self.hints = hints
        self.effort = effort
        self.expectedStarterError = expectedStarterError
        self.checkPlan = checkPlan
        self.practiceProfile = practiceProfile
    }
}

public struct QuizQuestion: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var prompt: String
    public var options: [String]
    public var correctIndex: Int
    public var explanation: String

    public init(id: String, prompt: String, options: [String], correctIndex: Int, explanation: String) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
    }
}

public enum ChapterTrack: String, Codable, CaseIterable, Sendable {
    case foundations, corePython, softwareCraft, dataScience

    public var title: String {
        switch self {
        case .foundations: "Foundations"
        case .corePython: "Core Python II"
        case .softwareCraft: "Software craft"
        case .dataScience: "Data science"
        }
    }
}

public struct Chapter: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let track: ChapterTrack
    public let prerequisites: [String]
    public let lesson: String
    public let exercises: [Exercise]
    public let assessment: Exercise
    public let quiz: [QuizQuestion]
    /// Authored roles keyed by exact lesson heading text (without `#`). Unlisted headings are practice.
    public let sectionRoles: [String: LessonSectionRole]
    /// App-authored guidance for AI generation in this chapter, e.g. a required checking pattern.
    public let generationNotes: String?

    /// Every lesson heading in order. IDs use the heading's position, so roles never renumber sections.
    public var lessonSections: [LessonSection] {
        var inCode = false
        let headings = lesson.components(separatedBy: .newlines).compactMap { line -> String? in
            if line.hasPrefix("```") { inCode.toggle(); return nil }
            guard !inCode, line.hasPrefix("# ") || line.hasPrefix("## ") else { return nil }
            return String(line.drop(while: { $0 == "#" || $0 == " " }))
        }
        return headings.enumerated().map {
            LessonSection(topic: PracticeTopic(id: "\(id)-section-\($0.offset + 1)", title: "\(title): \($0.element)"),
                          heading: $0.element, role: sectionRoles[$0.element] ?? .practice)
        }
    }

    /// Sections that can carry required learner work: practice sections, plus troubleshooting
    /// sections when the learner asked to debug broken code. Overview sections are never required.
    public func practiceTopics(for style: PracticeStyle) -> [PracticeTopic] {
        lessonSections.filter { $0.role == .practice || ($0.role == .troubleshooting && style == .debug) }.map(\.topic)
    }

    /// Format-independent practice sections; used for workload so the format never changes rewards.
    public var practiceTopics: [PracticeTopic] { practiceTopics(for: .write) }

    public init(id: String, title: String, subtitle: String, track: ChapterTrack = .foundations, prerequisites: [String] = [], lesson: String, exercises: [Exercise], assessment: Exercise, quiz: [QuizQuestion],
                sectionRoles: [String: LessonSectionRole] = [:], generationNotes: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.track = track
        self.prerequisites = prerequisites
        self.lesson = lesson
        self.exercises = exercises
        self.assessment = assessment
        self.quiz = quiz
        self.sectionRoles = sectionRoles
        self.generationNotes = generationNotes
    }
}

public enum LessonSectionRole: String, Sendable {
    /// Teaches syntax or a technique the learner should apply; required in whole-chapter coverage.
    case practice
    /// Motivation or orientation without new technique; sent as lesson context, never required.
    case overview
    /// Common mistakes and debugging advice; required only for the Debug broken code format.
    case troubleshooting
}

public struct LessonSection: Equatable, Sendable {
    public let topic: PracticeTopic
    public let heading: String
    public let role: LessonSectionRole
}

public struct Attempt: Codable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var chapterID: String
    public var exerciseID: String
    public var mode: LearningMode
    public var code: String
    public var testsPassed: Bool
    public var quizCorrect: Int
    public var quizTotal: Int
    public var hintCount: Int
    public var solutionRevealed: Bool
    public var reflection: String
    public var effort: ExerciseEffort?

    public init(id: UUID = UUID(), date: Date = Date(), chapterID: String, exerciseID: String, mode: LearningMode, code: String, testsPassed: Bool, quizCorrect: Int = 0, quizTotal: Int = 0, hintCount: Int = 0, solutionRevealed: Bool = false, reflection: String = "", effort: ExerciseEffort? = nil) {
        self.id = id
        self.date = date
        self.chapterID = chapterID
        self.exerciseID = exerciseID
        self.mode = mode
        self.code = code
        self.testsPassed = testsPassed
        self.quizCorrect = quizCorrect
        self.quizTotal = quizTotal
        self.hintCount = hintCount
        self.solutionRevealed = solutionRevealed
        self.reflection = reflection
        self.effort = effort
    }

    public var demonstratesMastery: Bool {
        mode == .assessment && testsPassed && quizTotal > 0 && quizCorrect == quizTotal && hintCount == 0 && !solutionRevealed && !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct TeacherContextVersion: Codable, Equatable, Sendable {
    public let codeFingerprint: String
    public let runID: UUID?

    public init(codeFingerprint: String, runID: UUID?) {
        self.codeFingerprint = codeFingerprint
        self.runID = runID
    }
}

public struct TeacherMessage: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let role: String
    public let text: String
    public var includeInContext: Bool
    public let contextVersion: TeacherContextVersion?

    public init(id: UUID = UUID(), role: String, text: String, includeInContext: Bool = true, contextVersion: TeacherContextVersion? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.includeInContext = includeInContext
        self.contextVersion = contextVersion
    }
}

public enum ExperienceRules {
    public static let policyVersion = 3
    public static let practiceXP = 100
    public static let assessmentXP = 300
    public static let reviewXP = 25
    public static let lessonXP = 25
    public static let focusXP = 50

    public static func completionXP(effort: ExerciseEffort?, mode: LearningMode, solutionRevealed: Bool = false) -> Int {
        let practice = effort?.practiceXP ?? practiceXP
        switch mode {
        case .practice: return solutionRevealed ? practice / 2 : practice
        case .assessment: return effort == nil ? assessmentXP : practice * 3
        case .lesson: return 0
        }
    }

    public static func generatedEffort(options: PracticeGenerationOptions, chapter: Chapter, selectedExercise: Exercise?,
                                       curriculum: [Chapter] = Curriculum.chapters) throws -> ExerciseEffort {
        let topics = try options.coverageTopics(for: chapter, selectedExercise: selectedExercise, curriculum: curriculum)
        let units: Int
        switch options.scope {
        case .selectedExercise: units = selectedExercise?.effort?.scopeUnits ?? 1
        case .currentChapter: units = chapter.practiceTopics.count
        case .project: units = topics.count
        }
        return ExerciseEffort(difficulty: options.difficulty, scopeUnits: units)
            .capped(at: generatedUnitCap(scope: options.scope, chapter: chapter))
    }

    /// AI-generated practice never earns more workload units than the chapter's reviewed assessment;
    /// project challenges may earn one more. This bounds both requested coverage and local structural
    /// estimates of provider-written reference solutions.
    public static func generatedUnitCap(scope: PracticeScope, chapter: Chapter) -> Int {
        let assessmentUnits = max(1, chapter.assessment.effort?.scopeUnits ?? 1)
        return scope == .project ? assessmentUnits + 1 : assessmentUnits
    }

    /// Saved generated exercises do not record their requested scope, so historical recalculation uses
    /// the most generous (project) cap, which equals the former cumulative cap. Unknown chapters use the
    /// largest cap in the curriculum.
    public static func historicalGeneratedUnitCap(chapterID: String, curriculum: [Chapter] = Curriculum.chapters) -> Int {
        if let chapter = curriculum.first(where: { $0.id == chapterID }) {
            return generatedUnitCap(scope: .project, chapter: chapter)
        }
        return curriculum.map { generatedUnitCap(scope: .project, chapter: $0) }.max() ?? 1
    }

    public static func totalXP(forLevel level: Int) -> Int {
        exactTotalXP(forLevel: level) ?? Int.max
    }

    fileprivate static func exactTotalXP(forLevel level: Int) -> Int? {
        let level = max(0, level)
        let (factor, additionOverflow) = level.addingReportingOverflow(3)
        let (product, productOverflow) = level.multipliedReportingOverflow(by: factor)
        let (total, totalOverflow) = product.multipliedReportingOverflow(by: 25)
        return additionOverflow || productOverflow || totalOverflow ? nil : total
    }
}

public struct PlayerProgress: Equatable, Sendable {
    public let totalXP: Int
    public let level: Int

    public init(totalXP: Int) {
        let normalizedXP = max(0, totalXP)
        self.totalXP = normalizedXP
        var lower = 0
        var upper = normalizedXP / 100
        while lower < upper {
            let middle = lower + (upper - lower + 1) / 2
            if let threshold = ExperienceRules.exactTotalXP(forLevel: middle), threshold <= normalizedXP {
                lower = middle
            } else {
                upper = middle - 1
            }
        }
        level = lower
    }

    public var xpIntoLevel: Int { totalXP - ExperienceRules.totalXP(forLevel: level) }
    public var xpToNextLevel: Int { 100 + 50 * level }

    public var xpRemaining: Int { xpToNextLevel - xpIntoLevel }
    public var fraction: Double { xpToNextLevel == 0 ? 1 : Double(xpIntoLevel) / Double(xpToNextLevel) }
    public var rankTitle: String {
        switch level {
        case 0..<10: return "Curious Starter"
        case 10..<25: return "Steady Learner"
        case 25..<50: return "Dedicated Learner"
        case 50..<75: return "Learning Adventurer"
        case 75..<100: return "Learning Veteran"
        default: return "Marathon Learner"
        }
    }
}

public struct ExperienceEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let date: Date
    public let title: String
    public let amount: Int

    public init(id: String, date: Date, title: String, amount: Int) {
        self.id = id
        self.date = date
        self.title = title
        self.amount = amount
    }
}

public struct StudySession: Codable, Identifiable, Equatable, Sendable {
    public static let duration: TimeInterval = 25 * 60
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date

    public init(id: UUID = UUID(), startedAt: Date, completedAt: Date) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    fileprivate var isValid: Bool {
        startedAt.timeIntervalSinceReferenceDate.isFinite && completedAt.timeIntervalSinceReferenceDate.isFinite
            && completedAt >= startedAt
    }

    private enum CodingKeys: String, CodingKey { case id, startedAt, completedAt }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        completedAt = try values.decode(Date.self, forKey: .completedAt)
        guard isValid else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid study session dates."))
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard isValid else {
            throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath, debugDescription: "Invalid study session dates."))
        }
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(startedAt, forKey: .startedAt)
        try values.encode(completedAt, forKey: .completedAt)
    }
}

public struct ActiveStudySession: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var elapsed: TimeInterval {
        didSet { elapsed = Self.clamped(elapsed) }
    }

    public init(id: UUID = UUID(), startedAt: Date = Date(), elapsed: TimeInterval = 0) {
        self.id = id
        self.startedAt = startedAt
        self.elapsed = Self.clamped(elapsed)
    }

    private static func clamped(_ elapsed: TimeInterval) -> TimeInterval {
        elapsed.isFinite ? min(StudySession.duration, max(0, elapsed)) : 0
    }

    fileprivate var isValid: Bool {
        startedAt.timeIntervalSinceReferenceDate.isFinite && elapsed.isFinite && (0...StudySession.duration).contains(elapsed)
    }

    private enum CodingKeys: String, CodingKey { case id, startedAt, elapsed }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        elapsed = try values.decode(TimeInterval.self, forKey: .elapsed)
        guard isValid else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid active study session."))
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard isValid else {
            throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath, debugDescription: "Invalid active study session."))
        }
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(startedAt, forKey: .startedAt)
        try values.encode(elapsed, forKey: .elapsed)
    }
}

public struct ProgressState: Codable, Sendable {
    public var schemaVersion: Int = 1
    public var rewardPolicyVersion: Int = 0
    public var selectedChapterID: String = "basics"
    public var selectedMode: LearningMode = .lesson
    public var selectedExerciseIDs: [String: String] = [:]
    public var drafts: [String: String] = [:]
    public var generatedExercises: [String: [Exercise]] = [:]
    public var attempts: [Attempt] = []
    public var hintCounts: [String: Int] = [:]
    public var revealedSolutions: Set<String> = []
    public var unlockedOverrides: Set<String> = []
    public var quizAnswers: [String: [String: Int]] = [:]
    public var reflections: [String: String] = [:]
    public var pythonPath: String = "/usr/bin/python3"
    public var provider: TeacherProvider = .openAI
    public var model: String = TeacherProvider.openAI.defaultModel
    public var sessionRequestLimit: Int = 20
    public var teacherConversations: [String: [TeacherMessage]] = [:]
    public var studySessions: [StudySession] = []
    public var activeStudySession: ActiveStudySession? = nil
    public var lessonCompletions: [String: Date] = [:]
    public var celebrationEffectsEnabled = true

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, rewardPolicyVersion, selectedChapterID, selectedMode, selectedExerciseIDs, drafts, generatedExercises
        case attempts, hintCounts, revealedSolutions, unlockedOverrides, quizAnswers, reflections
        case pythonPath, provider, model, sessionRequestLimit, teacherConversations
        case studySessions, activeStudySession, lessonCompletions, celebrationEffectsEnabled
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        rewardPolicyVersion = try values.decodeIfPresent(Int.self, forKey: .rewardPolicyVersion) ?? 0
        guard (0...ExperienceRules.policyVersion).contains(rewardPolicyVersion) else {
            throw DecodingError.dataCorruptedError(forKey: .rewardPolicyVersion, in: values, debugDescription: "Unsupported XP policy version.")
        }
        selectedChapterID = try values.decode(String.self, forKey: .selectedChapterID)
        selectedMode = try values.decode(LearningMode.self, forKey: .selectedMode)
        selectedExerciseIDs = try values.decode([String: String].self, forKey: .selectedExerciseIDs)
        drafts = try values.decode([String: String].self, forKey: .drafts)
        generatedExercises = try values.decode([String: [Exercise]].self, forKey: .generatedExercises)
        attempts = try values.decode([Attempt].self, forKey: .attempts)
        hintCounts = try values.decode([String: Int].self, forKey: .hintCounts)
        revealedSolutions = try values.decode(Set<String>.self, forKey: .revealedSolutions)
        unlockedOverrides = try values.decode(Set<String>.self, forKey: .unlockedOverrides)
        quizAnswers = try values.decode([String: [String: Int]].self, forKey: .quizAnswers)
        reflections = try values.decode([String: String].self, forKey: .reflections)
        pythonPath = try values.decode(String.self, forKey: .pythonPath)
        provider = try values.decodeIfPresent(TeacherProvider.self, forKey: .provider) ?? .openAI
        model = try values.decode(String.self, forKey: .model)
        sessionRequestLimit = try values.decode(Int.self, forKey: .sessionRequestLimit)
        teacherConversations = try values.contains(.teacherConversations)
            ? values.decode([String: [TeacherMessage]].self, forKey: .teacherConversations) : [:]
        studySessions = try values.contains(.studySessions)
            ? values.decode([StudySession].self, forKey: .studySessions) : []
        activeStudySession = try values.decodeIfPresent(ActiveStudySession.self, forKey: .activeStudySession)
        lessonCompletions = try values.contains(.lessonCompletions)
            ? values.decode([String: Date].self, forKey: .lessonCompletions) : [:]
        celebrationEffectsEnabled = try values.contains(.celebrationEffectsEnabled)
            ? values.decode(Bool.self, forKey: .celebrationEffectsEnabled) : true
        guard hasValidStudyHistory else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid or duplicate study history."))
        }
    }

    private var hasValidStudyHistory: Bool {
        let ids = Set(studySessions.map(\.id))
        return ids.count == studySessions.count && studySessions.allSatisfy(\.isValid)
            && lessonCompletions.values.allSatisfy { $0.timeIntervalSinceReferenceDate.isFinite }
            && (activeStudySession.map { $0.isValid && !ids.contains($0.id) } ?? true)
    }

    public func encode(to encoder: Encoder) throws {
        guard hasValidStudyHistory else {
            throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath, debugDescription: "Invalid or duplicate study history."))
        }
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(rewardPolicyVersion, forKey: .rewardPolicyVersion)
        try values.encode(selectedChapterID, forKey: .selectedChapterID)
        try values.encode(selectedMode, forKey: .selectedMode)
        try values.encode(selectedExerciseIDs, forKey: .selectedExerciseIDs)
        try values.encode(drafts, forKey: .drafts)
        try values.encode(generatedExercises, forKey: .generatedExercises)
        try values.encode(attempts, forKey: .attempts)
        try values.encode(hintCounts, forKey: .hintCounts)
        try values.encode(revealedSolutions, forKey: .revealedSolutions)
        try values.encode(unlockedOverrides, forKey: .unlockedOverrides)
        try values.encode(quizAnswers, forKey: .quizAnswers)
        try values.encode(reflections, forKey: .reflections)
        try values.encode(pythonPath, forKey: .pythonPath)
        try values.encode(provider, forKey: .provider)
        try values.encode(model, forKey: .model)
        try values.encode(sessionRequestLimit, forKey: .sessionRequestLimit)
        try values.encode(teacherConversations, forKey: .teacherConversations)
        try values.encode(studySessions, forKey: .studySessions)
        try values.encodeIfPresent(activeStudySession, forKey: .activeStudySession)
        try values.encode(lessonCompletions, forKey: .lessonCompletions)
        try values.encode(celebrationEffectsEnabled, forKey: .celebrationEffectsEnabled)
    }

    private struct Activity: Hashable {
        let chapterID: String
        let exerciseID: String
        let mode: LearningMode
    }

    public mutating func recalculateExperience() {
        var ratings: [Activity: ExerciseEffort] = [:]
        for (chapterID, exercises) in generatedExercises {
            let cap = ExperienceRules.historicalGeneratedUnitCap(chapterID: chapterID)
            for index in exercises.indices {
                let effort = exercises[index].effort?.capped(at: cap)
                generatedExercises[chapterID]?[index].effort = effort
                ratings[Activity(chapterID: chapterID, exerciseID: exercises[index].id, mode: .practice)] = effort
            }
        }
        for chapter in Curriculum.chapters {
            for exercise in chapter.exercises + Curriculum.legacyExercises(chapterID: chapter.id, mode: .practice) {
                ratings[Activity(chapterID: chapter.id, exerciseID: exercise.id, mode: .practice)] = exercise.effort
            }
            for exercise in [chapter.assessment] + Curriculum.legacyExercises(chapterID: chapter.id, mode: .assessment) {
                ratings[Activity(chapterID: chapter.id, exerciseID: exercise.id, mode: .assessment)] = exercise.effort
            }
        }
        for index in attempts.indices {
            let attempt = attempts[index]
            if let rating = ratings[Activity(chapterID: attempt.chapterID, exerciseID: attempt.exerciseID, mode: attempt.mode)] {
                attempts[index].effort = rating
            } else if attempt.mode == .practice, attempt.exerciseID.hasPrefix("generated-") {
                attempts[index].effort = attempt.effort?.capped(at: ExperienceRules.historicalGeneratedUnitCap(chapterID: attempt.chapterID))
            }
        }
        rewardPolicyVersion = ExperienceRules.policyVersion
    }

    private var chronologicalAttempts: [Attempt] {
        var seen = Set<UUID>()
        return attempts.filter { $0.date.timeIntervalSinceReferenceDate.isFinite }.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }.filter { seen.insert($0.id).inserted }
    }

    public var experienceEvents: [ExperienceEvent] {
        var events: [ExperienceEvent] = []
        var completedPractices = Set<Activity>()
        var masteredChapters = Set<String>()
        var latestIndependent: [Activity: Date] = [:]
        for attempt in chronologicalAttempts {
            let activity = Activity(chapterID: attempt.chapterID, exerciseID: Curriculum.activityID(for: attempt.exerciseID), mode: attempt.mode)
            let independent = attempt.testsPassed && attempt.hintCount == 0 && !attempt.solutionRevealed
            var amount = 0
            var title = "Weekly review"
            switch attempt.mode {
            case .practice:
                guard attempt.testsPassed else { continue }
                if completedPractices.insert(activity).inserted {
                    amount = ExperienceRules.completionXP(effort: attempt.effort, mode: .practice, solutionRevealed: attempt.solutionRevealed)
                    title = attempt.solutionRevealed ? "Guided practice" : "Practice completed"
                }
            case .assessment:
                guard attempt.demonstratesMastery else { continue }
                if masteredChapters.insert(attempt.chapterID).inserted {
                    amount = ExperienceRules.completionXP(effort: attempt.effort, mode: .assessment)
                    title = "Chapter mastered"
                }
            case .lesson:
                continue
            }
            if independent {
                if amount == 0, let latest = latestIndependent[activity], attempt.date.timeIntervalSince(latest) >= 7 * 24 * 60 * 60 {
                    amount = ExperienceRules.reviewXP
                }
                latestIndependent[activity] = attempt.date
            }
            if amount > 0 {
                events.append(ExperienceEvent(id: "attempt:\(attempt.id.uuidString)", date: attempt.date, title: title, amount: amount))
            }
        }
        for (chapter, date) in lessonCompletions where date.timeIntervalSinceReferenceDate.isFinite {
            events.append(ExperienceEvent(id: "lesson:\(chapter)", date: date, title: "Lesson completed", amount: ExperienceRules.lessonXP))
        }
        var sessionIDs = Set<UUID>()
        for session in studySessions.sorted(by: {
            $0.completedAt == $1.completedAt ? $0.id.uuidString < $1.id.uuidString : $0.completedAt < $1.completedAt
        }) where session.isValid && sessionIDs.insert(session.id).inserted {
            events.append(ExperienceEvent(id: "focus:\(session.id.uuidString)", date: session.completedAt, title: "Focus session completed", amount: ExperienceRules.focusXP))
        }
        return events.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date }
    }

    public var playerProgress: PlayerProgress {
        PlayerProgress(totalXP: experienceEvents.reduce(0) { total, event in
            let (sum, overflow) = total.addingReportingOverflow(event.amount)
            return overflow ? Int.max : sum
        })
    }

    public var completedPracticeCount: Int {
        Set(chronologicalAttempts.filter { $0.mode == .practice && $0.testsPassed }.map {
            Activity(chapterID: $0.chapterID, exerciseID: Curriculum.activityID(for: $0.exerciseID), mode: .practice)
        }).count
    }

    public var completedSessionCount: Int { Set(studySessions.filter(\.isValid).map(\.id)).count }
    public var totalFocusMinutes: Int {
        let (minutes, overflow) = completedSessionCount.multipliedReportingOverflow(by: 25)
        return overflow ? Int.max : minutes
    }

    public var masteredChapterIDs: Set<String> {
        Set(attempts.filter(\.demonstratesMastery).map(\.chapterID))
    }

    /// A chapter is unlocked when it is mastered, has a placement override, or ALL of its direct
    /// prerequisites are mastered. A chapter without prerequisites is always unlocked. Unknown chapters
    /// and prerequisites that are not in `chapters` fail closed.
    public func isUnlocked(_ chapterID: String, in chapters: [Chapter]) -> Bool {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return false }
        let mastered = masteredChapterIDs
        if mastered.contains(chapterID) || unlockedOverrides.contains(chapterID) { return true }
        let known = Set(chapters.map(\.id))
        return chapter.prerequisites.allSatisfy { $0 != chapterID && known.contains($0) && mastered.contains($0) }
    }

    /// Direct prerequisites of the chapter that are not yet mastered, in canonical order. Unknown
    /// prerequisite IDs cannot be represented as chapters and are omitted; they still keep the
    /// chapter locked (see `unknownPrerequisiteIDs`).
    public func missingPrerequisites(for chapterID: String, in chapters: [Chapter]) -> [Chapter] {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return [] }
        let mastered = masteredChapterIDs
        let required = Set(chapter.prerequisites)
        var seen = Set<String>()
        return chapters.filter { required.contains($0.id) && $0.id != chapterID && !mastered.contains($0.id) && seen.insert($0.id).inserted }
    }

    public func unknownPrerequisiteIDs(for chapterID: String, in chapters: [Chapter]) -> [String] {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return [] }
        let known = Set(chapters.map(\.id))
        return chapter.prerequisites.filter { !known.contains($0) || $0 == chapterID }
    }

    public func reviewChapterIDs(now: Date = Date()) -> Set<String> {
        Set(masteredChapterIDs.filter { chapterID in
            let latest = attempts.filter { $0.chapterID == chapterID && $0.testsPassed && $0.hintCount == 0 && !$0.solutionRevealed && ($0.mode == .practice || $0.demonstratesMastery) }.map(\.date).max() ?? .distantPast
            return now.timeIntervalSince(latest) >= 7 * 24 * 60 * 60
        })
    }
}
