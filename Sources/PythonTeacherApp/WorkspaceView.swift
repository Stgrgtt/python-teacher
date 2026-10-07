import PythonTeacherCore
import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var model: AppModel
    @State private var assessmentTab = 0
    @State private var confirmReset = false
    @State private var confirmOverride = false
    @State private var chaptersPresented = false
    @State private var focusPresented = false
    @State private var progressPresented = false
    @State private var generationPresented = false
    @State private var generationOptions = PracticeGenerationOptions()
    @State private var pendingGeneration: PracticeGenerationOptions?
    @State private var validationDetailsPresented = false
    @State private var confirmGenerationRepair = false
    @State private var lessonParts: [String: Int] = [:]
    @State private var rewardDetailsExpanded = false
    @AppStorage(AppearanceKey.lessonLayout) private var lessonLayout = LessonLayout.paced
    @AppStorage(AppearanceKey.codeSize) private var codeSize = 14.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let forceReducedMotion: Bool

    init(assessmentTab: Int = 0, forceReducedMotion: Bool = false) {
        _assessmentTab = State(initialValue: assessmentTab)
        self.forceReducedMotion = forceReducedMotion
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                instructionPanel.frame(minWidth: 320, idealWidth: 420, maxWidth: 640)
                codingWorkspace
                    .disabled(!model.isUnlocked)
                    .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
                TeacherPanel().frame(minWidth: 275, idealWidth: 310, maxWidth: 390)
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 1080, minHeight: 740)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlayPreferenceValue(PlayerBarAnchorKey.self) { anchor in
            GeometryReader { geometry in
                if let anchor, let reward = model.rewardCelebration {
                    let bar = geometry[anchor]
                    RewardEffectsOverlay(reward: reward, origin: CGPoint(x: bar.midX, y: bar.midY),
                                         effectsEnabled: model.progress.celebrationEffectsEnabled,
                                         forceReducedMotion: forceReducedMotion)
                        .id(reward.id)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .sheet(isPresented: $model.settingsPresented) { SettingsView().environmentObject(model) }
        .sheet(isPresented: $generationPresented, onDismiss: {
            if let options = pendingGeneration {
                pendingGeneration = nil
                model.generatePractice(options: options)
            }
        }) {
            PracticeGeneratorView(options: $generationOptions) { options in
                pendingGeneration = options
                generationPresented = false
            }.environmentObject(model)
        }
        .sheet(isPresented: $validationDetailsPresented) {
            if model.mode != .assessment, let rejected = model.rejectedPractice {
                GenerationValidationDetailsView(rejected: rejected).environmentObject(model)
            }
        }
        .confirmationDialog("Repair this rejected exercise with one more AI request?", isPresented: $confirmGenerationRepair) {
            Button("Send repair request") { model.repairGeneratedPractice() }
        } message: {
            Text("This sends the rejected AI exercise and its local validation evidence to \(model.progress.provider.name), not your current draft. API charges and the request limit apply. The repaired result must pass the same validation before it is added.")
        }
        .alert("Python Teacher", isPresented: Binding(get: { model.notice != nil && !model.settingsPresented }, set: { if !$0 && !model.settingsPresented { model.notice = nil } })) {
            Button("OK") { model.notice = nil }
        } message: { Text(model.notice ?? "") }
        .confirmationDialog("Restore starter code? Your current unsubmitted edits will be replaced. Submitted attempts are kept.", isPresented: $confirmReset) {
            Button("Restore starter", role: .destructive) { model.resetDraft() }
        }
        .confirmationDialog(model.overrideConfirmationTitle, isPresented: $confirmOverride) {
            Button("Record override and unlock") { model.overrideUnlock() }
        }
        .onChange(of: model.mode) { _, mode in
            assessmentTab = 0
            if mode == .assessment { validationDetailsPresented = false; confirmGenerationRepair = false }
        }
        .appearanceEnvironment()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "graduationcap.fill").font(.system(size: 25)).foregroundStyle(.teal)
            Text("Python Teacher").appFont(.headline).fixedSize()
            Spacer(minLength: 8)
            ZStack {
                if let reward = model.rewardCelebration {
                    RewardCelebrationView(reward: reward, effectsEnabled: model.progress.celebrationEffectsEnabled, forceReducedMotion: forceReducedMotion) {
                        model.dismissCelebration()
                    }
                    .id(reward.id)
                }
            }.frame(width: 280, height: 44)
            Button { focusPresented.toggle() } label: {
                Label(focusLabel, systemImage: model.progress.activeStudySession == nil ? "timer" : model.focusRunning ? "timer.circle.fill" : "pause.circle")
                    .appFont(.callout, monospacedDigit: true).frame(minWidth: 85)
            }
            .help("Saved focus sessions · 25 minutes earns 50 XP")
            .accessibilityLabel(model.progress.activeStudySession == nil ? "Start a focus session" : "Focus session \(model.focusRunning ? "running" : "paused"), \(model.focusRemainingSeconds / 60) minutes and \(model.focusRemainingSeconds % 60) seconds remaining")
            .popover(isPresented: $focusPresented) { FocusSessionView().environmentObject(model) }
            playerProgressButton
            Button { model.settingsPresented = true } label: { Image(systemName: "gearshape") }
                .help("Settings and API key").accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private var focusLabel: String {
        guard model.progress.activeStudySession != nil else { return "Focus" }
        let remaining = max(0, model.focusRemainingSeconds)
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private var playerProgressButton: some View {
        let player = model.progress.playerProgress
        let animate = !reduceMotion && !forceReducedMotion && model.progress.celebrationEffectsEnabled
        return Button { progressPresented.toggle() } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Level \(player.level)").appFont(.caption, weight: .bold).contentTransition(.numericText())
                    Spacer(minLength: 0)
                    Text("\(player.xpRemaining) XP to next")
                        .appFont(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
                ProgressView(value: player.fraction).tint(.teal)
                    .accessibilityHidden(true)
            }
            .frame(width: 190).padding(.horizontal, 10).padding(.vertical, 7)
            .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .anchorPreference(key: PlayerBarAnchorKey.self, value: .bounds) { $0 }
        .animation(animate ? .spring(response: 0.45, dampingFraction: 0.85) : nil, value: player.totalXP)
        .accessibilityLabel("Study effort level \(player.level), \(player.totalXP) total XP, \(player.xpRemaining) XP to next level")
        .accessibilityHint("Open player progress, rewards, and history")
        .help("Player level measures study effort, not chapter mastery")
        .popover(isPresented: $progressPresented) { PlayerProgressView().environmentObject(model) }
    }

    private var instructionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { chaptersPresented.toggle() } label: {
                    Label("Chapters", systemImage: "sidebar.left")
                }
                .help("Browse chapters and review your progress")
                .popover(isPresented: $chaptersPresented, arrowEdge: .leading) {
                    ChapterBrowserView { chaptersPresented = false }.environmentObject(model)
                        .frame(width: 310, height: 580)
                }
                Spacer()
                Text("\(model.masteryCount)/\(model.chapters.count) mastered")
                    .appFont(.caption, monospacedDigit: true).foregroundStyle(.secondary)
            }.padding(.horizontal, 16).padding(.top, 14)
            chapterHeader
            Divider()
            if !model.isUnlocked {
                ScrollView { lockedChapter }
            } else if model.mode == .lesson {
                lesson
            } else {
                if model.mode == .practice { exerciseControls }
                if model.mode == .assessment {
                    if model.assessments.count > 1 {
                        Picker("Assessment version", selection: Binding(get: { model.exercise.id }, set: { model.selectAssessment($0) })) {
                            ForEach(model.assessments) { exercise in Text(exercise.title).tag(exercise.id) }
                        }.padding(.horizontal, 12).padding(.top, 12).disabled(model.isBusy)
                    }
                    Picker("Assessment section", selection: $assessmentTab) {
                        Text("Coding task").tag(0)
                        Text("Theory & explanation").tag(1)
                    }.pickerStyle(.segmented).labelsHidden().padding(12)
                }
                Divider()
                if model.mode == .assessment && assessmentTab == 1 {
                    assessmentQuestions
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            exerciseHeader
                            if model.exercise.id.hasPrefix("generated-") && !model.exercise.hasRequiredInstructionSections {
                                Label("These saved instructions may be incomplete: required sections are missing or empty. Use New with AI to create a new variation, or choose a reviewed exercise. Your existing work is preserved.", systemImage: "exclamationmark.triangle")
                                    .appFont(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                            }
                            if model.isLegacyExercise {
                                Text("Saved legacy activity: original requirements, code and assistance history are preserved. The revised activity has a separate draft but shares completion XP. Legacy decisions use lists and loops, now taught in Loops and accumulators; new learners should use the revised activity.")
                                    .appFont(.callout).foregroundStyle(.secondary)
                            }
                            MarkdownContent(text: model.exercise.instructions)
                        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    }.id(model.exercise.id)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var chapterHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.chapter.title).appFont(.title2, weight: .bold)
                Spacer()
                if model.progress.masteredChapterIDs.contains(model.chapter.id) {
                    Label("Mastered", systemImage: "checkmark.seal.fill").appFont(.caption).foregroundStyle(.teal)
                }
            }
            Picker("Learning mode", selection: Binding(get: { model.mode }, set: { model.selectMode($0) })) {
                ForEach(LearningMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
            }.pickerStyle(.segmented).labelsHidden().disabled(model.isBusy || !model.isUnlocked)
        }.padding(20)
    }

    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.exercise.id.hasPrefix("generated-") ? "AI-GENERATED PRACTICE" : model.mode == .assessment ? "INDEPENDENT ASSESSMENT" : "REVIEWED PRACTICE")
                .appFont(.caption, weight: .semibold).tracking(0.8).foregroundStyle(.teal)
            Text(model.exercise.title).appFont(.title2, weight: .bold).fixedSize(horizontal: false, vertical: true)
            DisclosureGroup(isExpanded: $rewardDetailsExpanded) {
                Text(model.exerciseRewardDetails)
                    .appFont(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
            } label: {
                Label(model.exerciseRewardSummary, systemImage: "sparkles")
                    .appFont(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .help("Show how this exercise's XP is calculated")
        }
    }

    private var lesson: some View {
        let parts = MarkdownDocument.lessonParts(model.chapter.lesson)
        let paced = lessonLayout == .paced && parts.count > 1
        let index = min(lessonParts[model.chapter.id] ?? 0, max(parts.count - 1, 0))
        let isLast = !paced || index == parts.count - 1
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Group {
                        if paced { lessonProgress(parts, index: index) }
                        else { Label("One concept at a time", systemImage: "book.closed").appFont(.subheadline).foregroundStyle(.teal) }
                    }.id("lesson-top")
                    MarkdownContent(text: paced ? parts[index].markdown : model.chapter.lesson)
                        .id("\(model.chapter.id)-\(paced ? index : -1)")
                    if paced { lessonNavigation(parts, index: index) }
                    if isLast { lessonWrapUp }
                }.padding(24).frame(maxWidth: 820, alignment: .leading).frame(maxWidth: .infinity)
            }
            .onChange(of: index) { _, _ in proxy.scrollTo("lesson-top", anchor: .top) }
        }
    }

    private func showLessonPart(_ index: Int) {
        lessonParts[model.chapter.id] = index
    }

    private func lessonProgress(_ parts: [MarkdownDocument.LessonPart], index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Part \(index + 1) of \(parts.count)", systemImage: "book.closed")
                    .appFont(.subheadline, weight: .semibold).foregroundStyle(.teal)
                Spacer()
                Menu {
                    ForEach(parts) { part in
                        Button { showLessonPart(part.id) } label: {
                            if part.id == index { Label(part.title, systemImage: "checkmark") } else { Text(part.title) }
                        }
                    }
                } label: { Label("Contents", systemImage: "list.bullet") }
                    .menuStyle(.borderlessButton).fixedSize().appFont(.caption)
                    .help("Jump to any part of this lesson")
            }
            HStack(spacing: 4) {
                ForEach(parts) { part in
                    Capsule().fill(part.id <= index ? Color.teal : Color.secondary.opacity(0.2)).frame(height: 4)
                        .contentShape(Rectangle().inset(by: -6))
                        .onTapGesture { showLessonPart(part.id) }
                        .help(part.title)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lesson progress")
            .accessibilityValue("Part \(index + 1) of \(parts.count): \(parts[index].title)")
        }
    }

    private func lessonNavigation(_ parts: [MarkdownDocument.LessonPart], index: Int) -> some View {
        HStack(spacing: 12) {
            if index > 0 {
                Button { showLessonPart(index - 1) } label: { Label("Back", systemImage: "chevron.left") }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            }
            Spacer(minLength: 0)
            if index < parts.count - 1 {
                Button { showLessonPart(index + 1) } label: {
                    HStack(spacing: 6) {
                        Text("Next: \(parts[index + 1].title)").lineLimit(1).truncationMode(.tail)
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent).tint(.teal)
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .help("Continue to the next part (⌥⌘→)")
            }
        }
        .padding(.top, 6)
    }

    private var lessonWrapUp: some View {
        VStack(alignment: .leading, spacing: 22) {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Make it yours").appFont(.headline)
                    Text("Before opening the exercise, explain the main idea in your own words. Then write the code yourself—even when an example looks familiar.").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            model.completeLesson()
                        } label: {
                            Label(model.progress.lessonCompletions[model.chapter.id] == nil ? "Mark lesson read · +25 XP" : "Lesson marked read · XP saved",
                                  systemImage: model.progress.lessonCompletions[model.chapter.id] == nil ? "checkmark.circle" : "checkmark.circle.fill")
                        }
                        .disabled(model.progress.lessonCompletions[model.chapter.id] != nil || model.storageLocked)
                        Text("Your own check-in, not a mastery assessment. Awarded once per lesson.")
                            .appFont(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Button("Start hands-on practice") { model.selectMode(.practice) }.buttonStyle(.borderedProminent).tint(.teal)
                        Button("Already know this? Take the assessment") { model.selectMode(.assessment) }.buttonStyle(.link)
                    }.padding(.top, 5)
                }
                if !model.currentAttempts.isEmpty {
                    Divider()
                    Text("Recent attempts").appFont(.headline)
                    ForEach(model.currentAttempts.prefix(5)) { attempt in
                        HStack {
                            Image(systemName: attempt.demonstratesMastery ? "checkmark.seal" : attempt.testsPassed ? "checkmark.circle" : "arrow.clockwise")
                                .foregroundStyle(attempt.testsPassed ? Color.teal : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attempt.mode == .assessment ? (attempt.demonstratesMastery ? "Assessment passed" : "Assessment: more practice needed") : (attempt.testsPassed ? "Practice checks passed" : "Practice: checks not passed")).appFont(.callout)
                                Text(attempt.exerciseID).appFont(.caption, design: .monospaced).foregroundStyle(.secondary)
                                Text("\(attempt.hintCount) hints / teacher requests\(attempt.solutionRevealed ? " · solution viewed" : "")").appFont(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(attempt.date, style: .date).appFont(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
        }
    }

    private var codingWorkspace: some View {
        VStack(spacing: 0) {
            HStack {
                Label("main.py", systemImage: "doc.text").appFont(.caption, design: .monospaced)
                if model.mode == .lesson { Text("Practice draft").appFont(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button { model.exportCode() } label: { Image(systemName: "square.and.arrow.up") }.help("Export Python file").accessibilityLabel("Export Python file")
                Button("Restore starter") { confirmReset = true }.appFont(.caption).disabled(model.isBusy)
            }.buttonStyle(.borderless).padding(.horizontal, 14).padding(.vertical, 12)
            Divider()
            VSplitView {
                CodeEditor(text: $model.code, editable: !model.isBusy && model.isUnlocked, fontSize: codeSize.clamped(to: AppearanceKey.codeRange))
                    .id(model.draftKey).frame(minHeight: 330, maxHeight: .infinity)
                outputPanel.frame(minHeight: 80, idealHeight: 155, maxHeight: .infinity)
            }
            if model.mode == .practice {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "pencil.and.outline").foregroundStyle(.secondary).padding(.top, 4)
                    TextField("Reflection: why does your solution work?", text: $model.reflection, axis: .vertical)
                        .lineLimit(1...3).textFieldStyle(.plain).appFont(.callout).disabled(model.isBusy)
                }.padding(12)
            }
            Divider()
            runControls
        }
    }

    private var exerciseControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Exercise", selection: Binding(get: { model.exercise.id }, set: { model.selectExercise($0) })) {
                ForEach(model.exercises) { exercise in
                    Text(model.exercisePickerTitle(exercise)).tag(exercise.id)
                        .accessibilityLabel("\(exercise.title), \(model.completedPracticeExerciseIDs.contains(exercise.id) ? "previously passed checks" : "not completed")")
                }
            }.labelsHidden().frame(maxWidth: .infinity).disabled(model.isBusy)
            Text("✓ Previously passed checks · \(model.completedPracticeExerciseIDs.count)/\(model.exercises.count) completed")
                .appFont(.caption).foregroundStyle(.secondary)
                .help("Includes guided solutions. A checkmark records a past successful Check solution, not verification of your current draft or chapter mastery.")
            Button {
                generationOptions.normalizeProject(for: model.chapter, curriculum: model.chapters)
                generationPresented = true
            } label: { Label("New with AI…", systemImage: "plus") }
            .help("Choose a project or coverage, chapter-relative difficulty and format before generating.")
            .disabled(model.storageLocked || model.isBusy)
            if let message = model.generationState.message {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        if model.generationState.isInProgress {
                            ProgressView().controlSize(.small)
                        } else if case .failed = model.generationState {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        } else {
                            Image(systemName: "info.circle").foregroundStyle(.teal)
                        }
                        Text(message).appFont(.caption).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if model.rejectedPractice != nil && !model.generationState.isInProgress {
                        HStack {
                            Button("Validation details…") { validationDetailsPresented = true }
                            Button("Repair with AI…") { confirmGenerationRepair = true }
                                .disabled(!model.canRepairGeneratedPractice)
                                .help("One additional AI request using the rejected exercise and error. Return to its chapter to repair it.")
                        }.appFont(.caption)
                    }
                    HStack {
                        if model.generationState.isInProgress {
                            Button("Cancel generation") { model.cancelWork() }
                        } else {
                            if case .ready = model.generationState {
                                Button("Open exercise") { model.openGeneratedPractice() }.disabled(model.isBusy)
                            }
                            Spacer()
                            Button("Dismiss") { model.dismissGenerationStatus() }
                        }
                    }.appFont(.caption)
                }.padding(10).background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }.padding(12)
    }

    private var assessmentQuestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Show what you understand").appFont(.title3, weight: .bold)
                Text("Pass the coding checks and all three theory questions. Documentation is allowed; teacher assistance is disabled. Your written explanation is saved for reflection, not automatically graded.").appFont(.callout).foregroundStyle(.secondary)
                ForEach(Array(model.chapter.quiz.enumerated()), id: \.element.id) { index, question in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(index + 1). \(question.prompt)").appFont(.headline)
                        ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
                            Button { model.setAnswer(optionIndex, question: question.id) } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: model.quizAnswers[question.id] == optionIndex ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(model.quizAnswers[question.id] == optionIndex ? Color.teal : .secondary)
                                    Text(option).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }.padding(10).background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(.plain).disabled(model.isBusy)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explain your approach").appFont(.headline)
                    Text("How does your code work? Which edge case did you consider? What would you change if the requirements changed?").appFont(.callout).foregroundStyle(.secondary)
                    TextEditor(text: $model.reflection).appFont(.body).frame(minHeight: 110).padding(6)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8)).disabled(model.isBusy)
                }
            }.padding(20)
        }
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("OUTPUT & CHECKS", systemImage: "terminal").appFont(.caption2, weight: .semibold)
                if model.isOutputStale { Text("Previous code version").appFont(.caption2).foregroundStyle(.orange) }
                Spacer()
                if model.running { ProgressView().controlSize(.mini) }
            }.foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 9)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        Text(model.output).font(.system(size: codeSize.clamped(to: AppearanceKey.codeRange) - 2, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !model.feedback.isEmpty {
                        Text(model.feedback).appFont(.callout).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var runControls: some View {
        HStack(spacing: 10) {
            Button { model.runCode() } label: { Label("Run", systemImage: "play.fill") }
                .keyboardShortcut("r", modifiers: .command).disabled(model.isBusy)
            if model.mode == .practice {
                Button { model.runCode(test: true) } label: { Label("Check solution", systemImage: "checkmark.circle") }
                    .buttonStyle(.borderedProminent).tint(.teal).keyboardShortcut("r", modifiers: [.command, .shift]).disabled(model.isBusy)
            } else if model.mode == .assessment {
                Button("Submit assessment") { model.runCode(test: true, submit: true) }
                    .buttonStyle(.borderedProminent).tint(.teal).disabled(model.isBusy)
            }
            if model.isBusy { Button("Stop", role: .cancel) { model.cancelWork() } }
            Spacer()
            Text(model.mode == .assessment ? "Independent attempt" : model.solutionRevealed ? "Solution viewed" : "\(model.hintCount) assists")
                .appFont(.caption).foregroundStyle(.secondary)
        }.padding(12)
    }

    private var lockedChapter: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.open").font(.system(size: 35)).foregroundStyle(.teal)
            Text("Build on a solid foundation").appFont(.title2, weight: .bold)
            Text(model.lockedChapterExplanation)
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 430)
                .fixedSize(horizontal: false, vertical: true)
            if let first = model.missingPrerequisites.first {
                Button("Go to \(first.title)") { model.selectChapter(first.id) }
                    .buttonStyle(.borderedProminent).tint(.teal).disabled(model.isBusy)
                ForEach(model.missingPrerequisites.dropFirst()) { chapter in
                    Button("Go to \(chapter.title)") { model.selectChapter(chapter.id) }
                        .buttonStyle(.link).disabled(model.isBusy)
                }
            } else {
                Button("Start from \(model.rootChapter.title)") { model.selectChapter(model.rootChapter.id) }
                    .buttonStyle(.borderedProminent).tint(.teal).disabled(model.isBusy)
            }
            Button(model.overrideButtonTitle) { confirmOverride = true }
            Text("An override unlocks study, but never marks a chapter mastered.").appFont(.caption).foregroundStyle(.secondary)
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack(spacing: 15) {
            Label(model.saveStatus, systemImage: model.storageLocked ? "exclamationmark.triangle" : "internaldrive")
            Spacer()
            Text("Python · local execution")
            Divider().frame(height: 10)
            Text("AI: \(model.requestCount)/\(model.progress.sessionRequestLimit) requests this launch")
        }.appFont(.caption2).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 7)
    }
}

