import Foundation
import XCTest
@testable import PythonTeacherCore

final class CurriculumTests: XCTestCase {
    func testChapterOrderAndContentIntegrity() {
        XCTAssertEqual(Curriculum.chapters.filter { $0.track == .foundations }.map(\.id), ["basics", "values", "decisions", "loops", "functions", "collections", "reliability"])
        XCTAssertEqual(Set(Curriculum.chapters.map(\.id)).count, Curriculum.chapters.count)
        var exerciseIDs = Set<String>()
        var questionIDs = Set<String>()
        for chapter in Curriculum.chapters {
            XCTAssertFalse(chapter.title.isEmpty, chapter.id)
            XCTAssertFalse(chapter.subtitle.isEmpty, chapter.id)
            XCTAssertTrue(chapter.lesson.contains("```python\n"), chapter.id)
            let words = chapter.lesson.split(whereSeparator: { $0.isWhitespace }).count
            XCTAssertGreaterThanOrEqual(words, 200, "\(chapter.id): \(words) lesson words")
            XCTAssertGreaterThanOrEqual(chapter.exercises.count, 3, chapter.id)
            XCTAssertEqual(chapter.quiz.count, 3, chapter.id)
            XCTAssertFalse(chapter.exercises.contains { $0.id == chapter.assessment.id }, chapter.id)
            XCTAssertFalse(chapter.exercises.contains { $0.referenceSolution == chapter.assessment.referenceSolution }, chapter.id)
            for exercise in chapter.exercises + [chapter.assessment] {
                XCTAssertTrue(exerciseIDs.insert(exercise.id).inserted, exercise.id)
                XCTAssertTrue(exercise.id.hasPrefix(chapter.id + "-"), exercise.id)
                for value in [exercise.title, exercise.instructions, exercise.starterCode, exercise.referenceSolution, exercise.testCode] {
                    XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, exercise.id)
                }
                XCTAssertNotEqual(exercise.starterCode, exercise.referenceSolution, exercise.id)
                XCTAssertTrue(exercise.testCode.contains("assert "), exercise.id)
                XCTAssertEqual(exercise.hints.count, exercise.id == chapter.assessment.id ? 0 : 3, exercise.id)
                XCTAssertEqual(Set(exercise.hints).count, exercise.hints.count, exercise.id)
                XCTAssertTrue(exercise.hints.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, exercise.id)
                for code in [exercise.starterCode, exercise.referenceSolution, exercise.testCode] {
                    XCTAssertFalse(code.contains("input("), exercise.id)
                    XCTAssertFalse(code.split(separator: "\n").contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }, exercise.id)
                }
            }
            for question in chapter.quiz {
                XCTAssertTrue(questionIDs.insert(question.id).inserted, question.id)
                XCTAssertTrue(question.id.hasPrefix(chapter.id + "-"), question.id)
                XCTAssertFalse(question.prompt.isEmpty, question.id)
                XCTAssertFalse(question.explanation.isEmpty, question.id)
                XCTAssertGreaterThanOrEqual(question.options.count, 3, question.id)
                XCTAssertTrue(question.options.indices.contains(question.correctIndex), question.id)
                XCTAssertTrue(question.options.allSatisfy { !$0.isEmpty }, question.id)
                XCTAssertEqual(Set(question.options).count, question.options.count, question.id)
            }
        }
        XCTAssertEqual(exerciseIDs.count, Curriculum.chapters.reduce(0) { $0 + $1.exercises.count + 1 })
        XCTAssertEqual(questionIDs.count, Curriculum.chapters.count * 3)
    }

    func testCurriculumPrerequisiteGraphIsValid() throws {
        XCTAssertEqual(Curriculum.graph.validationIssues(), [])
        XCTAssertNoThrow(try CurriculumGraph(Curriculum.chapters).validate(rootID: "basics"))
        XCTAssertEqual(Curriculum.chapters.first?.id, CurriculumGraph.rootChapterID)
        XCTAssertEqual(Curriculum.chapters.filter(\.prerequisites.isEmpty).map(\.id), ["basics"])
        let foundations = ["basics", "values", "decisions", "loops", "functions", "collections", "reliability"]
        for (previous, chapter) in zip(foundations, foundations.dropFirst()) {
            XCTAssertEqual(Curriculum.graph.chapter(chapter)?.prerequisites, [previous], "Foundations remain a chain")
        }
        for (index, chapter) in Curriculum.chapters.enumerated() {
            XCTAssertEqual(Set(chapter.prerequisites).count, chapter.prerequisites.count, chapter.id)
            for prerequisite in chapter.prerequisites {
                let prerequisiteIndex = try XCTUnwrap(Curriculum.chapters.firstIndex { $0.id == prerequisite }, "\(chapter.id) requires unknown \(prerequisite)")
                XCTAssertLessThan(prerequisiteIndex, index, "\(chapter.id) must appear after its prerequisite \(prerequisite)")
            }
            XCTAssertNotNil(Curriculum.graph.prerequisiteClosure(of: chapter.id), chapter.id)
        }
    }

    /// Independent recursive closure used to cross-check the graph implementation.
    private func expectedClosure(of chapterID: String) -> Set<String> {
        guard let chapter = Curriculum.chapters.first(where: { $0.id == chapterID }) else { return [] }
        return chapter.prerequisites.reduce(into: Set(chapter.prerequisites)) { $0.formUnion(expectedClosure(of: $1)) }
    }

    func testGenerationCoverageTracksEveryLessonSectionAndPrerequisiteClosure() throws {
        XCTAssertEqual(PracticeGenerationOptions(), .init(scope: .currentChapter, difficulty: .similar, style: .write))
        var ids = Set<String>()
        for chapter in Curriculum.chapters {
            let headings = chapter.lesson.components(separatedBy: .newlines).filter { $0.hasPrefix("# ") || $0.hasPrefix("## ") }
            XCTAssertEqual(chapter.lessonSections.count, headings.count)
            for (index, (section, heading)) in zip(chapter.lessonSections, headings).enumerated() {
                XCTAssertTrue(ids.insert(section.topic.id).inserted)
                XCTAssertEqual(section.topic.id, "\(chapter.id)-section-\(index + 1)", "section IDs stay positional")
                XCTAssertEqual(section.heading, String(heading.drop(while: { $0 == "#" || $0 == " " })))
                XCTAssertTrue(section.topic.title.hasSuffix(section.heading))
            }
            let practice = chapter.lessonSections.filter { $0.role == .practice }.map(\.topic)
            let troubleshooting = chapter.lessonSections.filter { $0.role == .troubleshooting }.map(\.topic)
            XCTAssertEqual(chapter.practiceTopics, practice, chapter.id)
            XCTAssertGreaterThanOrEqual(practice.count, 3, "\(chapter.id) keeps enough required sections for whole-chapter practice")
            for style in PracticeStyle.allCases {
                let expected = chapter.lessonSections.filter { $0.role == .practice || (style == .debug && $0.role == .troubleshooting) }.map(\.topic)
                XCTAssertEqual(chapter.practiceTopics(for: style), expected, "\(chapter.id) \(style)")
                XCTAssertEqual(try PracticeGenerationOptions(style: style).coverageTopics(for: chapter, selectedExercise: nil), expected)
                XCTAssertEqual(try ExperienceRules.generatedEffort(options: .init(style: style), chapter: chapter, selectedExercise: nil),
                               try ExperienceRules.generatedEffort(options: .init(), chapter: chapter, selectedExercise: nil),
                               "format never changes whole-chapter rewards")
            }
            XCTAssertEqual(practice.count + troubleshooting.count + chapter.lessonSections.filter { $0.role == .overview }.count, headings.count)
            for difficulty in PracticeDifficulty.allCases {
                let options = PracticeGenerationOptions(difficulty: difficulty)
                for selected in chapter.exercises {
                    XCTAssertEqual(try options.coverageTopics(for: chapter, selectedExercise: selected), chapter.practiceTopics)
                }
                let project = PracticeGenerationOptions(scope: .project, difficulty: difficulty, scenario: "A synthetic garden planner")
                let closure = expectedClosure(of: chapter.id).union([chapter.id])
                let expected = Curriculum.chapters.filter { closure.contains($0.id) }
                XCTAssertEqual(try project.chapters(for: chapter).map(\.id), expected.map(\.id), chapter.id)
                XCTAssertEqual(try project.chapters(for: chapter).last?.id, chapter.id)
                let topics = try project.coverageTopics(for: chapter, selectedExercise: nil)
                XCTAssertEqual(Array(topics.dropLast()), Array(chapter.practiceTopics.prefix(PracticeGenerationOptions.maximumProjectFocus)), chapter.id)
                XCTAssertEqual(topics.last?.id, PracticeGenerationOptions.projectIntegrationTopicID)
            }
        }
    }

    func testReviewedEffortAndGeneratedScopeRatings() throws {
        for chapter in Curriculum.chapters {
            for exercise in chapter.exercises + [chapter.assessment] {
                XCTAssertNotNil(exercise.effort, exercise.id)
            }
            let assessmentUnits = try XCTUnwrap(chapter.assessment.effort?.scopeUnits)
            XCTAssertEqual(ExperienceRules.generatedUnitCap(scope: .currentChapter, chapter: chapter), assessmentUnits)
            XCTAssertEqual(ExperienceRules.generatedUnitCap(scope: .selectedExercise, chapter: chapter), assessmentUnits)
            XCTAssertEqual(ExperienceRules.generatedUnitCap(scope: .project, chapter: chapter), assessmentUnits + 1)
            let chapterEffort = try ExperienceRules.generatedEffort(options: .init(), chapter: chapter, selectedExercise: nil)
            XCTAssertEqual(chapterEffort.scopeUnits, min(chapter.practiceTopics.count, assessmentUnits))
            XCTAssertLessThanOrEqual(chapterEffort.practiceXP, ExperienceRules.completionXP(effort: chapter.assessment.effort, mode: .assessment))
            for exercise in chapter.exercises {
                let selected = try ExperienceRules.generatedEffort(options: .init(scope: .selectedExercise), chapter: chapter, selectedExercise: exercise)
                XCTAssertEqual(selected.scopeUnits, exercise.effort?.scopeUnits, "reviewed practice never exceeds its assessment workload")
                XCTAssertGreaterThanOrEqual(chapterEffort.practiceXP, selected.practiceXP)
            }
        }
        let chapter = Curriculum.chapters.last!
        let options = PracticeGenerationOptions(scope: .project, difficulty: .harder, projectBriefID: "project-weather-station")
        let effort = try ExperienceRules.generatedEffort(options: options, chapter: chapter, selectedExercise: nil)
        let projectCap = ExperienceRules.generatedUnitCap(scope: .project, chapter: chapter)
        let focusUnits = min(chapter.practiceTopics.count, PracticeGenerationOptions.maximumProjectFocus) + 1
        XCTAssertEqual(effort.scopeUnits, min(focusUnits, projectCap))
        XCTAssertEqual(effort.practiceXP, effort.scopeUnits * 150)
        XCTAssertEqual(projectCap, ExperienceRules.historicalGeneratedUnitCap(chapterID: chapter.id))
        let selectedEffort = effort.capped(at: ExperienceRules.generatedUnitCap(scope: .selectedExercise, chapter: chapter))
        var selected = chapter.exercises[0]
        selected.effort = effort
        for _ in 0..<5 {
            selected.effort = try ExperienceRules.generatedEffort(options: .init(scope: .selectedExercise, difficulty: .harder), chapter: chapter, selectedExercise: selected)
            XCTAssertEqual(selected.effort, selectedEffort)
        }
        selected.instructions = String(repeating: "Long instructions ", count: 100)
        selected.referenceSolution += String(repeating: "\n", count: 100)
        XCTAssertEqual(try ExperienceRules.generatedEffort(options: .init(scope: .selectedExercise, difficulty: .harder), chapter: chapter, selectedExercise: selected), selectedEffort)
        let root = try XCTUnwrap(Curriculum.graph.chapter(CurriculumGraph.rootChapterID))
        XCTAssertThrowsError(try ExperienceRules.generatedEffort(options: .init(scope: .project), chapter: root, selectedExercise: nil))
        XCTAssertThrowsError(try ExperienceRules.generatedEffort(options: .init(scope: .selectedExercise), chapter: chapter, selectedExercise: chapter.assessment))
    }

    func testSectionRolesAndGenerationNotesAreWellFormed() throws {
        for chapter in Curriculum.chapters {
            let headings = Set(chapter.lessonSections.map(\.heading))
            for heading in chapter.sectionRoles.keys {
                XCTAssertTrue(headings.contains(heading), "\(chapter.id) role names a missing heading: \(heading)")
            }
            XCTAssertFalse(chapter.sectionRoles.values.contains(.practice), "\(chapter.id) lists practice explicitly; leave it as the default")
            if let notes = chapter.generationNotes {
                XCTAssertFalse(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, chapter.id)
                XCTAssertLessThanOrEqual(notes.count, 1500, chapter.id)
                let assessment = chapter.assessment
                for line in (assessment.referenceSolution + "\n" + assessment.testCode).components(separatedBy: .newlines)
                    where line.trimmingCharacters(in: .whitespaces).count > 30 {
                    XCTAssertFalse(notes.contains(line.trimmingCharacters(in: .whitespaces)), "\(chapter.id) notes must not reproduce assessment code")
                }
            }
        }
        XCTAssertNotNil(Curriculum.graph.chapter("testing")?.generationNotes, "the testing chapter needs its checking pattern")
    }

    func testProjectFocusFollowsFormatRoles() throws {
        let lesson = "# Why it matters\nOrientation.\n\n## First skill\nText.\n\n## Second skill\nText.\n\n## Common mistakes\nTips.\n"
        let base = try XCTUnwrap(Curriculum.graph.chapter("basics"))
        let chapter = Chapter(id: "basics", title: "Roles", subtitle: "Synthetic", lesson: lesson, exercises: base.exercises,
                              assessment: base.assessment, quiz: base.quiz,
                              sectionRoles: ["Why it matters": .overview, "Common mistakes": .troubleshooting])
        let curriculum = [chapter]
        XCTAssertEqual(chapter.practiceTopics.map(\.id), ["basics-section-2", "basics-section-3"])
        XCTAssertEqual(chapter.practiceTopics(for: .debug).map(\.id), ["basics-section-2", "basics-section-3", "basics-section-4"])
        var options = PracticeGenerationOptions(scope: .project, style: .debug, scenario: "A synthetic recipe scaler",
                                                focusTopicIDs: ["basics-section-4"])
        XCTAssertEqual(try options.coverageTopics(for: chapter, selectedExercise: nil, curriculum: curriculum).map(\.id),
                       ["basics-section-4", PracticeGenerationOptions.projectIntegrationTopicID])
        options.style = .write
        XCTAssertThrowsError(try options.coverageTopics(for: chapter, selectedExercise: nil, curriculum: curriculum),
                             "troubleshooting focus needs the debug format")
        options.normalizeProject(for: chapter, curriculum: curriculum)
        XCTAssertEqual(options.projectFocusIDs(for: chapter), ["basics-section-2", "basics-section-3"])
        options.focusTopicIDs = ["basics-section-1"]
        XCTAssertThrowsError(try options.coverageTopics(for: chapter, selectedExercise: nil, curriculum: curriculum),
                             "overview sections are never focus sections")
        XCTAssertEqual(try ExperienceRules.generatedEffort(options: .init(style: .debug), chapter: chapter, selectedExercise: nil, curriculum: curriculum).scopeUnits,
                       min(2, ExperienceRules.generatedUnitCap(scope: .currentChapter, chapter: chapter)))
    }

    func testProjectBriefCatalogFollowsPrerequisiteGraph() throws {
        let ids = ProjectBrief.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for brief in ProjectBrief.catalog {
            XCTAssertTrue(brief.id.hasPrefix("project-"), brief.id)
            XCTAssertNotNil(Curriculum.graph.chapter(brief.minimumChapterID), brief.id)
            XCTAssertFalse(brief.title.isEmpty)
            XCTAssertTrue((40...400).contains(brief.objective.count), brief.id)
        }
        for chapter in Curriculum.chapters {
            let reachable = expectedClosure(of: chapter.id).union([chapter.id])
            XCTAssertEqual(ProjectBrief.available(for: chapter).map(\.id),
                           ProjectBrief.catalog.filter { reachable.contains($0.minimumChapterID) }.map(\.id), chapter.id)
        }
        let basics = try XCTUnwrap(Curriculum.graph.chapter("basics"))
        let values = try XCTUnwrap(Curriculum.graph.chapter("values"))
        let decisions = try XCTUnwrap(Curriculum.graph.chapter("decisions"))
        let aggregation = try XCTUnwrap(Curriculum.graph.chapter("ds-aggregation"))
        let testing = try XCTUnwrap(Curriculum.graph.chapter("testing"))
        XCTAssertTrue(ProjectBrief.available(for: basics).isEmpty)
        XCTAssertFalse(ProjectBrief.available(for: values).contains { $0.id == "project-vending-machine" })
        for chapter in [decisions, aggregation, testing] {
            XCTAssertTrue(ProjectBrief.available(for: chapter).contains { $0.id == "project-vending-machine" }, chapter.id)
        }
        XCTAssertFalse(ProjectBrief.available(for: testing).contains { $0.id == "project-weather-station" },
                       "data science briefs stay out of the software craft branch")
    }

    func testProjectFocusAndObjectiveValidation() throws {
        let chapter = try XCTUnwrap(Curriculum.graph.chapter("collections"))
        let topics = chapter.practiceTopics
        XCTAssertGreaterThan(topics.count, PracticeGenerationOptions.maximumProjectFocus)
        var options = PracticeGenerationOptions(scope: .project, projectBriefID: "project-vending-machine",
                                                focusTopicIDs: [topics[3].id, topics[1].id])
        let covered = try options.coverageTopics(for: chapter, selectedExercise: nil)
        XCTAssertEqual(covered.map(\.id), [topics[1].id, topics[3].id, PracticeGenerationOptions.projectIntegrationTopicID],
                       "focus follows lesson order")
        XCTAssertEqual(covered.last?.title, "Project integration: Vending machine")
        XCTAssertEqual(options.coverageLabel, "Project · Vending machine")
        XCTAssertEqual(try ExperienceRules.generatedEffort(options: options, chapter: chapter, selectedExercise: nil).scopeUnits,
                       min(3, ExperienceRules.generatedUnitCap(scope: .project, chapter: chapter)))

        for focus in [Array(topics.prefix(4).map(\.id)), [topics[0].id, topics[0].id], ["values-section-1"], ["unknown"]] {
            options.focusTopicIDs = focus
            XCTAssertThrowsError(try options.coverageTopics(for: chapter, selectedExercise: nil), focus.joined(separator: ","))
        }
        options.focusTopicIDs = []
        options.projectBriefID = "project-sales-report"
        XCTAssertThrowsError(try options.coverageTopics(for: chapter, selectedExercise: nil), "brief needs a later chapter")
        options.projectBriefID = "project-unknown"
        XCTAssertThrowsError(try options.coverageTopics(for: chapter, selectedExercise: nil))
        options.projectBriefID = nil
        options.scenario = "   "
        XCTAssertThrowsError(try options.coverageTopics(for: chapter, selectedExercise: nil), "own objective must not be blank")
        options.scenario = "A synthetic recipe scaler"
        XCTAssertEqual(try options.coverageTopics(for: chapter, selectedExercise: nil).last?.title, "Project integration: your objective")
        XCTAssertEqual(options.coverageLabel, "Project · Your own objective")
        XCTAssertEqual(PracticeGenerationOptions().coverageLabel, "Whole current chapter")
    }

    func testProjectChoicesNormalizeAcrossChapters() throws {
        let collections = try XCTUnwrap(Curriculum.graph.chapter("collections"))
        let values = try XCTUnwrap(Curriculum.graph.chapter("values"))
        var options = PracticeGenerationOptions(scope: .project, projectBriefID: "project-library-checkout",
                                                focusTopicIDs: [collections.practiceTopics[0].id])
        options.normalizeProject(for: values)
        XCTAssertEqual(options.projectBriefID, "project-cafe-receipt", "an unavailable brief becomes the first available one")
        XCTAssertEqual(options.focusTopicIDs, [], "other chapters' focus sections are dropped")
        XCTAssertEqual(options.projectFocusIDs(for: values), Array(values.practiceTopics.prefix(3).map(\.id)))
        XCTAssertNoThrow(try options.coverageTopics(for: values, selectedExercise: nil))

        var own = PracticeGenerationOptions(scope: .project, scenario: "A synthetic recipe scaler")
        own.normalizeProject(for: collections)
        XCTAssertNil(own.projectBriefID, "a described own objective is kept")
        var blank = PracticeGenerationOptions(scope: .project)
        blank.normalizeProject(for: collections)
        XCTAssertEqual(blank.projectBriefID, ProjectBrief.available(for: collections).first?.id)
        let basics = try XCTUnwrap(Curriculum.graph.chapter("basics"))
        blank = PracticeGenerationOptions(scope: .project, projectBriefID: "project-vending-machine")
        blank.normalizeProject(for: basics)
        XCTAssertNil(blank.projectBriefID, "chapters without briefs fall back to an own objective")
        XCTAssertThrowsError(try blank.coverageTopics(for: basics, selectedExercise: nil))
    }

    func testFirstChapterDoesNotRequireMethodsOrFormattingSyntax() throws {
        let chapter = try XCTUnwrap(Curriculum.chapters.first)
        XCTAssertEqual(chapter.id, "basics")
        for term in ["variable", "quotes", "print", "Check solution"] {
            XCTAssertTrue(chapter.lesson.contains(term), term)
        }
        for exercise in chapter.exercises + [chapter.assessment] {
            let learnerContent = [exercise.instructions, exercise.starterCode, exercise.referenceSolution].joined(separator: "\n")
            for advancedSyntax in [".strip(", ".lower(", "f'", "f\"", "def ", "for ", "import "] {
                XCTAssertFalse(exercise.starterCode.contains(advancedSyntax), exercise.id)
                XCTAssertFalse(exercise.referenceSolution.contains(advancedSyntax), exercise.id)
            }
            XCTAssertFalse(learnerContent.contains(".strip()"), exercise.id)
            XCTAssertFalse(learnerContent.contains(".lower()"), exercise.id)
        }
    }

    func testTasksHaveExplicitStepsAndExpectedResults() {
        for chapter in Curriculum.chapters {
            for exercise in chapter.exercises + [chapter.assessment] {
                for section in ["Goal:", "Starting code:", "Your task:", "Check:"] {
                    XCTAssertTrue(exercise.instructions.contains(section), "\(exercise.id) missing \(section)")
                }
                XCTAssertTrue(exercise.instructions.contains("Expected result:") || exercise.instructions.contains("Examples:"), exercise.id)
                XCTAssertTrue(exercise.instructions.contains("1. "), exercise.id)
                if exercise.id == chapter.assessment.id {
                    XCTAssertTrue(exercise.instructions.contains("Submit assessment"), exercise.id)
                    XCTAssertFalse(exercise.instructions.contains("Check solution"), exercise.id)
                } else {
                    XCTAssertTrue(exercise.instructions.contains("Check solution"), exercise.id)
                }
            }
        }
    }

    func testStringToolsAreExplainedBeforeTheLabelExercise() throws {
        let chapter = try XCTUnwrap(Curriculum.chapters.first { $0.id == "values" })
        for term in ["method", "parentheses", ".strip()", ".lower()", "len(", "f-string"] {
            XCTAssertTrue(chapter.lesson.contains(term), "Missing explanation for \(term)")
        }
        let exampleBlocks = chapter.lesson.components(separatedBy: "```python\n").dropFirst().map {
            String($0.components(separatedBy: "```")[0])
        }
        XCTAssertTrue(exampleBlocks.contains { $0.contains(".strip()") && !$0.contains(".strip().lower()") })
        XCTAssertTrue(exampleBlocks.contains { $0.contains(".lower()") && !$0.contains(".strip().lower()") })
    }

    func testEveryReferencePassesAndEveryStarterFailsInRestrictedRunner() async throws {
        let runner = PythonRunner()
        let python = ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
        let probe: RunResult
        do {
            probe = try await runner.run(code: "ready = True", tests: "assert ready", pythonPath: python)
        } catch PythonRunnerError.sandboxUnavailable {
            throw XCTSkip("macOS sandbox unavailable; no unrestricted curriculum execution attempted.")
        } catch PythonRunnerError.interpreterDiscovery(let reason) {
            throw XCTSkip("Python unavailable: \(reason). Set PYTHON_TEACHER_TEST_PYTHON to an interpreter binary.")
        }
        if probe.output.contains("sandbox_apply:") || probe.output.contains("sandbox-exec: Operation not permitted") {
            throw XCTSkip("This environment refuses sandbox creation: \(probe.output)")
        }
        XCTAssertTrue(probe.passed, probe.output)
        guard probe.passed else { return }
        for chapter in Curriculum.chapters {
            for exercise in chapter.exercises + [chapter.assessment] {
                let reference = try await runner.run(code: exercise.referenceSolution, tests: exercise.testCode, pythonPath: python)
                XCTAssertTrue(reference.passed, "\(exercise.id) reference: \(reference.output)")
                XCTAssertEqual(reference.exitCode, 0, exercise.id)
                XCTAssertFalse(reference.timedOut, exercise.id)
                let starter = try await runner.run(code: exercise.starterCode, tests: exercise.testCode, pythonPath: python)
                XCTAssertFalse(starter.passed, "\(exercise.id) starter unexpectedly passed")
                XCTAssertFalse(starter.timedOut, exercise.id)
                XCTAssertFalse(starter.cancelled, exercise.id)
                XCTAssertEqual(starter.diagnostic?.exceptionType, exercise.expectedStarterError ?? "AssertionError",
                               "\(exercise.id) starter must fail for its authored reason, not infrastructure: \(starter.output)")
            }
        }
    }

    func testLessonExamplesExecute() async throws {
        let runner = PythonRunner()
        let python = ProcessInfo.processInfo.environment["PYTHON_TEACHER_TEST_PYTHON"] ?? "/usr/bin/python3"
        for chapter in Curriculum.chapters {
            let blocks = chapter.lesson.components(separatedBy: "```python\n").dropFirst()
            for block in blocks {
                let code = String(block.components(separatedBy: "```")[0])
                let result: RunResult
                do {
                    result = try await runner.run(code: code, pythonPath: python)
                } catch PythonRunnerError.sandboxUnavailable {
                    throw XCTSkip("macOS sandbox unavailable; lesson examples were not executed.")
                } catch PythonRunnerError.interpreterDiscovery(let reason) {
                    throw XCTSkip("Python unavailable: \(reason)")
                }
                if result.output.contains("sandbox_apply:") || result.output.contains("sandbox-exec: Operation not permitted") {
                    throw XCTSkip("This environment refuses sandbox creation: \(result.output)")
                }
                XCTAssertTrue(result.passed, "\(chapter.id) lesson: \(result.output)")
            }
        }
    }
}
