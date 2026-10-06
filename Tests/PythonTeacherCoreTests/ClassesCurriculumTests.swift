import Foundation
import XCTest
@testable import PythonTeacherCore

final class ClassesCurriculumTests: XCTestCase {
    private var chapter: Chapter { Curriculum.classes }

    func testChapterIsRegisteredAfterPrerequisiteSlotWithCorePythonTrack() throws {
        let registered = try XCTUnwrap(Curriculum.chapters.first { $0.id == "classes" })
        XCTAssertEqual(registered.track, .corePython)
        XCTAssertEqual(registered.prerequisites, ["iteration"])
        XCTAssertEqual(registered.title, "Classes and objects")
        XCTAssertNil(registered.title.first(where: \.isNumber))
        if let iteration = Curriculum.chapters.firstIndex(where: { $0.id == "iteration" }), let classes = Curriculum.chapters.firstIndex(where: { $0.id == "classes" }) {
            XCTAssertLessThan(iteration, classes)
        }
    }

    func testLessonTeachesEverySyllabusTermInSections() {
        let lesson = chapter.lesson
        let lines = lesson.components(separatedBy: .newlines)
        XCTAssertEqual(lines.filter { $0.hasPrefix("# ") }.count, 1)
        let sections = lines.filter { $0.hasPrefix("## ") }
        XCTAssertTrue((4...6).contains(sections.count), "\(sections.count) sections")
        let words = lesson.split(whereSeparator: { $0.isWhitespace }).count
        XCTAssertTrue((1200...2600).contains(words), "\(words) words")
        for term in ["class", "instance", "object", "__init__", "self", "attribute", "method", "__repr__", "__eq__", "NotImplemented", "class attribute", "instance attribute", "aliasing", "mutate", "@dataclass", "from dataclasses import dataclass, field", "default_factory", "type annotation", "class BudgetError(ValueError):", "pass", "!r", "repr(", "Common mistakes"] {
            XCTAssertTrue(lesson.contains(term), "Lesson must explain \(term)")
        }
    }

    func testExercisesPracticeTheSyllabusAndHaveSafeEffort() {
        let headings = chapter.practiceTopics.count
        for exercise in chapter.exercises {
            let effort = exercise.effort
            XCTAssertNotNil(effort, exercise.id)
            XCTAssertLessThan(effort?.practiceXP ?? Int.max, headings * 100, exercise.id)
            XCTAssertTrue(exercise.instructions.contains("Check solution"), exercise.id)
            XCTAssertEqual(exercise.hints.count, 3, exercise.id)
        }
        XCTAssertNotNil(chapter.assessment.effort)
        XCTAssertTrue(chapter.assessment.hints.isEmpty)
        XCTAssertFalse(chapter.assessment.instructions.contains("Check solution"))
        let practiced = (chapter.exercises + [chapter.assessment]).map(\.referenceSolution).joined(separator: "\n")
        for term in ["class ", "__init__", "self.", "def ", "__repr__", "__eq__", "NotImplemented", "@dataclass", "default_factory=list", "(ValueError):", "!r", "raise "] {
            XCTAssertTrue(practiced.contains(term), "Exercises must practice \(term)")
        }
        XCTAssertTrue(chapter.exercises.contains { $0.testCode.contains(" is not ") }, "aliasing must be checked")
        XCTAssertTrue(chapter.exercises.contains { $0.testCode.contains("EvalResult.pass_mark") }, "class attributes must be checked")
    }

    func testOnlyTheOpeningOrientationIsOverview() {
        XCTAssertEqual(chapter.sectionRoles, ["Bundle data with the behaviour that uses it": .overview])
        let sections = chapter.lessonSections
        XCTAssertTrue(Set(chapter.sectionRoles.keys).isSubset(of: Set(sections.map(\.heading))))
        XCTAssertEqual(sections.filter { $0.role != .practice }.map(\.heading), ["Bundle data with the behaviour that uses it"])
        XCTAssertEqual(sections.first { $0.heading == "Custom exceptions and debugging" }?.role, .practice, "it teaches custom exceptions")
        XCTAssertEqual(chapter.practiceTopics.count, sections.count - 1)
        XCTAssertNil(chapter.generationNotes)
    }

    func testInstructionSectionsAreOrderedAndNonEmpty() {
        for exercise in chapter.exercises + [chapter.assessment] {
            XCTAssertTrue(exercise.hasRequiredInstructionSections, exercise.id)
            XCTAssertTrue(exercise.instructions.contains("Your task:\n1. "), exercise.id)
        }
    }

    func testOnlyKnownSyntaxIsUsedInLearnerCode() {
        for exercise in chapter.exercises + [chapter.assessment] {
            for code in [exercise.starterCode, exercise.referenceSolution, exercise.testCode] {
                for unknown in ["match ", "super(", "@property", "yield", "lambda", "import typing", "kw_only", "slots="] {
                    XCTAssertFalse(code.contains(unknown), "\(exercise.id) uses \(unknown)")
                }
            }
        }
    }
}