struct GenerationValidationDetailsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let rejected: RejectedPractice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Generated exercise validation").appFont(.title2, weight: .bold)
            Text("This report includes the rejected AI exercise's reference answer and tests, not your current draft or API key. It is kept only for this session. Copy it if you need help diagnosing the failure.")
                .appFont(.callout).foregroundStyle(.secondary)
            ScrollView {
                Text(rejected.report).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Copy report") { model.copyGenerationReport() }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(width: 640, height: 540)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PracticeGeneratorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Binding var options: PracticeGenerationOptions
    let generate: (PracticeGenerationOptions) -> Void

    private var topics: [PracticeTopic] {
        (try? options.coverageTopics(for: model.chapter, selectedExercise: model.exercise, curriculum: model.chapters)) ?? []
    }

    private var briefs: [ProjectBrief] { ProjectBrief.available(for: model.chapter, curriculum: model.chapters) }

    private var brief: ProjectBrief? { briefs.first { $0.id == options.projectBriefID } }

    private var scenarioPrompt: String {
        guard options.scope == .project else { return "Optional scenario, e.g. a library or a garden" }
        return brief == nil ? "Describe what you want to build, e.g. a recipe scaler" : "Optional twist, e.g. a space-station snack machine"
    }

    private func focusBinding(_ topic: PracticeTopic) -> Binding<Bool> {
        Binding(get: { options.projectFocusIDs(for: model.chapter).contains(topic.id) }, set: { included in
            let current = Set(options.projectFocusIDs(for: model.chapter))
            let updated = included ? current.union([topic.id]) : current.subtracting([topic.id])
            options.focusTopicIDs = model.chapter.practiceTopics(for: options.style).map(\.id).filter(updated.contains)
        })
    }

    private var projectChoices: some View {
        VStack(alignment: .leading, spacing: 7) {
            Picker("Objective", selection: $options.projectBriefID) {
                ForEach(briefs) { Text($0.title).tag(Optional($0.id)) }
                Text("My own objective…").tag(String?.none)
            }
            Text(brief?.objective ?? "Describe your objective in the field below. It is treated as theme data only.")
                .appFont(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Focus · 1–\(PracticeGenerationOptions.maximumProjectFocus) sections from this chapter").appFont(.subheadline, weight: .bold).padding(.top, 4)
            let focus = options.projectFocusIDs(for: model.chapter)
            ForEach(model.chapter.practiceTopics(for: options.style)) { topic in
                let selected = focus.contains(topic.id)
                Toggle(String(topic.title.dropFirst(model.chapter.title.count + 2)), isOn: focusBinding(topic))
                    .appFont(.callout)
                    .disabled(selected ? focus.count == 1 : focus.count >= PracticeGenerationOptions.maximumProjectFocus)
            }
            Text(model.prerequisiteChapters.isEmpty ? "Toolkit: this is the first chapter, so the project uses only this lesson."
                 : "Toolkit (allowed, not required): \(model.prerequisiteChapters.map(\.title).joined(separator: "; "))")
                .appFont(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create a practice challenge").appFont(.title2, weight: .bold)
            Text(model.chapter.title).appFont(.subheadline).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Picker("Coverage", selection: $options.scope) {
                            ForEach(PracticeScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .onChange(of: options.scope) { _, _ in options.normalizeProject(for: model.chapter, curriculum: model.chapters) }
                        Text(options.scope.explanation).appFont(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if options.scope == .selectedExercise {
                            Text("Selected: \(model.exercise.title)").appFont(.callout)
                        }
                    }
                    if options.scope == .project { projectChoices }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Difficulty · relative to this chapter's reviewed practice").appFont(.subheadline, weight: .bold)
                        Picker("Difficulty", selection: $options.difficulty) {
                            ForEach(PracticeDifficulty.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                        Text(options.difficulty.explanation).appFont(.callout).foregroundStyle(.secondary)
                        Text("More coverage can mean more steps, even on Easier.").appFont(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Format", selection: $options.style) {
                        ForEach(PracticeStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: options.style) { _, _ in options.normalizeProject(for: model.chapter, curriculum: model.chapters) }
                    VStack(alignment: .leading, spacing: 5) {
                        TextField(scenarioPrompt, text: $options.scenario, axis: .vertical)
                            .lineLimit(2...3).textFieldStyle(.roundedBorder)
                            .accessibilityLabel(options.scope == .project && brief == nil ? "Project objective" : "Optional scenario preference")
                            .onChange(of: options.scenario) { _, value in
                                if value.count > 400 { options.scenario = String(value.prefix(400)) }
                            }
                        Text("Use synthetic or public examples only. Sent to \(model.progress.provider.name). \(options.scenario.count)/400 characters.")
                            .appFont(.caption).foregroundStyle(.secondary)
                    }
                    DisclosureGroup(options.scope == .project ? "Required coverage · \(max(0, topics.count - 1)) focus sections + integration"
                                    : "Requested coverage · \(topics.count) \(options.scope == .selectedExercise ? "exercise" : "lesson sections")") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(topics) { Text($0.title).appFont(.caption).frame(maxWidth: .infinity, alignment: .leading) }
                        }.padding(.top, 8)
                    }
                    if let effort = try? ExperienceRules.generatedEffort(options: options, chapter: model.chapter, selectedExercise: model.exercise, curriculum: model.chapters) {
                        let maximum = ExerciseEffort(difficulty: options.difficulty,
                            scopeUnits: ExperienceRules.generatedUnitCap(scope: options.scope, chapter: model.chapter)).practiceXP
                        Label(maximum > effort.practiceXP ? "First success · +\(effort.practiceXP)–\(maximum) XP" : "First success · +\(effort.practiceXP) XP", systemImage: "sparkles")
                            .appFont(.callout, weight: .bold).foregroundStyle(.teal)
                        Text("Coverage sets the minimum workload. Local analysis of the generated starter and reference can increase it for additional work, up to the chapter assessment's workload (one more unit for projects). The exact reward appears on the finished exercise. Viewing the solution halves XP.")
                            .appFont(.caption).foregroundStyle(.secondary)
                    }
                    Text("One AI request; your current draft is kept. Requires a \(model.progress.provider.name) API key and cloud consent. Broad challenges can use more tokens and cost more. The app checks the coverage checklist and runs the reference and starter, but cannot guarantee the AI covered every concept correctly.")
                        .appFont(.caption).foregroundStyle(.secondary)
                }.padding(.trailing, 6)
            }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Generate challenge") { generate(options) }
                    .buttonStyle(.borderedProminent).tint(.teal).keyboardShortcut(.defaultAction)
                    .disabled(topics.isEmpty || model.isBusy || model.storageLocked || !model.isUnlocked || model.mode == .assessment)
            }
        }.padding(24).frame(width: 540, height: 590)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PlayerProgressView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Your player progress", systemImage: "sparkles").appFont(.headline)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).accessibilityLabel("Close player progress")
            }.padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    levelCard
                    if model.needsRewardUpdate {
                        Text(model.updatingRewards ? "Analyzing saved exercises and recalculating XP…" : "Earlier rewards need to be recalculated using difficulty and workload. Past totals and your level may change.")
                            .appFont(.callout).foregroundStyle(.secondary)
                        Button("Update XP ratings") { model.upgradeExperience() }
                            .disabled(model.isBusy || model.storageLocked)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(model.masteryCount)/\(model.chapters.count) assessments passed", systemImage: "checkmark.seal")
                            .appFont(.subheadline, weight: .bold)
                        Text("Player level measures study effort, NOT chapter mastery. Only passed assessments demonstrate mastery; XP and levels never unlock chapters.")
                            .appFont(.callout).foregroundStyle(.secondary)
                    }
                    milestones
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Every kind of effort counts").appFont(.headline)
                        rewardRule("First successful practice", detail: "50 / 100 / 150 XP per workload unit for Easier / Similar / Harder, relative to the chapter. Hints are welcome.", amount: "Scaled")
                        rewardRule("Reference-guided practice", detail: "First success after viewing the solution earns half the task's reward.", amount: "50%")
                        rewardRule("First full assessment passed", detail: "Three times the task's practice value. Coding checks and theory, independently.", amount: "3×")
                        rewardRule("Lesson marked read", detail: "Self-reported, once per lesson.", amount: "+25 XP")
                        rewardRule("Independent successful retake", detail: "Same task, 7 days after your last independent success. An earlier success restarts the wait.", amount: "+25 XP")
                        rewardRule("Completed focus session", detail: "25 active minutes. Pauses are always welcome.", amount: "+50 XP")
                        Text("Reviewed tasks have authored ratings. AI tasks use requested coverage plus a local estimate of changed result assignments and function work in the starter/reference, capped at the chapter assessment's workload (one more unit for projects). Older tasks without difficulty metadata use an estimated difficulty. Learner code length never affects XP.")
                            .appFont(.caption).foregroundStyle(.secondary)
                        Text("Past completion rewards are recalculated once when rules change; totals and levels can change, but no duplicate completions are added. Saved AI tasks receive the project cap. Missing exercises retain their last known reward within that cap. Old unsaved timer activity cannot be recovered. Breaks never cost XP; there are no streak penalties.")
                            .appFont(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    experienceHistory
                    Divider()
                    Toggle("Celebration effects", isOn: Binding(
                        get: { model.progress.celebrationEffectsEnabled },
                        set: { model.setCelebrationEffectsEnabled($0) }
                    ))
                    .disabled(model.storageLocked)
                    Text("XP feedback and history stay visible with effects off. Reduce Motion is always respected. No sounds.")
                        .appFont(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
        }
        .frame(width: 410, height: 620)
    }

    private var levelCard: some View {
        let player = model.progress.playerProgress
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Level \(player.level)").appFont(.largeTitle, weight: .bold).contentTransition(.numericText())
                Image(systemName: "infinity").appFont(.title3).foregroundStyle(.secondary)
                    .accessibilityLabel("No level cap")
                Spacer()
            }
            Text(player.rankTitle).appFont(.headline).foregroundStyle(.teal)
            ProgressView(value: player.fraction).tint(.teal)
            HStack {
                Text("\(player.totalXP.formatted()) XP earned")
                Spacer()
                Text("\(player.xpRemaining) to next")
            }.appFont(.caption, monospacedDigit: true)
            Text("\(player.xpIntoLevel) / \(player.xpToNextLevel) XP this level")
                .appFont(.caption).foregroundStyle(.secondary)
            Text("No finish line. Keep leveling beyond 100: each next level costs 100 + 50 × your current level in XP.")
                .appFont(.caption).foregroundStyle(.secondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .animation(!reduceMotion && model.progress.celebrationEffectsEnabled ? .spring(response: 0.45, dampingFraction: 0.85) : nil, value: player.totalXP)
    }

    private var milestones: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lifetime milestones").appFont(.headline)
            milestone("First practice", symbol: "terminal", earned: model.progress.completedPracticeCount >= 1,
                      detail: "\(model.progress.completedPracticeCount) successful practices")
            milestone("Focus five", symbol: "timer", earned: model.progress.completedSessionCount >= 5,
                      detail: "\(model.progress.completedSessionCount) / 5 completed sessions")
            milestone("Independent thinker", symbol: "checkmark.seal", earned: model.masteryCount >= 1,
                      detail: "Pass your first chapter assessment")
        }
    }

    private func milestone(_ title: String, symbol: String, earned: Bool, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).appFont(.title3).frame(width: 28)
                .foregroundStyle(earned ? Color.teal : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(.subheadline, weight: .medium)
                Text(detail).appFont(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(earned ? "Earned" : "Milestone").appFont(.caption)
                .foregroundStyle(earned ? Color.teal : .secondary)
        }
    }

    private func rewardRule(_ title: String, detail: String, amount: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(.callout)
                Text(detail).appFont(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(amount).appFont(.caption, weight: .bold, monospacedDigit: true).foregroundStyle(.teal).fixedSize()
        }
    }

    private var experienceHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent XP").appFont(.headline)
            if model.progress.experienceEvents.isEmpty {
                Text("Your story starts here. Read a lesson, try some code, or settle into a focus session.")
                    .appFont(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.progress.experienceEvents.sorted { $0.date > $1.date }.prefix(10))) { event in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title).appFont(.callout)
                            Text(event.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .appFont(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("+\(event.amount) XP").appFont(.caption, weight: .bold, monospacedDigit: true).foregroundStyle(.teal).fixedSize()
                    }
                }
            }
        }
    }
}

