import AppKit
import PythonTeacherCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var pythonPath = ""
    @State private var provider = TeacherProvider.openAI
    @State private var modelName = ""
    @State private var apiKey = ""
    @State private var requestLimit = 20
    @State private var checking = false
    @State private var pythonStatus = ""
    @State private var confirmRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings").appFont(.title2, weight: .bold)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(22)
            Divider()
            Form {
                if let notice = model.notice {
                    Section("Notice") {
                        Text(notice).appFont(.callout).textSelection(.enabled)
                        Button("Dismiss notice") { model.notice = nil }
                    }
                }
                AppearanceSettingsSection()
                Section("Python execution") {
                    TextField("Interpreter", text: $pythonPath).appFont(.body, design: .monospaced)
                    HStack {
                        Button("Choose executable…") { choosePython() }
                        Button("Verify restricted execution") { verifyPython() }.disabled(checking || model.isBusy)
                        if checking { ProgressView().controlSize(.small) }
                    }
                    Text("Choose the actual Python 3 binary, not a pyenv shim or shell script. Runs have no network access and cannot read your personal files. Standard-library exercises need no packages.").appFont(.caption).foregroundStyle(.secondary)
                    if !pythonStatus.isEmpty { Text(pythonStatus).appFont(.caption, design: .monospaced).textSelection(.enabled) }
                }
                Section("AI teacher") {
                    Picker("Provider", selection: $provider) {
                        ForEach(TeacherProvider.allCases) { Text($0.displayName).tag($0) }
                    }
                    Toggle("Allow relevant learning content to be sent to \(provider.name)", isOn: $model.cloudConsent)
                    Text("Cloud features send lesson context, current code, output, and conversation as needed. Do not include confidential work or banking data. \(provider == .openAI ? "OpenAI calls request store: false; this does not override the provider's retention policies." : "\(provider.name)'s data retention policies apply.") Built-in lessons, hints, and tests remain available offline.").appFont(.caption).foregroundStyle(.secondary)
                    SecureField(model.hasAPIKey ? "Replace saved \(provider.name) API key (optional)" : "\(provider.name) API key", text: $apiKey)
                    HStack {
                        Label(model.hasAPIKey ? "A \(provider.name) key is saved in macOS Keychain" : "No saved \(provider.name) key detected", systemImage: model.hasAPIKey ? "key.fill" : "key")
                            .appFont(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if model.hasAPIKey { Button("Remove key…", role: .destructive) { confirmRemove = true }.appFont(.caption) }
                    }
                    Text("Create a key at \(provider.keyConsole). Each provider's key is stored separately.").appFont(.caption).foregroundStyle(.secondary)
                    TextField("Model", text: $modelName)
                    Text("\(provider.modelGuidance) The default is \(provider.defaultModel); you can change it without rebuilding.").appFont(.caption).foregroundStyle(.secondary)
                    Stepper("Request limit per app launch: \(requestLimit)", value: $requestLimit, in: 1...100)
                    Text("Used this launch: \(model.requestCount) requests · \(model.inputTokens) input tokens · \(model.outputTokens) output tokens reported. Failed or cancelled calls may still be billed. This is a request cap, not a dollar budget; configure billing limits in your \(provider.name) account. Counts reset when the app restarts.").appFont(.caption).foregroundStyle(.secondary)
                }
                Section("Your learning data") {
                    Text("Drafts, attempts, generated exercises, and progress stay on this Mac. Backups contain your code and exercise reference solutions, but no API key.").appFont(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Open data folder") { model.showDataFolder() }
                        Button("Export backup…") { model.exportProgress() }
                    }
                    Text(model.store.directory.path).appFont(.caption2, design: .monospaced).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                Text("Personal workspace · no app account").appFont(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Save settings") {
                    model.saveSettings(provider: provider, pythonPath: pythonPath, model: modelName, requestLimit: requestLimit, apiKey: apiKey)
                    apiKey = ""
                }.buttonStyle(.borderedProminent).tint(.teal).keyboardShortcut(.defaultAction).disabled(model.isBusy || checking || pythonPath.isEmpty || modelName.isEmpty)
            }.padding(18)
        }
        .frame(width: 680, height: 760)
        .onAppear {
            pythonPath = model.progress.pythonPath
            provider = model.progress.provider
            modelName = model.progress.model
            requestLimit = model.progress.sessionRequestLimit
            model.checkKeyStatus(for: provider)
        }
        .onChange(of: provider) { _, selected in
            apiKey = ""
            modelName = selected == model.progress.provider ? model.progress.model : selected.defaultModel
            if selected != model.progress.provider { model.cloudConsent = false }
            model.checkKeyStatus(for: selected)
        }
        .confirmationDialog("Remove the \(provider.name) key from macOS Keychain? Offline learning remains available.", isPresented: $confirmRemove) {
            Button("Remove saved key", role: .destructive) { model.removeKey(for: provider) }
        }
    }

    private func choosePython() {
        let panel = NSOpenPanel()
        panel.title = "Choose the Python 3 executable"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pythonPath = url.resolvingSymlinksInPath().path
    }

    private func verifyPython() {
        checking = true
        pythonStatus = "Checking interpreter and execution restrictions…"
        let path = pythonPath
        Task {
            defer { checking = false }
            do {
                let result = try await PythonRunner().run(code: "import sys\nprint(sys.version)\nprint('Restricted Python execution is ready.')", pythonPath: path)
                pythonStatus = result.output
                if !result.passed { pythonStatus += "\nVerification failed. Choose a different Python executable." }
            } catch { pythonStatus = error.localizedDescription }
        }
    }
}

