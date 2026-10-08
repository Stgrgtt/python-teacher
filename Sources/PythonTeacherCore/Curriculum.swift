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

    private static let practiceProfiles: [String: PracticeProfile] = [
        "basics-name": .init(form: .complete, scaffolding: .guided, skillIDs: ["basics-section-2"], reflectionPrompts: ["How is the name learner_name different from the text it stores?"]),
        "basics-total": .init(form: .complete, scaffolding: .guided, skillIDs: ["basics-section-3"], reflectionPrompts: ["Why use the apple and pear names rather than a fixed fruit total?"]),
        "basics-message": .init(form: .complete, scaffolding: .guided, skillIDs: ["basics-section-4"], reflectionPrompts: ["Where does the space in your greeting come from?"]),
        "basics-debug-quote": .init(form: .debug, scaffolding: .guided, skillIDs: ["basics-section-2", "basics-section-5"], reflectionPrompts: ["What did the SyntaxError location tell you about the greeting program?", "How did you check that the saved message still matched its contract?"]),
        "basics-debug-saved-total": .init(form: .debug, scaffolding: .guided, skillIDs: ["basics-section-2", "basics-section-3", "basics-section-5"], reflectionPrompts: ["At which assignment did total_seats first stop matching your expectation?"]),
        "values-budget": .init(form: .write, scaffolding: .guided, skillIDs: ["values-section-5"], reflectionPrompts: ["What units does each intermediate token-cost calculation represent?"]),
        "values-label": .init(form: .write, scaffolding: .guided, skillIDs: ["values-section-2", "values-section-3", "values-section-4"], reflectionPrompts: ["How did you keep raw_label unchanged while making the cleaned report?", "Which spaces belong in the cleaned label and which belong in the report format?"]),
        "values-batches": .init(form: .write, scaffolding: .guided, skillIDs: ["values-section-6"], reflectionPrompts: ["How would you check scheduled_batches for zero items and an exact multiple?"]),
        "values-debug-clean-label": .init(form: .debug, scaffolding: .guided, skillIDs: ["values-section-2", "values-section-3"], reflectionPrompts: ["What evidence distinguished calling a cleaning method from saving its result?"]),
        "values-predict-token-total": .init(form: .predict, scaffolding: .guided, skillIDs: ["values-section-5"], reflectionPrompts: ["How did the original expression group the tokens for each job?", "What did changing the job count reveal about your repaired calculation?"]),
        "decisions-route": .init(form: .write, scaffolding: .guided, skillIDs: ["decisions-section-1", "decisions-section-2"], reflectionPrompts: ["Which route rule must win when a blocked result also has high confidence?"]),
        "decisions-quota": .init(form: .write, scaffolding: .guided, skillIDs: ["decisions-section-2", "decisions-section-3", "decisions-section-4"], reflectionPrompts: ["Which quota examples distinguish the admin exception from the usage boundary?"]),
        "decisions-bands-v2": .init(form: .write, scaffolding: .guided, skillIDs: ["decisions-section-1", "decisions-section-2", "decisions-section-4"], reflectionPrompts: ["Why is an above-range score useful when checking the order of your label rules?"]),
        "decisions-debug-priority": .init(form: .debug, scaffolding: .guided, skillIDs: ["decisions-section-1", "decisions-section-2"], reflectionPrompts: ["How did tracing every assignment to status explain the closed room opening?"]),
        "decisions-debug-entry-boundary": .init(form: .debug, scaffolding: .guided, skillIDs: ["decisions-section-2", "decisions-section-3"], reflectionPrompts: ["Which entry case checks equality, and which separately checks approval?"]),
        "loops-total": .init(form: .write, scaffolding: .guided, skillIDs: ["loops-section-2", "loops-section-3"], reflectionPrompts: ["How does a zero latency affect the total and the valid count differently?", "What should happen when no usable readings remain?"]),
        "loops-filter": .init(form: .write, scaffolding: .light, skillIDs: ["loops-section-1", "loops-section-2"], reflectionPrompts: ["Why must both appearances of a long prompt count remain in the queue?", "How is excess_tokens different from the sum of the selected counts?"]),
        "loops-retries-v2": .init(form: .write, scaffolding: .guided, skillIDs: ["loops-section-4", "loops-section-5", "loops-section-6"], reflectionPrompts: ["When should the next delay be compared with the wait budget?", "Which example distinguishes reaching the budget from exceeding it?"]),
        "loops-debug-running-total": .init(form: .debug, scaffolding: .guided, skillIDs: ["loops-section-2", "loops-section-7"], reflectionPrompts: ["Why did the first loop visit hide the running-total bug?", "What does the trace tell you that the final total alone does not?"]),
        "loops-predict-threshold": .init(form: .predict, scaffolding: .guided, skillIDs: ["loops-section-5", "loops-section-7"], reflectionPrompts: ["How did equality with the target affect your original sequence prediction?", "What should the trace contain when the starting value already reaches the target?"]),
        "functions-batches": .init(form: .write, scaffolding: .guided, skillIDs: ["functions-section-1", "values-section-6"], reflectionPrompts: ["How does batches_needed use each call's arguments rather than one saved example?"]),
        "functions-rate": .init(form: .write, scaffolding: .guided, skillIDs: ["functions-section-1", "loops-section-3"], reflectionPrompts: ["Why should repeated calls to pass_rate start with a fresh count?", "How did you separate the empty-list contract from the ordinary fraction calculation?"]),
        "functions-preview-v2": .init(form: .write, scaffolding: .guided, skillIDs: ["functions-section-1", "functions-section-2", "functions-section-4"], reflectionPrompts: ["Which preview calls distinguish the default marker from a caller-supplied marker?", "How does an exact-length text differ from one that needs shortening?"]),
        "functions-debug-return": .init(form: .debug, scaffolding: .guided, skillIDs: ["functions-section-1", "functions-section-5"], reflectionPrompts: ["What evidence separated the local ready count from the value received by the caller?"]),
        "functions-predict-counterexample": .init(form: .counterexample, scaffolding: .light, skillIDs: ["functions-section-5", "decisions-section-2"], reflectionPrompts: ["Why does your smallest title list distinguish the original behavior from the contract?", "What does the counterexample establish that the two initially passing calls did not?"]),
        "collections-count": .init(form: .write, scaffolding: .guided, skillIDs: ["collections-section-1", "collections-section-2"], reflectionPrompts: ["Why are differently spaced or capitalized labels separate keys in this contract?"]),
        "collections-json": .init(form: .write, scaffolding: .guided, skillIDs: ["collections-section-1", "collections-section-3"], reflectionPrompts: ["How does the type of payload differ from the records you iterate over?", "Why should repeated passing model names remain in the result?"]),
        "collections-rank": .init(form: .write, scaffolding: .guided, skillIDs: ["collections-section-4", "collections-section-5"], reflectionPrompts: ["How do the score and name parts of your ordering rule handle ties?", "How did you check that ranking left the original records unchanged?"]),
        "collections-debug-optional-field": .init(form: .debug, scaffolding: .light, skillIDs: ["collections-section-1", "collections-section-2", "collections-section-7"], reflectionPrompts: ["What distinguishes an absent bonus from a required points field?", "How did you verify that repairing the lookup did not add fields to the caller's records?"]),
        "reliability-score": .init(form: .write, scaffolding: .guided, skillIDs: ["reliability-section-1", "reliability-section-2"], reflectionPrompts: ["Which score inputs require a type check before numeric operations are safe?", "Why does accepting a numeric-looking string violate this score contract?"]),
        "reliability-parse": .init(form: .write, scaffolding: .guided, skillIDs: ["reliability-section-2", "reliability-section-4"], reflectionPrompts: ["Which retry spellings show that successful integer conversion is not enough?"]),
        "reliability-summary": .init(form: .debug, scaffolding: .guided, skillIDs: ["reliability-section-2", "reliability-section-5", "reliability-section-6"], reflectionPrompts: ["What did the premature latency report leave unprocessed?", "How did you check both an empty summary and an invalid later reading?"]),
        "reliability-debug-later-record": .init(form: .debug, scaffolding: .light, skillIDs: ["reliability-section-2", "reliability-section-5"], reflectionPrompts: ["Why did putting a good retry record before a bad one change the starter's behavior?", "Which regression case checks that every record receives validation?"]),
        "iteration-leaderboard": .init(form: .write, scaffolding: .guided, skillIDs: ["iteration-section-2", "iteration-section-3"], reflectionPrompts: ["How do numbering and pairing contribute different information to a leaderboard line?"]),
        "iteration-index": .init(form: .write, scaffolding: .guided, skillIDs: ["iteration-section-1", "iteration-section-4"], reflectionPrompts: ["Why do long_ids, tokens_by_id, and distinct_sizes need different collection shapes?"]),
        "iteration-grid": .init(form: .write, scaffolding: .light, skillIDs: ["iteration-section-2", "iteration-section-5", "iteration-section-6"], reflectionPrompts: ["How is an empty grid different from a grid containing an empty row?", "Which grid example checks the first-row tie rule?"]),
        "files-notes": .init(form: .write, scaffolding: .guided, skillIDs: ["files-section-2", "files-section-3"], reflectionPrompts: ["How do saving and appending affect notes already in the file?", "Why must loading preserve a deliberately empty note line?"]),
        "files-csv": .init(form: .write, scaffolding: .guided, skillIDs: ["files-section-3", "files-section-4"], reflectionPrompts: ["Which score values need conversion after CSV reading?", "What should the output CSV contain when no model passes?"]),
        "files-dates": .init(form: .complete, scaffolding: .guided, skillIDs: ["files-section-5", "files-section-6"], reflectionPrompts: ["Which refresh dates would reveal incorrect month or leap-year arithmetic?", "Why does the preview call belong inside the script guard?"]),
        "classes-budget": .init(form: .complete, scaffolding: .guided, skillIDs: ["classes-section-2", "classes-section-3", "classes-section-5"], reflectionPrompts: ["Which budget attributes may change after an accepted spend, and after a rejected one?", "How did you check that two budgets keep separate state?"]),
        "classes-results": .init(form: .complete, scaffolding: .guided, skillIDs: ["classes-section-3", "classes-section-4", "classes-section-5"], reflectionPrompts: ["How is making a result with a new score different from changing the original object?", "Which behavior should change when the shared pass mark changes?"]),
        "classes-dataset": .init(form: .complete, scaffolding: .guided, skillIDs: ["classes-section-5", "classes-section-6", "classes-section-7"], reflectionPrompts: ["How did you verify that each dataset receives its own tags list?", "What should remain unchanged when add_tag rejects a tag?"]),
        "inheritance-chat-card": .init(form: .complete, scaffolding: .guided, skillIDs: ["inheritance-section-2", "inheritance-section-3"], reflectionPrompts: ["Which chat-card behavior comes from the parent without an override?", "Why should a change to the parent's label appear in the child's label?"]),
        "inheritance-token-properties": .init(form: .complete, scaffolding: .guided, skillIDs: ["inheritance-section-3", "inheritance-section-5"], reflectionPrompts: ["Why should billable_tokens reflect attribute changes made after construction?"]),
        "inheritance-scorers": .init(form: .complete, scaffolding: .guided, skillIDs: ["inheritance-section-3", "inheritance-section-6", "inheritance-section-7"], reflectionPrompts: ["Why can the evaluator accept different scorer subclasses without changing its averaging logic?", "How does LooseMatch reuse the exact-match behavior?"]),
        "testing-latency-bands": .init(form: .complete, scaffolding: .guided, skillIDs: ["testing-section-2", "testing-section-6", "testing-section-7"], reflectionPrompts: ["Which latency assertion would fail if a band boundary moved by one?", "Why does passing only the correct classifier not show that your tests detect bugs?"]),
        "testing-cost-errors": .init(form: .complete, scaffolding: .guided, skillIDs: ["testing-section-4", "testing-section-6", "testing-section-7"], reflectionPrompts: ["How do your cost tests distinguish a harmless decimal difference from an incorrect rate?", "Which assertion distinguishes the documented error type from another exception?"]),
        "testing-budget-setup": .init(form: .complete, scaffolding: .guided, skillIDs: ["testing-section-4", "testing-section-5", "testing-section-7"], reflectionPrompts: ["Why should each token-budget test receive a fresh object?", "What evidence checks the budget's state after a rejected overspend?"]),
        "generators-countdown": .init(form: .complete, scaffolding: .guided, skillIDs: ["generators-section-2", "generators-section-3"], reflectionPrompts: ["What state must Countdown remember between next calls?", "How does an exhausted countdown behave on a second loop?"]),
        "generators-ids": .init(form: .write, scaffolding: .guided, skillIDs: ["generators-section-4", "generators-section-6"], reflectionPrompts: ["What keeps consuming request IDs bounded when the generator itself never ends?"]),
        "generators-stream": .init(form: .write, scaffolding: .guided, skillIDs: ["generators-section-5", "generators-section-6"], reflectionPrompts: ["How can you tell whether first_passing reads more scores than it needs?", "When do matching morning and evening statuses belong to the same run?"]),
        "typing-decorators-scalers": .init(form: .write, scaffolding: .guided, skillIDs: ["typing-decorators-section-2", "typing-decorators-section-3", "typing-decorators-section-4"], reflectionPrompts: ["How do two scaler closures remember different factors?", "What do the callable type hints describe about a scaler's input and result?"]),
        "typing-decorators-flexible": .init(form: .write, scaffolding: .guided, skillIDs: ["typing-decorators-section-3", "typing-decorators-section-5"], reflectionPrompts: ["How did you check that measure forwards positional and keyword arguments unchanged?", "Why should changing one returned settings dictionary not affect the next call?"]),
        "typing-decorators-record": .init(form: .complete, scaffolding: .guided, skillIDs: ["typing-decorators-section-5", "typing-decorators-section-6", "typing-decorators-section-7"], reflectionPrompts: ["Which properties of the original function should the recording wrapper preserve?", "What do computed and the cache statistics reveal about a repeated batch request?"]),
        "ds-cleaning-load": .init(form: .write, scaffolding: .guided, skillIDs: ["ds-cleaning-section-2", "ds-cleaning-section-3"], reflectionPrompts: ["Which run fields should remain text and which need numeric conversion?"]),
        "ds-cleaning-missing": .init(form: .write, scaffolding: .guided, skillIDs: ["ds-cleaning-section-3", "ds-cleaning-section-4"], reflectionPrompts: ["How is a missing score marker different from invalid numeric text?"]),
        "ds-cleaning-dedupe": .init(form: .write, scaffolding: .guided, skillIDs: ["ds-cleaning-section-5"], reflectionPrompts: ["Why must prompt normalization happen before duplicate detection?", "Why can the same normalized prompt still appear with two different labels?"]),
        "ds-statistics-summary": .init(form: .write, scaffolding: .light, skillIDs: ["ds-statistics-section-2", "ds-statistics-section-3"], reflectionPrompts: ["How do the sample and population spread measures differ for the same ratings?", "Why does the survey summary reject a single rating?"]),
        "ds-statistics-outliers": .init(form: .write, scaffolding: .guided, skillIDs: ["ds-statistics-section-3", "ds-statistics-section-4"], reflectionPrompts: ["How did you check a latency exactly on an outlier fence?", "Why should the returned outliers retain their original order?"]),
        "ds-statistics-correlation": .init(form: .write, scaffolding: .guided, skillIDs: ["ds-statistics-section-5"], reflectionPrompts: ["Why does Pearson correlation require aligned pairs and spread in both columns?", "What do your positive and negative examples reveal about the sign of the result?"]),
        "ds-aggregation-top-labels": .init(form: .write, scaffolding: .guided, skillIDs: ["ds-aggregation-section-2"], reflectionPrompts: ["Which label example distinguishes alphabetical tie-breaking from first appearance?"]),
        "ds-aggregation-pivot": .init(form: .write, scaffolding: .guided, skillIDs: ["ds-aggregation-section-3", "ds-aggregation-section-4"], reflectionPrompts: ["How is an absent model-day pair represented differently in pair_totals and token_pivot?"]),
        "ds-aggregation-join": .init(form: .complete, scaffolding: .guided, skillIDs: ["ds-aggregation-section-5", "ds-aggregation-section-6"], reflectionPrompts: ["What happens to a run with no matching owner, and why?", "How did you distinguish a join error from a report-formatting error?"])
    ]

    static func exercise(_ id: String, _ title: String, _ instructions: String, _ starter: String, _ solution: String, _ tests: String, _ hints: [String], effort: ExerciseEffort? = nil, expectedStarterError: String? = nil, checkPlan: AuthoredCheckPlan? = nil, practiceProfile: PracticeProfile? = nil) -> Exercise {
        Exercise(id: id, title: title, instructions: instructions, starterCode: starter, referenceSolution: solution, testCode: tests, hints: hints, effort: effort ?? efforts[id], expectedStarterError: expectedStarterError, checkPlan: checkPlan, practiceProfile: practiceProfile ?? practiceProfiles[id])
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
