import XCTest
@testable import PythonTeacherCore

final class SoftwareCraftInheritanceTestingCurriculumTests: XCTestCase {
    private func chapter(_ id: String) throws -> Chapter {
        try XCTUnwrap(Curriculum.chapters.first { $0.id == id }, id)
    }

    func testChaptersAreRegisteredOnTheSoftwareCraftTrackAfterClasses() throws {
        for id in ["inheritance", "testing"] {
            let chapter = try chapter(id)
            XCTAssertEqual(chapter.track, .softwareCraft, id)
            XCTAssertNil(chapter.title.first(where: \.isNumber), "Titles have no numeric prefix: \(chapter.title)")
            XCTAssertEqual(chapter.exercises.map(\.id).filter { $0.hasPrefix(id + "-") }.count, 3)
            XCTAssertEqual(chapter.assessment.id, id + "-assessment")
            XCTAssertEqual(chapter.quiz.map(\.id), [id + "-q1", id + "-q2", id + "-q3"])
        }
        XCTAssertEqual(try chapter("inheritance").prerequisites, ["classes"])
        XCTAssertEqual(try chapter("testing").prerequisites, ["classes", "files"], "testing relies on with and io.StringIO from files")
        let ids = Curriculum.chapters.map(\.id)
        XCTAssertLessThan(try XCTUnwrap(ids.firstIndex(of: "files")), try XCTUnwrap(ids.firstIndex(of: "testing")))
        let classesIndex = try XCTUnwrap(ids.firstIndex(of: "classes"))
        for id in ["inheritance", "testing"] {
            XCTAssertGreaterThan(try XCTUnwrap(ids.firstIndex(of: id)), classesIndex, id)
        }
    }

    func testEverySyllabusTermIsTaughtInTheLesson() throws {
        let inheritance = try chapter("inheritance").lesson
        for term in ["subclass", "super().__init__", "override", "isinstance", "issubclass", "@property", "ABC", "@abstractmethod", "from abc import ABC, abstractmethod", "composition", "Common mistakes"] {
            XCTAssertTrue(inheritance.contains(term), "inheritance lesson is missing \(term)")
        }
        let testing = try chapter("testing").lesson
        for term in ["unittest.TestCase", "assertEqual", "assertRaises", "assertAlmostEqual", "setUp", "unittest.main(argv=[''], exit=False)", "TextTestRunner(stream=io.StringIO())", "loadTestsFromTestCase", "wasSuccessful()", "boundar", "mutation", "Common mistakes"] {
            XCTAssertTrue(testing.contains(term), "testing lesson is missing \(term)")
        }
    }

    func testLessonShapeAndEffortStayWithinSectionBudget() throws {
        for id in ["inheritance", "testing"] {
            let chapter = try chapter(id)
            let lines = chapter.lesson.components(separatedBy: .newlines)
            XCTAssertEqual(lines.filter { $0.hasPrefix("# ") }.count, 1, id)
            let sections = lines.filter { $0.hasPrefix("## ") }.count
            XCTAssertTrue((4...6).contains(sections), "\(id) has \(sections) sections")
            let words = chapter.lesson.split(whereSeparator: { $0.isWhitespace }).count
            XCTAssertTrue((1200...3200).contains(words), "\(id): \(words) words")
            let headings = lines.filter { $0.hasPrefix("# ") || $0.hasPrefix("## ") }.count
            for exercise in chapter.exercises {
                let effort = try XCTUnwrap(exercise.effort, exercise.id)
                XCTAssertFalse(effort.estimated, exercise.id)
                XCTAssertLessThan(effort.practiceXP, headings * 100, exercise.id)
            }
            XCTAssertNotNil(chapter.assessment.effort)
            for exercise in chapter.exercises + [chapter.assessment] {
                let sectionOrder = ["Goal:", "Starting code:", "Your task:", "Expected result:", "Check:"].map { exercise.instructions.range(of: $0)?.lowerBound }
                XCTAssertFalse(sectionOrder.contains { $0 == nil }, exercise.id)
                let positions = sectionOrder.compactMap { $0 }
                XCTAssertEqual(positions, positions.sorted(), exercise.id)
            }
        }
    }

    func testTestingExercisesRunLearnerSuitesAgainstBuggyImplementations() throws {
        let testing = try chapter("testing")
        for exercise in testing.exercises + [testing.assessment] {
            XCTAssertTrue(exercise.starterCode.contains("unittest.TestCase"), exercise.id)
            XCTAssertTrue(exercise.testCode.contains("loadTestsFromTestCase"), exercise.id)
            XCTAssertTrue(exercise.testCode.contains("assert not run_learner_tests("), exercise.id)
            XCTAssertTrue(exercise.testCode.contains("__globals__"), exercise.id)
            XCTAssertTrue(exercise.instructions.contains("with its exact name"), exercise.id)
            XCTAssertTrue(exercise.instructions.contains("swaps"), exercise.id)
        }
    }

