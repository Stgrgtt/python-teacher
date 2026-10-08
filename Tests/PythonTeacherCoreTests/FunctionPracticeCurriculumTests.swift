import Foundation
import XCTest
@testable import PythonTeacherCore

final class FunctionPracticeCurriculumTests: XCTestCase {
    private let newIDs = ["functions-transfer-ticket-total", "functions-refactor-batch-cost"]

    private var pythonPath: String {
        ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
    }

    private func chapter() throws -> Chapter {
        try XCTUnwrap(Curriculum.chapters.first { $0.id == "functions" })
    }

    private func exercise(_ id: String) throws -> Exercise {
        try XCTUnwrap(chapter().exercises.first { $0.id == id }, id)
    }

    private func requireSandbox() async throws {
        let result: RunResult
        do {
            result = try await PythonRunner().run(code: "print('sandbox-ready')", pythonPath: pythonPath)
        } catch PythonRunnerError.sandboxUnavailable {
            throw XCTSkip("sandbox-exec is unavailable; unrestricted execution was not attempted.")
        } catch PythonRunnerError.interpreterDiscovery(let message) {
            throw XCTSkip("Python unavailable: \(message). Set PYTHON_TEACHER_TEST_PYTHON to a real interpreter.")
        }
        if result.output.contains("sandbox_apply:") || result.output.contains("sandbox-exec: Operation not permitted") {
            throw XCTSkip("This environment refuses sandbox creation: \(result.output)")
        }
        XCTAssertTrue(result.passed, result.output)
        XCTAssertEqual(result.exitCode, 0, result.output)
        XCTAssertTrue(result.output.contains("sandbox-ready"), result.output)
    }

    func testExactlyTwoExercisesAppendAfterUnchangedOriginalIDs() throws {
        let chapter = try chapter()
        XCTAssertEqual(chapter.exercises.map(\.id), [
            "functions-batches", "functions-rate", "functions-preview-v2",
            "functions-debug-return", "functions-predict-counterexample"
        ] + newIDs)
        XCTAssertEqual(chapter.assessment.id, "functions-assessment")
        XCTAssertEqual(chapter.assessment.effort?.scopeUnits, 2)
        XCTAssertEqual(chapter.quiz.map(\.id), ["functions-q1", "functions-q2", "functions-q3"])
        for id in newIDs {
            let exercise = try exercise(id)
            XCTAssertEqual(Curriculum.activityID(for: id), id)
            XCTAssertFalse(Curriculum.isAssessment(id))
            XCTAssertTrue(exercise.hasRequiredInstructionSections, id)
            for section in ["Goal:", "Starting code:", "Your task:", "Expected result:", "Check:"] {
                XCTAssertEqual(exercise.instructions.components(separatedBy: section).count, 2, "\(id): \(section)")
            }
            XCTAssertEqual(exercise.hints.count, 3, id)
            XCTAssertEqual(exercise.effort, ExerciseEffort(scopeUnits: 2), id)
            XCTAssertNil(exercise.expectedStarterError, id)
            XCTAssertNil(exercise.checkPlan, id)
            for code in [exercise.starterCode, exercise.referenceSolution, exercise.testCode] {
                XCTAssertFalse(code.contains("#"), id)
            }
        }
    }

    func testProfilesUseAuthoredFormsScaffoldingAndKnownTaughtSkills() throws {
        let transfer = try XCTUnwrap(exercise(newIDs[0]).practiceProfile)
        let refactor = try XCTUnwrap(exercise(newIDs[1]).practiceProfile)
        XCTAssertEqual(transfer.form, .transfer)
        XCTAssertEqual(transfer.scaffolding, .independent)
        XCTAssertEqual(transfer.skillIDs, ["functions-section-1", "loops-section-3"])
        XCTAssertEqual(refactor.form, .refactor)
        XCTAssertEqual(refactor.scaffolding, .light)
        XCTAssertEqual(refactor.skillIDs, ["functions-section-1", "functions-section-5"])
        let closure = try XCTUnwrap(Curriculum.graph.closureIncludingSelf(of: "functions"))
        let knownSkills = Set(closure.flatMap(\.lessonSections).filter { $0.role != .overview }.map { $0.topic.id })
        for profile in [transfer, refactor] {
            XCTAssertTrue(profile.isWellFormed)
            XCTAssertTrue(Set(profile.skillIDs).isSubset(of: knownSkills))
            XCTAssertTrue((1...3).contains(profile.reflectionPrompts.count))
            XCTAssertEqual(Set(profile.reflectionPrompts).count, profile.reflectionPrompts.count)
            for prompt in profile.reflectionPrompts {
                XCTAssertTrue(prompt.hasSuffix("?"), prompt)
                XCTAssertGreaterThan(prompt.count, 20, prompt)
            }
        }
        XCTAssertTrue(transfer.reflectionPrompts.joined().contains("child_boundary"))
        XCTAssertTrue(refactor.reflectionPrompts.joined().contains("total_batch_cost"))
    }

