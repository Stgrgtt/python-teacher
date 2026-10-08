import Foundation

public enum Curriculum {
    public static let chapters: [Chapter] = [basics, values, decisions, loops, functions, collections, reliability, iteration, files, classes, inheritance, testing, generators, typingDecorators, dsCleaning, dsStatistics, dsAggregation]

    private static let efforts: [String: ExerciseEffort] = [
        "basics-name": .init(difficulty: .easier),
        "basics-total": .init(),
        "basics-message": .init(),
        "basics-assessment": .init(),
        "values-budget": .init(scopeUnits: 2),
        "values-label": .init(scopeUnits: 3),
        "values-batches": .init(difficulty: .harder, scopeUnits: 2),
        "values-assessment": .init(scopeUnits: 3),
        "decisions-route": .init(),
        "decisions-quota": .init(scopeUnits: 2),
        "decisions-bands-v2": .init(scopeUnits: 2),
        "decisions-assessment-v2": .init(scopeUnits: 2),
        "loops-total": .init(difficulty: .harder, scopeUnits: 2),
        "loops-filter": .init(scopeUnits: 2),
        "loops-retries-v2": .init(difficulty: .harder, scopeUnits: 2),
        "loops-assessment": .init(difficulty: .harder, scopeUnits: 2),
        "functions-batches": .init(),
        "functions-rate": .init(scopeUnits: 2),
        "functions-preview-v2": .init(scopeUnits: 2),
        "functions-assessment": .init(scopeUnits: 2),
        "collections-count": .init(),
        "collections-json": .init(scopeUnits: 2),
        "collections-rank": .init(difficulty: .harder, scopeUnits: 2),
        "collections-assessment": .init(scopeUnits: 2),
        "reliability-score": .init(difficulty: .harder, scopeUnits: 2),
        "reliability-parse": .init(scopeUnits: 2),
        "reliability-summary": .init(difficulty: .harder, scopeUnits: 3),
        "reliability-assessment": .init(difficulty: .harder, scopeUnits: 4)
    ]

    static func exercise(_ id: String, _ title: String, _ instructions: String, _ starter: String, _ solution: String, _ tests: String, _ hints: [String], effort: ExerciseEffort? = nil, expectedStarterError: String? = nil) -> Exercise {
        Exercise(id: id, title: title, instructions: instructions, starterCode: starter, referenceSolution: solution, testCode: tests, hints: hints, effort: effort ?? efforts[id], expectedStarterError: expectedStarterError)
    }

    static func question(_ id: String, _ prompt: String, _ options: [String], _ answer: Int, _ explanation: String) -> QuizQuestion {
        QuizQuestion(id: id, prompt: prompt, options: options, correctIndex: answer, explanation: explanation)
    }

    public static func activityID(for exerciseID: String) -> String {
        switch exerciseID {
        case "decisions-bands-v2": return "decisions-bands"
        case "decisions-assessment-v2": return "decisions-assessment"
        case "loops-retries-v2": return "loops-retries"
        case "functions-preview-v2": return "functions-preview"
        default: return exerciseID
        }
    }

    public static func isAssessment(_ exerciseID: String, in curriculum: [Chapter] = chapters) -> Bool {
        exerciseID == "decisions-assessment" || (chapters + curriculum).contains { $0.assessment.id == exerciseID }
    }

    public static func legacyExercises(chapterID: String, mode: LearningMode) -> [Exercise] {
        switch (chapterID, mode) {
        case ("decisions", .practice): return [legacyBands]
        case ("decisions", .assessment): return [legacyDecisionAssessment]
        case ("loops", .practice): return [legacyRetries]
        case ("functions", .practice): return [legacyPreview]
        default: return []
        }
    }

