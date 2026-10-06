import Foundation

/// Cloud model providers the optional teacher can call with the learner's own API key.
public enum TeacherProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "openai"
    case anthropic
    case google
    case xAI = "xai"

    public var id: String { rawValue }

    /// Company name used in consent, privacy, and error text.
    public var name: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        case .xAI: return "xAI"
        }
    }

    /// Picker label naming the company and its model family.
    public var displayName: String {
        switch self {
        case .openAI: return "OpenAI (GPT)"
        case .anthropic: return "Anthropic (Claude)"
        case .google: return "Google (Gemini)"
        case .xAI: return "xAI (Grok)"
        }
    }

    public var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4.1-mini"
        case .anthropic: return "claude-sonnet-5-5"
        case .google: return "gemini-3.8-flash"
        case .xAI: return "grok-4.7"
        }
    }

    /// Where the learner creates an API key, shown as plain text in Settings.
    public var keyConsole: String {
        switch self {
        case .openAI: return "platform.openai.com"
        case .anthropic: return "platform.claude.com"
        case .google: return "aistudio.google.com"
        case .xAI: return "console.x.ai"
        }
    }

    public var modelGuidance: String {
        switch self {
        case .openAI: return "Use a model available to your API account that supports the Responses API and structured outputs."
        case .anthropic: return "Use a Claude model that supports structured outputs (Claude Haiku 4.5, Sonnet 4.5 or newer)."
        case .google: return "Use a Gemini model available to your API key that supports structured outputs through Google's OpenAI-compatible endpoint."
        case .xAI: return "Use a Grok model available to your API account that supports structured outputs."
        }
    }

    /// OpenAI uses the Responses API, Anthropic the Messages API, and Google and xAI their OpenAI-compatible Chat Completions APIs.
    var endpoint: URL {
        switch self {
        case .openAI: return URL(string: "https://api.openai.com/v1/responses")!
        case .anthropic: return URL(string: "https://api.anthropic.com/v1/messages")!
        case .google: return URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!
        case .xAI: return URL(string: "https://api.x.ai/v1/chat/completions")!
        }
    }

    /// Extra output-token allowance for providers whose current default models always reason;
    /// their reasoning tokens count against the request's output limit.
    var reasoningAllowance: Int { self == .openAI ? 0 : 8000 }
}
