import Foundation
import XCTest
@testable import PythonTeacherCore

/// Synthetic chapters for prerequisite-graph tests. Contain no real curriculum content.
enum SyntheticCurriculum {
    static func chapter(_ id: String, _ prerequisites: [String] = [], track: ChapterTrack = .foundations) -> Chapter {
        let exercise = Exercise(id: "\(id)-practice", title: "\(id) practice", instructions: "Goal:\nSynthetic.",
                                starterCode: "result = None", referenceSolution: "result = 1", testCode: "assert result == 1",
                                hints: ["a", "b", "c"], effort: ExerciseEffort(scopeUnits: 1))
        var assessment = exercise
        assessment.id = "\(id)-assessment"
        assessment.title = "\(id) assessment"
        return Chapter(id: id, title: "Synthetic \(id)", subtitle: "Synthetic subtitle \(id)", track: track,
                       prerequisites: prerequisites, lesson: "# \(id) first\nText.\n\n## \(id) second\nMore text.\n",
                       exercises: [exercise], assessment: assessment, quiz: [])
    }

    /// Diamond with a tail: D requires B and C, both require A; E requires D.
    static let diamond: [Chapter] = [chapter("A"), chapter("B", ["A"]), chapter("C", ["A"]), chapter("D", ["C", "B"]), chapter("E", ["D"])]
}

final class CurriculumGraphTests: XCTestCase {
    private func ids(_ chapters: [Chapter]?) -> [String]? { chapters?.map(\.id) }

    func testDiamondClosureIsTransitiveDeduplicatedAndCanonical() throws {
        let graph = CurriculumGraph(SyntheticCurriculum.diamond)
        XCTAssertEqual(graph.validationIssues(rootID: "A"), [])
        XCTAssertNoThrow(try graph.validate(rootID: "A"))
        XCTAssertEqual(ids(graph.prerequisiteClosure(of: "A")), [])
        XCTAssertEqual(ids(graph.prerequisiteClosure(of: "B")), ["A"])
        XCTAssertEqual(ids(graph.prerequisiteClosure(of: "D")), ["A", "B", "C"])
        XCTAssertEqual(ids(graph.prerequisiteClosure(of: "E")), ["A", "B", "C", "D"])
        XCTAssertEqual(ids(graph.closureIncludingSelf(of: "E")), ["A", "B", "C", "D", "E"])
        XCTAssertEqual(ids(graph.directPrerequisites(of: "D")), ["B", "C"], "Direct prerequisites use canonical order")
        XCTAssertEqual(ids(graph.directPrerequisites(of: "E")), ["D"])
        XCTAssertNil(graph.prerequisiteClosure(of: "missing"))
        XCTAssertNil(graph.directPrerequisites(of: "missing"))
        XCTAssertEqual(graph.index(of: "C"), 2)
    }

    func testValidationRejectsCycles() {
        let graph = CurriculumGraph([SyntheticCurriculum.chapter("A"), SyntheticCurriculum.chapter("B", ["A", "C"]), SyntheticCurriculum.chapter("C", ["B"])])
        let issues = graph.validationIssues(rootID: "A")
        XCTAssertTrue(issues.contains(.cycle(["B", "C"])), "\(issues)")
        XCTAssertTrue(issues.contains(.prerequisiteOutOfOrder(chapter: "B", prerequisite: "C")), "\(issues)")
        XCTAssertNil(graph.prerequisiteClosure(of: "B"))
        XCTAssertNil(graph.prerequisiteClosure(of: "C"))
        XCTAssertThrowsError(try graph.validate(rootID: "A")) { error in
            XCTAssertEqual((error as? CurriculumGraphError)?.issues, issues)
            XCTAssertTrue(error.localizedDescription.contains("cycle"), error.localizedDescription)
        }
        let longer = CurriculumGraph([SyntheticCurriculum.chapter("A"), SyntheticCurriculum.chapter("B", ["D"]),
                                      SyntheticCurriculum.chapter("C", ["B"]), SyntheticCurriculum.chapter("D", ["C", "A"])])
        XCTAssertEqual(longer.validationIssues(rootID: "A").filter { if case .cycle = $0 { return true } else { return false } },
                       [.cycle(["B", "D", "C"])])
    }

