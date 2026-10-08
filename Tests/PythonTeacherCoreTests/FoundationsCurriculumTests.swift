import Foundation
import XCTest
@testable import PythonTeacherCore

final class FoundationsCurriculumTests: XCTestCase {
    private func chapter(_ id: String) throws -> Chapter {
        try XCTUnwrap(Curriculum.chapters.first { $0.id == id }, id)
    }

    private func lessonCode(_ chapter: Chapter) -> [String] {
        chapter.lesson.components(separatedBy: "```python\n").dropFirst().map { String($0.components(separatedBy: "```")[0]) }
    }

    private func exerciseCode(_ chapter: Chapter) -> [String] {
        (chapter.exercises + [chapter.assessment]).flatMap { [$0.starterCode, $0.referenceSolution, $0.testCode] }
    }

    private func headings(_ chapter: Chapter) -> [String] {
        chapter.practiceTopics.map { String($0.title.dropFirst(chapter.title.count + 2)) }
    }

    func testDebuggingExpansionPreservesOriginalActivitiesAndSectionIDs() throws {
        let originals: [String: [String]] = [
            "basics": ["basics-name", "basics-total", "basics-message"],
            "values": ["values-budget", "values-label", "values-batches"],
            "decisions": ["decisions-route", "decisions-quota", "decisions-bands-v2"],
            "loops": ["loops-total", "loops-filter", "loops-retries-v2"],
            "functions": ["functions-batches", "functions-rate", "functions-preview-v2"],
            "collections": ["collections-count", "collections-json", "collections-rank"],
            "reliability": ["reliability-score", "reliability-parse", "reliability-summary"]
        ]
        let originalHeadings: [String: [String]] = [
            "basics": ["Code is a sequence of instructions", "Save a value with a name", "Calculate with saved numbers", "Join text", "Work in the editor"],
            "values": ["Build expressions one step at a time", "What the dot and parentheses mean", "Chaining is the same work written more compactly", "Put saved values into a message", "Numbers, rates, and units", "Complete groups, leftovers, and rounding up"],
            "decisions": ["Make the rule visible", "Debug the boundaries", "Combine conditions with and, or, and not", "Save a yes/no answer as a Boolean"],
            "loops": ["Keep several values in a list", "Visit every item with for", "Finish calculations after visiting every item", "Repeat a known number of times", "Repeat while a condition holds", "Stop early or skip an item", "Trace before guessing"],
            "functions": ["Separate inputs from results", "Read part of a string with a slice", "Replace a function's placeholder, not its interface", "Default values and keyword arguments", "Test a hypothesis"],
            "collections": ["Choose a structure that fits", "Count repeated categories", "Convert JSON text into Python values", "Group fixed values in a tuple", "Sort without changing the input", "Keep unique names when requested", "Debug the shape"],
            "reliability": ["Make failure part of the contract", "Check types before using operations", "Catch an expected failure", "Validate formats, not just conversions", "Tests are evidence, not validation code", "Build a small trustworthy tool"]
        ]
        var additions: [Exercise] = []
        for (id, ids) in originals {
            let current = try chapter(id)
            XCTAssertEqual(Array(current.exercises.prefix(3).map(\.id)), ids, id)
            XCTAssertEqual(current.lessonSections.map(\.heading), originalHeadings[id], id)
            XCTAssertEqual(current.lessonSections.map(\.topic.id), originalHeadings[id]?.indices.map { "\(id)-section-\($0 + 1)" }, id)
            XCTAssertEqual(current.assessment.id, id == "decisions" ? "decisions-assessment-v2" : "\(id)-assessment")
            XCTAssertNil(current.assessment.expectedStarterError)
            let labs = Array(current.exercises.dropFirst(3))
            XCTAssertEqual(labs.count, ["collections", "reliability"].contains(id) ? 1 : 2, id)
            for lab in labs {
                XCTAssertTrue(lab.id.hasPrefix("\(id)-debug-") || lab.id.hasPrefix("\(id)-predict-"), lab.id)
                XCTAssertFalse(Curriculum.isAssessment(lab.id), lab.id)
                XCTAssertEqual(Curriculum.activityID(for: lab.id), lab.id)
                XCTAssertTrue(lab.hasRequiredInstructionSections, lab.id)
                XCTAssertNotNil(lab.effort, lab.id)
                XCTAssertFalse(lab.effort?.estimated ?? true, lab.id)
                if let error = lab.expectedStarterError {
                    XCTAssertTrue(["SyntaxError", "IndentationError", "NameError", "TypeError", "KeyError", "IndexError"].contains(error), lab.id)
                }
            }
            additions += labs
        }
        XCTAssertEqual(additions.count, 12)
        XCTAssertEqual(additions.compactMap(\.effort).reduce(0) { $0 + $1.practiceXP }, 1_600)
        XCTAssertEqual(Set(additions.map(\.id)).count, 12)
        XCTAssertTrue(additions.contains { $0.expectedStarterError == "SyntaxError" })
        XCTAssertTrue(additions.contains { $0.id.contains("-predict-") })
        XCTAssertTrue(try chapter("basics").lesson.contains("Understanding errors"))
        XCTAssertTrue(try chapter("functions").lesson.contains("Debugging systematically"))
    }

