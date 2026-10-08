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