    func testTestingLessonExplainsStringIOAndWithBeforeUseWithoutAssumingInheritance() throws {
        let lesson = try chapter("testing").lesson
        let explained = try XCTUnwrap(lesson.range(of: "in-memory text container")).lowerBound
        let firstUse = try XCTUnwrap(lesson.range(of: "stream=io.StringIO()")).lowerBound
        XCTAssertLessThan(explained, firstUse)
        XCTAssertTrue(lesson.contains("same `with` statement you used in the files chapter"))
        XCTAssertFalse(lesson.contains("The inheritance chapter explains"))
    }

    func testSectionRolesMarkOnlyTheOrientationSectionsAsOverview() throws {
        let expected: [String: [String: LessonSectionRole]] = [
            "inheritance": ["Build new classes from existing ones": .overview],
            "testing": ["Tests are programs that check programs": .overview]
        ]
        for (id, roles) in expected {
            let chapter = try chapter(id)
            let headings = chapter.lessonSections.map(\.heading)
            XCTAssertEqual(chapter.sectionRoles, roles, id)
            for key in chapter.sectionRoles.keys {
                XCTAssertTrue(headings.contains(key), "\(id) role key \(key) matches no heading")
            }
            let nonPractice = Dictionary(uniqueKeysWithValues: chapter.lessonSections.filter { $0.role != .practice }.map { ($0.heading, $0.role) })
            XCTAssertEqual(nonPractice, roles, id)
            XCTAssertEqual(chapter.practiceTopics.count, headings.count - roles.count, id)
            XCTAssertEqual(chapter.practiceTopics(for: .debug), chapter.practiceTopics, "\(id) has no troubleshooting heading")
        }
        XCTAssertNil(try chapter("inheritance").generationNotes)
    }

    func testTestingGenerationNotesDescribeTheMutationCheckingPattern() throws {
        let notes = try XCTUnwrap(try chapter("testing").generationNotes)
        XCTAssertFalse(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertLessThan(notes.count, 1500)
        for term in ["unittest.TestCase", "loadTestsFromTestCase", "TextTestRunner(stream=io.StringIO())", "__globals__", "buggy", "restores", "wasSuccessful()", "testsRun", "unittest.main(argv=[''], exit=False)", "Never use test discovery", "starter must fail Check"] {
            XCTAssertTrue(notes.contains(term), "testing generationNotes missing \(term)")
        }
        for exercise in try chapter("testing").exercises {
            XCTAssertFalse(notes.contains(exercise.id), "notes must not copy exercise content")
        }
        XCTAssertFalse(notes.contains("LatencyTracker"), "notes must not reveal assessment content")
    }

    func testTestingChecksRejectRenamedImplementationsWithAssertionError() async throws {
        let testing = try chapter("testing")
        let renames = [
            "testing-latency-bands": "latency_band",
            "testing-cost-errors": "estimate_cost",
            "testing-budget-setup": "TokenBudget",
            "testing-assessment": "LatencyTracker"
        ]
        let runner = PythonRunner()
        let python = ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
        for exercise in testing.exercises + [testing.assessment] {
            let name = try XCTUnwrap(renames[exercise.id], exercise.id)
            let renamed = exercise.referenceSolution
                .replacingOccurrences(of: name + "(", with: name + "_renamed(")
                .replacingOccurrences(of: "class \(name):", with: "class \(name)_renamed:")
            XCTAssertNotEqual(renamed, exercise.referenceSolution, exercise.id)
            let result: RunResult
            do {
                result = try await runner.run(code: renamed, tests: exercise.testCode, pythonPath: python)
            } catch PythonRunnerError.sandboxUnavailable {
                throw XCTSkip("macOS sandbox unavailable; no unrestricted curriculum execution attempted.")
            } catch PythonRunnerError.interpreterDiscovery(let reason) {
                throw XCTSkip("Python unavailable: \(reason)")
            }
            if result.output.contains("sandbox_apply:") || result.output.contains("sandbox-exec: Operation not permitted") {
                throw XCTSkip("This environment refuses sandbox creation: \(result.output)")
            }
            XCTAssertFalse(result.passed, exercise.id)
            XCTAssertTrue(result.output.contains("AssertionError"), "\(exercise.id): \(result.output)")
            XCTAssertTrue(result.output.contains("original name"), "\(exercise.id): \(result.output)")
            XCTAssertFalse(result.output.contains("NameError"), "\(exercise.id): \(result.output)")
        }
    }
}
