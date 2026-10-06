import Foundation

public struct ProgressStore: Sendable {
    public var directory: URL

    public static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/PythonTeacher", isDirectory: true)
    /// Folder used while the app was named Coding Teacher.
    public static let legacyDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodingTeacher", isDirectory: true)

    public init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory
    }

    /// Moves the legacy data folder to the current location when only the legacy one exists.
    /// If the move fails, the legacy folder is used in place so saved progress is never hidden or replaced.
    public static func migratingLegacyDirectory(from legacy: URL = legacyDirectory, to current: URL = defaultDirectory) -> ProgressStore {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: current.path), manager.fileExists(atPath: legacy.path) else {
            return ProgressStore(directory: current)
        }
        do {
            try manager.createDirectory(at: current.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.moveItem(at: legacy, to: current)
            return ProgressStore(directory: current)
        } catch {
            return ProgressStore(directory: legacy)
        }
    }

    public func load() throws -> ProgressState {
        let data: Data
        do {
            data = try Data(contentsOf: stateURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return ProgressState()
        } catch {
            throw StoreError.unreadable(path: stateURL.path, reason: error.localizedDescription)
        }
        do {
            let header = try JSONDecoder().decode(SchemaHeader.self, from: data)
            guard header.schemaVersion == 1 else {
                throw StoreError.unsupportedSchema(header.schemaVersion)
            }
            return try JSONDecoder().decode(ProgressState.self, from: data)
        } catch let error as StoreError {
            throw error
        } catch {
            throw StoreError.malformed(path: stateURL.path, reason: error.localizedDescription)
        }
    }

    public func save(_ state: ProgressState, preservingRewardHistory: Bool = false) throws {
        guard state.schemaVersion == 1 else {
            throw StoreError.unsupportedSchema(state.schemaVersion)
        }
        let existing = try load()
        do {
            let data = try encode(state)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if preservingRewardHistory, existing.rewardPolicyVersion < state.rewardPolicyVersion,
               !existing.attempts.isEmpty || !existing.generatedExercises.isEmpty {
                let backup = directory.appendingPathComponent("progress-before-xp-v\(state.rewardPolicyVersion)-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: stateURL, to: backup)
            }
            try data.write(to: stateURL, options: .atomic)
        } catch {
            throw StoreError.writeFailed(path: stateURL.path, reason: error.localizedDescription)
        }
    }

    public func exportData() throws -> Data {
        try encode(load())
    }

    private var stateURL: URL {
        directory.appendingPathComponent("progress.json", isDirectory: false)
    }

    private func encode(_ state: ProgressState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    private struct SchemaHeader: Decodable {
        let schemaVersion: Int
    }

    public enum StoreError: Error, LocalizedError, Equatable {
        case unreadable(path: String, reason: String)
        case malformed(path: String, reason: String)
        case unsupportedSchema(Int)
        case writeFailed(path: String, reason: String)

        public var errorDescription: String? {
            switch self {
            case let .unreadable(path, reason):
                return "Cannot read saved progress at \(path). The existing file has not been changed. \(reason)"
            case let .malformed(path, reason):
                return "Saved progress at \(path) is malformed. The existing file has been preserved; restore a valid backup or move it aside before saving. \(reason)"
            case let .unsupportedSchema(version):
                return "Saved progress schema \(version) is not supported (expected 1). No saved progress has been changed."
            case let .writeFailed(path, reason):
                return "Cannot save progress at \(path). \(reason)"
            }
        }
    }
}