/// Device-local reading preferences; they apply immediately and are not part of learning progress.
struct AppearanceSettingsSection: View {
    @AppStorage(AppearanceKey.interfaceScale) private var interfaceScale = 1.0
    @AppStorage(AppearanceKey.readingScale) private var readingScale = 1.0
    @AppStorage(AppearanceKey.typeface) private var typeface = ReadingTypeface.system
    @AppStorage(AppearanceKey.spacing) private var spacing = ReadingSpacing.comfortable
    @AppStorage(AppearanceKey.codeSize) private var codeSize = 14.0
    @AppStorage(AppearanceKey.lessonLayout) private var lessonLayout = LessonLayout.paced

    var body: some View {
        Section {
            scaleSlider("Lesson text", value: $readingScale, range: AppearanceKey.readingRange)
            scaleSlider("Interface text", value: $interfaceScale, range: AppearanceKey.interfaceRange)
            Picker("Reading font", selection: $typeface) {
                ForEach(ReadingTypeface.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Line spacing", selection: $spacing) {
                ForEach(ReadingSpacing.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Lessons", selection: $lessonLayout) {
                ForEach(LessonLayout.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Stepper("Code font size: \(Int(codeSize)) pt", value: $codeSize, in: AppearanceKey.codeRange, step: 1)
            VStack(alignment: .leading, spacing: 6) {
                Text("Preview").appFont(.caption).foregroundStyle(.secondary)
                MarkdownContent(text: "A **variable** is a name for a value. Read `apples = 3` as “save 3 under the name `apples`”.\n\n> **Tip:** Lesson text, exercise steps and teacher replies all follow these settings.")
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            }
            HStack {
                Text("Changes apply immediately and are saved on this Mac.").appFont(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Restore defaults") {
                    interfaceScale = 1; readingScale = 1; typeface = .system; spacing = .comfortable; codeSize = 14; lessonLayout = .paced
                }.appFont(.caption)
            }
        } header: { Text("Reading & appearance") }
    }

    private func scaleSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary).accessibilityHidden(true)
                Slider(value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = ($0 * 20).rounded() / 20 }), in: range)
                    .frame(minWidth: 180)
                Image(systemName: "textformat.size.larger").foregroundStyle(.secondary).accessibilityHidden(true)
                Text("\(Int((value.wrappedValue * 100).rounded()))%").appFont(.callout, monospacedDigit: true).frame(width: 44, alignment: .trailing)
            }
        }
        .accessibilityValue("\(Int((value.wrappedValue * 100).rounded())) percent")
    }
}