struct FocusSessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("A little time, just for learning", systemImage: "timer").appFont(.headline)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).accessibilityLabel("Close focus session")
            }.padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    timerCard
                    HStack(spacing: 22) {
                        lifetimeStat("\(model.progress.completedSessionCount)", title: "completed sessions")
                        lifetimeStat("\(model.progress.totalFocusMinutes)", title: "focus minutes")
                    }
                    Text("Lifetime totals count finished 25-minute sessions only. Ending early never takes away XP. There is no streak to protect.")
                        .appFont(.caption).foregroundStyle(.secondary)
                    Divider()
                    sessionHistory
                }.padding(20)
            }
        }
        .frame(width: 390, height: 540)
        .confirmationDialog("End this session early?", isPresented: $confirmEnd) {
            Button("End without session XP") { model.endFocusSession() }
            Button("Keep studying", role: .cancel) { }
        } message: {
            Text("This unfinished session will not count toward completed sessions or earn 50 XP. Everything you already earned is safe. You can pause instead.")
        }
    }

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.progress.activeStudySession != nil {
                Label(model.focusRunning ? "Focus in progress" : "Paused · ready when you are",
                      systemImage: model.focusRunning ? "timer" : "pause.circle")
                    .appFont(.subheadline).foregroundStyle(.teal)
                Text(countdown).font(.system(size: 48, weight: .semibold, design: .rounded)).monospacedDigit()
                    .accessibilityLabel("\(max(0, model.focusRemainingSeconds) / 60) minutes and \(max(0, model.focusRemainingSeconds) % 60) seconds remaining")
                ProgressView(value: Double(max(0, min(1500, 1500 - model.focusRemainingSeconds))), total: 1500)
                    .tint(.teal).accessibilityLabel("Focus session progress")
                HStack {
                    if model.focusRunning {
                        Button("Pause", systemImage: "pause.fill") { model.pauseFocusSession() }
                    } else {
                        Button("Resume", systemImage: "play.fill") { model.resumeFocusSession() }
                            .buttonStyle(.borderedProminent).tint(.teal)
                    }
                    Spacer()
                    Button("End early…") { confirmEnd = true }.buttonStyle(.borderless)
                }
                .disabled(model.storageLocked)
                Text("Saved as you go. After closing and reopening the app, resume when you are ready. Paused and closed-app time do not count.")
                    .appFont(.caption).foregroundStyle(.secondary)
            } else {
                Text("Make room for one small win.").appFont(.title3, weight: .bold)
                Text("25 minutes of focused learning").appFont(.callout).foregroundStyle(.secondary)
                Label("+50 XP when complete", systemImage: "sparkles").appFont(.subheadline, weight: .bold).foregroundStyle(.teal)
                Button("Start 25-minute session", systemImage: "play.fill") { model.startFocusSession() }
                    .buttonStyle(.borderedProminent).tint(.teal).disabled(model.storageLocked)
                Text("Learn, practice, or assess at your own pace. You can pause for a break at any time.")
                    .appFont(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var countdown: String {
        let remaining = max(0, model.focusRemainingSeconds)
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private func lifetimeStat(_ value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).appFont(.title2, weight: .bold).monospacedDigit()
            Text(title).appFont(.caption).foregroundStyle(.secondary)
        }
    }

    private var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent completed sessions").appFont(.headline)
            if model.progress.studySessions.isEmpty {
                Text("Your first finished session will appear here. Small steps add up.")
                    .appFont(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.progress.studySessions.sorted { $0.completedAt > $1.completedAt }.prefix(6))) { session in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.completedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .appFont(.callout)
                            Text("25 minutes completed").appFont(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("+50 XP").appFont(.caption, weight: .bold, monospacedDigit: true).foregroundStyle(.teal)
                    }
                }
            }
        }
    }
}

