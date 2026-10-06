import Foundation
import XCTest
@testable import PythonTeacherCore

final class IterationFilesCurriculumTests: XCTestCase {
    private func chapter(_ id: String) throws -> Chapter {
        try XCTUnwrap(Curriculum.chapters.first { $0.id == id }, id)
    }

    private func headingCount(_ lesson: String) -> Int {
        var inCode = false
        return lesson.components(separatedBy: .newlines).filter { line in
            if line.hasPrefix("```") { inCode.toggle(); return false }
            return !inCode && (line.hasPrefix("# ") || line.hasPrefix("## "))
        }.count
    }

    func testPlacementInTheTree() throws {
        let ids = Curriculum.chapters.map(\.id)
        let iteration = try chapter("iteration")
        let files = try chapter("files")
        XCTAssertEqual(iteration.track, .corePython)
        XCTAssertEqual(files.track, .corePython)
        XCTAssertEqual(iteration.prerequisites, ["reliability"])
        XCTAssertEqual(files.prerequisites, ["iteration"])
        XCTAssertLessThan(try XCTUnwrap(ids.firstIndex(of: "reliability")), try XCTUnwrap(ids.firstIndex(of: "iteration")))
        XCTAssertLessThan(try XCTUnwrap(ids.firstIndex(of: "iteration")), try XCTUnwrap(ids.firstIndex(of: "files")))
        for item in [iteration, files] {
            XCTAssertNil(item.title.first.flatMap { $0.isNumber ? $0 : nil }, item.title)
        }
    }

    func testSyllabusTermsAreTaught() throws {
        let terms: [String: [String]] = [
            "iteration": ["enumerate(", "start=1", "zip(", "for name, score in", ".items()", "list comprehension", "dictionary comprehension", "set comprehension", "any(", "all(", "sum(", "min(", "max(", "key=", "nested list", "Common mistakes"],
            "files": ["import math", "from math import", " as js", "pathlib", "Path(", "with open(", "\"w\"", "\"a\"", "\"r\"", "encoding=\"utf-8\"", "rstrip(", "csv.reader", "csv.DictReader", "csv.DictWriter", "writeheader", "FileNotFoundError", "date(", "timedelta(", "fromisoformat", "isoformat()", "__name__ == \"__main__\"", "Common mistakes"]
        ]
        for (id, required) in terms {
            let lesson = try chapter(id).lesson
            for term in required {
                XCTAssertTrue(lesson.contains(term), "\(id) lesson missing \(term)")
            }
        }
    }

    func testEverySectionIsPracticeAndFilesCarryCheckingGuidance() throws {
        for id in ["iteration", "files"] {
            let item = try chapter(id)
            XCTAssertTrue(item.sectionRoles.isEmpty, id)
            XCTAssertEqual(item.practiceTopics.count, headingCount(item.lesson), id)
            XCTAssertTrue(item.lessonSections.allSatisfy { $0.role == .practice }, id)
        }
        XCTAssertNil(try chapter("iteration").generationNotes)
        let notes = try XCTUnwrap(try chapter("files").generationNotes)
        XCTAssertLessThan(notes.count, 1200)
        for phrase in ["relative name", "encoding='utf-8'", "newline=''", "fresh folder", "never list", "tempfile", "date.today()"] {
            XCTAssertTrue(notes.contains(phrase), phrase)
        }
    }

    func testStructureEffortAndKnowledgeBoundaries() throws {
        for id in ["iteration", "files"] {
            let item = try chapter(id)
            let headings = headingCount(item.lesson)
            XCTAssertTrue((5...7).contains(headings), "\(id): \(headings) headings")
            XCTAssertEqual(item.lesson.components(separatedBy: .newlines).filter { $0.hasPrefix("# ") }.count, 1, id)
            let words = item.lesson.split(whereSeparator: { $0.isWhitespace }).count
            XCTAssertTrue((1200...2600).contains(words), "\(id): \(words) words")
            for exercise in item.exercises {
                let effort = try XCTUnwrap(exercise.effort, exercise.id)
                XCTAssertFalse(effort.estimated, exercise.id)
                XCTAssertLessThan(effort.practiceXP, headings * 100, exercise.id)
            }
            XCTAssertNotNil(item.assessment.effort)
            for exercise in item.exercises + [item.assessment] {
                XCTAssertTrue(exercise.hasRequiredInstructionSections, exercise.id)
                for code in [exercise.starterCode, exercise.referenceSolution] {
                    for untaught in ["class ", "yield", "match ", "dataclass", "itertools", "unittest"] {
                        XCTAssertFalse(code.contains(untaught), "\(exercise.id) uses \(untaught)")
                    }
                }
            }
        }
        let iteration = try chapter("iteration")
        for exercise in iteration.exercises + [iteration.assessment] {
            for code in [exercise.starterCode, exercise.referenceSolution] {
                for later in ["import ", "open(", "Path("] {
                    XCTAssertFalse(code.contains(later), "\(exercise.id) uses \(later) before the files chapter")
                }
            }
        }
    }
}