    func testShortTeachingUnitsPreserveHeadingsSectionIDsAndRoles() throws {
        let chapter = try chapter()
        XCTAssertEqual(chapter.lessonSections.map(\.heading), [
            "Separate inputs from results", "Read part of a string with a slice",
            "Replace a function's placeholder, not its interface", "Default values and keyword arguments", "Test a hypothesis"
        ])
        XCTAssertEqual(chapter.lessonSections.map { $0.topic.id }, (1...5).map { "functions-section-\($0)" })
        XCTAssertEqual(chapter.sectionRoles, ["Replace a function's placeholder, not its interface": .overview, "Test a hypothesis": .troubleshooting])
        let firstSection = try XCTUnwrap(chapter.lesson.components(separatedBy: "## Read part of a string with a slice").first)
        let basicsEnd = try XCTUnwrap(firstSection.range(of: "Do not modify the input"))
        for heading in ["Plan from a specification", "Choose meaningful names", "Refactor without changing behavior", "Read a signature and docstring", "Comments explain why"] {
            let unit = try XCTUnwrap(firstSection.range(of: "### " + heading), heading)
            XCTAssertGreaterThan(unit.lowerBound, basicsEnd.lowerBound, heading)
        }
        for word in ["**decomposition**", "**helper function**", "**signature**", "**docstring**", "Triple quotes", "partial", "preserved behavior", "rather than merely repeating"] {
            XCTAssertTrue(firstSection.contains(word), word)
        }
        let documentation = try XCTUnwrap(firstSection.range(of: "Triple quotes"))
        let docstringExample = try XCTUnwrap(firstSection.range(of: "'''Return an integer box count"))
        XCTAssertLessThan(documentation.lowerBound, docstringExample.lowerBound)
        let refactor = try exercise(newIDs[1])
        for phrase in ["temporarily replaces", "__globals__", "not code length, style, or AI judgment", "does not grade explanation quality"] {
            XCTAssertTrue(refactor.instructions.contains(phrase), phrase)
        }
    }

    func testLessonPythonBlocksRunStandaloneWithOutputBoxesForPrints() async throws {
        try await requireSandbox()
        let lesson = try chapter().lesson
        let blocks = lesson.components(separatedBy: "```python\n").dropFirst()
        for (index, block) in blocks.enumerated() {
            let pieces = block.components(separatedBy: "```")
            let code = try XCTUnwrap(pieces.first)
            let result = try await PythonRunner().run(code: code, pythonPath: pythonPath)
            XCTAssertTrue(result.passed, "block \(index): \(result.output)")
            if code.contains("print(") {
                XCTAssertGreaterThanOrEqual(pieces.count, 3)
                XCTAssertTrue(block.contains("```text\n"), "block \(index) needs an output box")
            }
        }
    }

    func testNewStartersRunStandaloneAndFailOnlyChecksWhileReferencesPass() async throws {
        try await requireSandbox()
        for id in newIDs {
            let exercise = try exercise(id)
            let runner = PythonRunner()
            let standalone = try await runner.run(code: exercise.starterCode, pythonPath: pythonPath)
            XCTAssertTrue(standalone.passed, "\(id): \(standalone.output)")
            let starter = try await runner.check(code: exercise.starterCode, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(starter.passed, id)
            XCTAssertEqual(starter.diagnostic?.exceptionType, "AssertionError", starter.output)
            XCTAssertEqual(starter.diagnostic?.origin, .checks, starter.output)
            let reference = try await runner.check(code: exercise.referenceSolution, exercise: exercise, pythonPath: pythonPath)
            XCTAssertTrue(reference.passed, "\(id): \(reference.output)")
            XCTAssertFalse(reference.timedOut, id)
            XCTAssertFalse(reference.cancelled, id)
        }
    }

    func testChecksRejectWrongBoundaryFixedAnswersAndInputMutation() async throws {
        try await requireSandbox()
        let exercise = try exercise(newIDs[0])
        let mutations = [
            ("age < child_boundary", "age <= child_boundary"),
            ("return total", "return 26"),
            ("return total", "return total / 1"),
            ("return total", "ages.reverse()\n    return total"),
            ("total = 0", "ages.append(0)\n    total = 0"),
            ("for age in ages:", "for age in ages[:1]:")
        ]
        for (original, replacement) in mutations {
            XCTAssertTrue(exercise.referenceSolution.contains(original))
            let code = exercise.referenceSolution.replacingOccurrences(of: original, with: replacement)
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, replacement)
            XCTAssertEqual(result.diagnostic?.exceptionType, "AssertionError", result.output)
            XCTAssertEqual(result.diagnostic?.origin, .checks, result.output)
        }
    }

