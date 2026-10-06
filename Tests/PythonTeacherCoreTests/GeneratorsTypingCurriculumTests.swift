import Foundation
import XCTest
@testable import PythonTeacherCore

final class GeneratorsTypingCurriculumTests: XCTestCase {
    private func chapter(_ id: String) throws -> Chapter {
        try XCTUnwrap(Curriculum.chapters.first { $0.id == id }, id)
    }

    func testChaptersAreRegisteredAfterTheirPrerequisites() throws {
        let generators = try chapter("generators")
        let typing = try chapter("typing-decorators")
        XCTAssertEqual(generators.track, .softwareCraft)
        XCTAssertEqual(generators.prerequisites, ["classes"])
        XCTAssertEqual(typing.track, .softwareCraft)
        XCTAssertEqual(typing.prerequisites, ["inheritance", "generators"])
        let ids = Curriculum.chapters.map(\.id)
        XCTAssertLessThan(try XCTUnwrap(ids.firstIndex(of: "generators")), try XCTUnwrap(ids.firstIndex(of: "typing-decorators")))
        for item in [generators, typing] {
            XCTAssertFalse(item.title.first?.isNumber ?? true, item.id)
        }
    }

    func testSyllabusTermsAreTaught() throws {
        let terms: [String: [String]] = [
            "generators": ["iter(", "next(", "StopIteration", "__iter__", "__next__", "yield", "generator expression", "lazy", "itertools.islice", "itertools.count", "itertools.chain", "itertools.groupby", "Common mistakes"],
            "typing-decorators": ["type hint", "List[", "Dict[", "Optional[", "from __future__ import annotations", "not enforced at runtime", "Callable[", "closure", "nonlocal", "*args", "**kwargs", "decorator", "functools.wraps", "functools.lru_cache", "cache_info", "Common mistakes"]
        ]
        for (id, required) in terms {
            let lesson = try chapter(id).lesson
            for term in required {
                XCTAssertTrue(lesson.contains(term), "\(id) lesson missing \(term)")
            }
        }
    }

    func testLessonShapeEffortAndInstructionOrder() throws {
        for id in ["generators", "typing-decorators"] {
            let item = try chapter(id)
            let lines = item.lesson.components(separatedBy: .newlines)
            XCTAssertEqual(lines.filter { $0.hasPrefix("# ") }.count, 1, id)
            let sections = lines.filter { $0.hasPrefix("## ") }.count
            XCTAssertGreaterThanOrEqual(sections, 4, id)
            let words = item.lesson.split(whereSeparator: { $0.isWhitespace }).count
            XCTAssertGreaterThanOrEqual(words, 1200, "\(id): \(words) words")
            let blocks = item.lesson.components(separatedBy: "```python\n").dropFirst().map { String($0.components(separatedBy: "```")[0]) }
            XCTAssertGreaterThanOrEqual(blocks.count, 6, id)
            for block in blocks {
                XCTAssertFalse(block.contains("| None"), id)
                XCTAssertFalse(block.contains("input("), id)
            }
            let headings = item.practiceTopics.count
            for exercise in item.exercises {
                let effort = try XCTUnwrap(exercise.effort, exercise.id)
                XCTAssertLessThan(effort.practiceXP, headings * 100, exercise.id)
                XCTAssertEqual(exercise.hints.count, 3, exercise.id)
            }
            XCTAssertNotNil(item.assessment.effort)
            XCTAssertEqual(item.quiz.map(\.id), ["\(id)-q1", "\(id)-q2", "\(id)-q3"])
            for exercise in item.exercises + [item.assessment] {
                var cursor = exercise.instructions.startIndex
                for section in ["Goal:\n", "Starting code:\n", "Your task:\n1. ", "Expected result:\n", "Check:\n"] {
                    let range = try XCTUnwrap(exercise.instructions.range(of: section, range: cursor..<exercise.instructions.endIndex), "\(exercise.id) \(section)")
                    cursor = range.upperBound
                }
                for code in [exercise.starterCode, exercise.referenceSolution, exercise.testCode] {
                    XCTAssertFalse(code.contains("| None"), exercise.id)
                    XCTAssertFalse(code.contains("match "), exercise.id)
                }
            }
        }
    }

    func testSectionRolesSeparateOverviewAndTroubleshootingSections() throws {
        let expected: [String: [String: LessonSectionRole]] = [
            "generators": ["Produce values one at a time": .overview, "Common mistakes and debugging": .troubleshooting],
            "typing-decorators": ["Describe and wrap functions": .overview, "Common mistakes and debugging": .troubleshooting]
        ]
        for (id, roles) in expected {
            let item = try chapter(id)
            let headings = item.lessonSections.map(\.heading)
            XCTAssertEqual(item.sectionRoles, roles, id)
            for key in item.sectionRoles.keys {
                XCTAssertTrue(headings.contains(key), "\(id) role key \(key) matches no heading")
            }
            let nonPractice = Dictionary(uniqueKeysWithValues: item.lessonSections.filter { $0.role != .practice }.map { ($0.heading, $0.role) })
            XCTAssertEqual(nonPractice, roles, id)
            XCTAssertEqual(item.practiceTopics.count, headings.count - 2, id)
            XCTAssertEqual(item.practiceTopics(for: .debug).count, headings.count - 1, id)
            XCTAssertEqual(item.lessonSections.last?.role, .troubleshooting, id)
        }
    }

    func testGenerationNotesDescribeEvidenceBasedChecks() throws {
        let generators = try XCTUnwrap(try chapter("generators").generationNotes)
        XCTAssertLessThan(generators.count, 1000)
        for term in ["laziness", "inspect.isgeneratorfunction", "itertools.islice", "never call list", "iter(obj) is obj"] {
            XCTAssertTrue(generators.contains(term), "generators notes missing \(term)")
        }
        let typing = try XCTUnwrap(try chapter("typing-decorators").generationNotes)
        XCTAssertLessThan(typing.count, 1000)
        for term in ["__annotations__", "Optional[", "__wrapped__", "cache_clear()", "cache_info()"] {
            XCTAssertTrue(typing.contains(term), "typing-decorators notes missing \(term)")
        }
    }

    func testInfiniteIteratorsAreAlwaysBoundedInExamples() throws {
        let lesson = try chapter("generators").lesson
        XCTAssertFalse(lesson.contains("list(itertools.count"))
        XCTAssertFalse(lesson.contains("list(count("))
        XCTAssertFalse(lesson.contains("list(request_numbers("))
    }
}
