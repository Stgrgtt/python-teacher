import SwiftUI

struct TeacherPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var question = ""
    @State private var confirmReveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.text.bubble.right").foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your teacher").appFont(.headline)
                    Text(model.mode == .assessment ? "Independent assessment" : "Guidance, not autopilot").appFont(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(18)
            Divider()
            if model.mode == .assessment {
                VStack(alignment: .leading, spacing: 15) {
                    Image(systemName: "lock.shield").appFont(.largeTitle).foregroundStyle(.teal)
                    Text("Your turn to lead").appFont(.title3, weight: .bold)
                    Text("Teacher assistance is paused during assessments. Use what you know, consult Python documentation if needed, and explain your reasoning.")
                    Text("The app checks your code against a fixed test suite and scores the theory questions. Your written explanation is saved, but not automatically graded.")
                    Text("Need more practice? Switch back to Practice, then return when you are ready. Assessment drafts are kept.")
                }.appFont(.callout).foregroundStyle(.secondary).padding(20)
                Spacer()
            } else if !model.isUnlocked {
                Text(model.teacherLockedMessage).appFont(.callout).foregroundStyle(.secondary).padding(20)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            } else {
                conversation
                Divider()
                if model.mode == .practice {
                    VStack(spacing: 8) {
                        Button { model.showHint() } label: { Label(model.canShowHint ? "Give me a hint" : "All hints shown", systemImage: "lightbulb") }
                            .frame(maxWidth: .infinity).disabled(!model.canShowHint)
                        Button("Reveal reference solution…") { confirmReveal = true }.buttonStyle(.link).appFont(.caption)
                    }.padding(12).disabled(model.isBusy)
                    Divider()
                }
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Ask a question about your reasoning…", text: $question, axis: .vertical)
                        .textFieldStyle(.plain).lineLimit(3...6).padding(10)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .disabled(model.isBusy)
                        .onSubmit { send() }
                        .onKeyPress(.return, phases: .down) { press in
                            guard press.modifiers.contains(.shift) else { return .ignored }
                            return NSApp.sendAction(#selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)), to: nil, from: nil) ? .handled : .ignored
                        }
                        .help("Enter to send · Shift+Enter for a new line")
                    HStack {
                        Text("\(model.progress.provider.name) · cloud").appFont(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Ask teacher") { send() }.buttonStyle(.borderedProminent).tint(.teal)
                            .disabled(model.isBusy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Every question includes your full current code and the latest available run, labeled if it predates your edits. No need to paste them. Chat is saved locally. Use only synthetic or public data.")
                        .appFont(.caption2).foregroundStyle(.secondary)
                }.padding(14)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .confirmationDialog("Reveal the solution? This practice will be marked as assisted, even if you restore the starter later.", isPresented: $confirmReveal) {
            Button("Reveal and mark as assisted") { model.revealSolution() }
        }
        .onChange(of: model.chapter.id) { _, _ in question = "" }
        .onChange(of: model.mode) { _, _ in question = "" }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.messages.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Think it through, together.").appFont(.title3, weight: .bold)
                            Text("New to Python? You can ask what a word or symbol means, or ask me to explain the task before writing any code.").appFont(.callout).foregroundStyle(.secondary)
                            Text("Built-in hints and reference solutions work without an API key. For personalized discussion and new challenges, configure an AI provider (OpenAI, Anthropic, Google or xAI) in Settings.").appFont(.callout).foregroundStyle(.secondary)
                            if model.mode == .practice {
                                Button("Explain this task simply") { model.askTeacher("Assume I know nothing about Python. Explain what this exercise wants me to do, what the starter provides, and what the expected result means. Explain unfamiliar syntax with a small different example; do not solve the exercise.") }
                                Button("Help me read the error") { model.askTeacher("Help me interpret the latest output. Ask a guiding question; do not give the solution.") }
                                Button("Check my reasoning") { model.askTeacher("Review my current approach and ask one question that helps me test my understanding. Do not write the solution.") }
                            }
                        }.disabled(model.isBusy)
                    }
                    ForEach(model.messages) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message.role == "user" ? "YOU" : "TEACHER").appFont(.caption2, weight: .semibold).foregroundStyle(.secondary)
                            MarkdownContent(text: message.text, compact: true)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(message.role == "user" ? Color.secondary.opacity(0.07) : Color.teal.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                            .id(message.id)
                    }
                    if model.teacherBusy {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Working…").appFont(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Stop") { model.cancelWork() }.buttonStyle(.link)
                        }
                    }
                }.padding(16)
            }
            .onChange(of: model.messages.last?.id) { _, _ in
                if let id = model.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }

    private func send() {
        guard !model.isBusy, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = question
        question = ""
        model.askTeacher(text)
    }
}