    func testRefactorChecksRejectBrokenBoundariesUnusedHelperAndIgnoredHelperResults() async throws {
        try await requireSandbox()
        let exercise = try exercise(newIDs[1])
        let mutations = [
            ("(item_count + batch_size - 1) // batch_size", "item_count // batch_size"),
            ("(item_count + batch_size - 1) // batch_size", "item_count // batch_size + 1"),
            ("first_cost = batch_cost(first_count, batch_size, price_per_batch)", "first_cost = ((first_count + batch_size - 1) // batch_size) * price_per_batch"),
            ("return first_cost + second_cost", "return ((first_count + batch_size - 1) // batch_size + (second_count + batch_size - 1) // batch_size) * price_per_batch"),
            ("return first_cost + second_cost", "return batch_cost(first_count + second_count, batch_size, price_per_batch)"),
            ("return batch_count * price_per_batch", "return 12"),
            ("'''Return an integer charge for a nonnegative item count and price.\n    The batch size is positive. Count a partial batch; zero items costs zero.\n    '''", "''")
        ]
        for (original, replacement) in mutations {
            XCTAssertTrue(exercise.referenceSolution.contains(original))
            let code = exercise.referenceSolution.replacingOccurrences(of: original, with: replacement)
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, replacement)
            XCTAssertEqual(result.diagnostic?.exceptionType, "AssertionError", result.output)
            XCTAssertEqual(result.diagnostic?.origin, .checks, result.output)
        }
    }

    func testEquivalentCorrectImplementationsPassWithoutMatchingReferenceAlgorithm() async throws {
        try await requireSandbox()
        let solutions = [
            """
            def ticket_total(ages, child_price, adult_price, child_boundary):
                children = 0
                for age in ages:
                    if age < child_boundary:
                        children += 1
                adults = len(ages) - children
                return children * child_price + adults * adult_price
            """,
            """
            def batch_cost(item_count, batch_size, price_per_batch):
                '''Charge whole batches for nonnegative items and price, with positive size.
                Zero items costs zero; charge one batch for a partial group.
                '''
                charge = 0
                remaining = item_count
                while remaining > 0:
                    charge += price_per_batch
                    remaining -= batch_size
                return charge

            def total_batch_cost(first_count, second_count, batch_size, price_per_batch):
                second_charge = batch_cost(second_count, batch_size, price_per_batch)
                first_charge = batch_cost(first_count, batch_size, price_per_batch)
                return second_charge + first_charge
            """
        ]
        for (id, code) in zip(newIDs, solutions) {
            let exercise = try exercise(id)
            XCTAssertNotEqual(code, exercise.referenceSolution)
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertTrue(result.passed, "\(id): \(result.output)")
        }
    }

    func testPublicInputsStayUnchangedAndRefactoringPreservesWorkingStarterTotals() async throws {
        try await requireSandbox()
        let transfer = try exercise(newIDs[0])
        let inputChecks = """
        supplied_ages = [30, 5, 12, 5]
        assert ticket_total(supplied_ages, 4, 9, 12) == 26
        assert supplied_ages == [30, 5, 12, 5]
        assert ticket_total(supplied_ages, 2, 5, 13) == 11
        assert supplied_ages == [30, 5, 12, 5]
        assert ticket_total([], 4, 9, 12) == 0
        assert ticket_total(supplied_ages, 4, 9, 12) == 26
        assert supplied_ages == [30, 5, 12, 5]
        """
        let result = try await PythonRunner().run(code: transfer.referenceSolution, tests: inputChecks, pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
        let refactor = try exercise(newIDs[1])
        let publicChecks = """
        assert total_batch_cost(5, 3, 4, 6) == 18
        assert total_batch_cost(1, 1, 4, 6) == 12
        assert total_batch_cost(0, 8, 4, 6) == 12
        assert total_batch_cost(8, 0, 4, 6) == 12
        assert total_batch_cost(0, 0, 4, 6) == 0
        assert total_batch_cost(7, 3, 3, 2) == 8
        assert total_batch_cost(5, 3, 4, 6) == 18
        """
        for code in [refactor.starterCode, refactor.referenceSolution] {
            let result = try await PythonRunner().run(code: code, tests: publicChecks, pythonPath: pythonPath)
            XCTAssertTrue(result.passed, result.output)
        }
    }
}
