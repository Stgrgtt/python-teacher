import Foundation
import XCTest
@testable import PythonTeacherCore

final class TransferFoundationsCurriculumTests: XCTestCase {
    private let transferIDs = [
        "basics-transfer-delivery-note", "values-transfer-workshop-cost",
        "decisions-transfer-library-entry", "loops-transfer-water-log"
    ]

    private var pythonPath: String {
        ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
    }

    private var transfers: [Exercise] {
        Curriculum.chapters.flatMap(\.exercises).filter { transferIDs.contains($0.id) }
    }

    private func exercise(_ id: String) throws -> Exercise {
        try XCTUnwrap(transfers.first { $0.id == id }, id)
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

    func testExactlyFourTransfersAppendAfterOriginalPracticeAndRepairLabs() throws {
        let originalIDs = [
            ["basics-name", "basics-total", "basics-message", "basics-debug-quote", "basics-debug-saved-total"],
            ["values-budget", "values-label", "values-batches", "values-debug-clean-label", "values-predict-token-total"],
            ["decisions-route", "decisions-quota", "decisions-bands-v2", "decisions-debug-priority", "decisions-debug-entry-boundary"],
            ["loops-total", "loops-filter", "loops-retries-v2", "loops-debug-running-total", "loops-predict-threshold"]
        ]
        let chapterIDs = ["basics", "values", "decisions", "loops"]
        XCTAssertEqual(transfers.map(\.id), transferIDs)
        for index in chapterIDs.indices {
            let chapter = try XCTUnwrap(Curriculum.chapters.first { $0.id == chapterIDs[index] })
            XCTAssertEqual(chapter.exercises.map(\.id), originalIDs[index] + [transferIDs[index]])
            let transfer = try exercise(transferIDs[index])
            XCTAssertFalse(Curriculum.isAssessment(transfer.id))
            XCTAssertEqual(Curriculum.activityID(for: transfer.id), transfer.id)
            XCTAssertFalse(Curriculum.legacyExercises(chapterID: chapter.id, mode: .practice).contains { $0.id == transfer.id })
            XCTAssertNil(chapter.assessment.checkPlan)
            XCTAssertNil(chapter.assessment.practiceProfile)
        }
    }

    func testTransferProfilesInstructionsAndReviewedWorkload() throws {
        let skills = [
            ["basics-section-2", "basics-section-3", "basics-section-4"],
            ["values-section-2", "values-section-3", "values-section-5"],
            ["decisions-section-1", "decisions-section-2", "decisions-section-3", "decisions-section-4"],
            ["loops-section-1", "loops-section-2", "decisions-section-1"]
        ]
        let units = [1, 2, 1, 2]
        for (index, transfer) in transfers.enumerated() {
            let profile = try XCTUnwrap(transfer.practiceProfile, transfer.id)
            XCTAssertEqual(profile.form, .transfer)
            XCTAssertEqual(profile.scaffolding, .independent)
            XCTAssertEqual(profile.skillIDs, skills[index])
            XCTAssertTrue((1...3).contains(profile.reflectionPrompts.count))
            XCTAssertEqual(Set(profile.reflectionPrompts).count, profile.reflectionPrompts.count)
            XCTAssertTrue(profile.reflectionPrompts.allSatisfy { !$0.isEmpty && $0.count < 150 })
            for skill in profile.skillIDs {
                let section = try XCTUnwrap(Curriculum.chapters.flatMap(\.lessonSections).first { $0.topic.id == skill })
                XCTAssertNotEqual(section.role, .overview, skill)
            }
            XCTAssertEqual(transfer.effort, .init(difficulty: .similar, scopeUnits: units[index]))
            let chapter = try XCTUnwrap(Curriculum.chapters.first { $0.exercises.contains { $0.id == transfer.id } })
            XCTAssertLessThanOrEqual(units[index], try XCTUnwrap(chapter.assessment.effort).scopeUnits)
            XCTAssertNil(transfer.expectedStarterError)
            XCTAssertEqual(transfer.hints.count, 3)
            XCTAssertTrue(transfer.hasRequiredInstructionSections)
            let headings = transfer.instructions.components(separatedBy: "\n").filter { $0.hasSuffix(":") }
            XCTAssertEqual(headings, ["Goal:", "Starting code:", "Your task:", "Expected result:", "Check:"])
            XCTAssertTrue(transfer.instructions.contains("Your task:\n1. "))
            XCTAssertTrue(transfer.instructions.contains("Choose"))
            XCTAssertTrue(transfer.instructions.contains("Keep the supplied input lines unchanged"))
            XCTAssertTrue(transfer.instructions.contains("Python literal"))
            XCTAssertTrue(transfer.instructions.contains("**Run experiment**"))
            XCTAssertTrue(transfer.instructions.contains("without changing your draft, awarding XP, or completing the exercise"))
            XCTAssertTrue(transfer.instructions.contains("not reached"))
        }
    }

    func testNamedPlansCoverEveryInputAndSeparateResultsWithinBounds() throws {
        let expectedInputs: [[ExerciseInput]] = [
            [.init(name: "boxes", defaultLiteral: "3"), .init(name: "items_per_box", defaultLiteral: "4"), .init(name: "loose_items", defaultLiteral: "2"), .init(name: "destination", defaultLiteral: "'Studio'"), .init(name: "item_name", defaultLiteral: "'blankets'")],
            [.init(name: "raw_label", defaultLiteral: "'  CLAY Lab  '"), .init(name: "attendees", defaultLiteral: "4"), .init(name: "seat_price", defaultLiteral: "2.5"), .init(name: "setup_fee", defaultLiteral: "3.0")],
            [.init(name: "visitors", defaultLiteral: "3"), .init(name: "capacity", defaultLiteral: "4"), .init(name: "has_pass", defaultLiteral: "True"), .init(name: "is_open", defaultLiteral: "True")],
            [.init(name: "water_liters", defaultLiteral: "[3, 7, 2, 7]"), .init(name: "minimum_liters", defaultLiteral: "5")]
        ]
        let targets: [Set<String>] = [
            ["total_items", "delivery_note"], ["workshop_label", "total_cost"],
            ["can_enter"], ["total_liters", "qualifying_count", "qualifying_liters"]
        ]
        for (index, transfer) in transfers.enumerated() {
            let plan = try XCTUnwrap(transfer.checkPlan)
            XCTAssertNoThrow(try plan.validate(), transfer.id)
            XCTAssertEqual(try JSONDecoder().decode(AuthoredCheckPlan.self, from: JSONEncoder().encode(plan)), plan)
            XCTAssertEqual(plan.inputs, expectedInputs[index])
            XCTAssertEqual(plan.checks.count, 8)
            XCTAssertEqual(Set(plan.checks.map(\.target)), targets[index])
            XCTAssertTrue(plan.checks.contains { $0.inputs.isEmpty })
            XCTAssertTrue(plan.checks.contains { !$0.inputs.isEmpty })
            for input in plan.inputs {
                XCTAssertTrue(plan.checks.contains { $0.inputs[input.name] != nil && $0.inputs[input.name] != input.defaultLiteral }, "\(transfer.id): \(input.name) never varies")
            }
            for target in targets[index] {
                XCTAssertTrue(plan.checks.contains { $0.target == target && !$0.inputs.isEmpty }, "\(transfer.id): \(target) needs an alternate case")
                XCTAssertTrue(transfer.testCode.contains("type(\(target)) is "), "\(transfer.id): default check must require the result type")
            }
        }
        XCTAssertEqual(transfers.compactMap(\.checkPlan).reduce(0) { $0 + $1.checks.count }, 32)
    }

    func testZeroBoundaryEmptyAndAlternateCasesHaveExplicitContracts() throws {
        let cases: [(String, String, [String: String], String, String)] = [
            (transferIDs[0], "changed-count", ["boxes": "2", "items_per_box": "5", "loose_items": "1"], "total_items", "11"),
            (transferIDs[0], "zero-count", ["boxes": "0", "loose_items": "0"], "total_items", "0"),
            (transferIDs[0], "loose-only", ["boxes": "0", "loose_items": "5"], "total_items", "5"),
            (transferIDs[0], "empty-note", ["destination": "''", "item_name": "''"], "delivery_note", "': '"),
            (transferIDs[1], "zero-attendance", ["attendees": "0"], "total_cost", "3.0"),
            (transferIDs[1], "changed-prices", ["attendees": "6", "seat_price": "0.5", "setup_fee": "1.5"], "total_cost", "4.5"),
            (transferIDs[1], "blank-label", ["raw_label": "'   '"], "workshop_label", "''"),
            (transferIDs[2], "full-room", ["visitors": "4"], "can_enter", "False"),
            (transferIDs[2], "above-capacity", ["visitors": "5"], "can_enter", "False"),
            (transferIDs[2], "missing-pass", ["has_pass": "False"], "can_enter", "False"),
            (transferIDs[2], "closed-room", ["is_open": "False"], "can_enter", "False"),
            (transferIDs[2], "changed-capacity", ["visitors": "4", "capacity": "5"], "can_enter", "True"),
            (transferIDs[2], "zero-capacity", ["visitors": "0", "capacity": "0"], "can_enter", "False"),
            (transferIDs[3], "empty-total", ["water_liters": "[]"], "total_liters", "0"),
            (transferIDs[3], "empty-count", ["water_liters": "[]"], "qualifying_count", "0"),
            (transferIDs[3], "empty-list", ["water_liters": "[]"], "qualifying_liters", "[]"),
            (transferIDs[3], "zero-threshold-total", ["water_liters": "[0, 2, 0, 1]", "minimum_liters": "0"], "total_liters", "3"),
            (transferIDs[3], "zero-threshold-count", ["water_liters": "[0, 2, 0, 1]", "minimum_liters": "0"], "qualifying_count", "4"),
            (transferIDs[3], "zero-threshold-list", ["water_liters": "[0, 2, 0, 1]", "minimum_liters": "0"], "qualifying_liters", "[0, 2, 0, 1]"),
            (transferIDs[3], "no-qualifying-list", ["water_liters": "[1, 2]", "minimum_liters": "3"], "qualifying_liters", "[]")
        ]
        for (id, caseID, inputs, target, expected) in cases {
            let check = try XCTUnwrap(exercise(id).checkPlan?.checks.first { $0.id == caseID }, caseID)
            XCTAssertEqual(check.inputs, inputs, caseID)
            XCTAssertEqual(check.target, target, caseID)
            XCTAssertEqual(check.expectedLiteral, expected, caseID)
        }
    }

    func testUniqueLiteralInputInterfacesAndOnlyTaughtLearnerSyntax() throws {
        for transfer in transfers {
            let plan = try XCTUnwrap(transfer.checkPlan)
            for source in [transfer.starterCode, transfer.referenceSolution] {
                let lines = source.components(separatedBy: "\n")
                for input in plan.inputs {
                    XCTAssertEqual(lines.filter { $0 == "\(input.name) = \(input.defaultLiteral)" }.count, 1, transfer.id)
                    XCTAssertEqual(lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(input.name) =") }.count, 1, transfer.id)
                }
                for laterSyntax in ["def ", "class ", "lambda ", "import ", "try:", "except ", "yield ", "sum(", "enumerate(", "map(", "filter(", "sorted(", "set(", "tuple(", ".format(", ":.2f", "#"] {
                    XCTAssertFalse(source.contains(laterSyntax), "\(transfer.id): \(laterSyntax)")
                }
                XCTAssertNil(source.range(of: #"\[[^\n]*\bfor\b"#, options: .regularExpression), transfer.id)
                if !transfer.id.hasPrefix("loops-") {
                    for laterSyntax in ["[", "for ", "while ", ".append("] {
                        XCTAssertFalse(source.contains(laterSyntax), "\(transfer.id): \(laterSyntax)")
                    }
                }
                if transfer.id.hasPrefix("basics-") {
                    for laterSyntax in ["(", ".strip", ".lower", "f'", "if ", "True", "False"] {
                        XCTAssertFalse(source.contains(laterSyntax), "\(transfer.id): \(laterSyntax)")
                    }
                }
                if transfer.id.hasPrefix("values-") {
                    XCTAssertFalse(source.contains("if "), transfer.id)
                }
                let calls = try NSRegularExpression(pattern: #"([A-Za-z_][A-Za-z_0-9]*)\("#)
                let text = source as NSString
                let names = calls.matches(in: source, range: NSRange(location: 0, length: text.length)).map { text.substring(with: $0.range(at: 1)) }
                XCTAssertTrue(Set(names).isSubset(of: ["strip", "lower", "append", "len", "print"]), transfer.id)
            }
            let literals = plan.inputs.map(\.defaultLiteral) + plan.checks.flatMap { Array($0.inputs.values) + [$0.expectedLiteral] }
            let scalar = #"(?:True|False|[0-9]+(?:\.[0-9]+)?|'[^'\n]*')"#
            let integerList = #"\[(?:[0-9]+(?:, [0-9]+)*)?\]"#
            let pattern = transfer.id.hasPrefix("loops-") ? "\\A(?:\(scalar)|\(integerList))\\z" : "\\A\(scalar)\\z"
            for literal in literals {
                XCTAssertNotNil(literal.range(of: pattern, options: .regularExpression), "\(transfer.id): \(literal)")
                XCTAssertLessThanOrEqual(literal.utf8.count, AuthoredCheckPlan.maximumLiteralBytes)
            }
        }
    }

    func testAllReferencesPassNamedAndIndependentOriginalChecks() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        for transfer in transfers {
            let original = try await runner.run(code: transfer.referenceSolution, tests: transfer.testCode, pythonPath: pythonPath)
            XCTAssertTrue(original.passed, "\(transfer.id): \(original.output)")
            let result = try await runner.check(code: transfer.referenceSolution, exercise: transfer, pythonPath: pythonPath)
            XCTAssertTrue(result.passed, "\(transfer.id): \(result.output)")
            XCTAssertEqual(result.exitCode, 0, result.output)
            XCTAssertEqual(result.checkOutcomes.map(\.id), transfer.checkPlan?.checks.map(\.id))
            XCTAssertEqual(result.checkOutcomes.map(\.status), Array(repeating: .passed, count: 8))
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }

    func testStartersRunStandaloneButFailOriginalAssertionsAndNamedChecks() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        for transfer in transfers {
            let standalone = try await runner.run(code: transfer.starterCode, pythonPath: pythonPath)
            XCTAssertTrue(standalone.passed, "\(transfer.id): \(standalone.output)")
            XCTAssertNil(standalone.diagnostic)
            let original = try await runner.run(code: transfer.starterCode, tests: transfer.testCode, pythonPath: pythonPath)
            XCTAssertFalse(original.passed, transfer.id)
            XCTAssertEqual(original.diagnostic?.exceptionType, "AssertionError", original.output)
            XCTAssertEqual(original.diagnostic?.origin, .checks, original.output)
            let result = try await runner.check(code: transfer.starterCode, exercise: transfer, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, transfer.id)
            XCTAssertEqual(result.checkOutcomes.map(\.status), [.failed] + Array(repeating: .notReached, count: 7))
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }

    func testNamedCasesRejectHardcodesDroppedConditionsAndWrongBoundariesThatPassOriginalExamples() async throws {
        try await requireSandbox()
        let mutations: [(String, String, String, String)] = [
            (transferIDs[0], "boxes * items_per_box + loose_items", "14", "changed-count"),
            (transferIDs[0], "destination + ': ' + item_name", "'Studio: blankets'", "changed-note"),
            (transferIDs[1], "raw_label.strip().lower()", "'clay lab'", "changed-label"),
            (transferIDs[1], "attendees * seat_price + setup_fee", "13.0", "zero-attendance"),
            (transferIDs[1], "attendees * seat_price + setup_fee", "attendees * 2.5 + setup_fee", "changed-prices"),
            (transferIDs[1], "total_cost = attendees * seat_price + setup_fee", "total_cost = attendees * seat_price + setup_fee\nif attendees == 0:\n    total_cost = 0.0", "zero-attendance"),
            (transferIDs[2], "visitors < capacity", "visitors <= capacity", "full-room"),
            (transferIDs[2], " and has_pass", "", "missing-pass"),
            (transferIDs[2], " and is_open", "", "closed-room"),
            (transferIDs[2], "visitors < capacity", "visitors < 4", "changed-capacity"),
            (transferIDs[2], "visitors < capacity", "visitors != capacity", "above-capacity"),
            (transferIDs[3], "qualifying_liters.append(liters)", "qualifying_liters.append(liters)\ntotal_liters = 19", "empty-total"),
            (transferIDs[3], "qualifying_liters.append(liters)", "qualifying_liters.append(liters)\nqualifying_count = 2", "empty-count"),
            (transferIDs[3], "qualifying_liters.append(liters)", "qualifying_liters.append(liters)\nqualifying_liters = [7, 7]", "empty-list"),
            (transferIDs[3], "liters >= minimum_liters", "liters > minimum_liters", "zero-threshold-count"),
            (transferIDs[3], "liters >= minimum_liters", "liters >= minimum_liters and liters > 0", "zero-threshold-count"),
            (transferIDs[3], "qualifying_liters.append(liters)", "qualifying_liters.append(liters)\nif not water_liters:\n    total_liters = 1", "empty-total")
        ]
        let runner = PythonRunner()
        for (id, original, replacement, failedID) in mutations {
            let transfer = try exercise(id)
            XCTAssertTrue(transfer.referenceSolution.contains(original), "Mutation must apply: \(id)")
            let code = transfer.referenceSolution.replacingOccurrences(of: original, with: replacement)
            XCTAssertNotEqual(code, transfer.referenceSolution, id)
            let baseline = try await runner.run(code: code, tests: transfer.testCode, pythonPath: pythonPath)
            XCTAssertTrue(baseline.passed, "Original example must accept this mutation: \(id): \(baseline.output)")
            let result = try await runner.check(code: code, exercise: transfer, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, "Accepted \(id): \(replacement)")
            XCTAssertEqual(result.checkOutcomes.filter { $0.status == .failed }.map(\.id), [failedID], result.output)
            let failedIndex = try XCTUnwrap(result.checkOutcomes.firstIndex { $0.status == .failed }, result.output)
            XCTAssertTrue(result.checkOutcomes.prefix(failedIndex).allSatisfy { $0.status == .passed }, result.output)
            XCTAssertTrue(result.checkOutcomes.dropFirst(failedIndex + 1).allSatisfy { $0.status == .notReached }, result.output)
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }

    func testEquivalentCorrectApproachesPassAllCases() async throws {
        try await requireSandbox()
        let equivalents: [(String, String, String)] = [
            (transferIDs[0], "total_items = boxes * items_per_box + loose_items", "boxed_items = items_per_box * boxes\ntotal_items = loose_items + boxed_items"),
            (transferIDs[1], "workshop_label = raw_label.strip().lower()", "lowercase_label = raw_label.lower()\nworkshop_label = lowercase_label.strip()"),
            (transferIDs[2], "can_enter = visitors < capacity and has_pass and is_open", "if not is_open:\n    can_enter = False\nelif not has_pass:\n    can_enter = False\nelse:\n    can_enter = visitors < capacity"),
            (transferIDs[3], "        qualifying_count += 1\n        qualifying_liters.append(liters)", "        qualifying_liters.append(liters)\nqualifying_count = len(qualifying_liters)")
        ]
        let runner = PythonRunner()
        for (id, original, replacement) in equivalents {
            let transfer = try exercise(id)
            XCTAssertTrue(transfer.referenceSolution.contains(original), id)
            let code = transfer.referenceSolution.replacingOccurrences(of: original, with: replacement)
            XCTAssertNotEqual(code, transfer.referenceSolution, id)
            let result = try await runner.check(code: code, exercise: transfer, pythonPath: pythonPath)
            XCTAssertTrue(result.passed, "\(id): \(result.output)")
            XCTAssertEqual(result.checkOutcomes.map(\.status), Array(repeating: .passed, count: 8))
            XCTAssertFalse(result.timedOut, result.output)
            XCTAssertFalse(result.cancelled, result.output)
        }
    }
}
