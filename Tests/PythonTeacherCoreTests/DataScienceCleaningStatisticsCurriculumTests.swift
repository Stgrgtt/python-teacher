import Foundation
import XCTest
@testable import PythonTeacherCore

final class DataScienceCleaningStatisticsCurriculumTests: XCTestCase {
    private func chapter(_ id: String) throws -> Chapter {
        try XCTUnwrap(Curriculum.chapters.first { $0.id == id }, id)
    }

    func testChaptersAreRegisteredInTheDataScienceTrack() throws {
        let cleaning = try chapter("ds-cleaning")
        let statistics = try chapter("ds-statistics")
        XCTAssertEqual(cleaning.track, .dataScience)
        XCTAssertEqual(statistics.track, .dataScience)
        XCTAssertEqual(cleaning.prerequisites, ["files"])
        XCTAssertEqual(statistics.prerequisites, ["ds-cleaning"])
        let ids = Curriculum.chapters.map(\.id)
        XCTAssertLessThan(try XCTUnwrap(ids.firstIndex(of: "ds-cleaning")), try XCTUnwrap(ids.firstIndex(of: "ds-statistics")))
        for item in [cleaning, statistics] {
            XCTAssertFalse(item.title.first?.isNumber ?? true, item.title)
            XCTAssertEqual(item.exercises.count, 3)
            XCTAssertEqual(item.quiz.map(\.id), ["q1", "q2", "q3"].map { "\(item.id)-\($0)" })
        }
    }

    func testEverySyllabusTopicIsTaughtInTheLesson() throws {
        let topics: [String: [String]] = [
            "ds-cleaning": ["list of dictionaries", "csv.DictReader", "io.StringIO", "Type conversion", "int(", "float(", "missing marker", "None", "Normalization", "De-duplication", "cleaning report", "csv.DictWriter", "writerows", "pandas"],
            "ds-statistics": ["statistics.mean", "statistics.median", "statistics.mode", "statistics.stdev", "statistics.pstdev", "statistics.quantiles", "sample", "population", "interquartile range", "z-score", "Pearson", "random.Random(", "seed", "train/test split", "data leakage", "tolerance", "abs(x)", "absolute value", "scientific notation", "0.000000001"]
        ]
        for (id, terms) in topics {
            let lesson = try chapter(id).lesson
            for term in terms {
                XCTAssertTrue(lesson.contains(term), "\(id) lesson does not teach \(term)")
            }
            let lines = lesson.components(separatedBy: .newlines)
            XCTAssertEqual(lines.filter { $0.hasPrefix("# ") }.count, 1, id)
            XCTAssertTrue((4...6).contains(lines.filter { $0.hasPrefix("## ") }.count), id)
            XCTAssertTrue(lesson.contains("## Common mistakes and debugging"), id)
            let words = lesson.split(whereSeparator: { $0.isWhitespace }).count
            XCTAssertTrue((1200...2500).contains(words), "\(id): \(words) words")
        }
    }

    func testToleranceSyntaxIsExplainedBeforeItIsUsedAndDedupeExampleMatchesExercise() throws {
        let statistics = try chapter("ds-statistics").lesson
        let explained = try XCTUnwrap(statistics.range(of: "scientific notation")).lowerBound
        let firstUse = try XCTUnwrap(statistics.range(of: "abs(total - 0.3) < 1e-9")).lowerBound
        XCTAssertLessThan(explained, firstUse)
        let cleaning = try chapter("ds-cleaning").lesson
        let blocks = cleaning.components(separatedBy: "```python\n").dropFirst().map { String($0.components(separatedBy: "```")[0]) }
        let dedupe = try XCTUnwrap(blocks.first { $0.contains("seen = set()") })
        XCTAssertTrue(dedupe.contains("unique.append({\"prompt\": prompt, \"label\": label})"))
        XCTAssertFalse(dedupe.contains("unique.append(row)"))
    }

