import Foundation
import PythonTeacherCore
import XCTest
@testable import PythonTeacherApp

private final class DebugGenerationURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let data = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class GeneratedDebugValidationTests: XCTestCase {
    private var directory: URL!
    private var model: AppModel!

    @MainActor
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("GeneratedDebugValidationTests-\(UUID().uuidString)")
    }

    @MainActor
    override func tearDown() async throws {
        model?.cancelWork()
        model?.flushSave()
        model = nil
        DebugGenerationURLProtocol.handler = nil
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    func testStarterFailurePredicateRequiresCheckOriginAssertionOnlyForDebug() {
        func result(_ type: String? = "AssertionError", origin: RunDiagnostic.Origin = .checks,
                    exitCode: Int32 = 1, passed: Bool = false, timedOut: Bool = false, cancelled: Bool = false,
                    output: String = "Synthetic failure") -> RunResult {
            RunResult(output: output, exitCode: exitCode, passed: passed, timedOut: timedOut, cancelled: cancelled,
                diagnostic: type.map { RunDiagnostic(exceptionType: $0, message: "Synthetic", origin: origin, frames: []) })
        }
        let cases: [(String, RunResult, Bool, Bool)] = [
            ("check assertion", result(), true, true),
            ("syntax error", result("SyntaxError", origin: .learner), false, true),
            ("undefined name", result("NameError", origin: .learner), false, true),
            ("function lookup", result("KeyError", origin: .learner), false, true),
            ("function division", result("ZeroDivisionError", origin: .learner), false, true),
            ("learner assertion", result(origin: .learner), false, true),
            ("runner assertion", result(origin: .runner), false, true),
            ("check runtime error", result("KeyError"), false, true),
            ("missing asserts", result("RuntimeError", origin: .runner, output: "Tests must contain executable assert statements"), false, true),
            ("skipped asserts", result("RuntimeError", origin: .runner, output: "Tests skipped assertions"), false, true),
            ("infrastructure", result(nil, output: "Sandbox setup failed"), false, true),
            ("raw assertion is not evidence", result(nil, output: "AssertionError"), false, true),
            ("successful exit without completion", result(exitCode: 0), false, true),
            ("setup sentinel with misleading diagnostic", result(exitCode: -1), false, true),
            ("already passing", result(exitCode: 0, passed: true), false, false),
            ("passed flag cannot be overridden", result(passed: true), false, false),
            ("timeout cannot be overridden", result(timedOut: true), false, false),
            ("cancellation cannot be overridden", result(cancelled: true), false, false)
        ]
        for (name, run, debugAccepted, otherAccepted) in cases {
            XCTAssertEqual(PracticeStyle.debug.acceptsStarterFailure(run), debugAccepted, name)
            for style in [PracticeStyle.write, .complete] {
                XCTAssertEqual(style.acceptsStarterFailure(run), otherAccepted, "\(style): \(name)")
            }
        }
    }

    @MainActor
    func testDebugAcceptsRunnableWrongResultAndPreservesOriginalDraft() async throws {
        var requests = 0
        let session = try generationSession(starter: "total = 1 + 1", onRequest: { requests += 1 })
        defer { session.invalidateAndCancel() }
        installModel(session: session)
        model.code = "saved_draft = 17"
        let originalKey = model.draftKey
        let options = PracticeGenerationOptions(scope: .selectedExercise, difficulty: .easier, style: .debug, scenario: "Synthetic seats")
        model.generatePractice(options: options)
        try await waitForGeneration()
        let generated = try XCTUnwrap(model.progress.generatedExercises[model.chapter.id]?.last, model.feedback)
        XCTAssertEqual(model.exercise, generated)
        XCTAssertEqual(model.code, "total = 1 + 1")
        XCTAssertEqual(model.progress.drafts[originalKey], "saved_draft = 17")
        XCTAssertNil(generated.checkPlan)
        XCTAssertNil(generated.expectedStarterError)
        XCTAssertNil(model.rejectedPractice)
        XCTAssertEqual(model.generationState, .ready(chapterID: model.chapter.id, exerciseID: generated.id, title: generated.title))
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(model.requestCount, 1)
        XCTAssertTrue(model.progress.attempts.isEmpty)
        XCTAssertEqual(try model.store.load().generatedExercises[model.chapter.id]?.last, generated)
    }

    @MainActor
    func testDebugRejectsSyntaxErrorWithPassingReference() async throws {
        try await assertDebugRejection(starter: "total = (", diagnostic: "SyntaxError")
    }

    @MainActor
    func testDebugRejectsNameErrorWithPassingReference() async throws {
        try await assertDebugRejection(starter: "total = missing_total", diagnostic: "NameError")
    }

    @MainActor
    func testDebugRejectsTestTriggeredFunctionExceptionsWithPassingReferences() async throws {
        for (expression, diagnostic) in [("{}['missing']", "KeyError"), ("3 / 0", "ZeroDivisionError")] {
            try await assertDebugRejection(starter: "def total():\n    return \(expression)\n",
                reference: "def total():\n    return 3\n", tests: "assert total() == 3", diagnostic: diagnostic)
        }
    }

    @MainActor
    func testDebugRejectsLearnerOwnedAssertionsWithPassingReferences() async throws {
        try await assertDebugRejection(starter: "total = 0\nassert total == 3", diagnostic: "AssertionError")
        try await assertDebugRejection(starter: "def total():\n    assert False\n    return 3\n",
            reference: "def total():\n    return 3\n", tests: "assert total() == 3", diagnostic: "AssertionError")
        try await assertDebugRejection(starter: "raise AssertionError('learner-owned')", diagnostic: "AssertionError")
    }

    @MainActor
    func testDebugRejectsSkippedStarterAssertionWithPassingReference() async throws {
        try await assertDebugRejection(starter: "total = 0", tests: "if total == 3:\n    assert total == 3\n",
            diagnostic: "Tests skipped assertions")
    }

    @MainActor
    func testDebugRejectsAlreadyPassingStarterWithPassingReference() async throws {
        try await assertDebugRejection(starter: "total = 3", diagnostic: "starter already passes all checks")
    }

    @MainActor
    func testOtherGenerationStylesStillAcceptRuntimeNameErrorStarters() async throws {
        for style in [PracticeStyle.write, .complete] {
            var requests = 0
            let session = try generationSession(starter: "total = missing_total", onRequest: { requests += 1 })
            defer { session.invalidateAndCancel() }
            installModel(session: session)
            let previousCount = model.progress.generatedExercises[model.chapter.id]?.count ?? 0
            model.generatePractice(options: .init(scope: .selectedExercise, style: style))
            try await waitForGeneration()
            XCTAssertEqual(model.progress.generatedExercises[model.chapter.id]?.count, previousCount + 1, model.feedback)
            XCTAssertEqual(model.exercise.starterCode, "total = missing_total")
            XCTAssertNil(model.rejectedPractice)
            XCTAssertEqual(requests, 1)
            XCTAssertEqual(model.requestCount, 1)
        }
    }

    @MainActor
    func testReviewedSyntaxAndKeyErrorLabsRemainExecutableOutsideGenerationPolicy() async throws {
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: false)
        for (chapterID, exception) in [("basics", "SyntaxError"), ("collections", "KeyError")] {
            let chapter = try XCTUnwrap(Curriculum.chapters.first { $0.id == chapterID })
            let exercise = try XCTUnwrap(chapter.exercises.first { $0.expectedStarterError == exception })
            model.progress.unlockedOverrides.insert(chapterID)
            model.selectChapter(chapterID)
            model.selectMode(.practice)
            model.selectExercise(exercise.id)
            XCTAssertEqual(model.code, exercise.starterCode)
            XCTAssertEqual(model.exercise.expectedStarterError, exception)
            model.runCode(test: true)
            try await waitForRun()
            XCTAssertEqual(model.lastRunDiagnostic?.exceptionType, exception, model.output)
            XCTAssertEqual(model.progress.attempts.last?.testsPassed, false)
            XCTAssertEqual(model.progress.attempts.last?.exerciseID, exercise.id)
            XCTAssertNil(model.rejectedPractice)
            model.code = exercise.referenceSolution
            model.runCode(test: true)
            try await waitForRun()
            XCTAssertEqual(model.progress.attempts.last?.testsPassed, true, model.output)
            XCTAssertEqual(model.progress.attempts.last?.exerciseID, exercise.id)
            XCTAssertEqual(model.requestCount, 0)
        }
    }

    @MainActor
    private func assertDebugRejection(starter: String, reference: String = "total = 3", tests: String = "assert total == 3",
                                      diagnostic: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        var requests = 0
        let session = try generationSession(starter: starter, reference: reference, tests: tests, onRequest: { requests += 1 })
        defer { session.invalidateAndCancel() }
        installModel(session: session)
        var existing = model.chapter.exercises[0]
        existing.id = "generated-existing-synthetic"
        model.progress.generatedExercises[model.chapter.id] = [existing]
        model.code = "unchanged_private_draft = 23"
        model.flushSave()
        let original = model.exercise
        let key = model.draftKey
        let generatedBefore = model.progress.generatedExercises
        let attemptsBefore = model.progress.attempts.map(\.id)
        let referenceRun = try await model.runner.run(code: reference, tests: tests, pythonPath: model.progress.pythonPath)
        XCTAssertTrue(referenceRun.passed, referenceRun.output, file: file, line: line)
        let options = PracticeGenerationOptions(scope: .selectedExercise, difficulty: .easier, style: .debug, scenario: "Synthetic seats")
        model.generatePractice(options: options)
        try await waitForGeneration()
        XCTAssertEqual(model.exercise, original, file: file, line: line)
        XCTAssertEqual(model.code, "unchanged_private_draft = 23", file: file, line: line)
        XCTAssertEqual(model.progress.drafts[key], "unchanged_private_draft = 23", file: file, line: line)
        XCTAssertEqual(model.progress.generatedExercises, generatedBefore, file: file, line: line)
        XCTAssertEqual(model.progress.attempts.map(\.id), attemptsBefore, file: file, line: line)
        let rejected = try XCTUnwrap(model.rejectedPractice, model.feedback, file: file, line: line)
        XCTAssertEqual(rejected.options, options, file: file, line: line)
        XCTAssertEqual(rejected.options.style, .debug, file: file, line: line)
        XCTAssertEqual(rejected.selectedExercise, original, file: file, line: line)
        XCTAssertEqual(rejected.repair.exercise.starterCode, starter, file: file, line: line)
        XCTAssertEqual(rejected.repair.exercise.referenceSolution, reference, file: file, line: line)
        XCTAssertTrue(rejected.repair.validationFeedback.hasPrefix("Starter validation."), rejected.repair.validationFeedback, file: file, line: line)
        XCTAssertTrue(rejected.repair.validationFeedback.contains(diagnostic), rejected.repair.validationFeedback, file: file, line: line)
        XCTAssertTrue(rejected.repair.validationFeedback.contains("checks-origin AssertionError"), file: file, line: line)
        XCTAssertTrue(model.notice?.contains("Generated starter rejected") == true, model.feedback, file: file, line: line)
        XCTAssertTrue(model.canRepairGeneratedPractice, file: file, line: line)
        XCTAssertFalse(rejected.report.contains("unchanged_private_draft"), file: file, line: line)
        XCTAssertFalse(rejected.report.contains("test-not-a-real-key"), file: file, line: line)
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(requests, 1, file: file, line: line)
        XCTAssertEqual(model.requestCount, 1, file: file, line: line)
        model.flushSave()
        let saved = try model.store.load()
        XCTAssertEqual(saved.generatedExercises, generatedBefore, file: file, line: line)
        XCTAssertEqual(saved.drafts[key], "unchanged_private_draft = 23", file: file, line: line)
    }

    @MainActor
    private func installModel(session: URLSession) {
        model?.flushSave()
        model = AppModel(store: ProgressStore(directory: directory), cloudConsent: true) {
            TeacherClient(apiKey: "test-not-a-real-key", model: "test-model", session: session)
        }
        model.selectMode(.practice)
        model.selectExercise("basics-total")
    }

    @MainActor
    private func waitForGeneration() async throws {
        let deadline = Date().addingTimeInterval(15)
        while model.teacherBusy && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(model.teacherBusy, "Generation exceeded test deadline")
    }

    @MainActor
    private func waitForRun() async throws {
        let deadline = Date().addingTimeInterval(15)
        while model.running && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(model.running, "Reviewed lab execution exceeded test deadline")
    }

    private func generationSession(starter: String, reference: String = "total = 3", tests: String = "assert total == 3",
                                   onRequest: @escaping () -> Void) throws -> URLSession {
        let sections = ["Goal": "Repair a synthetic total.", "Starting code": "The total is incorrect.",
            "Your task": "1. Make total equal 3.", "Expected result": "total is 3.", "Check": "Check solution inspects total."]
        let payload: [String: Any] = ["title": "Synthetic Debug total", "instructions": sections,
            "starterCode": starter, "referenceSolution": reference, "testCode": tests,
            "hints": ["Trace the result.", "Compare with three.", "Check the calculation."],
            "coverage": ["selected-exercise": "Step 1: repair total, then check it."]]
        let text = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
        let response: [String: Any] = ["status": "completed", "output": [["type": "message", "content": [["type": "output_text", "text": text]]]]]
        let event: [String: Any] = ["type": "response.completed", "response": response]
        let data = Data("data: ".utf8) + (try JSONSerialization.data(withJSONObject: event)) + Data("\n\n".utf8)
        DebugGenerationURLProtocol.handler = { _ in
            onRequest()
            return data
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.protocolClasses = [DebugGenerationURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
