import Foundation
import XCTest
@testable import PythonTeacherCore

final class RecordPracticeCurriculumTests: XCTestCase {
    private let stockID = "collections-transfer-stock-report"
    private let labelsID = "collections-maintenance-label-counts"
    private let gradebookID = "reliability-transfer-gradebook"

    private var pythonPath: String {
        ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
    }

    private var exercises: [Exercise] {
        Curriculum.chapters.flatMap(\.exercises).filter { [stockID, labelsID, gradebookID].contains($0.id) }
    }

    private func exercise(_ id: String) throws -> Exercise {
        try XCTUnwrap(exercises.first { $0.id == id }, id)
    }

    private enum SandboxProbeFailure: Error {
        case failed(String)
    }

    private func requireSandbox() async throws {
        let result: RunResult
        do {
            result = try await PythonRunner().run(code: "print('sandbox-ready')", pythonPath: pythonPath)
        } catch PythonRunnerError.sandboxUnavailable {
            throw XCTSkip("sandbox-exec is unavailable; unrestricted execution was not attempted.")
        } catch PythonRunnerError.interpreterDiscovery(let message) {
            throw XCTSkip("Apple developer-tools Python unavailable: \(message). Set PYTHON_TEACHER_TEST_PYTHON to a real interpreter.")
        }
        if result.output.contains("sandbox_apply:") || result.output.contains("sandbox-exec: Operation not permitted") {
            throw XCTSkip("This environment refuses sandbox creation: \(result.output)")
        }
        XCTAssertTrue(result.passed, result.output)
        XCTAssertEqual(result.exitCode, 0, result.output)
        XCTAssertTrue(result.output.contains("sandbox-ready"), result.output)
        guard result.passed else { throw SandboxProbeFailure.failed(result.output) }
    }

    func testExactlyThreeRecordTasksAppendAfterUnchangedActivityIDs() throws {
        let collections = try XCTUnwrap(Curriculum.chapters.first { $0.id == "collections" })
        let reliability = try XCTUnwrap(Curriculum.chapters.first { $0.id == "reliability" })
        XCTAssertEqual(collections.exercises.map(\.id), ["collections-count", "collections-json", "collections-rank", "collections-debug-optional-field", stockID, labelsID])
        XCTAssertEqual(reliability.exercises.map(\.id), ["reliability-score", "reliability-parse", "reliability-summary", "reliability-debug-later-record", gradebookID])
        XCTAssertEqual(exercises.count, 3)
        XCTAssertEqual(collections.assessment.id, "collections-assessment")
        XCTAssertEqual(reliability.assessment.id, "reliability-assessment")
        XCTAssertEqual(collections.lessonSections.map(\.heading), ["Choose a structure that fits", "Count repeated categories", "Convert JSON text into Python values", "Group fixed values in a tuple", "Sort without changing the input", "Keep unique names when requested", "Debug the shape"])
        XCTAssertEqual(reliability.lessonSections.map(\.heading), ["Make failure part of the contract", "Check types before using operations", "Catch an expected failure", "Validate formats, not just conversions", "Tests are evidence, not validation code", "Build a small trustworthy tool"])
        XCTAssertTrue(collections.lesson.contains("### Maintenance/change-request checklist"))
        XCTAssertTrue(collections.lesson.contains("Rerun the new example and the retained old examples"))
    }

    func testRecordProfilesInstructionsAndReviewedEfforts() throws {
        let expected: [(String, PracticeForm, PracticeScaffolding, Int, [String])] = [
            (stockID, .transfer, .independent, 2, ["collections-section-1", "collections-section-2", "functions-section-1"]),
            (labelsID, .maintenance, .light, 1, ["values-section-2", "collections-section-2", "collections-section-7"]),
            (gradebookID, .transfer, .independent, 3, ["reliability-section-1", "reliability-section-2", "reliability-section-5", "reliability-section-6"])
        ]
        let sections = Curriculum.chapters.flatMap(\.lessonSections)
        for (id, form, scaffolding, units, skills) in expected {
            let task = try exercise(id)
            let profile = try XCTUnwrap(task.practiceProfile, id)
            XCTAssertEqual(profile.form, form, id)
            XCTAssertEqual(profile.scaffolding, scaffolding, id)
            XCTAssertEqual(profile.skillIDs, skills, id)
            XCTAssertTrue((1...3).contains(profile.reflectionPrompts.count), id)
            XCTAssertTrue(profile.reflectionPrompts.allSatisfy { $0.hasSuffix("?") }, id)
            for skill in skills {
                let section = try XCTUnwrap(sections.first { $0.topic.id == skill }, skill)
                XCTAssertNotEqual(section.role, .overview, skill)
            }
            XCTAssertEqual(task.effort, .init(difficulty: .similar, scopeUnits: units), id)
            let chapter = try XCTUnwrap(Curriculum.chapters.first { $0.exercises.contains(where: { $0.id == id }) })
            XCTAssertLessThanOrEqual(units, try XCTUnwrap(chapter.assessment.effort).scopeUnits, id)
            XCTAssertFalse(try XCTUnwrap(task.effort).estimated, id)
            XCTAssertEqual(task.hints.count, 3, id)
            XCTAssertTrue(task.hasRequiredInstructionSections, id)
            let headings = task.instructions.components(separatedBy: "\n").filter { $0.hasSuffix(":") }
            XCTAssertEqual(headings, ["Goal:", "Starting code:", "Your task:", "Expected result:", "Check:"], id)
            XCTAssertTrue(task.instructions.contains("Your task:\n1. "), id)
            XCTAssertNil(task.checkPlan, id)
            XCTAssertNil(task.expectedStarterError, id)
            XCTAssertFalse(Curriculum.isAssessment(id), id)
            XCTAssertEqual(Curriculum.activityID(for: id), id)
            for code in [task.starterCode, task.referenceSolution, task.testCode] {
                for laterSyntax in ["class ", "yield ", "async ", "await ", "with open", "import pandas", "import numpy", ":="] {
                    XCTAssertFalse(code.contains(laterSyntax), "\(id): \(laterSyntax)")
                }
            }
        }
    }

