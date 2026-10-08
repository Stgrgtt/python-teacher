import Foundation
import Darwin

public struct RunDiagnostic: Codable, Equatable, Sendable {
    public enum Origin: String, Codable, Sendable {
        case learner, checks, runner
    }

    public struct Frame: Codable, Equatable, Sendable {
        public let line: Int
        public let function: String

        public init(line: Int, function: String) {
            self.line = line
            self.function = function
        }
    }

    public let exceptionType: String
    public let message: String
    public let origin: Origin
    public let frames: [Frame]
    public var learnerLine: Int? { frames.last?.line }

    public init(exceptionType: String, message: String, origin: Origin, frames: [Frame]) {
        self.exceptionType = exceptionType
        self.message = message
        self.origin = origin
        self.frames = frames
    }
}

public struct RunResult: Sendable {
    public let output: String
    public let exitCode: Int32
    public let passed: Bool
    public let timedOut: Bool
    public let cancelled: Bool
    public let diagnostic: RunDiagnostic?
    public let checkOutcomes: [CheckOutcome]

    public init(output: String, exitCode: Int32, passed: Bool, timedOut: Bool, cancelled: Bool, diagnostic: RunDiagnostic? = nil, checkOutcomes: [CheckOutcome] = []) {
        self.output = output
        self.exitCode = exitCode
        self.passed = passed
        self.timedOut = timedOut
        self.cancelled = cancelled
        self.diagnostic = diagnostic
        self.checkOutcomes = checkOutcomes
    }
}

public enum PythonRunnerError: LocalizedError, Sendable {
    case invalidInterpreter(String)
    case sandboxUnavailable
    case invalidTimeout
    case interpreterDiscovery(String)
    case effortAnalysisFailed

    public var errorDescription: String? {
        switch self {
        case .invalidInterpreter(let path):
            return "Choose an absolute path to a real Python executable, not a shell script or pyenv shim: \(path)"
        case .sandboxUnavailable:
            return "The macOS sandbox is unavailable. Python execution is disabled; there is no unrestricted fallback."
        case .invalidTimeout:
            return "The execution timeout must be a positive, finite number of seconds."
        case .interpreterDiscovery(let detail):
            return "Apple's Python could not be located. Install Command Line Tools or select an actual Python binary. \(detail)"
        case .effortAnalysisFailed:
            return "Exercise workload could not be analyzed in restricted Python. Existing progress is unchanged. Check the interpreter and the exercise's Python syntax before retrying the XP update."
        }
    }
}

