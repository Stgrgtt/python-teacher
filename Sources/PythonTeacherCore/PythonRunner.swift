import Foundation
import Darwin

public struct RunResult: Sendable {
    public let output: String
    public let exitCode: Int32
    public let passed: Bool
    public let timedOut: Bool
    public let cancelled: Bool
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

    private func execute(code: String, tests: String?, pythonPath: String, timeout: TimeInterval, control: RunControl) throws -> RunResult {
        guard timeout.isFinite, timeout > 0 else { throw PythonRunnerError.invalidTimeout }
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
        if control.flags.cancelled { return stoppedResult(control) }
        let interpreter = try resolveInterpreter(pythonPath, environment: environment, control: control)
        if control.flags.cancelled { return stoppedResult(control) }
        let token = "\n__PYTHON_TEACHER_COMPLETE_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))__\n"
        let script = harness(learner: learner.path, tests: tests == nil ? nil : testFile.path, token: token)
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
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var capture = OutputCapture(marker: Data(token.utf8))
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
        let passed = inputFailure == nil && process.terminationStatus == 0 && capture.completed && !flags.cancelled && !flags.timedOut
        if flags.timedOut { text += "\n[Execution timed out.]\n" }
        else if flags.cancelled { text += "\n[Execution cancelled.]\n" }
        else if process.terminationStatus == 0 && !capture.completed {
            text += "\n[Execution ended before the runner completed; tests did not pass.]\n"
        }
        if text.contains("sandbox-exec:") && !capture.completed {
            text += "\n[Sandboxed execution failed. No unrestricted fallback was attempted.]\n"
        }
        return RunResult(output: text, exitCode: process.terminationStatus, passed: passed, timedOut: flags.timedOut, cancelled: flags.cancelled)
    }

    private func stoppedResult(_ control: RunControl) -> RunResult {
        let flags = control.flags
        return RunResult(output: "[Execution cancelled.]\n", exitCode: -1, passed: false, timedOut: flags.timedOut, cancelled: flags.cancelled)
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
            if control.flags.cancelled { return candidate }
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

    private func harness(learner: String, tests: String?, token: String) -> String {
        let testsLiteral = tests.map(quoted) ?? "None"
        return """
        def __python_teacher_main():
            import ast
            import os
            import runpy
            import sys
            import traceback
            stdout, stderr, terminate = sys.stdout, sys.stderr, os._exit
            completed = \(quoted(token))
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
                test_path = \(testsLiteral)
                checked = set()
                assertion_count = 0
                counter_name = "__ct_check_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
                if test_path is not None:
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
                        raise RuntimeError("Tests must contain executable assert statements; no assertions were provided.")
                    compiled_tests = compile(ast.fix_missing_locations(tree), test_path, "exec")
                namespace = runpy.run_path(\(quoted(learner)), run_name="__main__")
                if test_path is not None:
                    namespace[counter_name] = checked.add
                    exec(compiled_tests, namespace, namespace)
                    if len(checked) != assertion_count:
                        raise RuntimeError("Tests skipped assertions: executed %d of %d assertion sites." % (len(checked), assertion_count))
                    stdout.write("Tests passed (%d assertions).\\n" % assertion_count)
                stdout.write(completed)
                status = 0
            except BaseException:
                traceback.print_exc(file=stderr)
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

private struct OutputCapture {
    let marker: Data
    private var pending = Data()
    private var stored = Data()
    private var truncated = false
    private(set) var completed = false
    private let limit = 64 * 1024

    init(marker: Data) { self.marker = marker }

    mutating func consume(_ data: Data) {
        pending.append(data)
        while let range = pending.range(of: marker) {
            store(Data(pending[..<range.lowerBound]))
            pending.removeSubrange(pending.startIndex..<range.upperBound)
            completed = true
        }
        let safeCount = max(0, pending.count - marker.count + 1)
        if safeCount > 0 {
            store(Data(pending.prefix(safeCount)))
            pending.removeFirst(safeCount)
        }
    }

    mutating func finish() {
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
