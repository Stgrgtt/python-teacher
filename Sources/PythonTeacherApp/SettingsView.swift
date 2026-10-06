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
                Text("Settings").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(22)
            Divider()
            Form {
                if let notice = model.notice {
                    Section("Notice") {
                        Text(notice).font(.callout).textSelection(.enabled)
                        Button("Dismiss notice") { model.notice = nil }
                    }
                }
                Section("Python execution") {
                    TextField("Interpreter", text: $pythonPath).font(.system(.body, design: .monospaced))
                    HStack {
                        Button("Choose executable…") { choosePython() }
                        Button("Verify restricted execution") { verifyPython() }.disabled(checking || model.isBusy)
                        if checking { ProgressView().controlSize(.small) }
                    }
                    Text("Choose the actual Python 3 binary, not a pyenv shim or shell script. Runs have no network access and cannot read your personal files. Standard-library exercises need no packages.").font(.caption).foregroundStyle(.secondary)
                    if !pythonStatus.isEmpty { Text(pythonStatus).font(.caption.monospaced()).textSelection(.enabled) }
                }
                Section("AI teacher") {
                    Picker("Provider", selection: $provider) {
                        ForEach(TeacherProvider.allCases) { Text($0.displayName).tag($0) }
                    }
                    Toggle("Allow relevant learning content to be sent to \(provider.name)", isOn: $model.cloudConsent)
                    Text("Cloud features send lesson context, current code, output, and conversation as needed. Do not include confidential work or banking data. \(provider == .openAI ? "OpenAI calls request store: false; this does not override the provider's retention policies." : "\(provider.name)'s data retention policies apply.") Built-in lessons, hints, and tests remain available offline.").font(.caption).foregroundStyle(.secondary)
                    SecureField(model.hasAPIKey ? "Replace saved \(provider.name) API key (optional)" : "\(provider.name) API key", text: $apiKey)
                    HStack {
                        Label(model.hasAPIKey ? "A \(provider.name) key is saved in macOS Keychain" : "No saved \(provider.name) key detected", systemImage: model.hasAPIKey ? "key.fill" : "key")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if model.hasAPIKey { Button("Remove key…", role: .destructive) { confirmRemove = true }.font(.caption) }
                    }
                    Text("Create a key at \(provider.keyConsole). Each provider's key is stored separately.").font(.caption).foregroundStyle(.secondary)
                    TextField("Model", text: $modelName)
                    Text("\(provider.modelGuidance) The default is \(provider.defaultModel); you can change it without rebuilding.").font(.caption).foregroundStyle(.secondary)
                    Stepper("Request limit per app launch: \(requestLimit)", value: $requestLimit, in: 1...100)
                    Text("Used this launch: \(model.requestCount) requests · \(model.inputTokens) input tokens · \(model.outputTokens) output tokens reported. Failed or cancelled calls may still be billed. This is a request cap, not a dollar budget; configure billing limits in your \(provider.name) account. Counts reset when the app restarts.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Your learning data") {
                    Text("Drafts, attempts, generated exercises, and progress stay on this Mac. Backups contain your code and exercise reference solutions, but no API key.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Open data folder") { model.showDataFolder() }
                        Button("Export backup…") { model.exportProgress() }
                    }
                    Text(model.store.directory.path).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                Text("Personal workspace · no app account").font(.caption).foregroundStyle(.secondary)
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
