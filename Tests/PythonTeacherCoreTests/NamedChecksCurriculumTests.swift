import Foundation
import XCTest
@testable import PythonTeacherCore

final class NamedChecksCurriculumTests: XCTestCase {
    private let adoptedIDs: Set<String> = [
        "decisions-debug-priority", "decisions-debug-entry-boundary",
        "loops-debug-running-total", "loops-predict-threshold"
    ]

    private var pythonPath: String {
        ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
    }

    private var labs: [Exercise] {
        Curriculum.chapters.flatMap(\.exercises).filter { adoptedIDs.contains($0.id) }
    }

    private func lab(_ id: String) throws -> Exercise {
        try XCTUnwrap(labs.first { $0.id == id }, id)
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

    func testOnlyFourReviewedLabsHaveValidNamedPlansAndAssessmentsHaveNone() throws {
        let allPractice = Curriculum.chapters.flatMap(\.exercises)
        XCTAssertEqual(Set(allPractice.filter { $0.checkPlan != nil }.map(\.id)), adoptedIDs)
        XCTAssertEqual(labs.count, 4)
        for exercise in labs {
            let plan = try XCTUnwrap(exercise.checkPlan, exercise.id)
            XCTAssertNoThrow(try plan.validate(), exercise.id)
            XCTAssertEqual(try JSONDecoder().decode(AuthoredCheckPlan.self, from: JSONEncoder().encode(plan)), plan)
            XCTAssertFalse(Curriculum.isAssessment(exercise.id), exercise.id)
            XCTAssertEqual(Curriculum.activityID(for: exercise.id), exercise.id)
            XCTAssertTrue(exercise.hasRequiredInstructionSections, exercise.id)
            XCTAssertTrue(exercise.instructions.contains("**Run experiment**"), exercise.id)
            XCTAssertTrue(exercise.instructions.contains("Python literal"), exercise.id)
            XCTAssertTrue(exercise.instructions.contains("Keep the supplied input"), exercise.id)
            XCTAssertTrue(exercise.instructions.contains("without changing your draft, awarding XP, or completing the exercise"), exercise.id)
            XCTAssertTrue(exercise.instructions.contains("not reached"), exercise.id)
        }
        for chapter in Curriculum.chapters {
            XCTAssertNil(chapter.assessment.checkPlan, chapter.assessment.id)
            for mode in [LearningMode.practice, .assessment] {
                for legacy in Curriculum.legacyExercises(chapterID: chapter.id, mode: mode) {
                    XCTAssertNil(legacy.checkPlan, legacy.id)
                }
            }
        }
    }

    func testNamedFixturesCoverDecisionBoundariesAndSeparateLoopResults() throws {
        let priority = try XCTUnwrap(lab("decisions-debug-priority").checkPlan)
        XCTAssertEqual(priority.inputs, [.init(name: "maintenance", defaultLiteral: "True"), .init(name: "guests", defaultLiteral: "6")])
        XCTAssertEqual(priority.checks.map(\.inputs), [[:], ["guests": "1"], ["maintenance": "False", "guests": "1"], ["maintenance": "False", "guests": "2"], ["maintenance": "False"]])
        XCTAssertEqual(priority.checks.map(\.target), Array(repeating: "status", count: 5))
        XCTAssertEqual(priority.checks.map(\.expectedLiteral), ["'closed'", "'closed'", "'waiting'", "'open'", "'open'"])

        let entry = try XCTUnwrap(lab("decisions-debug-entry-boundary").checkPlan)
        XCTAssertEqual(entry.inputs, [.init(name: "age", defaultLiteral: "12"), .init(name: "minimum_age", defaultLiteral: "12"), .init(name: "approved", defaultLiteral: "True")])
        XCTAssertEqual(entry.checks.map(\.inputs), [[:], ["age": "11"], ["age": "13", "approved": "False"], ["age": "17", "minimum_age": "18"], ["age": "19", "minimum_age": "18"]])
        XCTAssertEqual(entry.checks.map(\.target), Array(repeating: "can_enter", count: 5))
        XCTAssertEqual(entry.checks.map(\.expectedLiteral), ["True", "False", "False", "False", "True"])

        let totals = try XCTUnwrap(lab("loops-debug-running-total").checkPlan)
        XCTAssertEqual(totals.inputs, [.init(name: "amounts", defaultLiteral: "[4, 3, 2]")])
        XCTAssertEqual(totals.checks.map(\.inputs), [[:], [:], ["amounts": "[]"], ["amounts": "[]"], ["amounts": "[5]"], ["amounts": "[5]"], ["amounts": "[4, -3, 0, 2]"], ["amounts": "[4, -3, 0, 2]"]])
        XCTAssertEqual(totals.checks.map(\.target), (0..<4).flatMap { _ in ["total", "totals_after"] })
        XCTAssertEqual(totals.checks.map(\.expectedLiteral), ["9", "[4, 7, 9]", "0", "[]", "5", "[5]", "3", "[4, 1, 1, 3]"])
        XCTAssertEqual(totals.checks[2].title, "Empty input: total")

        let threshold = try XCTUnwrap(lab("loops-predict-threshold").checkPlan)
        XCTAssertEqual(threshold.inputs, [.init(name: "start_value", defaultLiteral: "2"), .init(name: "target", defaultLiteral: "8")])
        XCTAssertEqual(threshold.checks.map(\.inputs), [[:], [:], ["target": "2"], ["target": "2"], ["target": "5"], ["target": "5"], ["start_value": "3", "target": "12"], ["start_value": "3", "target": "12"], ["start_value": "10"], ["start_value": "10"]])
        XCTAssertEqual(threshold.checks.map(\.target), (0..<5).flatMap { _ in ["value", "visited"] })
        XCTAssertEqual(threshold.checks.map(\.expectedLiteral), ["8", "[4, 8]", "2", "[]", "8", "[4, 8]", "12", "[6, 12]", "10", "[]"])
        for check in threshold.checks {
            let effective = Dictionary(uniqueKeysWithValues: threshold.inputs.map { ($0.name, $0.defaultLiteral) }).merging(check.inputs) { _, value in value }
            XCTAssertGreaterThan(try XCTUnwrap(Int(try XCTUnwrap(effective["start_value"]))), 0)
            XCTAssertGreaterThan(try XCTUnwrap(Int(try XCTUnwrap(effective["target"]))), 0)
        }
        XCTAssertEqual(labs.compactMap(\.checkPlan).reduce(0) { $0 + $1.checks.count }, 28)
    }

    func testDeclaredInputsMatchUniqueOriginalAssignmentsAndFixturesUseOnlyTaughtLiterals() throws {
        for exercise in labs {
            let plan = try XCTUnwrap(exercise.checkPlan, exercise.id)
            for input in plan.inputs {
                let assignment = "\(input.name) = \(input.defaultLiteral)"
                for source in [exercise.starterCode, exercise.referenceSolution] {
                    let lines = source.components(separatedBy: "\n")
                    XCTAssertEqual(lines.filter { $0 == assignment }.count, 1, "\(exercise.id): \(assignment)")
                    XCTAssertEqual(lines.filter { $0.hasPrefix("\(input.name) =") }.count, 1, exercise.id)
                }
            }
            let literals = plan.inputs.map(\.defaultLiteral) + plan.checks.flatMap { Array($0.inputs.values) + [$0.expectedLiteral] }
            let scalar = #"(?:True|False|-?[0-9]+|'[a-z]+')"#
            let integerList = #"\[(?:-?[0-9]+(?:, -?[0-9]+)*)?\]"#
            let pattern = exercise.id.hasPrefix("decisions-") ? "\\A\(scalar)\\z" : "\\A(?:\(scalar)|\(integerList))\\z"
            for literal in literals {
                XCTAssertNotNil(literal.range(of: pattern, options: .regularExpression), "\(exercise.id): \(literal)")
                XCTAssertLessThanOrEqual(literal.utf8.count, AuthoredCheckPlan.maximumLiteralBytes)
            }
            for source in [exercise.starterCode, exercise.referenceSolution, exercise.testCode] {
                for laterSyntax in ["def ", "class ", "lambda ", "import ", "try:", "except ", "yield "] {
                    XCTAssertFalse(source.contains(laterSyntax), "\(exercise.id): \(laterSyntax)")
                }
                if exercise.id.hasPrefix("decisions-") {
                    for laterSyntax in ["[", "for ", "while ", ".append("] {
                        XCTAssertFalse(source.contains(laterSyntax), "\(exercise.id): \(laterSyntax)")
                    }
                }
            }
            XCTAssertFalse(plan.checks.contains { ["first_wrong_visit", "predicted_before"].contains($0.target) }, exercise.id)
            XCTAssertFalse(plan.inputs.contains { ["first_wrong_visit", "predicted_before"].contains($0.name) }, exercise.id)
        }
    }

    func testAdoptedLabsRetainOriginalCodeContractsAndEffort() throws {
        let contracts: [(String, String, String, String, ExerciseEffort)] = [
            ("decisions-debug-priority",
             "maintenance = True\nguests = 6\nif maintenance:\n    status = 'closed'\nif guests >= 2:\n    status = 'open'\nelse:\n    status = 'waiting'\n",
             "maintenance = True\nguests = 6\nif maintenance:\n    status = 'closed'\nelif guests >= 2:\n    status = 'open'\nelse:\n    status = 'waiting'\n",
             "assert maintenance is True and guests == 6\nassert status == 'closed'\n",
             .init(difficulty: .similar, scopeUnits: 1)),
            ("decisions-debug-entry-boundary",
             "age = 12\nminimum_age = 12\napproved = True\ncan_enter = age > minimum_age and approved\n",
             "age = 12\nminimum_age = 12\napproved = True\ncan_enter = age >= minimum_age and approved\n",
             "assert age == 12 and minimum_age == 12 and approved is True\nassert can_enter is True\n",
             .init(difficulty: .easier, scopeUnits: 1)),
            ("loops-debug-running-total",
             "amounts = [4, 3, 2]\nfirst_wrong_visit = 0\ntotal = 0\ntotals_after = []\nfor amount in amounts:\n    total = 0\n    total += amount\n    totals_after.append(total)\n",
             "amounts = [4, 3, 2]\nfirst_wrong_visit = 2\ntotal = 0\ntotals_after = []\nfor amount in amounts:\n    total += amount\n    totals_after.append(total)\n",
             "assert amounts == [4, 3, 2]\nassert type(first_wrong_visit) is int and first_wrong_visit == 2\nassert type(total) is int and total == 9\nassert totals_after == [4, 7, 9]\n",
             .init(difficulty: .similar, scopeUnits: 2)),
            ("loops-predict-threshold",
             "start_value = 2\ntarget = 8\npredicted_before = []\nvalue = start_value\nvisited = []\nwhile value <= target:\n    value = value * 2\n    visited.append(value)\n",
             "start_value = 2\ntarget = 8\npredicted_before = [4, 8, 16]\nvalue = start_value\nvisited = []\nwhile value < target:\n    value = value * 2\n    visited.append(value)\n",
             "assert start_value == 2 and target == 8\nassert predicted_before == [4, 8, 16]\nassert visited == [4, 8]\nassert type(value) is int and value == 8\n",
             .init(difficulty: .similar, scopeUnits: 2))
        ]
        for (id, starter, reference, checks, effort) in contracts {
            let exercise = try lab(id)
            XCTAssertEqual(exercise.starterCode, starter, id)
            XCTAssertEqual(exercise.referenceSolution, reference, id)
            XCTAssertEqual(exercise.testCode, checks, id)
            XCTAssertEqual(exercise.effort, effort, id)
            XCTAssertNil(exercise.expectedStarterError, id)
        }
    }

    func testNamedPlanReferencesPassAllCasesAndOriginalChecks() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        for exercise in labs {
            let plan = try XCTUnwrap(exercise.checkPlan)
            let result = try await runner.check(code: exercise.referenceSolution, exercise: exercise, pythonPath: pythonPath)
            XCTAssertTrue(result.passed, "\(exercise.id): \(result.output)")
            XCTAssertEqual(result.exitCode, 0, result.output)
            XCTAssertEqual(result.checkOutcomes.map(\.id), plan.checks.map(\.id), exercise.id)
            XCTAssertEqual(result.checkOutcomes.map(\.status), Array(repeating: .passed, count: plan.checks.count), result.output)
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }

    func testNamedPlanStartersFailFirstCaseAndLeaveLaterCasesNotReached() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        for exercise in labs {
            let plan = try XCTUnwrap(exercise.checkPlan)
            let result = try await runner.check(code: exercise.starterCode, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, exercise.id)
            XCTAssertEqual(result.checkOutcomes.map(\.id), plan.checks.map(\.id), exercise.id)
            XCTAssertEqual(result.checkOutcomes.map(\.status), [.failed] + Array(repeating: .notReached, count: plan.checks.count - 1), result.output)
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }

    func testNamedPlansRejectWrongRepairsThatPassOriginalChecks() async throws {
        try await requireSandbox()
        let mutations: [(String, String, String, String)] = [
            ("decisions-debug-entry-boundary", "age >= minimum_age and approved", "age >= minimum_age", "without-approval"),
            ("decisions-debug-entry-boundary", "age >= minimum_age", "age >= 12", "changed-minimum-below"),
            ("decisions-debug-priority", "if maintenance:\n    status = 'closed'\nelif guests >= 2:\n    status = 'open'\nelse:\n    status = 'waiting'", "status = 'closed'", "no-maintenance-few"),
            ("decisions-debug-priority", "elif guests >= 2:\n    status = 'open'\n", "", "no-maintenance-boundary"),
            ("decisions-debug-priority", "status = 'waiting'", "status = 'open'", "no-maintenance-few"),
            ("loops-debug-running-total", "totals_after.append(total)", "totals_after.append(total * 1.0)", "original-trace"),
            ("loops-predict-threshold", "visited.append(value)", "visited.append(value * 1.0)", "original-visited"),
            ("loops-debug-running-total", "    totals_after.append(total)", "    if amount != 0:\n        totals_after.append(total)", "negative-zero-trace"),
            ("loops-debug-running-total", "    total += amount", "    if amount >= 0:\n        total += amount", "negative-zero-total"),
            ("loops-debug-running-total", "    totals_after.append(total)\n", "    totals_after.append(total)\ntotal = 9\n", "empty-total"),
            ("loops-predict-threshold", "    visited.append(value)\n", "    visited.append(value)\nvisited = [4, 8]\n", "already-reached-visited"),
            ("loops-predict-threshold", "    visited.append(value)\n", "    visited.append(value)\nvalue = target\n", "overshoot-value")
        ]
        let runner = PythonRunner()
        for (id, original, replacement, failedID) in mutations {
            let exercise = try lab(id)
            XCTAssertTrue(exercise.referenceSolution.contains(original), "Mutation must apply: \(id)")
            let code = exercise.referenceSolution.replacingOccurrences(of: original, with: replacement)
            XCTAssertNotEqual(code, exercise.referenceSolution, id)
            let baseline = try await runner.run(code: code, tests: exercise.testCode, pythonPath: pythonPath)
            XCTAssertTrue(baseline.passed, "Original example must not detect this mutation: \(id): \(baseline.output)")
            let result = try await runner.check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, "Accepted \(id): \(replacement)")
            XCTAssertEqual(result.checkOutcomes.filter { $0.status == .failed }.map(\.id), [failedID], result.output)
            let failedIndex = try XCTUnwrap(result.checkOutcomes.firstIndex { $0.status == .failed }, result.output)
            XCTAssertTrue(result.checkOutcomes.prefix(failedIndex).allSatisfy { $0.status == .passed }, result.output)
            XCTAssertTrue(result.checkOutcomes.dropFirst(failedIndex + 1).allSatisfy { $0.status == .notReached }, result.output)
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }

    func testNamedPlansAcceptEquivalentCorrectSolutions() async throws {
        try await requireSandbox()
        let equivalents: [(String, String, String)] = [
            ("decisions-debug-priority", "if maintenance:\n    status = 'closed'\nelif guests >= 2:\n    status = 'open'\nelse:\n    status = 'waiting'", "if not maintenance:\n    if guests < 2:\n        status = 'waiting'\n    else:\n        status = 'open'\nelse:\n    status = 'closed'"),
            ("decisions-debug-entry-boundary", "can_enter = age >= minimum_age and approved", "if age < minimum_age or not approved:\n    can_enter = False\nelse:\n    can_enter = True"),
            ("loops-debug-running-total", "total += amount", "total = total + amount"),
            ("loops-predict-threshold", "while value < target:", "while not value >= target:")
        ]
        let runner = PythonRunner()
        for (id, original, replacement) in equivalents {
            let exercise = try lab(id)
            XCTAssertTrue(exercise.referenceSolution.contains(original), id)
            let code = exercise.referenceSolution.replacingOccurrences(of: original, with: replacement)
            XCTAssertNotEqual(code, exercise.referenceSolution, id)
            let result = try await runner.check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertTrue(result.passed, "\(id): \(result.output)")
            XCTAssertEqual(result.checkOutcomes.count, exercise.checkPlan?.checks.count, id)
            XCTAssertTrue(result.checkOutcomes.allSatisfy { $0.status == .passed }, result.output)
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }

    func testOriginalPredictionEvidenceRemainsRequiredAfterAllNamedCasesPass() async throws {
        try await requireSandbox()
        let mutations = [
            ("loops-debug-running-total", "first_wrong_visit = 2", "first_wrong_visit = 0"),
            ("loops-predict-threshold", "predicted_before = [4, 8, 16]", "predicted_before = [4, 8]")
        ]
        let runner = PythonRunner()
        for (id, original, replacement) in mutations {
            let exercise = try lab(id)
            let code = exercise.referenceSolution.replacingOccurrences(of: original, with: replacement)
            XCTAssertNotEqual(code, exercise.referenceSolution, id)
            let result = try await runner.check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, id)
            XCTAssertEqual(result.checkOutcomes.count, exercise.checkPlan?.checks.count, id)
            XCTAssertTrue(result.checkOutcomes.allSatisfy { $0.status == .passed }, result.output)
            XCTAssertEqual(result.diagnostic?.exceptionType, "AssertionError", result.output)
            XCTAssertEqual(result.diagnostic?.origin, .checks, result.output)
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }

    func testExperimentsKeepOriginalPredictionsForAlternateInputs() async throws {
        try await requireSandbox()
        let experiments: [(String, [String: String], String)] = [
            ("loops-debug-running-total", ["amounts": "[]"], "assert first_wrong_visit == 2\nassert amounts == []\nassert total == 0 and totals_after == []\n"),
            ("loops-debug-running-total", ["amounts": "[4, -3, 0, 2]"], "assert first_wrong_visit == 2\nassert amounts == [4, -3, 0, 2]\nassert total == 3 and totals_after == [4, 1, 1, 3]\n"),
            ("loops-predict-threshold", ["target": "2"], "assert predicted_before == [4, 8, 16]\nassert start_value == 2 and target == 2\nassert value == 2 and visited == []\n"),
            ("loops-predict-threshold", ["start_value": "3", "target": "12"], "assert predicted_before == [4, 8, 16]\nassert start_value == 3 and target == 12\nassert value == 12 and visited == [6, 12]\n")
        ]
        let runner = PythonRunner()
        for (id, inputs, evidence) in experiments {
            let exercise = try lab(id)
            let plan = try XCTUnwrap(exercise.checkPlan)
            let result = try await runner.experiment(code: exercise.referenceSolution + evidence, plan: plan, inputs: inputs, pythonPath: pythonPath)
            XCTAssertTrue(result.passed, "\(id): \(result.output)")
            XCTAssertTrue(result.checkOutcomes.isEmpty, "Experiments observe rather than grade named cases")
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }
}