    func testValidationRejectsUnknownSelfDuplicateAndOutOfOrderPrerequisites() {
        let unknown = CurriculumGraph([SyntheticCurriculum.chapter("A"), SyntheticCurriculum.chapter("B", ["A", "ghost"])])
        XCTAssertEqual(unknown.validationIssues(rootID: "A"), [.unknownPrerequisite(chapter: "B", prerequisite: "ghost")])
        XCTAssertNil(unknown.prerequisiteClosure(of: "B"))
        XCTAssertNil(unknown.directPrerequisites(of: "B"))

        let selfReference = CurriculumGraph([SyntheticCurriculum.chapter("A"), SyntheticCurriculum.chapter("B", ["B"])])
        XCTAssertEqual(selfReference.validationIssues(rootID: "A"), [.selfPrerequisite("B")])
        XCTAssertNil(selfReference.prerequisiteClosure(of: "B"))

        let outOfOrder = CurriculumGraph([SyntheticCurriculum.chapter("A"), SyntheticCurriculum.chapter("C", ["B"]), SyntheticCurriculum.chapter("B", ["A"])])
        XCTAssertEqual(outOfOrder.validationIssues(rootID: "A"), [.prerequisiteOutOfOrder(chapter: "C", prerequisite: "B")])
        XCTAssertNil(outOfOrder.prerequisiteClosure(of: "C"), "A misordered edge fails closed")
        XCTAssertEqual(ids(outOfOrder.prerequisiteClosure(of: "B")), ["A"])

        let duplicates = CurriculumGraph([SyntheticCurriculum.chapter("A"), SyntheticCurriculum.chapter("B", ["A", "A"]), SyntheticCurriculum.chapter("B", ["A"])])
        XCTAssertEqual(duplicates.validationIssues(rootID: "A"), [.duplicateChapterID("B"), .duplicatePrerequisite(chapter: "B", prerequisite: "A")])
    }

    func testValidationRequiresExactlyTheExpectedRoot() {
        let twoRoots = CurriculumGraph([SyntheticCurriculum.chapter("A"), SyntheticCurriculum.chapter("X"), SyntheticCurriculum.chapter("B", ["A"])])
        XCTAssertEqual(twoRoots.validationIssues(rootID: "A"), [.invalidRoots(expected: "A", found: ["A", "X"])])
        XCTAssertEqual(CurriculumGraph(SyntheticCurriculum.diamond).validationIssues(), [.invalidRoots(expected: "basics", found: ["A"])])
        let noRoot = CurriculumGraph([SyntheticCurriculum.chapter("A", ["B"]), SyntheticCurriculum.chapter("B", ["A"])])
        XCTAssertTrue(noRoot.validationIssues(rootID: "A").contains(.invalidRoots(expected: "A", found: [])))
        XCTAssertEqual(CurriculumGraph([]).validationIssues(), [.empty])
        for issue in twoRoots.validationIssues(rootID: "A") + [.empty, .cycle(["A", "B"])] {
            XCTAssertFalse(issue.description.isEmpty)
        }
    }

    func testProjectScopeUsesPrerequisiteClosureAsToolkitForSyntheticCurriculum() throws {
        let curriculum = SyntheticCurriculum.diamond
        let d = curriculum[3]
        let project = PracticeGenerationOptions(scope: .project, difficulty: .harder, scenario: "A synthetic garden planner")
        XCTAssertEqual(try project.chapters(for: d, curriculum: curriculum).map(\.id), ["A", "B", "C", "D"])
        XCTAssertEqual(try project.chapters(for: curriculum[1], curriculum: curriculum).map(\.id), ["A", "B"])
        XCTAssertEqual(try project.chapters(for: curriculum[4], curriculum: curriculum).map(\.id), ["A", "B", "C", "D", "E"])
        XCTAssertEqual(try project.chapters(for: curriculum[0], curriculum: curriculum).map(\.id), ["A"], "the root chapter can host a project")
        XCTAssertThrowsError(try project.chapters(for: SyntheticCurriculum.chapter("unlisted", ["A"]), curriculum: curriculum))
        XCTAssertEqual(try PracticeGenerationOptions().chapters(for: d, curriculum: curriculum).map(\.id), ["D"])
        XCTAssertTrue(ProjectBrief.available(for: d, curriculum: curriculum).isEmpty, "catalog briefs need real chapters")
        let topics = try project.coverageTopics(for: d, selectedExercise: nil, curriculum: curriculum)
        XCTAssertEqual(Array(topics.dropLast()), d.practiceTopics, "only current-chapter focus sections are required")
        XCTAssertEqual(topics.last?.id, PracticeGenerationOptions.projectIntegrationTopicID)
        let effort = try ExperienceRules.generatedEffort(options: project, chapter: d, selectedExercise: nil, curriculum: curriculum)
        XCTAssertEqual(topics.count, 3)
        XCTAssertEqual(effort.scopeUnits, 2, "project coverage is capped at the assessment workload plus one unit")
        XCTAssertEqual(effort.practiceXP, 300)
        XCTAssertThrowsError(try PracticeGenerationOptions(scope: .project).coverageTopics(for: d, selectedExercise: nil, curriculum: curriculum),
                             "an own objective must be described")
        XCTAssertThrowsError(try PracticeGenerationOptions(scope: .selectedExercise).coverageTopics(for: d, selectedExercise: d.assessment, curriculum: curriculum))

        let invalid = [SyntheticCurriculum.chapter("A"), SyntheticCurriculum.chapter("B", ["A", "ghost"]),
                       SyntheticCurriculum.chapter("C", ["D"]), SyntheticCurriculum.chapter("D", ["C"])]
        for chapter in invalid.dropFirst() {
            XCTAssertThrowsError(try project.chapters(for: chapter, curriculum: invalid), chapter.id)
        }
    }
}
