import Foundation

/// A structural problem in a chapter prerequisite graph.
public enum CurriculumGraphIssue: Equatable, Sendable, CustomStringConvertible {
    case empty
    case duplicateChapterID(String)
    case duplicatePrerequisite(chapter: String, prerequisite: String)
    case selfPrerequisite(String)
    case unknownPrerequisite(chapter: String, prerequisite: String)
    /// Chapter IDs forming a prerequisite cycle, starting from the earliest in canonical order.
    case cycle([String])
    /// A prerequisite that does not appear earlier than its dependent in canonical order.
    case prerequisiteOutOfOrder(chapter: String, prerequisite: String)
    /// The graph must have exactly one chapter without prerequisites: the expected root.
    case invalidRoots(expected: String, found: [String])

    public var description: String {
        switch self {
        case .empty: return "The curriculum has no chapters."
        case .duplicateChapterID(let id): return "Chapter ID \(id) appears more than once."
        case let .duplicatePrerequisite(chapter, prerequisite): return "\(chapter) lists prerequisite \(prerequisite) more than once."
        case .selfPrerequisite(let id): return "\(id) lists itself as a prerequisite."
        case let .unknownPrerequisite(chapter, prerequisite): return "\(chapter) requires unknown chapter \(prerequisite)."
        case .cycle(let ids): return "Prerequisite cycle: \((ids + ids.prefix(1)).joined(separator: " → "))."
        case let .prerequisiteOutOfOrder(chapter, prerequisite): return "\(chapter) appears before its prerequisite \(prerequisite) in canonical order."
        case let .invalidRoots(expected, found): return "Expected exactly one chapter without prerequisites (\(expected)); found \(found.isEmpty ? "none" : found.joined(separator: ", "))."
        }
    }
}

public struct CurriculumGraphError: LocalizedError, Equatable, Sendable {
    public let issues: [CurriculumGraphIssue]
    public var errorDescription: String? { issues.map(\.description).joined(separator: "\n") }
}

/// Prerequisite graph over chapters supplied in canonical (display and lesson) order.
///
/// Queries fail closed: an unknown chapter, an unknown prerequisite, or a prerequisite edge that
/// does not point to an earlier chapter (which includes self-references and cycles) yields `nil`
/// rather than a partial answer.
public struct CurriculumGraph: Sendable {
    public static let rootChapterID = "basics"

    public let chapters: [Chapter]
    private let indices: [String: Int]

    public init(_ chapters: [Chapter]) {
        self.chapters = chapters
        var indices: [String: Int] = [:]
        for (index, chapter) in chapters.enumerated() where indices[chapter.id] == nil {
            indices[chapter.id] = index
        }
        self.indices = indices
    }

    public func index(of chapterID: String) -> Int? { indices[chapterID] }

    public func chapter(_ chapterID: String) -> Chapter? { indices[chapterID].map { chapters[$0] } }

    /// The chapter's direct prerequisites in canonical order, or `nil` if any is unknown.
    public func directPrerequisites(of chapterID: String) -> [Chapter]? {
        guard let chapter = chapter(chapterID) else { return nil }
        var seen = Set<Int>()
        for prerequisite in chapter.prerequisites {
            guard let index = indices[prerequisite] else { return nil }
            seen.insert(index)
        }
        return seen.sorted().map { chapters[$0] }
    }

    /// Every chapter the given chapter transitively depends on, excluding itself, in canonical order.
    /// Returns `nil` for an unknown chapter, an unknown prerequisite, or any edge that is not
    /// topologically ordered (self-references and cycles included).
    public func prerequisiteClosure(of chapterID: String) -> [Chapter]? {
        guard indices[chapterID] != nil else { return nil }
        var visited = Set<String>()
        var pending = [chapterID]
        while let id = pending.popLast() {
            guard let index = indices[id] else { return nil }
            for prerequisite in chapters[index].prerequisites {
                guard let prerequisiteIndex = indices[prerequisite], prerequisiteIndex < index else { return nil }
                if visited.insert(prerequisite).inserted { pending.append(prerequisite) }
            }
        }
        return visited.compactMap { indices[$0] }.sorted().map { chapters[$0] }
    }

    /// The prerequisite closure followed by the chapter itself, in canonical order.
    public func closureIncludingSelf(of chapterID: String) -> [Chapter]? {
        guard let chapter = chapter(chapterID), let closure = prerequisiteClosure(of: chapterID) else { return nil }
        return closure + [chapter]
    }

    public func validationIssues(rootID: String = CurriculumGraph.rootChapterID) -> [CurriculumGraphIssue] {
        guard !chapters.isEmpty else { return [.empty] }
        var issues: [CurriculumGraphIssue] = []
        var seenIDs = Set<String>()
        for chapter in chapters where !seenIDs.insert(chapter.id).inserted {
            issues.append(.duplicateChapterID(chapter.id))
        }
        for (index, chapter) in chapters.enumerated() where indices[chapter.id] == index {
            var seenPrerequisites = Set<String>()
            for prerequisite in chapter.prerequisites {
                if !seenPrerequisites.insert(prerequisite).inserted {
                    issues.append(.duplicatePrerequisite(chapter: chapter.id, prerequisite: prerequisite))
                } else if prerequisite == chapter.id {
                    issues.append(.selfPrerequisite(chapter.id))
                } else if let prerequisiteIndex = indices[prerequisite] {
                    if prerequisiteIndex >= index {
                        issues.append(.prerequisiteOutOfOrder(chapter: chapter.id, prerequisite: prerequisite))
                    }
                } else {
                    issues.append(.unknownPrerequisite(chapter: chapter.id, prerequisite: prerequisite))
                }
            }
        }
        issues += cycles().map(CurriculumGraphIssue.cycle)
        let roots = chapters.enumerated().filter { indices[$0.element.id] == $0.offset && $0.element.prerequisites.isEmpty }.map(\.element.id)
        if roots != [rootID] {
            issues.append(.invalidRoots(expected: rootID, found: roots))
        }
        return issues
    }

    public func validate(rootID: String = CurriculumGraph.rootChapterID) throws {
        let issues = validationIssues(rootID: rootID)
        guard issues.isEmpty else { throw CurriculumGraphError(issues: issues) }
    }

    /// Cycles among known chapters, excluding self-references (reported separately).
    private func cycles() -> [[String]] {
        enum Mark { case visiting, done }
        var marks: [String: Mark] = [:]
        var stack: [String] = []
        var found: [[String]] = []
        var seen = Set<[String]>()

        func visit(_ id: String) {
            marks[id] = .visiting
            stack.append(id)
            for prerequisite in chapter(id)?.prerequisites ?? [] where prerequisite != id && indices[prerequisite] != nil {
                switch marks[prerequisite] {
                case .none: visit(prerequisite)
                case .visiting:
                    guard let start = stack.lastIndex(of: prerequisite) else { continue }
                    let members = Array(stack[start...])
                    let first = members.indices.min { (indices[members[$0]] ?? 0) < (indices[members[$1]] ?? 0) } ?? 0
                    let cycle = Array(members[first...] + members[..<first])
                    if seen.insert(cycle).inserted { found.append(cycle) }
                case .done: continue
                }
            }
            stack.removeLast()
            marks[id] = .done
        }

        for chapter in chapters where marks[chapter.id] == nil { visit(chapter.id) }
        return found
    }
}

extension Curriculum {
    /// Prerequisite graph of the built-in curriculum in canonical order.
    public static let graph = CurriculumGraph(chapters)
}