    private static let legacyBands = exercise("decisions-bands", "Classify evaluation scores (legacy)", "Goal:\nGive each invented evaluation score a label. 'pass' means acceptable, 'retry' means try again, and 'invalid' means outside the permitted scale.\n\nStarting code:\nscores contains [-0.1, 0.0, 0.59, 0.6, 1.0, 1.1]. labels = [] starts an empty output list. The supplied for loop visits one score at a time; its current body always adds 'pass' and must be replaced.\n\nYour task:\n1. Leave scores unchanged and keep labels as a list of strings in the same order as the scores.\n2. For each score below 0 or above 1, add 'invalid'. Both 0 and 1 are valid endpoints.\n3. For each valid score at least 0.6, add 'pass'. For every other valid score, add 'retry'. Exactly 0.6 passes.\n4. Add exactly one label per score using decisions inside the supplied loop. append adds a value to the end of a list; do not leave the unconditional starter append after your decision.\n\nExpected result:\nlabels is ['invalid', 'retry', 'retry', 'pass', 'pass', 'invalid'].\n\nCheck:\nChoose Check solution. It checks the original scores and the exact output list, including its order and length.",
        "scores = [-0.1, 0.0, 0.59, 0.6, 1.0, 1.1]\nlabels = []\nfor score in scores:\n    labels.append('pass')\n",
        "scores = [-0.1, 0.0, 0.59, 0.6, 1.0, 1.1]\nlabels = []\nfor score in scores:\n    if score < 0 or score > 1:\n        labels.append('invalid')\n    elif score >= 0.6:\n        labels.append('pass')\n    else:\n        labels.append('retry')\n",
        "assert scores == [-0.1, 0.0, 0.59, 0.6, 1.0, 1.1]\nassert labels == ['invalid', 'retry', 'retry', 'pass', 'pass', 'invalid']\n",
        ["A score above 1 also exceeds the passing threshold, but it is invalid. Validate the scale before judging whether a score passes.", "Keep the decision inside the loop so each score gets its own result. One if/elif/else chain runs exactly one selected branch for that score.", "A score is invalid when either endpoint rule fails, so or combines those two conditions. In the selected branch, append one label to labels; do not also retain the starter's unconditional append."],
        effort: .init(difficulty: .harder, scopeUnits: 2))

    private static let legacyDecisionAssessment = exercise("decisions-assessment", "Choose safe deployment actions (legacy)", "Goal:\nChoose an action for each invented release candidate. 'hold' means do not publish because of sensitive data, 'release' means ready to publish, and 'revise' means improve the candidate first. No real sensitive data is present.\n\nStarting code:\ncases is [(True, 0.99), (False, 0.9), (False, 0.899), (False, 0.0)]. Each pair contains a Boolean has_sensitive_data followed by a numeric quality score. actions starts empty. The supplied loop names those two values for each pair; its body is a placeholder.\n\nYour task:\n1. Keep cases unchanged. Produce actions as a list of strings, one action per case in original order.\n2. Any case with has_sensitive_data True must get 'hold', whatever its quality.\n3. Other cases must get 'release' when quality is at least 0.9, including exactly 0.9; they must get 'revise' below 0.9. All supplied quality scores are valid numbers between 0 and 1 inclusive.\n\nExpected result:\nactions is ['hold', 'release', 'revise', 'revise'].\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment. It checks the unchanged cases and exact actions list. Work independently without hints or solutions; printing is not required.",
        "cases = [(True, 0.99), (False, 0.9), (False, 0.899), (False, 0.0)]\nactions = []\nfor has_sensitive_data, quality in cases:\n    actions.append('release')\n",
        "cases = [(True, 0.99), (False, 0.9), (False, 0.899), (False, 0.0)]\nactions = []\nfor has_sensitive_data, quality in cases:\n    if has_sensitive_data:\n        actions.append('hold')\n    elif quality >= 0.9:\n        actions.append('release')\n    else:\n        actions.append('revise')\n",
        "assert cases == [(True, 0.99), (False, 0.9), (False, 0.899), (False, 0.0)]\nassert actions == ['hold', 'release', 'revise', 'revise']\n", [], effort: .init(scopeUnits: 2))