    func testCodeAvoidsNewerPythonAndUnseededRandomness() throws {
        let forbidden = ["statistics.correlation", "linear_regression", "fmean", "match ", "strict=", "dataclass", "class ", "input("]
        for item in [try chapter("ds-cleaning"), try chapter("ds-statistics")] {
            let blocks = item.lesson.components(separatedBy: "```python\n").dropFirst().map { String($0.components(separatedBy: "```")[0]) }
            let code = blocks + (item.exercises + [item.assessment]).flatMap { [$0.starterCode, $0.referenceSolution, $0.testCode] }
            for snippet in code {
                for term in forbidden {
                    XCTAssertFalse(snippet.contains(term), "\(item.id) uses \(term)")
                }
                for unseeded in ["random.shuffle(", "random.sample(", "random.random(", "random.choice(", "random.seed("] {
                    XCTAssertFalse(snippet.contains(unseeded), "\(item.id) uses module-level \(unseeded)")
                }
            }
        }
        let assessment = try chapter("ds-statistics").assessment
        XCTAssertTrue(assessment.referenceSolution.contains("random.Random(seed)"))
    }

    func testEffortIsExplicitAndBelowWholeChapterPractice() throws {
        let expected: [String: ExerciseEffort] = [
            "ds-cleaning-load": .init(scopeUnits: 2),
            "ds-cleaning-missing": .init(scopeUnits: 2),
            "ds-cleaning-dedupe": .init(scopeUnits: 3),
            "ds-cleaning-assessment": .init(scopeUnits: 4),
            "ds-statistics-summary": .init(scopeUnits: 3),
            "ds-statistics-outliers": .init(scopeUnits: 2),
            "ds-statistics-correlation": .init(difficulty: .harder, scopeUnits: 3),
            "ds-statistics-assessment": .init(scopeUnits: 3)
        ]
        for item in [try chapter("ds-cleaning"), try chapter("ds-statistics")] {
            let headings = item.lesson.components(separatedBy: .newlines).filter { $0.hasPrefix("# ") || $0.hasPrefix("## ") }.count
            for exercise in item.exercises + [item.assessment] {
                XCTAssertEqual(exercise.effort, expected[exercise.id], exercise.id)
            }
            for exercise in item.exercises {
                XCTAssertLessThan(try XCTUnwrap(exercise.effort).practiceXP, headings * 100, exercise.id)
            }
        }
    }

    func testInstructionSectionsAppearInOrder() throws {
        let sections = ["Goal:", "Starting code:", "Your task:", "Expected result:", "Check:"]
        for item in [try chapter("ds-cleaning"), try chapter("ds-statistics")] {
            for exercise in item.exercises + [item.assessment] {
                var cursor = exercise.instructions.startIndex
                for section in sections {
                    let range = try XCTUnwrap(exercise.instructions.range(of: section, range: cursor..<exercise.instructions.endIndex), "\(exercise.id) \(section)")
                    cursor = range.upperBound
                }
                XCTAssertTrue(exercise.instructions.contains("\n1. "), exercise.id)
            }
        }
    }

    func testSectionRolesMarkOnlyOrientationAndTroubleshootingAsNonPractice() throws {
        let expected: [String: [String: LessonSectionRole]] = [
            "ds-cleaning": ["Clean data before you analyze it": .overview, "Common mistakes and debugging": .troubleshooting],
            "ds-statistics": ["Summarize data with numbers": .overview, "Common mistakes and debugging": .troubleshooting]
        ]
        for (id, roles) in expected {
            let item = try chapter(id)
            let headings = Set(item.lessonSections.map(\.heading))
            for key in item.sectionRoles.keys {
                XCTAssertTrue(headings.contains(key), "\(id) role key \(key) is not a lesson heading")
            }
            let nonPractice = Dictionary(uniqueKeysWithValues: item.lessonSections.filter { $0.role != .practice }.map { ($0.heading, $0.role) })
            XCTAssertEqual(nonPractice, roles, id)
            XCTAssertEqual(item.practiceTopics.count, item.lessonSections.count - 2, id)
            XCTAssertEqual(item.practiceTopics(for: .debug).count, item.lessonSections.count - 1, id)
        }
        XCTAssertNil(try chapter("ds-cleaning").generationNotes)
        let notes = try XCTUnwrap(try chapter("ds-statistics").generationNotes)
        XCTAssertLessThan(notes.count, 1_000)
        XCTAssertTrue(notes.contains("random.Random(seed)"))
    }
}
