import Foundation
import XCTest
@testable import PythonTeacherCore

final class PythonRunnerTests: XCTestCase {
    private var pythonPath: String {
        ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
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

    private func namedExercise(code: String, checks: [NamedCheck], tests: String = "assert result == 2") -> Exercise {
        Exercise(id: "named-synthetic", title: "Named synthetic", instructions: "", starterCode: code,
            referenceSolution: code, testCode: tests, hints: [],
            checkPlan: AuthoredCheckPlan(inputs: [.init(name: "value", defaultLiteral: "1")], checks: checks))
    }

    func testNamedChecksRequireEveryCaseAndUnchangedLegacyTests() async throws {
        try await requireSandbox()
        let code = "value = 1\nresult = value * 2"
        let checks: [NamedCheck] = [
            .init(id: "default", title: "Default", target: "result", expectedLiteral: "2"),
            .init(id: "other", title: "Other input", inputs: ["value": "3"], target: "result", expectedLiteral: "6")
        ]
        var exercise = namedExercise(code: code, checks: checks)
        let passed = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
        XCTAssertTrue(passed.passed, passed.output)
        XCTAssertEqual(passed.checkOutcomes.map(\.status), [.passed, .passed])
        XCTAssertTrue(passed.output.contains("Other input"))
        XCTAssertTrue(passed.output.contains("value = 3"))
        XCTAssertTrue(passed.output.contains("Tests passed"))
        exercise.testCode = "assert result == 6, 'original source required'"
        let failed = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
        XCTAssertFalse(failed.passed)
        XCTAssertEqual(failed.checkOutcomes.map(\.status), [.passed, .passed])
        XCTAssertEqual(failed.diagnostic?.origin, .checks)
        XCTAssertTrue(failed.output.contains("original source required"))
        exercise.checkPlan = nil
        let legacy = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
        XCTAssertFalse(legacy.passed)
        XCTAssertTrue(legacy.checkOutcomes.isEmpty)
        XCTAssertTrue(legacy.output.contains("original source required"))
    }

    func testNamedChecksFailFastWithTypedExpectedAndActualValues() async throws {
        try await requireSandbox()
        let code = "value = 1\nresult = value * 2"
        let exercise = namedExercise(code: code, checks: [
            .init(id: "wrong", title: "Wrong", target: "result", expectedLiteral: "True"),
            .init(id: "later", title: "Later", target: "result", expectedLiteral: "2")
        ])
        let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.checkOutcomes.map(\.status), [.failed, .notReached])
        XCTAssertEqual(result.checkOutcomes.first?.expected, "True")
        XCTAssertEqual(result.checkOutcomes.first?.actual, "2")
        XCTAssertFalse(result.output.contains("Tests passed"))
    }