    private static let legacyRetries = exercise("loops-retries", "Build a retry schedule (legacy)", "Goal:\nPlan delays before repeated attempts. A retry is another attempt after a failure. This schedule is only a list of numbers; your code must not actually wait or contact a service.\n\nStarting code:\nretry_count = 4 and base_seconds = 2 are inputs. delays = [] and total_wait = 0 are result starting values.\n\nYour task:\n1. Keep both inputs unchanged. Use a loop to build delays as a list of integer seconds in retry order.\n2. Number retries from 0 up to, but not including, retry_count. Each delay is base_seconds multiplied by 2 raised to that retry number. The lesson explains range and the power operator **. The first delay is base_seconds; each next delay doubles.\n3. Set integer total_wait to the sum of all delays. If retry_count were zero, the results would be an empty list and zero total. Assume a nonnegative retry count and positive integer base_seconds.\n\nExpected result:\ndelays is [2, 4, 8, 16] and total_wait is 30.\n\nCheck:\nChoose Check solution. It checks the unchanged inputs, ordered delays, and saved total; do not use a sleep operation.",
        "retry_count = 4\nbase_seconds = 2\ndelays = []\ntotal_wait = 0\n",
        "retry_count = 4\nbase_seconds = 2\ndelays = []\ntotal_wait = 0\nfor retry_number in range(retry_count):\n    delay = base_seconds * (2 ** retry_number)\n    delays.append(delay)\n    total_wait += delay\n",
        "assert retry_count == 4 and base_seconds == 2\nassert delays == [2, 4, 8, 16]\nassert total_wait == 30\n",
        ["range with a single stop value starts at zero and excludes the stop, giving exactly retry_count visits.", "** means raising to a power, not multiplication by the exponent. A power of zero gives 1, so the first delay is the base itself. ^ is a different operation and is not suitable here.", "Within each visit, save that retry's delay so the same value can enter both the list and the running total. Initialize both outputs before the loop so they survive across visits."], effort: .init(scopeUnits: 2))

    private static let legacyPreview = exercise("functions-preview", "Create prompt previews (legacy)", "Goal:\nCreate a short display of text, called a preview. Three dots show that some original text was omitted.\n\nStarting code:\ndef preview(text, max_chars): is the required function. return text is a placeholder that currently never shortens anything.\n\nYour task:\n1. Keep the function name and parameters. text is a string and max_chars is a nonnegative integer. Use each call's arguments, not fixed example values.\n2. Return text unchanged if its length is at most max_chars, including exact equality.\n3. If it is longer, return its first max_chars characters followed by exactly three ordinary dots, '...'. The added dots do not count toward max_chars. Use the lesson's slicing concept to take a beginning portion.\n4. Preserve all original spaces and letter case in the kept portion. Return a string; do not print instead. Empty text stays empty, and nonempty text with max_chars zero produces only the three dots.\n\nExamples:\npreview('demo', 4) returns 'demo'.\npreview('demo', 2) returns 'de...'.\npreview('demo', 0) returns '...'.\npreview('', 0) returns ''.\npreview('  AI', 2) returns '  ...' with two spaces before the dots.\n\nCheck:\nChoose Check solution. It tests empty text, zero and oversized limits, exact length, and preservation of spaces.",
        "def preview(text, max_chars):\n    return text\n",
        "def preview(text, max_chars):\n    if len(text) <= max_chars:\n        return text\n    return text[:max_chars] + '...'\n",
        "assert preview('', 0) == ''\nassert preview('demo', 4) == 'demo'\nassert preview('demo', 8) == 'demo'\nassert preview('demo', 0) == '...'\nassert preview('Synthetic prompt', 9) == 'Synthetic...'\nassert preview('  AI', 2) == '  ...'\n",
        ["Text that already fits, including an exact-length match, must be returned unchanged without dots. Separate that case from text that needs shortening.", "A slice with no start begins at the first character; its stop is excluded. Using the character limit as that stop takes at most that many characters without changing their spaces or case.", "Join three ordinary dots only to a shortened result. With a zero character limit the kept portion is empty, but dots are still needed if the original text was nonempty."], effort: .init())
}