    func testStarterFailureMetadataIsOptionalAndRoundTripsWithoutChangingLegacyWork() throws {
        let original = try XCTUnwrap(Curriculum.chapters.first?.exercises.first)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        payload.removeValue(forKey: "expectedStarterError")
        let decoded = try JSONDecoder().decode(Exercise.self, from: JSONSerialization.data(withJSONObject: payload))
        XCTAssertNil(decoded.expectedStarterError)
        XCTAssertEqual(decoded, original)
        for error in ["SyntaxError", "NameError", "KeyError"] {
            var lab = original
            lab.expectedStarterError = error
            XCTAssertEqual(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(lab)), lab)
        }
        var state = ProgressState()
        state.generatedExercises["basics"] = [decoded]
        state.drafts["basics:practice:\(decoded.id)"] = "learner_name = 'unchanged'\n"
        state.attempts = [Attempt(chapterID: "basics", exerciseID: "basics-assessment", mode: .assessment,
                                  code: "saved evidence", testsPassed: true, quizCorrect: 3, quizTotal: 3, reflection: "A saved explanation")]
        let restored = try JSONDecoder().decode(ProgressState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.generatedExercises["basics"], [decoded])
        XCTAssertEqual(restored.drafts, state.drafts)
        XCTAssertEqual(restored.masteredChapterIDs, ["basics"])
        XCTAssertEqual(restored.attempts.map(\.id), state.attempts.map(\.id))
        XCTAssertEqual(restored.attempts.map(\.code), state.attempts.map(\.code))
        XCTAssertEqual(restored.playerProgress, state.playerProgress)
    }

    func testNewDebuggingStartersAreRunnableUnlessSyntaxFailureIsExplicit() async throws {
        let runner = PythonRunner()
        let python = ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
        for chapter in Curriculum.chapters where chapter.track == .foundations {
            for lab in chapter.exercises.dropFirst(3) {
                let result = try await runner.run(code: lab.starterCode, pythonPath: python)
                if lab.expectedStarterError == "SyntaxError" {
                    XCTAssertFalse(result.passed, lab.id)
                    XCTAssertEqual(result.diagnostic?.exceptionType, "SyntaxError", result.output)
                    XCTAssertEqual(result.diagnostic?.origin, .learner)
                    XCTAssertEqual(result.diagnostic?.learnerLine, 2)
                } else {
                    XCTAssertTrue(result.passed, "\(lab.id): \(result.output)")
                    XCTAssertNil(result.diagnostic, lab.id)
                }
                XCTAssertFalse(result.timedOut, lab.id)
                XCTAssertFalse(result.cancelled, lab.id)
            }
        }
    }

    func testDebuggingCheckersRejectPlausibleWrongRepairs() async throws {
        let mutations: [(String, String, String, String)] = [
            ("functions-debug-return", "return count", "return 0", "AssertionError"),
            ("functions-debug-return", "reading >= minimum", "reading > minimum", "AssertionError"),
            ("functions-debug-return", "            count += 1\n    return count", "            count += 1\n        return count", "AssertionError"),
            ("functions-predict-counterexample", "len(title) <= max_chars", "len(title) < max_chars", "AssertionError"),
            ("collections-debug-optional-field", "record.get('bonus', 0)", "0", "AssertionError"),
            ("collections-debug-optional-field", "        totals.append", "        record['bonus'] = record.get('bonus', 0)\n        totals.append", "AssertionError"),
            ("reliability-debug-later-record", "for record in records:\n        if not isinstance(record", "for record in records[:2]:\n        if not isinstance(record", "TypeError"),
            ("reliability-debug-later-record", "type(retries) is not int", "not isinstance(retries, int)", "AssertionError"),
            ("loops-debug-running-total", "total += amount", "total = amount", "AssertionError"),
            ("loops-predict-threshold", "while value < target", "while value <= target", "AssertionError")
        ]
        let labs = Curriculum.chapters.flatMap(\.exercises)
        let runner = PythonRunner()
        let python = ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
        for (id, original, replacement, expectedError) in mutations {
            let lab = try XCTUnwrap(labs.first { $0.id == id }, id)
            XCTAssertTrue(lab.referenceSolution.contains(original), "mutation must remain applicable: \(id)")
            let wrongRepair = lab.referenceSolution.replacingOccurrences(of: original, with: replacement)
            XCTAssertNotEqual(wrongRepair, lab.referenceSolution, id)
            let result = try await runner.run(code: wrongRepair, tests: lab.testCode, pythonPath: python)
            XCTAssertFalse(result.passed, "\(id) accepted \(replacement)")
            XCTAssertEqual(result.diagnostic?.exceptionType, expectedError, "\(id): \(result.output)")
            XCTAssertFalse(result.timedOut, id)
            XCTAssertFalse(result.cancelled, id)
        }
    }

    func testRevisedFoundationActivitiesHaveDistinctIDsAndExecutableStartersAndReferences() async throws {
        for (chapterID, activityID) in [("decisions", "decisions-bands"), ("decisions", "decisions-assessment"),
                                       ("loops", "loops-retries"), ("functions", "functions-preview")] {
            let current = try chapter(chapterID)
            let exercise = try XCTUnwrap((current.exercises + [current.assessment]).first { $0.id == activityID + "-v2" })
            let reference = try await PythonRunner().run(code: exercise.referenceSolution, tests: exercise.testCode, pythonPath: "/usr/bin/python3")
            XCTAssertTrue(reference.passed, "\(exercise.id): \(reference.output)")
            let starter = try await PythonRunner().run(code: exercise.starterCode, tests: exercise.testCode, pythonPath: "/usr/bin/python3")
            XCTAssertFalse(starter.passed, exercise.id)
        }
    }

    func testFoundationVariantsDoNotDuplicateCompletionOrWeeklyReviewRewards() {
        for activityID in ["decisions-bands", "loops-retries", "functions-preview"] {
            var saved = ProgressState()
            let date = Date(timeIntervalSince1970: 1_000_000)
            let chapterID = String(activityID.split(separator: "-")[0])
            let original = Attempt(date: date, chapterID: chapterID, exerciseID: activityID, mode: .practice,
                                   code: "original evidence", testsPassed: true, effort: .init(scopeUnits: 2))
            saved.attempts = [original]
            let originalEvents = saved.experienceEvents
            saved.attempts.append(Attempt(date: date.addingTimeInterval(1), chapterID: chapterID, exerciseID: activityID + "-v2",
                                          mode: .practice, code: "new evidence", testsPassed: true, effort: .init(scopeUnits: 2)))
            XCTAssertEqual(saved.experienceEvents, originalEvents)
            XCTAssertEqual(saved.completedPracticeCount, 1)
            saved.attempts.append(Attempt(date: date.addingTimeInterval(8 * 86400), chapterID: chapterID, exerciseID: activityID,
                                          mode: .practice, code: "review evidence", testsPassed: true, effort: .init(scopeUnits: 2)))
            XCTAssertEqual(saved.playerProgress.totalXP, 225)
            XCTAssertEqual(saved.attempts.first?.code, original.code)
            XCTAssertEqual(saved.attempts.first?.effort, original.effort)
        }
    }

    func testAssessmentVariantsPreserveMasteryAndDeduplicateReviewInEitherOrder() {
        for ids in [["decisions-assessment", "decisions-assessment-v2"], ["decisions-assessment-v2", "decisions-assessment"]] {
            var saved = ProgressState()
            let date = Date(timeIntervalSince1970: 1_000_000)
            func attempt(_ id: String, days: Double) -> Attempt {
                Attempt(date: date.addingTimeInterval(days * 86400), chapterID: "decisions", exerciseID: id,
                        mode: .assessment, code: "unaltered evidence: \(id)", testsPassed: true, quizCorrect: 3,
                        quizTotal: 3, reflection: "Independent explanation", effort: .init(scopeUnits: 2))
            }
            saved.attempts = [attempt(ids[0], days: 0)]
            let original = saved.experienceEvents
            saved.attempts.append(attempt(ids[1], days: 1))
            XCTAssertEqual(saved.experienceEvents, original)
            XCTAssertEqual(saved.masteredChapterIDs, ["decisions"])
            saved.attempts.append(attempt(ids[1], days: 9))
            saved.attempts.append(attempt(ids[0], days: 9.5))
            XCTAssertEqual(saved.playerProgress.totalXP, 625)
            XCTAssertEqual(saved.experienceEvents.filter { $0.title == "Weekly review" }.count, 1)
        }
    }

    func testLegacyRatingsAndHistoricalUpgradePolicyAreUnchanged() throws {
        var saved = ProgressState()
        let contracts: [(String, LearningMode, ExerciseEffort)] = [
            ("decisions", .practice, .init(difficulty: .harder, scopeUnits: 2)),
            ("decisions", .assessment, .init(scopeUnits: 2)),
            ("loops", .practice, .init(scopeUnits: 2)),
            ("functions", .practice, .init())
        ]
        for (chapterID, mode, effort) in contracts {
            let legacy = try XCTUnwrap(Curriculum.legacyExercises(chapterID: chapterID, mode: mode).first)
            XCTAssertEqual(legacy.effort, effort)
            saved.attempts.append(Attempt(chapterID: chapterID, exerciseID: legacy.id, mode: mode,
                                          code: legacy.referenceSolution, testsPassed: true))
        }
        let source = saved.attempts.map(\.code)
        let ids = saved.attempts.map(\.id)
        _ = saved.playerProgress
        XCTAssertTrue(saved.attempts.allSatisfy { $0.effort == nil }, "ordinary XP reads never migrate attempts")
        saved.recalculateExperience()
        XCTAssertEqual(ExperienceRules.policyVersion, 3)
        XCTAssertEqual(saved.attempts.map(\.effort), contracts.map { Optional($0.2) })
        XCTAssertEqual(saved.attempts.map(\.code), source)
        XCTAssertEqual(saved.attempts.map(\.id), ids)
    }

    func testDecisionsRequireNoListsLoopsOrTuples() throws {
        let decisions = try chapter("decisions")
        for code in lessonCode(decisions) + exerciseCode(decisions) {
            XCTAssertFalse(code.contains("["), code)
            XCTAssertFalse(code.contains("for "), code)
            XCTAssertFalse(code.contains("while "), code)
            XCTAssertFalse(code.contains(".append("), code)
            XCTAssertFalse(code.contains("range("), code)
        }
        for exercise in decisions.exercises + [decisions.assessment] {
            XCTAssertFalse(exercise.instructions.contains("list"), exercise.id)
            XCTAssertFalse(exercise.instructions.contains("loop"), exercise.id)
        }
        XCTAssertFalse(decisions.lesson.contains("tuple"))
        XCTAssertFalse(decisions.lesson.contains("**list**"))
        for term in ["`and`", "`or`", "`not`", "Boolean", "`elif`", "`else`", "0 <= score <= 1"] {
            XCTAssertTrue(decisions.lesson.contains(term), term)
        }
    }

    func testLoopsIntroduceListsBeforeForAndTeachWhileBreakContinue() throws {
        let loops = try chapter("loops")
        let blocks = lessonCode(loops)
        let firstFor = try XCTUnwrap(blocks.firstIndex { $0.contains("for ") })
        let listBlocks = blocks[..<firstFor]
        XCTAssertTrue(listBlocks.contains { $0.contains("[0]") && $0.contains("len(") }, "index and len before for")
        XCTAssertTrue(listBlocks.contains { $0.contains("= []") && $0.contains(".append(") }, "empty list and append before for")
        let lesson = loops.lesson
        let listIntro = try XCTUnwrap(lesson.range(of: "A **list**"))
        let forIntro = try XCTUnwrap(lesson.range(of: "A `for` loop"))
        XCTAssertLessThan(listIntro.lowerBound, forIntro.lowerBound)
        for term in ["IndexError", "index", "`while`", "infinite loop", "8 seconds", "`break`", "`continue`", "range(", "accumulator", "trace"] {
            XCTAssertTrue(lesson.contains(term), term)
        }
        XCTAssertTrue(blocks.contains { $0.contains("while ") })
        XCTAssertTrue(blocks.contains { $0.contains("break\n") })
        XCTAssertTrue(blocks.contains { $0.contains("continue\n") })
        XCTAssertTrue((loops.exercises + [loops.assessment]).contains { $0.referenceSolution.contains("while ") || $0.referenceSolution.contains("break\n") },
                      "a loops task must exercise while or break")
        XCTAssertTrue(headings(loops).first?.contains("list") == true)
    }

    func testFunctionsTeachDefaultAndKeywordArguments() throws {
        let functions = try chapter("functions")
        XCTAssertTrue(headings(functions).contains { $0.contains("Default values and keyword arguments") })
        for term in ["**default value**", "**keyword argument**", "None"] {
            XCTAssertTrue(functions.lesson.contains(term), term)
        }
        XCTAssertTrue(lessonCode(functions).contains { $0.contains("=None") && $0.contains("is None") }, "mutable-default pitfall example")
        XCTAssertTrue(functions.exercises.contains { exercise in
            exercise.starterCode.contains("='") && exercise.testCode.contains("marker=")
        }, "an exercise uses a default and a keyword argument")
    }

    func testCollectionsTeachTuplesAndSetsBeforeUsingThem() throws {
        let collections = try chapter("collections")
        let lesson = collections.lesson
        for term in ["**tuple**", "immutable", "unpacking", "**set**", "set()", ".add(", "`lambda`", "key="] {
            XCTAssertTrue(lesson.contains(term), term)
        }
        let blocks = lessonCode(collections)
        XCTAssertTrue(blocks.contains { $0.contains(", ") && $0.contains(" = pair") }, "tuple unpacking example")
        XCTAssertTrue(blocks.contains { $0.contains("set()") && $0.contains(" in ") && $0.contains("len(") })
        let tupleIntro = try XCTUnwrap(lesson.range(of: "A **tuple**"))
        let sortSection = try XCTUnwrap(lesson.range(of: "## Sort without changing the input"))
        XCTAssertLessThan(tupleIntro.lowerBound, sortSection.lowerBound)
    }

    func testFoundationCodeAvoidsComprehensionsAndLaterSyntax() throws {
        let comprehension = try NSRegularExpression(pattern: "[\\[{(][^\\]})\\n]*\\bfor\\b[^\\]})\\n]*\\bin\\b")
        let laterSyntax = ["enumerate(", "zip(", "yield", "class ", "with open", "match ", "any(", "all("]
        for chapter in Curriculum.chapters where chapter.track == .foundations {
            for code in lessonCode(chapter) + exerciseCode(chapter) {
                let range = NSRange(code.startIndex..., in: code)
                XCTAssertNil(comprehension.firstMatch(in: code, range: range), "\(chapter.id) comprehension: \(code)")
                for term in laterSyntax {
                    XCTAssertFalse(code.contains(term), "\(chapter.id) uses \(term)")
                }
            }
        }
    }

    func testFoundationSectionRolesMarkOnlyOrientationAndDebuggingAdvice() throws {
        let expected: [String: [String: LessonSectionRole]] = [
            "basics": ["Code is a sequence of instructions": .overview],
            "values": ["Build expressions one step at a time": .overview],
            "decisions": [:],
            "loops": ["Trace before guessing": .troubleshooting],
            "functions": ["Replace a function's placeholder, not its interface": .overview, "Test a hypothesis": .troubleshooting],
            "collections": ["Debug the shape": .troubleshooting],
            "reliability": [:]
        ]
        for (id, roles) in expected {
            let current = try chapter(id)
            let sections = current.lessonSections
            XCTAssertEqual(current.sectionRoles, roles, id)
            XCTAssertTrue(Set(current.sectionRoles.keys).isSubset(of: Set(sections.map(\.heading))), "\(id) role keys must match headings")
            XCTAssertEqual(Dictionary(uniqueKeysWithValues: sections.filter { $0.role != .practice }.map { ($0.heading, $0.role) }), roles, id)
            XCTAssertNil(current.generationNotes, id)
        }
        // Concrete skills that reviewed exercises practise stay required.
        let decisions = try chapter("decisions")
        XCTAssertEqual(decisions.lessonSections.first { $0.heading == "Debug the boundaries" }?.role, .practice)
        let basics = try chapter("basics")
        XCTAssertEqual(basics.lessonSections.first { $0.heading == "Work in the editor" }?.role, .practice)
        let functions = try chapter("functions")
        XCTAssertTrue(functions.practiceTopics(for: .debug).contains { $0.title.hasSuffix("Test a hypothesis") })
        XCTAssertFalse(functions.practiceTopics(for: .write).contains { $0.title.hasSuffix("Test a hypothesis") })
    }

    func testPracticeRewardsStayBelowChapterScope() throws {
        for chapter in Curriculum.chapters where chapter.track == .foundations {
            for exercise in chapter.exercises {
                let effort = try XCTUnwrap(exercise.effort, exercise.id)
                XCTAssertLessThan(effort.practiceXP, chapter.practiceTopics.count * 100, exercise.id)
            }
        }
    }
}