    func testRecordReferencesPassAndStartersRunButFailChecksWithAssertionError() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        for task in exercises {
            let reference = try await runner.check(code: task.referenceSolution, exercise: task, pythonPath: pythonPath)
            XCTAssertTrue(reference.passed, "\(task.id): \(reference.output)")
            XCTAssertEqual(reference.exitCode, 0, reference.output)
            let runnable = try await runner.run(code: task.starterCode, pythonPath: pythonPath)
            XCTAssertTrue(runnable.passed, "\(task.id): \(runnable.output)")
            let starter = try await runner.check(code: task.starterCode, exercise: task, pythonPath: pythonPath)
            XCTAssertFalse(starter.passed, task.id)
            XCTAssertEqual(starter.diagnostic?.exceptionType, "AssertionError", starter.output)
            XCTAssertEqual(starter.diagnostic?.origin, .checks, starter.output)
            XCTAssertFalse(starter.timedOut, task.id)
            XCTAssertFalse(starter.cancelled, task.id)
        }
    }

    func testRecordChecksRejectFixedResultsDroppedDuplicatesMutationAndWrongTypes() async throws {
        try await requireSandbox()
        let mutations: [(String, String, String)] = [
            (stockID, "total_units += record['units']", "total_units = 9"),
            (stockID, "category_counts.get(category, 0) + 1", "category_counts.get(category, 0) + record['units']"),
            (stockID, "if record['units'] <= low_limit:", "if record['units'] < low_limit:"),
            (stockID, "if record['units'] <= low_limit:", "if record['units'] <= low_limit and record['name'] not in low_stock:"),
            (stockID, "for record in records:", "for record in sorted(records, key=lambda record: record['name']):"),
            (stockID, "        total_units += record['units']", "        record['tag'] = 'changed'\n        total_units += record['units']"),
            (stockID, "'total_units': total_units", "'total_units': float(total_units)"),
            (labelsID, "for label in labels:", "for label in set(labels):"),
            (labelsID, "label.strip().lower()", "label.lower()"),
            (labelsID, "label.strip().lower()", "label.strip()"),
            (labelsID, "if cleaned:", "if True:"),
            (labelsID, "    return counts", "    labels.append('changed')\n    return counts"),
            (labelsID, "counts.get(cleaned, 0) + 1", "counts.get(cleaned, 0) + 1.0"),
            (gradebookID, "if type(points) is not int or not 0 <= points <= 100:", "if record is records[0] and (type(points) is not int or not 0 <= points <= 100):"),
            (gradebookID, "type(points) is not int", "not isinstance(points, int)"),
            (gradebookID, "type(points) is not int", "type(points) not in (int, float)"),
            (gradebookID, "points = record['points']", "points = int(record['points'])"),
            (gradebookID, "if points >= 60:", "if points > 60:"),
            (gradebookID, "mean_points = total / count", "mean_points = round(total / count, 2)"),
            (gradebookID, "'count': count", "'count': float(count)"),
            (gradebookID, "'passed': passed", "'passed': float(passed)"),
            (gradebookID, "student = record['student']", "record['student'] = record['student'].strip()\n        student = record['student']"),
            (gradebookID, "            raise ValueError('points must be an integer from 0 to 100')", "            raise ValueError('')")
        ]
        let runner = PythonRunner()
        for (id, original, replacement) in mutations {
            let task = try exercise(id)
            XCTAssertTrue(task.referenceSolution.contains(original), "Mutation must apply: \(id): \(original)")
            let wrong = task.referenceSolution.replacingOccurrences(of: original, with: replacement)
            XCTAssertNotEqual(wrong, task.referenceSolution, id)
            let result = try await runner.check(code: wrong, exercise: task, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, "Accepted \(id): \(replacement)")
            XCTAssertEqual(result.diagnostic?.exceptionType, "AssertionError", "\(id): \(replacement): \(result.output)")
            XCTAssertFalse(result.timedOut, id)
            XCTAssertFalse(result.cancelled, id)
        }
        for (id, code) in [
            (stockID, "def stock_report(records, low_limit):\n    return {'total_units': 7, 'category_counts': {'desk': 3}, 'low_stock': ['pen', 'pen']}\n"),
            (labelsID, "def count_clean_labels(labels):\n    return {'blue': 2, 'red': 2}\n"),
            (gradebookID, "def gradebook_report(records):\n    return {'count': 3, 'passed': 2, 'mean_points': 50.0}\n")
        ] {
            let result = try await runner.check(code: code, exercise: exercise(id), pythonPath: pythonPath)
            XCTAssertFalse(result.passed, id)
            XCTAssertEqual(result.diagnostic?.exceptionType, "AssertionError", result.output)
        }
        let gradebook = try exercise(gradebookID)
        let droppedDuplicates = gradebook.referenceSolution.replacingOccurrences(of: "    total = 0", with: "    unique = []\n    for record in records:\n        if record not in unique:\n            unique.append(record)\n    records = unique\n    total = 0")
        let duplicateResult = try await runner.check(code: droppedDuplicates, exercise: gradebook, pythonPath: pythonPath)
        XCTAssertFalse(duplicateResult.passed, duplicateResult.output)
        XCTAssertEqual(duplicateResult.diagnostic?.exceptionType, "AssertionError", duplicateResult.output)
    }

    func testMaintenanceStarterRetainsOldOrdinaryCountsButFailsNewRequirement() async throws {
        try await requireSandbox()
        let task = try exercise(labelsID)
        let runner = PythonRunner()
        let oldChecks = "assert count_clean_labels([]) == {}\nassert count_clean_labels(['red', 'red', 'blue']) == {'red': 2, 'blue': 1}\n"
        let oldResult = try await runner.run(code: task.starterCode, tests: oldChecks, pythonPath: pythonPath)
        XCTAssertTrue(oldResult.passed, oldResult.output)
        let newResult = try await runner.run(code: task.starterCode, tests: "assert count_clean_labels([' Blue ', 'blue', ' ']) == {'blue': 2}\n", pythonPath: pythonPath)
        XCTAssertFalse(newResult.passed, newResult.output)
        XCTAssertEqual(newResult.diagnostic?.exceptionType, "AssertionError", newResult.output)
        XCTAssertEqual(newResult.diagnostic?.origin, .checks, newResult.output)
    }

    func testRecordChecksAcceptEquivalentCorrectImplementations() async throws {
        try await requireSandbox()
        let stock = """
        def stock_report(records, low_limit):
            result = {'low_stock': [], 'category_counts': {}, 'total_units': 0}
            for batch in records:
                result['total_units'] = result['total_units'] + batch['units']
                category = batch['category']
                if category not in result['category_counts']:
                    result['category_counts'][category] = 0
                result['category_counts'][category] += 1
            for batch in records:
                if not batch['units'] > low_limit:
                    result['low_stock'].append(batch['name'])
            return result
        """
        let labels = """
        def count_clean_labels(labels):
            counts = {}
            for original in labels:
                key = original.lower().strip()
                if key == '':
                    continue
                if key in counts:
                    counts[key] += 1
                else:
                    counts[key] = 1
            return counts
        """
        let gradebook = """
        def accepted_record(record):
            if type(record) is not dict:
                raise ValueError('expected a record')
            if 'student' not in record or 'points' not in record:
                raise ValueError('missing field')
            name = record['student']
            points = record['points']
            if type(name) is not str or name.strip() == '':
                raise ValueError('expected a student name')
            if type(points) is not int:
                raise ValueError('expected integer points')
            if points < 0 or points > 100:
                raise ValueError('points out of range')
            return points

        def gradebook_report(records):
            if type(records) is not list:
                raise ValueError('expected a list')
            total = 0
            count = 0
            passed = 0
            for record in records:
                points = accepted_record(record)
                total = total + points
                count = count + 1
                if points < 60:
                    continue
                passed = passed + 1
            if count == 0:
                return {'mean_points': 0.0, 'passed': 0, 'count': 0}
            return {'mean_points': total / count, 'passed': passed, 'count': count}
        """
        let runner = PythonRunner()
        for (id, code) in [(stockID, stock), (labelsID, labels), (gradebookID, gradebook)] {
            let result = try await runner.check(code: code, exercise: exercise(id), pythonPath: pythonPath)
            XCTAssertTrue(result.passed, "\(id): \(result.output)")
            XCTAssertEqual(result.exitCode, 0, result.output)
            XCTAssertFalse(result.timedOut, id)
            XCTAssertFalse(result.cancelled, id)
        }
    }
}