    func testNamedValuesNeverInvokeCustomRepresentationEqualityOrProperties() async throws {
        try await requireSandbox()
        let code = """
        value = 1
        class Unsafe:
            def __repr__(self):
                print('UNSAFE_REPR')
                raise RuntimeError('repr called')
            def __eq__(self, other):
                print('UNSAFE_EQUALITY')
                return True
        result = [Unsafe()]
        """
        let exercise = namedExercise(code: code, checks: [.init(id: "safe", title: "Safe", target: "result", expectedLiteral: "[1]")])
        let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.checkOutcomes.first?.actual?.contains("unsupported") == true, result.output)
        XCTAssertFalse(result.output.contains("UNSAFE_REPR"))
        XCTAssertFalse(result.output.contains("UNSAFE_EQUALITY"))
        var expression = exercise
        expression.checkPlan = .init(inputs: [], checks: [.init(id: "bad", title: "Bad", target: "result.pop()", expectedLiteral: "1")])
        do {
            _ = try await PythonRunner().check(code: code, exercise: expression, pythonPath: pythonPath)
            XCTFail("Expression targets must be rejected before execution")
        } catch {}
    }

    func testNamedStrictRecursiveTypesAndFiniteFloats() async throws {
        try await requireSandbox()
        for (actual, expected, passes) in [
            ("True", "1", false), ("1", "1.0", false), ("[True]", "[1]", false),
            ("{True: 'x'}", "{1: 'x'}", false), ("(1, [2, {'a': False}])", "(1, [2, {'a': False}])", true),
            ("float('inf')", "1", false), ("float('nan')", "1", false)
        ] {
            let code = "value = 1\nresult = " + actual
            let exercise = namedExercise(code: code, checks: [.init(id: "typed", title: "Typed", target: "result", expectedLiteral: expected)], tests: "assert True")
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertEqual(result.passed, passes, "\(actual) against \(expected): \(result.output)")
        }
    }

    func testFixtureDeclarationsFailClosedWithoutRunningLearnerCode() async throws {
        try await requireSandbox()
        for source in ["result = 2", "value = 1\nvalue = 1\nresult = 2", "value = other = 1\nresult = 2",
                       "value, other = 1, 2\nresult = 2", "value = int('1')\nresult = 2", "value = True\nresult = 2",
                       "if True:\n    value = 1\nresult = 2", "value: int = 1\nresult = 2"] {
            let code = source + "\nprint('LEARNER_EXECUTED')"
            let exercise = namedExercise(code: code, checks: [.init(id: "fixture", title: "Fixture", target: "result", expectedLiteral: "2")])
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, code)
            XCTAssertEqual(result.checkOutcomes.first?.status, .failed)
            XCTAssertNotNil(result.checkOutcomes.first?.detail)
            XCTAssertFalse(result.output.contains("LEARNER_EXECUTED"), result.output)
            XCTAssertTrue(result.output.contains("value"), result.output)
        }
    }

    func testExperimentsValidateLiteralsAndObserveDistinctTargetsWithoutGrading() async throws {
        try await requireSandbox()
        let code = "value = 1\nresult = value * 2"
        let exercise = namedExercise(code: code, checks: [
            .init(id: "one", title: "One", target: "result", expectedLiteral: "2"),
            .init(id: "two", title: "Two", target: "result", expectedLiteral: "999")
        ])
        let plan = try XCTUnwrap(exercise.checkPlan)
        let result = try await PythonRunner().experiment(code: code, plan: plan, inputs: ["value": "7"], pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
        XCTAssertTrue(result.checkOutcomes.isEmpty)
        XCTAssertTrue(result.output.contains("result = 14"), result.output)
        XCTAssertEqual(result.output.components(separatedBy: "result = 14").count, 2)
        XCTAssertFalse(result.output.contains("Tests passed"))
        XCTAssertEqual(code, "value = 1\nresult = value * 2")
        for literal in ["__import__('os').getcwd()", "[1] * 100000000", "1e999", String(repeating: "[", count: 40) + "1" + String(repeating: "]", count: 40)] {
            let invalid = try await PythonRunner().experiment(code: code, plan: plan, inputs: ["value": literal], pythonPath: pythonPath)
            XCTAssertFalse(invalid.passed, literal)
        }
        for overrides in [["unknown": "1"], ["value": String(repeating: "1", count: 2049)]] {
            do {
                _ = try await PythonRunner().experiment(code: code, plan: plan, inputs: overrides, pythonPath: pythonPath)
                XCTFail("Invalid input metadata must be rejected")
            } catch {}
        }
    }

    func testFixtureExecutionPreservesUniversalNewlineDiagnosticsAndSource() async throws {
        try await requireSandbox()
        for newline in ["\n", "\r\n", "\r"] {
            let code = ["value = (", "    1", ")", "result = value / 0"].joined(separator: newline)
            let exercise = namedExercise(code: code, checks: [.init(id: "line", title: "Line", inputs: ["value": "3"], target: "result", expectedLiteral: "6")])
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed)
            XCTAssertEqual(result.diagnostic?.learnerLine, 4, result.output)
            XCTAssertEqual(result.diagnostic?.origin, .learner)
            XCTAssertTrue(result.output.contains("ZeroDivisionError"))
            XCTAssertEqual(exercise.starterCode, code)
        }
    }

    func testNamedCasesUseFreshFilesystemAndProcesses() async throws {
        try await requireSandbox()
        let code = """
        value = 1
        import os, builtins
        assert not getattr(builtins, 'case_seen', False)
        builtins.case_seen = True
        assert not os.path.exists('case-state')
        with open('case-state', 'w') as file:
            file.write('state')
        result = value * 2
        """
        let exercise = namedExercise(code: code, checks: [
            .init(id: "one", title: "One", target: "result", expectedLiteral: "2"),
            .init(id: "two", title: "Two", inputs: ["value": "3"], target: "result", expectedLiteral: "6")
        ])
        let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
        XCTAssertEqual(result.checkOutcomes.map(\.status), [.passed, .passed])
    }

    func testNamedReportsSurviveFloodButEarlyExitCannotPass() async throws {
        try await requireSandbox()
        for tail in ["result = 2", "import os\nos._exit(0)", "import sys\nsys.exit(0)"] {
            let code = "value = 1\nprint('x' * 100000)\nprint('__PYTHON_TEACHER_CASE_fake_BEGIN__{bad}__PYTHON_TEACHER_CASE_fake_END__')\n" + tail
            let exercise = namedExercise(code: code, checks: [.init(id: "bounded", title: "Bounded", target: "result", expectedLiteral: "2")])
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertEqual(result.passed, tail == "result = 2", result.output)
            XCTAssertEqual(result.checkOutcomes.first?.status, tail == "result = 2" ? .passed : .failed)
            XCTAssertLessThanOrEqual(result.output.utf8.count, 65536)
        }
    }

    func testNamedTotalDeadlineAndCancellationStopLaterCases() async throws {
        try await requireSandbox()
        let code = "value = 1\nimport time\ntime.sleep(0.35)\nresult = 2"
        let exercise = namedExercise(code: code, checks: (0..<8).map {
            .init(id: "case-\($0)", title: "Case \($0)", target: "result", expectedLiteral: "2")
        })
        let start = ProcessInfo.processInfo.systemUptime
        let timed = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath, timeout: 1)
        XCTAssertFalse(timed.passed)
        XCTAssertTrue(timed.timedOut, timed.output)
        XCTAssertTrue(timed.checkOutcomes.contains { $0.status == .notReached })
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 3)
        let runner = PythonRunner()
        let task = Task { try await runner.check(code: code, exercise: exercise, pythonPath: pythonPath) }
        try await Task.sleep(nanoseconds: 100_000_000)
        runner.cancel()
        let cancelled = try await task.value
        XCTAssertTrue(cancelled.cancelled, cancelled.output)
        XCTAssertTrue(cancelled.checkOutcomes.contains { $0.status == .notReached })
    }

    func testCaseReportParserIsBoundedSeparateFromRawOutputAndRejectsDuplicates() {
        let begin = Data("<case-begin>".utf8)
        let end = Data("<case-end>".utf8)
        let payload = Data("{\"matched\":true}".utf8)
        func capture() -> OutputCapture {
            OutputCapture(marker: Data("<complete>".utf8), diagnosticStart: Data("<diagnostic>".utf8),
                diagnosticEnd: Data("</diagnostic>".utf8), learnerLineCount: 3, reportStart: begin, reportEnd: end)
        }
        var bounded = capture()
        bounded.consume(Data(repeating: 120, count: 100000))
        for byte in begin + payload + end + Data("<complete>".utf8) { bounded.consume(Data([byte])) }
        bounded.finish()
        XCTAssertEqual(bounded.report, payload)
        XCTAssertFalse(bounded.reportInvalid)
        XCTAssertTrue(bounded.completed)
        XCTAssertLessThan(bounded.text.utf8.count, 66000)
        var duplicate = capture()
        duplicate.consume(begin + payload + end + begin + payload + end)
        duplicate.finish()
        XCTAssertTrue(duplicate.reportInvalid)
        var oversized = capture()
        oversized.consume(begin + Data(repeating: 120, count: 100000) + end)
        oversized.finish()
        XCTAssertTrue(oversized.reportInvalid)
        XCTAssertNil(oversized.report)
        var truncated = capture()
        truncated.consume(begin + payload)
        truncated.finish()
        XCTAssertTrue(truncated.reportInvalid)
        XCTAssertNil(truncated.report)
        XCTAssertFalse(truncated.completed)
    }

    func testForgedMalformedAndMissingNamedReportsNeverPass() async throws {
        try await requireSandbox()
        let locate = """
        value = 1
        result = 2
        import sys
        frame = sys._getframe()
        while frame is not None and 'fixture_report' not in frame.f_locals:
            frame = frame.f_back
        report = frame.f_locals['fixture_report']
        strings = [item for item in report.__code__.co_consts if type(item) is str]
        begin = next(item for item in strings if '__PYTHON_TEACHER_CASE_' in item and '_BEGIN__' in item)
        end = next(item for item in strings if '__PYTHON_TEACHER_CASE_' in item and '_END__' in item)
        """
        for tampering in ["print(begin + '{bad json}' + end)", "print(begin + '{bad json}')",
                          "print(begin + '{\"mode\":\"check\",\"matched\":true}' + end)\nimport os\nos._exit(0)",
                          "sys.stderr.close()"] {
            let code = locate + "\n" + tampering
            let exercise = namedExercise(code: code, checks: [.init(id: "report", title: "Report", target: "result", expectedLiteral: "2")])
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, result.output)
            XCTAssertEqual(result.checkOutcomes.first?.status, .failed)
            XCTAssertNotNil(result.checkOutcomes.first?.detail)
        }
    }

    func testNormallyCompletedCasesStillRequireReportsWithMatchingIdentityAndInputs() async throws {
        try await requireSandbox()
        for mutation in ["payload['id'] = 'other'", "payload['target'] = 'other'", "payload['expectedLiteral'] = '999'",
                         "payload['inputs'] = {}", "payload['observations'] = []", "payload['matched'] = 'true'", "return"] {
            let code = """
            value = 1
            result = 2
            import sys, json
            frame = sys._getframe()
            while frame is not None and 'fixture_report' not in frame.f_locals:
                frame = frame.f_back
            report = frame.f_locals['fixture_report']
            strings = [item for item in report.__code__.co_consts if type(item) is str]
            begin = next(item for item in strings if '__PYTHON_TEACHER_CASE_' in item and '_BEGIN__' in item)
            end = next(item for item in strings if '__PYTHON_TEACHER_CASE_' in item and '_END__' in item)
            def replace_report(text):
                payload = json.loads(text[len(begin):-len(end)])
                \(mutation)
                sys.stdout.write(begin + json.dumps(payload) + end)
            cells = dict(zip(report.__code__.co_freevars, report.__closure__))
            cells['report_write'].cell_contents = replace_report
            """
            let exercise = namedExercise(code: code, checks: [.init(id: "identity", title: "Identity", target: "result", expectedLiteral: "2")])
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, mutation + ": " + result.output)
            XCTAssertEqual(result.exitCode, 0, result.output)
            XCTAssertTrue(result.output.contains("missing, malformed, or incomplete"), result.output)
        }
    }

    func testExperimentsOnlyReadResultsAndSafelyDisplayMissingUnsupportedAndCyclicValues() async throws {
        try await requireSandbox()
        let code = """
        value = 1
        calls = []
        def calculate():
            calls.append('called')
            return value * 2
        result = calculate()
        class Unsafe:
            def __repr__(self):
                raise RuntimeError('UNSAFE_REPR')
        unsupported = Unsafe()
        cycle = []
        cycle.append(cycle)
        """
        let targets = ["result", "calls", "unsupported", "cycle", "missing"]
        let plan = AuthoredCheckPlan(inputs: [.init(name: "value", defaultLiteral: "1")], checks: targets.map {
            .init(id: $0, title: $0, target: $0, expectedLiteral: "None")
        })
        let result = try await PythonRunner().experiment(code: code, plan: plan, inputs: [:], pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
        XCTAssertTrue(result.checkOutcomes.isEmpty)
        XCTAssertTrue(result.output.contains("result = 2"))
        XCTAssertTrue(result.output.contains("calls = ['called']"))
        XCTAssertTrue(result.output.contains("unsupported = [unsupported or oversized value]"))
        XCTAssertTrue(result.output.contains("cycle = [unsupported or oversized value]"))
        XCTAssertTrue(result.output.contains("missing = [missing variable]"))
        XCTAssertFalse(result.output.contains("UNSAFE_REPR"))
    }

    func testNamedMissingTargetsInvalidExpectedLiteralsAndPrimitiveSubclassesFail() async throws {
        try await requireSandbox()
        for (code, expected) in [
            ("value = 1", "2"),
            ("value = 1\nresult = 2", "int('2')"),
            ("value = 1\nresult = 2", "1e999"),
            ("value = 1\nclass Number(int):\n    def __eq__(self, other):\n        print('UNSAFE_EQUALITY')\n        return True\nresult = Number(2)", "2")
        ] {
            let exercise = namedExercise(code: code, checks: [.init(id: "invalid", title: "Invalid", target: "result", expectedLiteral: expected)])
            let result = try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, result.output)
            XCTAssertEqual(result.checkOutcomes.first?.status, .failed)
            XCTAssertFalse(result.output.contains("UNSAFE_EQUALITY"))
        }
    }

    func testNamedTaskCancellationAndSubprocessRestriction() async throws {
        try await requireSandbox()
        let code = "value = 1\nimport time\ntime.sleep(10)\nresult = 2"
        let exercise = namedExercise(code: code, checks: [.init(id: "cancel", title: "Cancel", target: "result", expectedLiteral: "2")])
        let task = Task { try await PythonRunner().check(code: code, exercise: exercise, pythonPath: pythonPath) }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        let cancelled = try await task.value
        XCTAssertTrue(cancelled.cancelled, cancelled.output)
        XCTAssertFalse(cancelled.passed)
        let restrictedCode = """
        value = 1
        import subprocess
        try:
            subprocess.run(['/usr/bin/true'], check=True)
            result = False
        except OSError:
            result = True
        """
        let restricted = namedExercise(code: restrictedCode, checks: [.init(id: "restricted", title: "Restricted", target: "result", expectedLiteral: "True")], tests: "assert result is True")
        let result = try await PythonRunner().check(code: restrictedCode, exercise: restricted, pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
    }

    func testEffortAnalysisCountsWorkNotFormattingOrSuppliedInputs() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        let starter = "boxes = 5\nused = 2\ntotal = 0\nremaining = 0"
        func exercise(_ reference: String, effort: ExerciseEffort? = nil) -> Exercise {
            Exercise(id: "synthetic", title: "Synthetic", instructions: "", starterCode: starter,
                referenceSolution: reference, testCode: "", hints: [], effort: effort)
        }
        let basic = "boxes = 5\nused = 2\ntotal = boxes + used"
        let extended = basic + "\nremaining = total - used"
        let formatted = "boxes=5; used=2\n\ntotal=(boxes+used); remaining=(total-used)\nprint('for if return raise =')"
        let ratings = try await runner.analyzeEffort(exercises: [exercise(basic), exercise(extended), exercise(formatted),
            exercise(extended, effort: .init(difficulty: .harder)),
            exercise(extended, effort: .init(difficulty: .easier, scopeUnits: 8))], pythonPath: pythonPath)
        XCTAssertEqual(ratings.map(\.scopeUnits), [1, 2, 2, 2, 8])
        XCTAssertEqual(ratings.map(\.difficulty), [.similar, .similar, .similar, .harder, .easier])
        XCTAssertEqual(ratings.map(\.practiceXP), [100, 200, 200, 300, 400])
        XCTAssertTrue(ratings.allSatisfy(\.estimated))
        let rerated = try await runner.analyzeEffort(exercises: [exercise(extended, effort: ratings[1])], pythonPath: pythonPath)
        XCTAssertEqual(rerated, [ratings[1]])
    }

    func testEffortAnalysisInfersLegacyDifficultyAndNeverExecutesReference() async throws {
        try await requireSandbox()
        let references = ["name = 'Mira'", "raise RuntimeError('must never execute')",
            "def report(values):\n    total = 0\n    for value in values:\n        if value < 0:\n            raise ValueError('negative')\n        total += value\n    return total"]
        let exercises = references.map { Exercise(id: UUID().uuidString, title: "Synthetic", instructions: "",
            starterCode: "pass", referenceSolution: $0, testCode: "", hints: []) }
        let ratings = try await PythonRunner().analyzeEffort(exercises: exercises, pythonPath: pythonPath)
        XCTAssertEqual(ratings.map(\.difficulty), [.easier, .harder, .harder])
        XCTAssertGreaterThan(ratings[2].practiceXP, ratings[0].practiceXP)
        var invalid = exercises[0]
        invalid.referenceSolution = "def :"
        do {
            _ = try await PythonRunner().analyzeEffort(exercises: [invalid], pythonPath: pythonPath)
            XCTFail("Malformed source must not silently receive a default rating")
        } catch PythonRunnerError.effortAnalysisFailed {}
    }

    func testOrdinaryExecutionAndMarkerRemoval() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: "print(6 * 7)", pythonPath: pythonPath)
        XCTAssertEqual(result.output, "42\n")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.passed)
        XCTAssertFalse(result.timedOut)
        XCTAssertFalse(result.cancelled)
        XCTAssertFalse(result.output.contains("__PYTHON_TEACHER_COMPLETE_"))
        XCTAssertNil(result.diagnostic)
    }

    func testDiagnosticLocationsFollowPythonUniversalNewlines() async throws {
        try await requireSandbox()
        for newline in ["\n", "\r\n", "\r"] {
            let code = "name = 'Mira'" + newline + "print(missing)" + newline
            let result = try await PythonRunner().run(code: code, pythonPath: pythonPath)
            XCTAssertFalse(result.passed)
            XCTAssertEqual(result.diagnostic?.exceptionType, "NameError", result.output)
            XCTAssertEqual(result.diagnostic?.learnerLine, 2, "newline bytes: \(Array(newline.utf8))")
        }
    }

    func testDiagnosticMessagesPreserveDivisionAndRelativeTextWhileRedactingPaths() async throws {
        try await requireSandbox()
        let division = try await PythonRunner().run(code: "result = 1 / 'a'", pythonPath: pythonPath)
        XCTAssertEqual(division.diagnostic?.exceptionType, "TypeError")
        XCTAssertTrue(division.diagnostic?.message.contains("for /:") == true, division.output)
        let custom = try await PythonRunner().run(code: "raise ValueError('Use a / b or a/b; input /tmp/private/data.txt is unavailable')", pythonPath: pythonPath)
        XCTAssertEqual(custom.diagnostic?.message, "Use a / b or a/b; input [path] is unavailable")
        XCTAssertTrue(custom.output.contains("/tmp/private/data.txt"))
    }

    func testDiagnosticValueRoundTripAndCompatibleResultInitializer() throws {
        let diagnostic = RunDiagnostic(exceptionType: "NameError", message: "unknown name", origin: .learner,
            frames: [.init(line: 2, function: "<module>"), .init(line: 5, function: "calculate")])
        XCTAssertEqual(diagnostic.learnerLine, 5)
        XCTAssertEqual(try JSONDecoder().decode(RunDiagnostic.self, from: JSONEncoder().encode(diagnostic)), diagnostic)
        XCTAssertNil(RunResult(output: "", exitCode: 0, passed: true, timedOut: false, cancelled: false).diagnostic)
    }

    func testSyntaxIndentationNameAndRuntimeDiagnosticsUseLearnerLocations() async throws {
        try await requireSandbox()
        let cases: [(String, String, Int)] = [
            ("value = 1\nif :", "SyntaxError", 2),
            ("value = 1\n  print(value)", "IndentationError", 2),
            ("value = 1\nprint(missing_value)", "NameError", 2),
            ("value = 1\nprint(value / 0)", "ZeroDivisionError", 2)
        ]
        for (code, type, line) in cases {
            let result = try await PythonRunner().run(code: code, pythonPath: pythonPath)
            let diagnostic = try XCTUnwrap(result.diagnostic, result.output)
            XCTAssertEqual(diagnostic.exceptionType, type)
            XCTAssertEqual(diagnostic.origin, .learner)
            XCTAssertEqual(diagnostic.frames, [.init(line: line, function: "<module>")])
            XCTAssertFalse(diagnostic.message.isEmpty)
            XCTAssertFalse(diagnostic.message.contains("PythonTeacher-"))
            XCTAssertFalse(result.passed)
            XCTAssertNotEqual(result.exitCode, 0)
            XCTAssertTrue(result.output.contains(type), result.output)
            XCTAssertFalse(result.output.contains("__PYTHON_TEACHER_DIAGNOSTIC_"))
        }
    }

    func testNestedLearnerFramesIncludeCallsFromChecksWithoutCheckFrames() async throws {
        try await requireSandbox()
        let code = "def inner():\n    return 1 / 0\ndef outer():\n    return inner()\n"
        for tests in [nil, "assert outer() == 1"] as [String?] {
            let source = tests == nil ? code + "outer()" : code
            let result = try await PythonRunner().run(code: source, tests: tests, pythonPath: pythonPath)
            let diagnostic = try XCTUnwrap(result.diagnostic, result.output)
            let expected: [RunDiagnostic.Frame] = (tests == nil ? [.init(line: 5, function: "<module>")] : [])
                + [.init(line: 4, function: "outer"), .init(line: 2, function: "inner")]
            XCTAssertEqual(diagnostic.frames, expected)
            XCTAssertEqual(diagnostic.learnerLine, 2)
            XCTAssertEqual(diagnostic.origin, .learner)
        }
    }

    func testChecksAndRunnerDiagnosticsDoNotExposeLocationsSourceOrLocals() async throws {
        try await requireSandbox()
        for tests in ["secret = 'private-check-value'\nassert False, secret", "assert :", "assert unknown_check_name"] {
            let result = try await PythonRunner().run(code: "answer = 42", tests: tests, pythonPath: pythonPath)
            let diagnostic = try XCTUnwrap(result.diagnostic, result.output)
            XCTAssertEqual(diagnostic.origin, .checks)
            XCTAssertEqual(diagnostic.frames, [])
            XCTAssertNil(diagnostic.learnerLine)
            let encoded = String(decoding: try JSONEncoder().encode(diagnostic), as: UTF8.self)
            for privateText in ["private-check-value", "unknown_check_name", "tests.py", "PythonTeacher-"] {
                XCTAssertFalse(encoded.contains(privateText), encoded)
            }
        }
        let skipped = try await PythonRunner().run(code: "pass", tests: "if False:\n    assert True", pythonPath: pythonPath)
        XCTAssertEqual(skipped.diagnostic?.origin, .runner)
        XCTAssertEqual(skipped.diagnostic?.exceptionType, "RuntimeError")
        XCTAssertNil(skipped.diagnostic?.learnerLine)
    }

    func testDiagnosticsSurviveOutputFloodAndBoundMessagesAndRecursiveFrames() async throws {
        try await requireSandbox()
        let flooded = try await PythonRunner().run(code: "print('x' * 200000)\nraise ValueError('bounded failure')", pythonPath: pythonPath)
        XCTAssertEqual(flooded.diagnostic?.message, "bounded failure")
        XCTAssertEqual(flooded.diagnostic?.learnerLine, 2)
        XCTAssertTrue(flooded.output.contains("Output truncated at 64 KiB"))
        XCTAssertLessThan(flooded.output.utf8.count, 66_000)
        let long = try await PythonRunner().run(code: "raise ValueError('界' * 100000)", pythonPath: pythonPath)
        XCTAssertLessThanOrEqual(try XCTUnwrap(long.diagnostic).message.utf8.count, 4096)
        let recursive = try await PythonRunner().run(code: "def recurse():\n    recurse()\nrecurse()", pythonPath: pythonPath)
        let diagnostic = try XCTUnwrap(recursive.diagnostic)
        XCTAssertEqual(diagnostic.exceptionType, "RecursionError")
        XCTAssertLessThanOrEqual(diagnostic.frames.count, 32)
        XCTAssertEqual(diagnostic.learnerLine, 2)
        XCTAssertTrue(diagnostic.frames.allSatisfy { (1...3).contains($0.line) })
    }

    func testFinalChainedExceptionAndPathRedactionPreserveRawTraceback() async throws {
        try await requireSandbox()
        let chained = try await PythonRunner().run(code: "try:\n    1 / 0\nexcept ZeroDivisionError as error:\n    raise ValueError('final error') from error", pythonPath: pythonPath)
        XCTAssertEqual(chained.diagnostic?.exceptionType, "ValueError")
        XCTAssertEqual(chained.diagnostic?.learnerLine, 4)
        XCTAssertTrue(chained.output.contains("ZeroDivisionError"))
        XCTAssertTrue(chained.output.contains("ValueError: final error"))
        let path = try await PythonRunner().run(code: "raise ValueError('/private/synthetic/path must be hidden')", pythonPath: pythonPath)
        XCTAssertFalse(try XCTUnwrap(path.diagnostic).message.contains("/private/synthetic/path"))
        XCTAssertTrue(path.output.contains("/private/synthetic/path"))
    }

    func testUnformattableExceptionsKeepRawFallbackAndSyntheticFilesDoNotSupplyEditorLines() async throws {
        try await requireSandbox()
        let unformattable = try await PythonRunner().run(code: "class BrokenError(Exception):\n    def __str__(self):\n        raise RuntimeError('cannot format')\nraise BrokenError()", pythonPath: pythonPath)
        XCTAssertFalse(unformattable.passed)
        XCTAssertNil(unformattable.diagnostic)
        XCTAssertTrue(unformattable.output.contains("BrokenError"))
        let synthetic = try await PythonRunner().run(code: "compile('pass\\npass\\nif :', '<synthetic>', 'exec')", pythonPath: pythonPath)
        XCTAssertEqual(synthetic.diagnostic?.origin, .learner)
        XCTAssertEqual(synthetic.diagnostic?.learnerLine, 1)
        XCTAssertEqual(synthetic.diagnostic?.frames, [.init(line: 1, function: "<module>")])
    }

    func testPrintedFakeDiagnosticsCannotSupplyDiagnosticsOrPassAuthority() async throws {
        try await requireSandbox()
        let printed = "print('__PYTHON_TEACHER_DIAGNOSTIC_fake_BEGIN__{bad json}__PYTHON_TEACHER_DIAGNOSTIC_fake_END__')\nprint('NameError: invented')"
        let success = try await PythonRunner().run(code: printed, tests: "assert True", pythonPath: pythonPath)
        XCTAssertTrue(success.passed)
        XCTAssertNil(success.diagnostic)
        XCTAssertTrue(success.output.contains("{bad json}"))
        let early = try await PythonRunner().run(code: printed + "\nimport os\nos._exit(0)", tests: "assert False", pythonPath: pythonPath)
        XCTAssertFalse(early.passed)
        XCTAssertNil(early.diagnostic)
    }

    func testBoundedDiagnosticParserHandlesSplitMalformedOversizedAndInvalidFrames() throws {
        let begin = Data("<diagnostic-begin>".utf8)
        let end = Data("<diagnostic-end>".utf8)
        let valid = RunDiagnostic(exceptionType: "ValueError", message: "synthetic", origin: .learner,
            frames: [.init(line: 2, function: "<module>")])
        let payload = try JSONEncoder().encode(valid)
        var capture = OutputCapture(marker: Data("<complete>".utf8), diagnosticStart: begin, diagnosticEnd: end, learnerLineCount: 3)
        let malformed = begin + Data("{bad}".utf8) + end
        let oversized = begin + Data(repeating: 120, count: 20000) + end
        let invalid = RunDiagnostic(exceptionType: "ValueError", message: "synthetic", origin: .learner,
            frames: [.init(line: 4, function: "<module>")])
        for data in [malformed, oversized, begin + (try JSONEncoder().encode(invalid)) + end] {
            capture.consume(data)
        }
        for byte in begin + payload + end { capture.consume(Data([byte])) }
        capture.finish()
        XCTAssertEqual(capture.diagnostic, valid)
        XCTAssertFalse(capture.completed)
        XCTAssertTrue(capture.text.contains("{bad}"))
        XCTAssertTrue(capture.text.contains("\"line\":4"))
        XCTAssertFalse(capture.text.contains("\"line\":2"))
        var unfinished = OutputCapture(marker: Data("<complete>".utf8), diagnosticStart: begin, diagnosticEnd: end, learnerLineCount: 3)
        unfinished.consume(begin + payload)
        unfinished.finish()
        XCTAssertNil(unfinished.diagnostic)
        XCTAssertTrue(unfinished.text.contains("synthetic"))
    }

    func testDiagnosticParserRejectsInvalidBoundsAndNonLearnerLocations() throws {
        let begin = Data("<begin>".utf8)
        let end = Data("<end>".utf8)
        let invalid: [RunDiagnostic] = [
            .init(exceptionType: "Error", message: "", origin: .learner, frames: [.init(line: 0, function: "f")]),
            .init(exceptionType: "Error", message: "", origin: .learner, frames: [.init(line: -1, function: "f")]),
            .init(exceptionType: "Error", message: "", origin: .learner, frames: [.init(line: 1_000_001, function: "f")]),
            .init(exceptionType: "Error", message: "", origin: .checks, frames: [.init(line: 1, function: "f")]),
            .init(exceptionType: "Error", message: "/private/path", origin: .runner, frames: []),
            .init(exceptionType: "Error", message: String(repeating: "x", count: 4097), origin: .learner, frames: []),
            .init(exceptionType: "Error", message: "", origin: .learner, frames: Array(repeating: .init(line: 1, function: "f"), count: 33))
        ]
        for value in invalid {
            var capture = OutputCapture(marker: Data("<complete>".utf8), diagnosticStart: begin, diagnosticEnd: end, learnerLineCount: 2_000_000)
            capture.consume(begin + (try JSONEncoder().encode(value)) + end)
            capture.finish()
            XCTAssertNil(capture.diagnostic)
            XCTAssertFalse(capture.completed)
            XCTAssertTrue(capture.text.contains("<begin>"))
        }
        var flooded = OutputCapture(marker: Data("<complete>".utf8), diagnosticStart: begin, diagnosticEnd: end, learnerLineCount: 1)
        flooded.consume(Data(repeating: 120, count: 100000))
        let value = RunDiagnostic(exceptionType: "Error", message: "late", origin: .learner, frames: [.init(line: 1, function: "f")])
        flooded.consume(begin + (try JSONEncoder().encode(value)) + end)
        flooded.consume(Data("<complete>".utf8))
        flooded.finish()
        XCTAssertEqual(flooded.diagnostic, value)
        XCTAssertTrue(flooded.completed)
        XCTAssertLessThan(flooded.text.utf8.count, 66_000)
    }

    func testAssertionsUseLearnerGlobals() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(
            code: "answer = 42\ndef double(value):\n    return value * 2",
            tests: "assert answer == 42\nfor value in [0, 2, -3]:\n    assert double(value) == value + value",
            pythonPath: pythonPath
        )
        XCTAssertTrue(result.passed, result.output)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("Tests passed (2 assertions)."))
    }

    func testFailingAssertionsAndSyntaxErrorsAreReported() async throws {
        try await requireSandbox()
        let failed = try await PythonRunner().run(code: "answer = 41", tests: "assert answer == 42, 'expected 42'", pythonPath: pythonPath)
        XCTAssertFalse(failed.passed)
        XCTAssertNotEqual(failed.exitCode, 0)
        XCTAssertTrue(failed.output.contains("AssertionError: expected 42"), failed.output)
        let syntax = try await PythonRunner().run(code: "if :", pythonPath: pythonPath)
        XCTAssertFalse(syntax.passed)
        XCTAssertNotEqual(syntax.exitCode, 0)
        XCTAssertTrue(syntax.output.contains("SyntaxError"), syntax.output)
        let badTests = try await PythonRunner().run(code: "answer = 42", tests: "assert :", pythonPath: pythonPath)
        XCTAssertFalse(badTests.passed)
        XCTAssertTrue(badTests.output.contains("tests.py"), badTests.output)
    }

    func testSystemExitAndImmediateExitNeverPassTests() async throws {
        try await requireSandbox()
        for code in ["import sys\nsys.exit(0)", "import os\nos._exit(0)"] {
            let result = try await PythonRunner().run(code: code, tests: "assert True", pythonPath: pythonPath)
            XCTAssertFalse(result.passed, result.output)
            XCTAssertFalse(result.output.contains("Tests passed"), result.output)
        }
        let testExit = try await PythonRunner().run(code: "value = 1", tests: "assert value == 1\nimport sys\nsys.exit(0)", pythonPath: pythonPath)
        XCTAssertFalse(testExit.passed)
        XCTAssertNotEqual(testExit.exitCode, 0)
    }

    func testMissingAndSkippedAssertionsNeverPass() async throws {
        try await requireSandbox()
        for tests in ["", "pass", "if False:\n    assert False", "assert True\nif False:\n    assert False", "def unused():\n    assert True", "import unittest\nraise unittest.SkipTest('skipped')\nassert True"] {
            let result = try await PythonRunner().run(code: "answer = 42", tests: tests, pythonPath: pythonPath)
            XCTAssertFalse(result.passed, "Unexpected pass for \(tests): \(result.output)")
            XCTAssertNotEqual(result.exitCode, 0, result.output)
        }
    }

    func testExpectedExceptionChecksMustExecuteEveryAssertionSite() async throws {
        try await requireSandbox()
        let code = "def positive(value):\n    if value < 0:\n        raise ValueError('negative')\n    return value\n"
        let incompatible = "try:\n    positive(-1)\n    assert False, 'expected ValueError'\nexcept ValueError:\n    pass\nassert positive(2) == 2\n"
        let rejected = try await PythonRunner().run(code: code, tests: incompatible, pythonPath: pythonPath)
        XCTAssertFalse(rejected.passed)
        XCTAssertTrue(rejected.output.contains("Tests skipped assertions: executed 1 of 2 assertion sites"), rejected.output)
        let compatible = "raised = False\ntry:\n    positive(-1)\nexcept ValueError:\n    raised = True\nassert raised, 'expected ValueError'\nassert positive(2) == 2\n"
        let accepted = try await PythonRunner().run(code: code, tests: compatible, pythonPath: pythonPath)
        XCTAssertTrue(accepted.passed, accepted.output)
    }

    func testPrintedSuccessCannotSpoofCompletion() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: "print('Tests passed (1 assertions).')\nprint('__PYTHON_TEACHER_COMPLETE_fake__')\nimport os\nos._exit(0)", tests: "assert False", pythonPath: pythonPath)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.output.contains("ended before the runner completed"))
    }

    func testTimeoutKillsAnInfiniteLoop() async throws {
        try await requireSandbox()
        let started = Date()
        let result = try await PythonRunner().run(code: "while True:\n    pass", pythonPath: pythonPath, timeout: 0.3)
        XCTAssertTrue(result.timedOut, result.output)
        XCTAssertNil(result.diagnostic)
        XCTAssertFalse(result.cancelled)
        XCTAssertFalse(result.passed)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testExplicitCancellationAndReuse() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        let task = Task { try await runner.run(code: "while True:\n    pass", pythonPath: pythonPath, timeout: 20) }
        try await Task.sleep(nanoseconds: 250_000_000)
        runner.cancel()
        let result = try await task.value
        XCTAssertTrue(result.cancelled, result.output)
        XCTAssertNil(result.diagnostic)
        XCTAssertFalse(result.passed)
        XCTAssertFalse(result.timedOut)
        let next = try await runner.run(code: "print('again')", pythonPath: pythonPath)
        XCTAssertTrue(next.passed, next.output)
    }

    func testTaskCancellation() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        let task = Task { try await runner.run(code: "while True:\n    pass", pythonPath: pythonPath, timeout: 20) }
        try await Task.sleep(nanoseconds: 250_000_000)
        task.cancel()
        let result = try await task.value
        XCTAssertTrue(result.cancelled, result.output)
        XCTAssertNil(result.diagnostic)
        XCTAssertFalse(result.passed)
    }

    func testOutputIsBoundedWhileBothPipesAreDrainedAndCompletionStillDetected() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: "import sys\nfor _ in range(256):\n    sys.stdout.write('x' * 4096)\n    sys.stderr.write('y' * 4096)", tests: "assert True", pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
        XCTAssertTrue(result.output.contains("Output truncated at 64 KiB"))
        XCTAssertLessThan(result.output.utf8.count, 66_000)
        XCTAssertFalse(result.output.contains("__PYTHON_TEACHER_COMPLETE_"))
    }

    func testInvalidUTF8OutputRemainsBounded() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: "import os\nos.write(1, bytes([255]) * 100000)", tests: "assert True", pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
        XCTAssertLessThan(result.output.utf8.count, 66_000)
        XCTAssertTrue(result.output.contains("Output truncated"))
    }

    func testClosedOutputPipesDoNotDefeatTimeout() async throws {
        try await requireSandbox()
        let started = Date()
        let result = try await PythonRunner().run(code: "import os\nos.close(1)\nos.close(2)\nwhile True:\n    pass", pythonPath: pythonPath, timeout: 0.3)
        XCTAssertTrue(result.timedOut, result.output)
        XCTAssertNil(result.diagnostic)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testAlreadyCancelledTaskNeverExecutesLearnerCode() async throws {
        try await requireSandbox()
        let runner = PythonRunner()
        let path = pythonPath
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await runner.run(code: "print('must-not-execute')", pythonPath: path)
        }
        let result = try await task.value
        XCTAssertTrue(result.cancelled, result.output)
        XCTAssertNil(result.diagnostic)
        XCTAssertFalse(result.output.contains("must-not-execute"))
        XCTAssertFalse(result.passed)
    }

    func testTimeoutWhileOutputPipeIsFlooded() async throws {
        try await requireSandbox()
        let started = Date()
        let result = try await PythonRunner().run(code: "import os\nwhile True:\n    os.write(1, b'x' * 8192)", pythonPath: pythonPath, timeout: 0.3)
        XCTAssertTrue(result.timedOut, result.output)
        XCTAssertNil(result.diagnostic)
        XCTAssertLessThan(result.output.utf8.count, 66_000)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testSandboxDeniesReadingAndWritingOutsideWorkspace() async throws {
        try await requireSandbox()
        let outside = try makeFixture()
        defer { try? FileManager.default.removeItem(at: outside) }
        let secret = outside.appendingPathComponent("synthetic-secret.txt")
        try "synthetic-private-value".write(to: secret, atomically: true, encoding: .utf8)
        let target = outside.appendingPathComponent("must-not-exist.txt")
        let code = """
        denied_read = False
        denied_write = False
        denied_project_read = False
        try:
            open(\(pythonString(secret.path))).read()
        except PermissionError:
            denied_read = True
        try:
            open(\(pythonString(target.path)), 'w').write('not allowed')
        except PermissionError:
            denied_write = True
        try:
            open(\(pythonString(#filePath))).read()
        except PermissionError:
            denied_project_read = True
        """
        let result = try await PythonRunner().run(code: code, tests: "assert denied_read\nassert denied_write\nassert denied_project_read", pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertEqual(try String(contentsOf: secret, encoding: .utf8), "synthetic-private-value")
    }

    func testSandboxDeniesNetwork() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: """
        import socket
        denied = False
        try:
            connection = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            connection.sendto(b'synthetic-test', ('127.0.0.1', 9))
        except OSError as error:
            denied = error.errno in (1, 13)
        """, tests: "assert denied", pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
    }

    func testSandboxDeniesForkAndSubprocesses() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: """
        import os
        import subprocess
        import sys
        denied_fork = False
        try:
            child = os.fork()
            if child == 0:
                os._exit(0)
            os.waitpid(child, 0)
        except PermissionError:
            denied_fork = True
        denied_spawn = False
        try:
            subprocess.run([sys.executable, '-I', '-B', '-c', 'pass'], check=True, timeout=1)
        except PermissionError:
            denied_spawn = True
        denied_exec = False
        try:
            os.execv('/bin/echo', ['echo', 'must-not-execute'])
        except PermissionError:
            denied_exec = True
        """, tests: "assert denied_fork\nassert denied_spawn\nassert denied_exec", pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
    }

    func testWorkspaceIsWritableIsolatedAndCleanedWithoutFollowingSymlinks() async throws {
        try await requireSandbox()
        let outside = try makeFixture()
        defer { try? FileManager.default.removeItem(at: outside) }
        let fixture = outside.appendingPathComponent("keep.txt")
        try "keep".write(to: fixture, atomically: true, encoding: .utf8)
        let code = """
        import os
        import tempfile
        print(os.getcwd())
        with open('local.txt', 'w') as file:
            file.write('local')
        with tempfile.TemporaryFile() as file:
            file.write(b'temporary')
        os.symlink(\(pythonString(fixture.path)), 'outside-link')
        """
        let runner = PythonRunner()
        let first = try await runner.run(code: code, pythonPath: pythonPath)
        let second = try await runner.run(code: "import os\nprint(os.getcwd())", pythonPath: pythonPath)
        XCTAssertTrue(first.passed, first.output)
        XCTAssertTrue(second.passed, second.output)
        let firstPath = first.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondPath = second.output.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertNotEqual(firstPath, secondPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondPath))
        XCTAssertEqual(try String(contentsOf: fixture, encoding: .utf8), "keep")
    }

    func testEnvironmentAndInterpreterStartupAreIsolated() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: """
        import os
        import sys
        allowed = {'PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_CTYPE', '__CF_USER_TEXT_ENCODING'}
        unexpected = set(os.environ) - allowed
        isolated = sys.flags.isolated
        no_bytecode = sys.flags.dont_write_bytecode
        no_site = sys.flags.no_site
        """, tests: "assert not unexpected, unexpected\nassert isolated == 1\nassert no_bytecode == 1\nassert no_site == 1", pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
    }

    func testResourceSafeguardsAreConfiguredBeforeLearnerCode() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: """
        import resource
        file_limit = resource.getrlimit(resource.RLIMIT_FSIZE)
        core_limit = resource.getrlimit(resource.RLIMIT_CORE)
        descriptor_limit = resource.getrlimit(resource.RLIMIT_NOFILE)
        """, tests: """
        assert file_limit[0] == file_limit[1]
        assert 0 <= file_limit[1] <= 8 * 1024 * 1024
        assert core_limit == (0, 0)
        assert descriptor_limit[0] == descriptor_limit[1]
        assert 0 < descriptor_limit[1] <= 64
        """, pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
    }

    func testFileGrowthBeyondEightMiBIsRejected() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: """
        import errno
        import os
        import resource
        chunk = b'x' * (64 * 1024)
        try:
            with open('bounded.bin', 'wb', buffering=0) as file:
                for _ in range(9 * 1024 * 1024 // len(chunk)):
                    file.write(chunk)
        except OSError as error:
            assert error.errno == errno.EFBIG
            assert os.path.getsize('bounded.bin') <= resource.getrlimit(resource.RLIMIT_FSIZE)[0]
            assert os.path.getsize('bounded.bin') < 9 * 1024 * 1024
            print('file-growth-rejected')
            raise
        """, tests: "assert True", pythonPath: pythonPath)
        XCTAssertFalse(result.passed, result.output)
        XCTAssertNotEqual(result.exitCode, 0, result.output)
        XCTAssertTrue(result.output.contains("file-growth-rejected"), result.output)
        XCTAssertTrue(result.output.contains("File too large"), result.output)
        XCTAssertFalse(result.timedOut)
    }

    func testDescriptorAccumulationIsBounded() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: """
        import errno
        handles = []
        rejected = False
        try:
            for _ in range(128):
                handles.append(open('descriptor.txt', 'wb'))
        except OSError as error:
            rejected = error.errno == errno.EMFILE
        finally:
            for handle in handles:
                handle.close()
        """, tests: "assert rejected\nassert len(handles) < 64", pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
    }

    func testLearnerAndTestsAreReadOnly() async throws {
        try await requireSandbox()
        let result = try await PythonRunner().run(code: """
        import pathlib
        denied = 0
        for target in [pathlib.Path(__file__), pathlib.Path(__file__).with_name('tests.py')]:
            try:
                target.write_text('pass')
            except PermissionError:
                denied += 1
        """, tests: "assert denied == 2", pythonPath: pythonPath)
        XCTAssertTrue(result.passed, result.output)
    }

    func testMissingExecutableAndShimAreRejected() async throws {
        let runner = PythonRunner()
        for path in ["/does-not-exist/python3", "python3", "/tmp/shims/python3"] {
            do {
                _ = try await runner.run(code: "pass", pythonPath: path)
                XCTFail("Expected invalid interpreter error for \(path)")
            } catch PythonRunnerError.invalidInterpreter {
            } catch PythonRunnerError.sandboxUnavailable {
                throw XCTSkip("sandbox-exec unavailable")
            }
        }
        let directory = try makeFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = directory.appendingPathComponent("python3")
        try "#!/bin/sh\nexit 0\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        do {
            _ = try await runner.run(code: "pass", pythonPath: script.path)
            XCTFail("A shell wrapper must not be accepted as a Python binary")
        } catch PythonRunnerError.invalidInterpreter {
        }
    }

    func testInterpreterSymlinkIsResolved() async throws {
        try await requireSandbox()
        let directory = try makeFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let alias = directory.appendingPathComponent("selected-python")
        try FileManager.default.createSymbolicLink(atPath: alias.path, withDestinationPath: pythonPath)
        let result = try await PythonRunner().run(code: "print('resolved')", pythonPath: alias.path)
        XCTAssertTrue(result.passed, result.output)
        XCTAssertEqual(result.output, "resolved\n")
    }

    func testInvalidTimeoutIsRejected() async throws {
        for timeout in [0.0, -1.0, Double.infinity, Double.nan] {
            do {
                _ = try await PythonRunner().run(code: "pass", pythonPath: pythonPath, timeout: timeout)
                XCTFail("Expected invalid timeout")
            } catch PythonRunnerError.invalidTimeout {
            }
        }
    }

    private func makeFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PythonTeacherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory.resolvingSymlinksInPath()
    }

    private func pythonString(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private enum SandboxProbeFailure: Error {
        case failed(String)
    }
}