public final class PythonRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var active: [UUID: RunControl] = [:]

    public init() {}

    public func cancel() {
        let controls = lock.withLock { Array(active.values) }
        controls.forEach { $0.stop(cancelled: true) }
    }

    public func run(code: String, tests: String? = nil, pythonPath: String, timeout: TimeInterval = 8) async throws -> RunResult {
        let id = UUID()
        let control = RunControl()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock { active[id] = control }
                if Task.isCancelled { control.stop(cancelled: true) }
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    let result = Result {
                        try execute(code: code, tests: tests, pythonPath: pythonPath, timeout: timeout, control: control)
                    }
                    _ = lock.withLock { active.removeValue(forKey: id) }
                    continuation.resume(with: result)
                }
            }
        } onCancel: {
            control.stop(cancelled: true)
        }
    }

    public func check(code: String, exercise: Exercise, pythonPath: String, timeout: TimeInterval = 8) async throws -> RunResult {
        guard let plan = exercise.checkPlan else {
            return try await run(code: code, tests: exercise.testCode, pythonPath: pythonPath, timeout: timeout)
        }
        try plan.validate()
        return try await runPlan(code: code, plan: plan, overrides: nil, tests: exercise.testCode, pythonPath: pythonPath, timeout: timeout)
    }

    public func experiment(code: String, plan: AuthoredCheckPlan, inputs: [String: String], pythonPath: String, timeout: TimeInterval = 8) async throws -> RunResult {
        try plan.validate(overrides: inputs)
        return try await runPlan(code: code, plan: plan, overrides: inputs, tests: nil, pythonPath: pythonPath, timeout: timeout)
    }

    private func runPlan(code: String, plan: AuthoredCheckPlan, overrides: [String: String]?, tests: String?, pythonPath: String, timeout: TimeInterval) async throws -> RunResult {
        guard timeout.isFinite, timeout > 0 else { throw PythonRunnerError.invalidTimeout }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        let id = UUID()
        let control = RunControl()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock { active[id] = control }
                if Task.isCancelled { control.stop(cancelled: true) }
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    let result = Result {
                        try executePlan(code: code, plan: plan, overrides: overrides, tests: tests, pythonPath: pythonPath,
                            deadline: deadline, control: control)
                    }
                    _ = lock.withLock { active.removeValue(forKey: id) }
                    continuation.resume(with: result)
                }
            }
        } onCancel: {
            control.stop(cancelled: true)
        }
    }

    private func executePlan(code: String, plan: AuthoredCheckPlan, overrides: [String: String]?, tests: String?, pythonPath: String,
                             deadline: TimeInterval, control: RunControl) throws -> RunResult {
        let deadlineTask = DispatchWorkItem { control.stop(cancelled: false, timedOut: true) }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + max(0, deadline - ProcessInfo.processInfo.systemUptime), execute: deadlineTask)
        defer { deadlineTask.cancel() }
        var output = BoundedPlanOutput()
        var outcomes: [CheckOutcome] = []
        func remaining() -> TimeInterval {
            let value = deadline - ProcessInfo.processInfo.systemUptime
            if value <= 0 { control.stop(cancelled: false, timedOut: true) }
            return max(0.001, value)
        }
        func finish(_ result: RunResult, suffix: String = "") -> RunResult {
            output.append(result.output)
            output.append(suffix)
            return RunResult(output: output.text, exitCode: result.exitCode, passed: result.passed,
                timedOut: result.timedOut, cancelled: result.cancelled, diagnostic: result.diagnostic, checkOutcomes: outcomes)
        }
        if let overrides {
            let request = FixtureRequest(plan: plan, overrides: overrides, check: nil)
            output.append(request.header)
            let result = try execute(code: code, tests: nil, pythonPath: pythonPath, timeout: remaining(), control: control,
                fixture: request, totalDeadline: deadline)
            return finish(result)
        }
        for (index, check) in plan.checks.enumerated() {
            let request = FixtureRequest(plan: plan, overrides: check.inputs, check: check)
            output.append(request.header)
            let result: RunResult
            do {
                result = try execute(code: code, tests: nil, pythonPath: pythonPath, timeout: remaining(), control: control,
                    fixture: request, totalDeadline: deadline)
            } catch {
                result = RunResult(output: "[Named check could not start: \(error.localizedDescription)]\n", exitCode: -1,
                    passed: false, timedOut: control.flags.timedOut, cancelled: control.flags.cancelled)
            }
            outcomes.append(result.checkOutcomes.first ?? CheckOutcome(id: check.id, title: check.title, status: .failed,
                detail: result.timedOut ? "The total check deadline was reached." : result.cancelled ? "Execution was cancelled." : "The named check could not complete. See the original output."))
            if !result.passed {
                outcomes.append(contentsOf: plan.checks.dropFirst(index + 1).map {
                    CheckOutcome(id: $0.id, title: $0.title, status: .notReached, detail: "An earlier case did not pass.")
                })
                return finish(result)
            }
            output.append(result.output)
        }
        output.append("\n[Original exercise checks on the saved source]\n")
        let legacy: RunResult
        do {
            legacy = try execute(code: code, tests: tests, pythonPath: pythonPath, timeout: remaining(), control: control,
                totalDeadline: deadline)
        } catch {
            legacy = RunResult(output: "[Original checks could not start: \(error.localizedDescription)]\n", exitCode: -1,
                passed: false, timedOut: control.flags.timedOut, cancelled: control.flags.cancelled)
        }
        return finish(legacy, suffix: legacy.passed ? "" : "\n[Original exercise checks did not pass. Named cases alone cannot complete this exercise.]\n")
    }

    public func analyzeEffort(exercises: [Exercise], pythonPath: String) async throws -> [ExerciseEffort] {
        guard !exercises.isEmpty else { return [] }
        let payload = try JSONSerialization.data(withJSONObject: exercises.map {
            ["starter": $0.starterCode, "reference": $0.referenceSolution]
        }).base64EncodedString()
        let code = """
        import ast
        import base64
        import json
        import math

        def signature(node):
            return ast.dump(node, include_attributes=False)

        def analyze(item):
            starter = ast.parse(item['starter'])
            reference = ast.parse(item['reference'])
            supplied = {signature(node) for node in ast.walk(starter) if isinstance(node, ast.stmt)}
            functions = (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)
            work_types = (ast.Assign, ast.AnnAssign, ast.AugAssign, ast.Return, ast.Raise)
            controls = (ast.If, ast.For, ast.AsyncFor, ast.While, ast.Try, ast.With, ast.AsyncWith, ast.IfExp)
            bindings = set()
            function_units = 0
            max_depth = 0
            has_reasoning = False
            has_errors = False

            def visit(node, depth=0, in_function=False):
                nonlocal function_units, max_depth, has_reasoning, has_errors
                changed = signature(node) not in supplied
                if isinstance(node, functions) and not in_function:
                    if not changed:
                        return
                    work = [child for child in ast.walk(node) if isinstance(child, work_types) and signature(child) not in supplied]
                    function_units += max(1, math.ceil(len(work) / 2))
                    in_function = True
                if isinstance(node, controls):
                    depth += 1
                    max_depth = max(max_depth, depth)
                if isinstance(node, (ast.BinOp, ast.BoolOp, ast.Compare, ast.Call, ast.Subscript)):
                    has_reasoning = True
                if isinstance(node, (ast.Raise, ast.Try)):
                    has_errors = True
                if not in_function and changed and isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
                    targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                    for target in targets:
                        bindings.add(signature(target))
                for child in ast.iter_child_nodes(node):
                    visit(child, depth, in_function)

            for node in reference.body:
                if signature(node) not in supplied:
                    visit(node)
            difficulty = 'Harder' if max_depth >= 2 or has_errors else 'Similar' if has_reasoning or max_depth else 'Easier'
            return {'difficulty': difficulty, 'scopeUnits': min(1000, max(1, len(bindings) + function_units)), 'estimated': True}

        items = json.loads(base64.b64decode('\(payload)'))
        print(json.dumps([analyze(item) for item in items]))
        """
        let result = try await run(code: code, pythonPath: pythonPath)
        try Task.checkCancellation()
        guard result.passed, !result.cancelled,
              let ratings = try? JSONDecoder().decode([ExerciseEffort].self, from: Data(result.output.utf8)),
              ratings.count == exercises.count else { throw PythonRunnerError.effortAnalysisFailed }
        return zip(exercises, ratings).map { exercise, rating in
            ExerciseEffort(difficulty: exercise.effort?.difficulty ?? rating.difficulty,
                scopeUnits: max(exercise.effort?.scopeUnits ?? 1, rating.scopeUnits), estimated: true)
        }
    }

    private func execute(code: String, tests: String?, pythonPath: String, timeout: TimeInterval, control: RunControl,
                         fixture: FixtureRequest? = nil, totalDeadline: TimeInterval? = nil) throws -> RunResult {
        guard timeout.isFinite, timeout > 0 else { throw PythonRunnerError.invalidTimeout }
        if totalDeadline != nil, control.flags.cancelled || control.flags.timedOut { return stoppedResult(control) }
        let manager = FileManager.default
        guard manager.isExecutableFile(atPath: "/usr/bin/sandbox-exec") else {
            throw PythonRunnerError.sandboxUnavailable
        }
        var root = manager.temporaryDirectory.appendingPathComponent("PythonTeacher-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        if let resolved = realpath(root.path, nil) {
            root = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
            free(resolved)
        } else {
            try? manager.removeItem(at: root)
            throw POSIXError(.EIO)
        }
        defer { try? manager.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        let temporary = workspace.appendingPathComponent("tmp", isDirectory: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let learner = root.appendingPathComponent("learner.py")
        let testFile = root.appendingPathComponent("tests.py")
        try code.write(to: learner, atomically: true, encoding: .utf8)
        if let tests { try tests.write(to: testFile, atomically: true, encoding: .utf8) }
        let environment = [
            "PATH": "/usr/bin:/bin", "HOME": workspace.path, "TMPDIR": temporary.path + "/",
            "LANG": "en_US.UTF-8", "LC_CTYPE": "UTF-8"
        ]
        if control.flags.cancelled || control.flags.timedOut { return stoppedResult(control) }
        let interpreter = try resolveInterpreter(pythonPath, environment: environment, control: control)
        if control.flags.cancelled || control.flags.timedOut { return stoppedResult(control) }
        let token = "\n__PYTHON_TEACHER_COMPLETE_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))__\n"
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let diagnosticStart = "\n__PYTHON_TEACHER_DIAGNOSTIC_\(nonce)_BEGIN__"
        let diagnosticEnd = "__PYTHON_TEACHER_DIAGNOSTIC_\(nonce)_END__\n"
        let reportStart = "\n__PYTHON_TEACHER_CASE_\(nonce)_BEGIN__"
        let reportEnd = "__PYTHON_TEACHER_CASE_\(nonce)_END__\n"
        var learnerLineCount = 1
        var previousByte: UInt8 = 0
        for byte in code.utf8 {
            if byte == 13 || (byte == 10 && previousByte != 13) {
                learnerLineCount = min(1_000_000, learnerLineCount + 1)
            }
            previousByte = byte
        }
        let script = harness(learner: learner.path, tests: tests == nil ? nil : testFile.path, token: token,
            diagnosticStart: diagnosticStart, diagnosticEnd: diagnosticEnd, learnerLineCount: learnerLineCount,
            fixture: fixture, reportStart: reportStart, reportEnd: reportEnd)
        let input = Pipe()
        let output = Pipe()
        defer {
            try? input.fileHandleForWriting.close()
            try? input.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        process.arguments = ["-p", sandboxProfile(interpreter: interpreter, root: root, workspace: workspace), interpreter.path, "-I", "-B", "-S", "-u", "-"]
        process.environment = environment
        process.currentDirectoryURL = workspace
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        guard try control.launch(process) else { return stoppedResult(control) }
        defer { control.clear(process) }
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        var inputFailure: String?
        do {
            try input.fileHandleForWriting.write(contentsOf: Data(script.utf8))
            try input.fileHandleForWriting.close()
        } catch {
            inputFailure = "[Could not deliver the sandboxed Python harness: \(error.localizedDescription)]\n"
            control.stop(cancelled: false)
            try? input.fileHandleForWriting.close()
        }
        let descriptor = output.fileHandleForReading.fileDescriptor
        let existingFlags = fcntl(descriptor, F_GETFL)
        guard existingFlags >= 0, fcntl(descriptor, F_SETFL, existingFlags | O_NONBLOCK) >= 0 else {
            control.stop(cancelled: false)
            process.waitUntilExit()
            throw POSIXError(.EIO)
        }
        let deadline = min(totalDeadline ?? .infinity, ProcessInfo.processInfo.systemUptime + timeout)
        var capture = OutputCapture(marker: Data(token.utf8), diagnosticStart: Data(diagnosticStart.utf8),
            diagnosticEnd: Data(diagnosticEnd.utf8), learnerLineCount: learnerLineCount,
            reportStart: fixture == nil ? nil : Data(reportStart.utf8), reportEnd: fixture == nil ? nil : Data(reportEnd.utf8))
        var bytes = [UInt8](repeating: 0, count: 8192)
        while true {
            for _ in 0..<16 {
                let count = Darwin.read(descriptor, &bytes, bytes.count)
                if count > 0 { capture.consume(Data(bytes.prefix(count))) }
                else { break }
            }
            if !process.isRunning {
                while true {
                    let count = Darwin.read(descriptor, &bytes, bytes.count)
                    guard count > 0 else { break }
                    capture.consume(Data(bytes.prefix(count)))
                }
                break
            }
            if ProcessInfo.processInfo.systemUptime >= deadline { control.stop(cancelled: false, timedOut: true) }
            var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
            _ = poll(&pollDescriptor, 1, 25)
            if pollDescriptor.revents & Int16(POLLHUP) != 0 { Thread.sleep(forTimeInterval: 0.025) }
        }
        process.waitUntilExit()
        capture.finish()
        let flags = control.flags
        var text = capture.text
        if let inputFailure { text += "\n" + inputFailure }
        var passed = inputFailure == nil && process.terminationStatus == 0 && capture.completed && !flags.cancelled && !flags.timedOut
        var outcomes: [CheckOutcome] = []
        if let fixture {
            let report = capture.reportInvalid ? nil : capture.report.flatMap { fixture.validatedReport($0) }
            let completedNormally = passed
            passed = passed && report != nil && (fixture.check == nil || report?.matched == true)
            if let check = fixture.check {
                let detail: String?
                if flags.timedOut { detail = "The total check deadline was reached." }
                else if flags.cancelled { detail = "Execution was cancelled." }
                else if !completedNormally {
                    detail = capture.diagnostic.map { "\($0.exceptionType): \($0.message)" }
                        ?? "The case did not complete normally. See the original output."
                }
                else if report == nil { detail = "The case report was missing, malformed, or incomplete." }
                else if report?.matched != true { detail = "The observed value did not match the expected value and type." }
                else { detail = nil }
                outcomes = [CheckOutcome(id: check.id, title: check.title, status: passed ? .passed : .failed,
                    expected: report?.expected, actual: report?.observations.first?.value, detail: detail)]
                if let report {
                    text += "\nExpected: \(report.expected ?? check.expectedLiteral)\nActual: \(report.observations.first?.value ?? "[missing]")\n"
                }
                if let detail { text += "[\(detail)]\n" }
            } else if let report {
                text += "\n[Observed values — not graded]\n"
                for observation in report.observations { text += "\(observation.target) = \(observation.value)\n" }
            } else {
                text += "\n[The experiment report was missing, malformed, or incomplete.]\n"
            }
        }
        if flags.timedOut { text += "\n[Execution timed out.]\n" }
        else if flags.cancelled { text += "\n[Execution cancelled.]\n" }
        else if process.terminationStatus == 0 && !capture.completed {
            text += "\n[Execution ended before the runner completed; tests did not pass.]\n"
        }
        if text.contains("sandbox-exec:") && !capture.completed {
            text += "\n[Sandboxed execution failed. No unrestricted fallback was attempted.]\n"
        }
        return RunResult(output: text, exitCode: process.terminationStatus, passed: passed, timedOut: flags.timedOut,
            cancelled: flags.cancelled, diagnostic: passed || flags.timedOut || flags.cancelled ? nil : capture.diagnostic,
            checkOutcomes: outcomes)
    }

    private func stoppedResult(_ control: RunControl) -> RunResult {
        let flags = control.flags
        return RunResult(output: flags.timedOut ? "[Execution timed out.]\n" : "[Execution cancelled.]\n", exitCode: -1,
            passed: false, timedOut: flags.timedOut, cancelled: flags.cancelled)
    }

    private func resolveInterpreter(_ path: String, environment: [String: String], control: RunControl) throws -> URL {
        guard path.hasPrefix("/"), !path.split(separator: "/").contains("shims") else {
            throw PythonRunnerError.invalidInterpreter(path)
        }
        var candidate = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        if candidate.path == "/usr/bin/python3" {
            let discovery = Process()
            let output = Pipe()
            discovery.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            discovery.arguments = ["--find", "python3"]
            discovery.environment = environment
            discovery.standardOutput = output
            discovery.standardError = FileHandle.nullDevice
            discovery.standardInput = FileHandle.nullDevice
            defer {
                try? output.fileHandleForReading.close()
                try? output.fileHandleForWriting.close()
                control.clear(discovery)
            }
            guard try control.launch(discovery) else { return candidate }
            let deadline = ProcessInfo.processInfo.systemUptime + 3
            while discovery.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if discovery.isRunning { control.stop(cancelled: false) }
            discovery.waitUntilExit()
            try? output.fileHandleForWriting.close()
            if control.flags.cancelled || control.flags.timedOut { return candidate }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let found = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard discovery.terminationStatus == 0, found.hasPrefix("/"), found != "/usr/bin/python3" else {
                throw PythonRunnerError.interpreterDiscovery("xcrun did not resolve a developer-tools interpreter.")
            }
            candidate = URL(fileURLWithPath: found).resolvingSymlinksInPath()
        }
        let components = candidate.pathComponents
        if let versionsIndex = components.firstIndex(of: "Versions"), components.prefix(versionsIndex).contains(where: { $0.hasSuffix(".framework") }), components.count > versionsIndex + 1 {
            let version = URL(fileURLWithPath: NSString.path(withComponents: Array(components.prefix(versionsIndex + 2))))
            let binary = version.appendingPathComponent("Resources/Python.app/Contents/MacOS/Python")
            if FileManager.default.isExecutableFile(atPath: binary.path) { candidate = binary.resolvingSymlinksInPath() }
        } else {
            let prefix = candidate.deletingLastPathComponent().deletingLastPathComponent()
            let developer = prefix.deletingLastPathComponent()
            if prefix.lastPathComponent == "usr", developer.path.hasPrefix("/Applications/") || developer.path.hasPrefix("/Library/Developer/") {
                for framework in ["Python3.framework", "Python.framework"] {
                    let versions = developer.appendingPathComponent("Library/Frameworks/\(framework)/Versions")
                    let version = candidate.lastPathComponent.replacingOccurrences(of: "python", with: "")
                    for name in [version, "Current"] {
                        let binary = versions.appendingPathComponent(name).appendingPathComponent("Resources/Python.app/Contents/MacOS/Python")
                        if FileManager.default.isExecutableFile(atPath: binary.path) {
                            candidate = binary.resolvingSymlinksInPath()
                            break
                        }
                    }
                }
            }
        }
        guard FileManager.default.isExecutableFile(atPath: candidate.path),
              !candidate.pathComponents.contains("shims"),
              let handle = try? FileHandle(forReadingFrom: candidate) else {
            throw PythonRunnerError.invalidInterpreter(path)
        }
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 4) ?? Data()
        let signatures: [[UInt8]] = [[0xcf, 0xfa, 0xed, 0xfe], [0xfe, 0xed, 0xfa, 0xcf], [0xca, 0xfe, 0xba, 0xbe], [0xbe, 0xba, 0xfe, 0xca], [0xca, 0xfe, 0xba, 0xbf], [0xbf, 0xba, 0xfe, 0xca]]
        guard signatures.contains(Array(header)) else { throw PythonRunnerError.invalidInterpreter(path) }
        return candidate
    }

    private func sandboxProfile(interpreter: URL, root: URL, workspace: URL) -> String {
        var directories: Set<String> = ["/System/Library", "/usr/lib", "/usr/share/locale", "/private/var/db/dyld", "/Library/Apple/System/Library"]
        var dependencyAliases = Set<String>()
        let components = interpreter.pathComponents
        if let frameworkIndex = components.firstIndex(where: { $0.hasSuffix(".framework") }) {
            directories.insert(NSString.path(withComponents: Array(components.prefix(frameworkIndex + 1))))
        } else {
            let prefix = interpreter.deletingLastPathComponent().deletingLastPathComponent()
            directories.insert(prefix.appendingPathComponent("lib").resolvingSymlinksInPath().path)
            directories.insert(prefix.appendingPathComponent("Frameworks").resolvingSymlinksInPath().path)
            if prefix.lastPathComponent == "usr" {
                let developer = prefix.deletingLastPathComponent()
                for framework in ["Python3.framework", "Python.framework"] {
                    let url = developer.appendingPathComponent("Library/Frameworks").appendingPathComponent(framework)
                    if FileManager.default.fileExists(atPath: url.path) { directories.insert(url.resolvingSymlinksInPath().path) }
                }
            }
        }
        for base in ["/opt/homebrew/opt", "/usr/local/opt"] {
            for library in ["openssl@3", "xz", "readline", "sqlite", "gdbm", "mpdecimal", "zstd", "bzip2", "gettext", "zlib", "libffi"] {
                let url = URL(fileURLWithPath: base).appendingPathComponent(library).appendingPathComponent("lib")
                if FileManager.default.fileExists(atPath: url.path) {
                    directories.insert(url.resolvingSymlinksInPath().path)
                    dependencyAliases.insert(url.path)
                }
            }
        }
        var profile = """
        (version 1)
        (deny default)
        (allow process-exec (literal \(quoted(interpreter.path))))
        (allow sysctl-read)
        (allow mach-lookup (global-name "com.apple.system.logger"))
        (allow file-read* (literal \(quoted(interpreter.path))))
        (allow file-read* (subpath \(quoted(root.path))))
        (allow file-read* file-write* (subpath \(quoted(workspace.path))))
        (allow file-read* file-write-data (literal "/dev/null"))
        (allow file-read* (literal "/") (literal "/dev/urandom") (literal "/dev/random"))
        """
        for directory in directories.sorted() {
            profile += "\n(allow file-read* (subpath \(quoted(directory))))"
        }
        var ancestors = Set<String>()
        for path in directories.union(dependencyAliases).union([interpreter.path, root.path, "/System/Cryptexes/OS/usr/lib"]) {
            var parent = URL(fileURLWithPath: path).deletingLastPathComponent()
            while parent.path != "/" {
                ancestors.insert(parent.path)
                parent.deleteLastPathComponent()
            }
        }
        ancestors.insert("/")
        for ancestor in ancestors.sorted() {
            profile += "\n(allow file-read-metadata (literal \(quoted(ancestor))))"
        }
        return profile
    }

    private func quoted(_ string: String) -> String {
        "\"" + string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r") + "\""
    }

    private func fixturePreparation(_ request: FixtureRequest, reportStart: String, reportEnd: String) -> String {
        let payload = (try? JSONEncoder().encode(request).base64EncodedString()) ?? ""
        let source = """
        def prepare_fixture():
            import base64
            import math
            import keyword
            from builtins import type, len, repr, str, int, float, bool, bytes, list, tuple, dict, sorted, enumerate, zip, ValueError, RuntimeError
            finite = math.isfinite
            encode_json = json.dumps
            report_write = stderr.write
            request = json.loads(base64.b64decode('\(payload)'))
            check = request.get('check')
            effective = request['effectiveInputs']
            targets = request['targets']
            for name in list(effective) + targets:
                if not name.isidentifier() or keyword.iskeyword(name):
                    raise ValueError('Input and observation targets must be plain variable names: ' + name)
            def snapshot(value, depth=0, budget=None):
                if budget is None:
                    budget = [512, 2048]
                budget[0] -= 1
                if depth > 16 or budget[0] < 0:
                    raise ValueError('Value exceeds the supported size or depth.')
                kind = type(value)
                if value is None:
                    return ('none', None)
                if kind is bool:
                    return ('bool', value)
                if kind is int:
                    if int.bit_length(value) > 4096:
                        raise ValueError('Integer is too large.')
                    return ('int', value)
                if kind is float:
                    if not finite(value):
                        raise ValueError('Only finite floats are supported.')
                    return ('float', 0.0 if value == 0.0 else value)
                if kind is str or kind is bytes:
                    if len(value) > budget[1]:
                        raise ValueError('Text value is too large.')
                    size = len(str.encode(value, 'utf-8', 'replace')) if kind is str else len(value)
                    budget[1] -= size
                    if budget[1] < 0:
                        raise ValueError('Text value is too large.')
                    return ('str' if kind is str else 'bytes', value)
                if kind is list or kind is tuple:
                    if len(value) > budget[0]:
                        raise ValueError('Collection is too large.')
                    return ('list' if kind is list else 'tuple', tuple(snapshot(item, depth + 1, budget) for item in value))
                if kind is dict:
                    if len(value) * 2 > budget[0]:
                        raise ValueError('Dictionary is too large.')
                    pairs = [(snapshot(key, depth + 1, budget), snapshot(item, depth + 1, budget)) for key, item in dict.items(value)]
                    return ('dict', tuple(sorted(pairs, key=repr)))
                raise ValueError('Unsupported value type; only built-in literal values are supported.')
            def display(value):
                kind, item = value
                if kind == 'none':
                    return 'None'
                if kind == 'list' or kind == 'tuple':
                    text = ', '.join(display(child) for child in item)
                    return '[' + text + ']' if kind == 'list' else '(' + text + (',' if len(item) == 1 else '') + ')'
                if kind == 'dict':
                    return '{' + ', '.join(display(key) + ': ' + display(child) for key, child in item) + '}'
                return repr(item)
            def bounded_display(value):
                text = display(value)
                data = str.encode(text, 'utf-8', 'replace')
                return data[:1000].decode('utf-8', 'ignore') + ('...' if len(data) > 1000 else '')
            def literal(node, label):
                stack = [(node, 0)]
                count = 0
                while stack:
                    current, depth = stack.pop()
                    count += 1
                    if count > 512 or depth > 16:
                        raise ValueError(label + ': literal exceeds the supported size or depth.')
                    stack.extend((child, depth + 1) for child in ast.iter_child_nodes(current))
                try:
                    return snapshot(ast.literal_eval(node))
                except (ValueError, TypeError, SyntaxError, RecursionError) as error:
                    raise ValueError(label + ': use a bounded Python literal with built-in values and finite numbers.') from error
            def parse_literal(text, label):
                if len(str.encode(text, 'utf-8')) > 2048:
                    raise ValueError(label + ': literal is too large.')
                try:
                    node = ast.parse(text.strip(), mode='eval').body
                except (SyntaxError, ValueError, RecursionError) as error:
                    raise ValueError(label + ': enter a Python literal, not an expression or a call.') from error
                return node, literal(node, label)
            with open(learner_path, encoding='utf-8') as source:
                tree = ast.parse(source.read(), filename=learner_path)
            nodes = [(tree, 0)]
            node_count = 0
            while nodes:
                node, depth = nodes.pop()
                node_count += 1
                if node_count > 50000 or depth > 256:
                    raise ValueError('Source is too large or deeply nested for input fixtures.')
                nodes.extend((child, depth + 1) for child in ast.iter_child_nodes(node))
            declarations = {item['name']: item for item in request['inputs']}
            bindings = {name: [] for name in declarations}
            class Bindings(ast.NodeVisitor):
                def record(self, name, node):
                    if name in bindings:
                        bindings[name].append(node)
                def visit_Name(self, node):
                    if isinstance(node.ctx, (ast.Store, ast.Del)):
                        self.record(node.id, node)
                def visit_FunctionDef(self, node):
                    self.record(node.name, node)
                    for child in node.decorator_list + [node.args] + ([node.returns] if node.returns is not None else []):
                        self.visit(child)
                visit_AsyncFunctionDef = visit_FunctionDef
                def visit_ClassDef(self, node):
                    self.record(node.name, node)
                    for child in node.decorator_list + node.bases + node.keywords:
                        self.visit(child)
                def visit_Lambda(self, node):
                    self.visit(node.args)
                def visit_alias(self, node):
                    self.record(node.asname or node.name.split('.')[0], node)
                def visit_ExceptHandler(self, node):
                    self.record(node.name, node)
                    self.generic_visit(node)
            Bindings().visit(tree)
            for node in ast.walk(tree):
                if isinstance(node, (ast.Global, ast.Nonlocal)):
                    for name in node.names:
                        if name in bindings:
                            bindings[name].append(node)
            for name, declaration in declarations.items():
                candidates = [node for node in tree.body if isinstance(node, ast.Assign) and len(node.targets) == 1
                              and isinstance(node.targets[0], ast.Name) and node.targets[0].id == name]
                if len(candidates) != 1 or len(bindings[name]) != 1:
                    raise ValueError('Input ' + name + ': keep exactly one simple top-level assignment, with no duplicate or compound bindings.')
                assignment = candidates[0]
                _, default = parse_literal(declaration['defaultLiteral'], 'Default for ' + name)
                original = literal(assignment.value, 'Original input ' + name)
                if original != default:
                    raise ValueError('Input ' + name + ': restore its declared default literal before using checks or experiments.')
                replacement, _ = parse_literal(effective[name], 'Input ' + name)
                for child in ast.walk(replacement):
                    ast.copy_location(child, assignment.value)
                assignment.value = replacement
            expected = None
            if check is not None:
                _, expected = parse_literal(check['expectedLiteral'], 'Expected value for ' + check['title'])
            compiled = compile(ast.fix_missing_locations(tree), learner_path, 'exec')
            def report(namespace):
                observations = []
                observed = None
                for target in targets:
                    try:
                        value = namespace[target]
                    except KeyError:
                        observations.append({'target': target, 'value': '[missing variable]'})
                        continue
                    try:
                        observed = snapshot(value)
                        text = bounded_display(observed)
                    except ValueError:
                        observed = None
                        text = '[unsupported or oversized value]'
                    observations.append({'target': target, 'value': text})
                result = {'mode': request['mode'], 'inputs': effective, 'observations': observations}
                if check is not None:
                    result.update({'id': check['id'], 'target': check['target'], 'expectedLiteral': check['expectedLiteral'],
                                   'expected': bounded_display(expected), 'matched': observed is not None and observed == expected})
                payload = encode_json(result, ensure_ascii=False, separators=(',', ':'))
                if len(str.encode(payload, 'utf-8')) > 65536:
                    raise RuntimeError('The bounded observation report was too large.')
                report_write(\(quoted(reportStart)) + payload + \(quoted(reportEnd)))
            return compiled, report
        fixture_code, fixture_report = prepare_fixture()
        """
        return source.replacingOccurrences(of: "\n", with: "\n        ")
    }

    private func harness(learner: String, tests: String?, token: String, diagnosticStart: String, diagnosticEnd: String, learnerLineCount: Int,
                         fixture: FixtureRequest?, reportStart: String, reportEnd: String) -> String {
        let testsLiteral = tests.map(quoted) ?? "None"
        let preparation = fixture.map { fixturePreparation($0, reportStart: reportStart, reportEnd: reportEnd) } ?? ""
        let execution = fixture == nil ? "namespace = runpy.run_path(learner_path, run_name=\"__main__\")" : "namespace = {'__name__': '__main__', '__file__': learner_path, '__package__': '', '__spec__': None, '__loader__': None, '__cached__': None}\n        exec(fixture_code, namespace, namespace)"
        let observation = fixture == nil ? "" : "fixture_report(namespace)"
        return """
        def __python_teacher_main():
            import ast
            import os
            import runpy
            import sys
            import traceback
            import json
            import re
            stdout, stderr, terminate = sys.stdout, sys.stderr, os._exit
            completed = \(quoted(token))
            learner_path = \(quoted(learner))
            test_path = \(testsLiteral)
            stage = 'runner'
            def bounded_text(value, limit):
                text = str(value).encode('utf-8', 'replace')[:limit].decode('utf-8', 'ignore')
                text = re.sub(r'''(?<![\\w/])/[\\w.~][^\\s'"<>:;]*''', '[path]', text)
                text = ''.join(character if character >= ' ' else ' ' for character in text)
                return text.encode('utf-8', 'replace')[:limit].decode('utf-8', 'ignore')
            def emit_diagnostic(error):
                frames = []
                origin = stage
                current = error.__traceback__
                while current is not None:
                    filename = current.tb_frame.f_code.co_filename
                    if filename == learner_path:
                        origin = 'learner'
                        line = current.tb_lineno
                        if type(line) is int and 0 < line <= \(learnerLineCount):
                            frames.append({'line': line, 'function': bounded_text(current.tb_frame.f_code.co_name, 128)})
                            frames = frames[-32:]
                    elif filename == test_path:
                        origin = 'checks'
                    current = current.tb_next
                if isinstance(error, SyntaxError) and error.filename == learner_path:
                    origin = 'learner'
                    if type(error.lineno) is int and 0 < error.lineno <= \(learnerLineCount):
                        frames = [{'line': error.lineno, 'function': '<module>'}]
                if origin != 'learner':
                    frames = []
                if origin == 'checks':
                    message = 'An exercise check failed. See the original output for details.'
                else:
                    message = bounded_text(error.msg if isinstance(error, SyntaxError) else error, 4000)
                diagnostic = {'exceptionType': bounded_text(type(error).__name__, 128), 'message': message, 'origin': origin, 'frames': frames}
                payload = json.dumps(diagnostic, ensure_ascii=False, separators=(',', ':'))
                if len(payload.encode('utf-8')) <= 16384:
                    stderr.write(\(quoted(diagnosticStart)) + payload + \(quoted(diagnosticEnd)))
            status = 1
            try:
                try:
                    import resource
                    for kind, maximum in [(resource.RLIMIT_CORE, 0), (resource.RLIMIT_FSIZE, 8 * 1024 * 1024), (resource.RLIMIT_NOFILE, 64)]:
                        inherited = resource.getrlimit(kind)
                        ceiling = min([maximum] + [value for value in inherited if value != resource.RLIM_INFINITY])
                        resource.setrlimit(kind, (ceiling, ceiling))
                        if resource.getrlimit(kind) != (ceiling, ceiling):
                            raise RuntimeError("Resource limit verification failed.")
                except (ImportError, OSError, ValueError, RuntimeError) as error:
                    raise RuntimeError("Could not apply required Python resource safeguards; learner execution was stopped.") from error
                checked = set()
                assertion_count = 0
                counter_name = "__ct_check_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
                if test_path is not None:
                    stage = 'checks'
                    with open(test_path, encoding="utf-8") as source:
                        tree = ast.parse(source.read(), filename=test_path)
                    class InstrumentAssertions(ast.NodeTransformer):
                        def visit_Assert(self, node):
                            nonlocal assertion_count
                            index = assertion_count
                            assertion_count += 1
                            record = ast.Expr(value=ast.Call(func=ast.Name(id=counter_name, ctx=ast.Load()), args=[ast.Constant(value=index)], keywords=[]))
                            return [node, ast.copy_location(record, node)]
                    tree = InstrumentAssertions().visit(tree)
                    if assertion_count == 0:
                        stage = 'runner'
                        raise RuntimeError("Tests must contain executable assert statements; no assertions were provided.")
                    compiled_tests = compile(ast.fix_missing_locations(tree), test_path, "exec")
                \(preparation)
                stage = 'learner'
                \(execution)
                stage = 'runner'
                \(observation)
                if test_path is not None:
                    namespace[counter_name] = checked.add
                    stage = 'checks'
                    exec(compiled_tests, namespace, namespace)
                    stage = 'runner'
                    if len(checked) != assertion_count:
                        raise RuntimeError("Tests skipped assertions: executed %d of %d assertion sites." % (len(checked), assertion_count))
                    stdout.write("Tests passed (%d assertions).\\n" % assertion_count)
                stdout.write(completed)
                status = 0
            except BaseException as error:
                traceback.print_exc(file=stderr)
                try:
                    emit_diagnostic(error)
                except BaseException:
                    pass
            finally:
                try:
                    stdout.flush()
                    stderr.flush()
                finally:
                    terminate(status)
        __python_teacher_main()
        """
    }
}

private struct FixtureRequest: Encodable {
    let inputs: [ExerciseInput]
    let effectiveInputs: [String: String]
    let check: NamedCheck?
    let targets: [String]
    let mode: String

    init(plan: AuthoredCheckPlan, overrides: [String: String], check: NamedCheck?) {
        inputs = plan.inputs
        effectiveInputs = Dictionary(uniqueKeysWithValues: plan.inputs.map { ($0.name, overrides[$0.name] ?? $0.defaultLiteral) })
        self.check = check
        var seen = Set<String>()
        targets = (check.map { [$0.target] } ?? plan.checks.map(\.target)).filter { seen.insert($0).inserted }
        mode = check == nil ? "experiment" : "check"
    }

    var header: String {
        let title = check?.title ?? "Experiment — not graded"
        return "\n[\(title)]\n" + inputs.map { "\($0.name) = \(effectiveInputs[$0.name] ?? $0.defaultLiteral)\n" }.joined()
    }

    func validatedReport(_ data: Data) -> FixtureReport? {
        guard data.count <= 65536, let value = try? JSONDecoder().decode(FixtureReport.self, from: data),
              value.mode == mode, value.inputs == effectiveInputs,
              value.observations.map(\.target) == targets,
              value.observations.allSatisfy({ !$0.value.isEmpty && $0.value.utf8.count <= 1024 }) else { return nil }
        if let check {
            guard value.id == check.id, value.target == check.target, value.expectedLiteral == check.expectedLiteral,
                  let expected = value.expected, !expected.isEmpty, expected.utf8.count <= 1024,
                  value.matched != nil else { return nil }
        } else {
            guard value.id == nil, value.target == nil, value.expectedLiteral == nil, value.expected == nil, value.matched == nil else { return nil }
        }
        return value
    }
}

private struct FixtureReport: Decodable {
    struct Observation: Decodable {
        let target: String
        let value: String
    }
    let mode: String
    let inputs: [String: String]
    let observations: [Observation]
    let id: String?
    let target: String?
    let expectedLiteral: String?
    let expected: String?
    let matched: Bool?
}

private struct BoundedPlanOutput {
    private var stored = Data()
    private let limit = 65536

    mutating func append(_ text: String) {
        stored.append(contentsOf: text.utf8)
        if stored.count > limit {
            let marker = Data("\n[Aggregate output truncated at 64 KiB; showing beginning and latest output.]\n".utf8)
            stored = stored.prefix(32768) + marker + stored.suffix(limit - 32768 - marker.count)
        }
    }

    var text: String {
        let decoded = String(decoding: stored, as: UTF8.self)
        return String(decoding: Data(decoded.utf8).prefix(limit - 3), as: UTF8.self)
    }
}

private final class RunControl: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var timedOut = false

    var flags: (cancelled: Bool, timedOut: Bool) {
        lock.withLock { (cancelled, timedOut) }
    }

    func launch(_ process: Process) throws -> Bool {
        try lock.withLock {
            guard !cancelled, !timedOut else { return false }
            try process.run()
            self.process = process
            return true
        }
    }

    func clear(_ process: Process) {
        lock.withLock {
            if self.process === process { self.process = nil }
        }
    }

    func stop(cancelled: Bool, timedOut: Bool = false) {
        lock.withLock {
            self.cancelled = self.cancelled || cancelled
            self.timedOut = self.timedOut || timedOut
            if let process, process.isRunning { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
        }
    }
}

struct OutputCapture {
    let marker: Data
    private let diagnosticStart: Data
    private let diagnosticEnd: Data
    private let learnerLineCount: Int
    private let reportStart: Data?
    private let reportEnd: Data?
    private(set) var report: Data?
    private(set) var reportInvalid = false
    private var reportSeen = false
    private let reportLimit = 65536
    private var pending = Data()
    private var stored = Data()
    private var truncated = false
    private(set) var completed = false
    private(set) var diagnostic: RunDiagnostic?
    private let limit = 64 * 1024
    private let diagnosticLimit = 16 * 1024

    init(marker: Data, diagnosticStart: Data, diagnosticEnd: Data, learnerLineCount: Int, reportStart: Data? = nil, reportEnd: Data? = nil) {
        self.marker = marker
        self.diagnosticStart = diagnosticStart
        self.diagnosticEnd = diagnosticEnd
        self.learnerLineCount = min(1_000_000, learnerLineCount)
        self.reportStart = reportStart
        self.reportEnd = reportEnd
    }

    mutating func consume(_ data: Data) {
        var offset = data.startIndex
        while offset < data.endIndex {
            let end = min(offset + 8192, data.endIndex)
            pending.append(data[offset..<end])
            drainPending()
            offset = end
        }
    }

    private mutating func drainPending() {
        while !pending.isEmpty {
            let completion = pending.range(of: marker)
            let start = pending.range(of: diagnosticStart)
            let reportRange = reportStart.flatMap { pending.range(of: $0) }
            if let reportRange, let reportStart, let reportEnd,
               reportRange.lowerBound < (start?.lowerBound ?? pending.endIndex),
               reportRange.lowerBound < (completion?.lowerBound ?? pending.endIndex) {
                store(Data(pending[..<reportRange.lowerBound]))
                pending.removeSubrange(pending.startIndex..<reportRange.lowerBound)
                let payloadStart = pending.startIndex + reportStart.count
                if let end = pending.range(of: reportEnd, in: payloadStart..<pending.endIndex) {
                    let payload = Data(pending[payloadStart..<end.lowerBound])
                    if reportSeen || payload.count > reportLimit {
                        reportInvalid = true
                        store(Data(pending[..<end.upperBound]))
                    } else {
                        report = payload
                    }
                    reportSeen = true
                    pending.removeSubrange(pending.startIndex..<end.upperBound)
                    continue
                }
                if pending.count <= reportStart.count + reportLimit + reportEnd.count - 1 { return }
                reportInvalid = true
                reportSeen = true
                store(Data(pending.prefix(reportStart.count)))
                pending.removeFirst(reportStart.count)
                continue
            }
            if let completion, completion.lowerBound < (start?.lowerBound ?? pending.endIndex) {
                store(Data(pending[..<completion.lowerBound]))
                pending.removeSubrange(pending.startIndex..<completion.upperBound)
                completed = true
                continue
            }
            if let start {
                store(Data(pending[..<start.lowerBound]))
                pending.removeSubrange(pending.startIndex..<start.lowerBound)
                let payloadStart = pending.startIndex + diagnosticStart.count
                if let end = pending.range(of: diagnosticEnd, in: payloadStart..<pending.endIndex) {
                    let payload = Data(pending[payloadStart..<end.lowerBound])
                    if payload.count <= diagnosticLimit, let decoded = validatedDiagnostic(payload) {
                        diagnostic = decoded
                    } else {
                        store(Data(pending[..<end.upperBound]))
                    }
                    pending.removeSubrange(pending.startIndex..<end.upperBound)
                    continue
                }
                if pending.count <= diagnosticStart.count + diagnosticLimit + diagnosticEnd.count - 1 { return }
                store(Data(pending.prefix(diagnosticStart.count)))
                pending.removeFirst(diagnosticStart.count)
                continue
            }
            let safeCount = max(0, pending.count - max(marker.count, diagnosticStart.count, reportStart?.count ?? 0) + 1)
            if safeCount > 0 {
                store(Data(pending.prefix(safeCount)))
                pending.removeFirst(safeCount)
            }
            return
        }
    }

    private func validatedDiagnostic(_ data: Data) -> RunDiagnostic? {
        guard let value = try? JSONDecoder().decode(RunDiagnostic.self, from: data),
              !value.exceptionType.isEmpty, value.exceptionType.utf8.count <= 128,
              value.message.utf8.count <= 4096, value.frames.count <= 32,
              value.origin == .learner || value.frames.isEmpty,
              !value.exceptionType.contains("/"),
              value.message.range(of: #"(?<![\w/])/[\w.~][^\s'"<>:;]*"#, options: .regularExpression) == nil,
              value.frames.allSatisfy({
                  $0.line > 0 && $0.line <= learnerLineCount && !$0.function.isEmpty
                      && $0.function.utf8.count <= 128 && !$0.function.contains("/")
              }) else { return nil }
        return value
    }

    mutating func finish() {
        if let reportStart, pending.range(of: reportStart) != nil { reportInvalid = true }
        store(pending)
        pending.removeAll()
    }

    private mutating func store(_ data: Data) {
        let remaining = max(0, limit - stored.count)
        stored.append(data.prefix(remaining))
        if data.count > remaining { truncated = true }
    }

    var text: String {
        let decoded = String(decoding: stored, as: UTF8.self)
        let bounded = String(decoding: decoded.utf8.prefix(limit), as: UTF8.self)
        return bounded + (truncated || decoded.utf8.count > limit ? "\n[Output truncated at 64 KiB; remaining output was drained.]\n" : "")
    }
}