private struct PlayerBarAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct RewardEffectStyle {
    let leveledUp: Bool
    var particleCount: Int { leveledUp ? 110 : 36 }
    var duration: Double { leveledUp ? 2.8 : 1.8 }
    var spread: Double { leveledUp ? 760 : 360 }
    var borderWidth: CGFloat { leveledUp ? 4 : 2.5 }

    static func allowsMotion(effectsEnabled: Bool, reduceMotion: Bool, forced: Bool) -> Bool {
        effectsEnabled && !reduceMotion && !forced
    }
}

struct RewardEffectsOverlay: View {
    let reward: RewardCelebration
    let origin: CGPoint
    var effectsEnabled = true
    var forceReducedMotion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    @State private var finished = false

    var body: some View {
        Group {
            if !finished && RewardEffectStyle.allowsMotion(effectsEnabled: effectsEnabled, reduceMotion: reduceMotion, forced: forceReducedMotion) {
                RewardEffectsFrame(progress: progress, origin: origin, style: RewardEffectStyle(leveledUp: reward.leveledUp))
                    .task {
                        let duration = RewardEffectStyle(leveledUp: reward.leveledUp).duration
                        withAnimation(.linear(duration: duration)) { progress = 1 }
                        do { try await Task.sleep(for: .seconds(duration)) } catch { return }
                        finished = true
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct RewardEffectsFrame: View, Animatable {
    var progress: Double
    let origin: CGPoint
    let style: RewardEffectStyle
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static func scatter(_ index: Int, salt: Double) -> Double {
        let value = sin(Double(index + 1) * 127.1 + salt * 311.7) * 43758.5453
        return value - floor(value)
    }

    var body: some View {
        Canvas { context, size in
            let phase = max(0, min(1, progress))
            let fade = min(1, max(0, (1 - phase) / 0.35))
            let reveal = min(1, phase / 0.45)
            let green = Color(red: 0.25, green: 1, blue: 0.42)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
            for side in [-1.0, 1.0] {
                var edge = Path()
                edge.move(to: CGPoint(x: rect.midX, y: rect.maxY))
                edge.addLine(to: CGPoint(x: side < 0 ? rect.minX : rect.maxX, y: rect.maxY))
                edge.addLine(to: CGPoint(x: side < 0 ? rect.minX : rect.maxX, y: rect.minY))
                edge.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
                let sweep = edge.trimmedPath(from: 0, to: reveal)
                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: 6))
                    glow.stroke(sweep, with: .color(green.opacity(fade * 0.65)), style: StrokeStyle(lineWidth: style.borderWidth * 3, lineCap: .round, lineJoin: .round))
                }
                context.stroke(sweep, with: .color(green.opacity(fade)), style: StrokeStyle(lineWidth: style.borderWidth, lineCap: .round, lineJoin: .round))
            }
            let time = phase * style.duration
            let colors: [Color] = style.leveledUp ? [green, .yellow, .cyan, .pink, .white] : [green, .teal, .mint, .white]
            for index in 0..<style.particleCount {
                let seed = Self.scatter(index, salt: 0)
                let other = Self.scatter(index, salt: 1)
                let velocityX = (seed - 0.62) * style.spread
                let velocityY = -130 + other * 200
                let position = CGPoint(x: origin.x + velocityX * time,
                                       y: origin.y + velocityY * time + 160 * time * time)
                let length = (style.leveledUp ? 8.0 : 5.0) + other * 5
                var particle = context
                particle.opacity = fade * min(1, phase / 0.04)
                particle.translateBy(x: position.x, y: position.y)
                particle.rotate(by: .degrees(Double(index * 47) + time * (seed - 0.5) * 720))
                let bounds = CGRect(x: -length / 2, y: -length / 4, width: length, height: length / 2)
                let shape = index % 3 == 0 ? Path(ellipseIn: bounds) : Path(roundedRect: bounds, cornerRadius: 1)
                particle.fill(shape, with: .color(colors[index % colors.count]))
            }
            if phase < 0.5 {
                let pulse = CGRect(x: origin.x - 105 - phase * 32, y: origin.y - 22 - phase * 16,
                                   width: 210 + phase * 64, height: 44 + phase * 32)
                context.stroke(Path(roundedRect: pulse, cornerRadius: 12), with: .color(green.opacity((1 - phase * 2) * 0.8)), lineWidth: 2)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct RewardCelebrationView: View {
    let reward: RewardCelebration
    var effectsEnabled: Bool = true
    var forceReducedMotion = false
    var onDismiss: () -> Void = { }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burstExpanded = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Image(systemName: reward.leveledUp ? "star.circle.fill" : "checkmark.circle.fill")
                    .appFont(.title2).foregroundStyle(.teal)
                if reward.leveledUp && effectsEnabled && !reduceMotion && !forceReducedMotion {
                    ForEach(0..<6) { index in
                        Image(systemName: "star.fill").font(.system(size: 6)).foregroundStyle(.teal)
                            .offset(y: burstExpanded ? -20 : -5)
                            .rotationEffect(.degrees(Double(index) * 60))
                            .opacity(burstExpanded ? 0 : 1)
                    }
                }
            }.frame(width: 32, height: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(reward.leveledUp ? "+\(reward.amount) XP · Level \(reward.level)!" : "+\(reward.amount) XP")
                    .appFont(.callout, weight: .bold).foregroundStyle(.teal)
                Text(reward.title).appFont(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) { Image(systemName: "xmark").appFont(.caption) }
                .buttonStyle(.borderless).accessibilityLabel("Dismiss XP celebration")
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .help("\(reward.title) · +\(reward.amount) XP. Saved in player progress history.")
        .task(id: reward.id) {
            AccessibilityNotification.Announcement(reward.accessibilityAnnouncement).post()
            if reward.leveledUp && effectsEnabled && !reduceMotion && !forceReducedMotion {
                withAnimation(.easeOut(duration: 0.9)) { burstExpanded = true }
            }
        }
    }
}

/// Chapter browser grouped by curriculum track. Locked chapters name their unmastered prerequisites.
struct ChapterBrowserView: View {
    @EnvironmentObject private var model: AppModel
    var onSelect: () -> Void = {}

    struct Entry: Identifiable {
        let number: Int
        let chapter: Chapter
        var id: String { chapter.id }
    }

    struct Section: Identifiable {
        let track: ChapterTrack
        let entries: [Entry]
        var id: ChapterTrack { track }
    }

    /// Chapters grouped by `ChapterTrack.allCases` order; numbering follows canonical curriculum order.
    static func sections(for chapters: [Chapter]) -> [Section] {
        let entries = chapters.enumerated().map { Entry(number: $0.offset + 1, chapter: $0.element) }
        return ChapterTrack.allCases.compactMap { track in
            let members = entries.filter { $0.chapter.track == track }
            return members.isEmpty ? nil : Section(track: track, entries: members)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR PYTHON PATH").appFont(.caption, weight: .semibold).foregroundStyle(.secondary)
                HStack {
                    Text("Chapters").appFont(.title3, weight: .bold)
                    Spacer()
                    Text("\(model.masteryCount)/\(model.chapters.count)").appFont(.callout, monospacedDigit: true).foregroundStyle(.secondary)
                        .accessibilityLabel("\(model.masteryCount) of \(model.chapters.count) chapters mastered")
                }
                ProgressView(value: Double(model.masteryCount), total: Double(model.chapters.count)).tint(.teal)
            }.padding(18)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Self.sections(for: model.chapters)) { section in
                        trackHeader(section.track, chapters: section.entries.map(\.chapter))
                        ForEach(section.entries) { entry in
                            chapterButton(entry.chapter, number: entry.number)
                        }
                    }
                    if !model.reviewIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Due for recall", systemImage: "arrow.counterclockwise").appFont(.subheadline, weight: .bold)
                            Text("Revisit these topics with an independent practice attempt.").appFont(.caption).foregroundStyle(.secondary)
                            ForEach(model.chapters.filter { model.reviewIDs.contains($0.id) }) { chapter in
                                Button(chapter.title) { model.selectChapter(chapter.id); model.selectMode(.practice); onSelect() }
                                    .buttonStyle(.link).disabled(model.isBusy)
                            }
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10)).padding(.top, 18)
                    }
                }.padding(.horizontal, 10).padding(.bottom, 6)
            }
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 8) {
                Label("A little, every day", systemImage: "sun.max").appFont(.subheadline, weight: .medium)
                Text("3 min recall · 5 min learn\n14 min code · 3 min reflect").appFont(.caption).foregroundStyle(.secondary).lineSpacing(3)
                Divider().padding(.vertical, 5)
                Button { model.exportProgress() } label: { Label("Export learning backup", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.borderless).appFont(.caption)
            }.padding(18)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private func trackHeader(_ track: ChapterTrack, chapters: [Chapter]) -> some View {
        let mastered = chapters.filter { model.progress.masteredChapterIDs.contains($0.id) }.count
        return HStack {
            Text(track.title.uppercased()).appFont(.caption, weight: .semibold).foregroundStyle(.secondary)
            Spacer()
            Text("\(mastered)/\(chapters.count)").appFont(.caption, monospacedDigit: true).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(track.title), \(mastered) of \(chapters.count) mastered")
        .accessibilityAddTraits(.isHeader)
    }

    private func chapterButton(_ chapter: Chapter, number: Int) -> some View {
        let selected = model.chapter.id == chapter.id
        let mastered = model.progress.masteredChapterIDs.contains(chapter.id)
        let unlocked = model.isUnlocked(chapter.id)
        let detail = mastered ? "Assessment passed" : model.progress.unlockedOverrides.contains(chapter.id) ? "Placement override"
            : unlocked ? chapter.subtitle : model.requirementSummary(for: chapter.id)
        return Button { model.selectChapter(chapter.id); onSelect() } label: {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(mastered ? Color.teal.opacity(0.16) : Color.secondary.opacity(0.09)).frame(width: 30, height: 30)
                    if mastered { Image(systemName: "checkmark").foregroundStyle(.teal) }
                    else { Text(String(format: "%02d", number)).appFont(.caption, weight: .bold, monospacedDigit: true).foregroundStyle(unlocked ? .primary : .secondary) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title).appFont(.subheadline, weight: .medium)
                    Text(detail).appFont(.caption).foregroundStyle(.secondary).lineLimit(unlocked ? 2 : 3)
                }
                Spacer(minLength: 0)
                if !unlocked { Image(systemName: "lock.fill").appFont(.caption2).foregroundStyle(.tertiary).accessibilityHidden(true) }
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.teal.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(model.isBusy)
            .accessibilityLabel("\(chapter.title), \(unlocked ? (mastered ? "mastered" : "unlocked") : "locked")")
            .accessibilityValue(detail)
    }
}
