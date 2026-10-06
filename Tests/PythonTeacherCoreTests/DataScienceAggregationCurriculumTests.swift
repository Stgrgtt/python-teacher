import XCTest
@testable import PythonTeacherCore

final class DataScienceAggregationCurriculumTests: XCTestCase {
    private var chapter: Chapter { Curriculum.dsAggregation }

    func testChapterIsRegisteredWithItsTrackAndPrerequisites() throws {
        let registered = try XCTUnwrap(Curriculum.chapters.first { $0.id == "ds-aggregation" })
        XCTAssertEqual(registered.track, .dataScience)
        XCTAssertEqual(registered.prerequisites, ["ds-statistics", "classes"])
        XCTAssertFalse(registered.title.first?.isNumber ?? true)
        let index = try XCTUnwrap(Curriculum.chapters.firstIndex { $0.id == "ds-aggregation" })
        for prerequisite in registered.prerequisites {
            if let prerequisiteIndex = Curriculum.chapters.firstIndex(where: { $0.id == prerequisite }) {
                XCTAssertLessThan(prerequisiteIndex, index, prerequisite)
            }
        }
    }

    func testLessonTeachesEverySyllabusTerm() {
        let lesson = chapter.lesson
        for term in ["Counter", "most_common", "defaultdict", "Group-by", "multi-key", "tuple", "join", "left join", "inner join", "unmatched", "pivot", "top-n", "dataclass", ":.2f", ":>8", ":,", "round(", "groupby", "merge", "pivot_table", "Common mistakes", "nothing to do with the earlier chapter called \"Collections and JSON\""] {
            XCTAssertTrue(lesson.contains(term), "lesson missing \(term)")
        }
        let headings = lesson.components(separatedBy: .newlines)
        XCTAssertEqual(headings.filter { $0.hasPrefix("# ") }.count, 1)
        let sections = headings.filter { $0.hasPrefix("## ") }.count
        XCTAssertTrue((4...6).contains(sections), "\(sections) sections")
        let words = lesson.split(whereSeparator: { $0.isWhitespace }).count
        XCTAssertTrue((1200...2500).contains(words), "\(words) words")
    }

    func testExercisesPracticeEveryTopicAndRespectEffortLimits() throws {
        let headingCount = chapter.lesson.components(separatedBy: .newlines).filter { $0.hasPrefix("# ") || $0.hasPrefix("## ") }.count
        for exercise in chapter.exercises {
            let effort = try XCTUnwrap(exercise.effort, exercise.id)
            XCTAssertLessThan(effort.practiceXP, headingCount * 100, exercise.id)
        }
        XCTAssertNotNil(chapter.assessment.effort)
        let allCode = (chapter.exercises + [chapter.assessment]).map(\.referenceSolution).joined(separator: "\n")
        for term in ["Counter(", "defaultdict(", "@dataclass", ":.2f", ",}", ":>", ":<", ".get(", "[:n]"] {
            XCTAssertTrue(allCode.contains(term), "references never practice \(term)")
        }
        XCTAssertTrue(allCode.contains("(row['model'], row['day'])"), "multi-key tuple grouping")
        XCTAssertEqual(chapter.exercises.map(\.id), ["ds-aggregation-top-labels", "ds-aggregation-pivot", "ds-aggregation-join"])
        XCTAssertEqual(chapter.quiz.map(\.id), ["ds-aggregation-q1", "ds-aggregation-q2", "ds-aggregation-q3"])
    }

    func testInstructionSectionsAppearInOrder() {
        for exercise in chapter.exercises + [chapter.assessment] {
            let sections = ["Goal:", "Starting code:", "Your task:", "Expected result:", "Check:"]
            var cursor = exercise.instructions.startIndex
            var ranges: [Range<String.Index>] = []
            for section in sections {
                guard let range = exercise.instructions.range(of: section, range: cursor..<exercise.instructions.endIndex) else {
                    XCTFail("\(exercise.id) missing \(section) in order")
                    return
                }
                ranges.append(range)
                cursor = range.upperBound
            }
            for (offset, range) in ranges.enumerated() {
                let end = offset + 1 < ranges.count ? ranges[offset + 1].lowerBound : exercise.instructions.endIndex
                XCTAssertFalse(exercise.instructions[range.upperBound..<end].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(exercise.id) empty \(sections[offset])")
            }
            XCTAssertTrue(exercise.instructions.contains("\n1. "), exercise.id)
        }
    }

    func testSectionRolesMarkOnlyOrientationAndTroubleshootingAsNonPractice() throws {
        let headings = Set(chapter.lessonSections.map(\.heading))
        for key in chapter.sectionRoles.keys {
            XCTAssertTrue(headings.contains(key), "role key \(key) is not a lesson heading")
        }
        let nonPractice = Dictionary(uniqueKeysWithValues: chapter.lessonSections.filter { $0.role != .practice }.map { ($0.heading, $0.role) })
        XCTAssertEqual(nonPractice, ["Turn rows into summaries": .overview, "Common mistakes and debugging": .troubleshooting])
        XCTAssertEqual(chapter.practiceTopics.count, chapter.lessonSections.count - 2)
        XCTAssertEqual(chapter.practiceTopics(for: .debug).count, chapter.lessonSections.count - 1)
        let notes = try XCTUnwrap(chapter.generationNotes)
        XCTAssertLessThan(notes.count, 1_000)
        XCTAssertTrue(notes.contains("tie"))
    }
}
