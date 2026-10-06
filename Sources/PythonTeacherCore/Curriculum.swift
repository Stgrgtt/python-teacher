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

    static func exercise(_ id: String, _ title: String, _ instructions: String, _ starter: String, _ solution: String, _ tests: String, _ hints: [String], effort: ExerciseEffort? = nil) -> Exercise {
        Exercise(id: id, title: title, instructions: instructions, starterCode: starter, referenceSolution: solution, testCode: tests, hints: hints, effort: effort ?? efforts[id])
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

    private static let basics = Chapter(
        id: "basics", title: "1. Your first Python steps", subtitle: "Start with names, numbers, and text",
        lesson: """
        # Code is a sequence of instructions

        You do not need to know Python yet. A program is text that tells the computer what to do. The editor is where you write that text. Python reads the instructions from top to bottom, one line at a time. Spelling, punctuation, and the order of lines matter. All the data in this course is invented; you do not need an account, an API key, or personal information to complete an exercise.

        ## Save a value with a name

        A value is a piece of information, such as a number or some text. A variable is a name you give a value so you can use it later. An assignment has the form `name = value`. Read the equals sign as “save the value on the right under the name on the left,” not as a question about whether two things are equal.

        ```python
        learner = "Mira"
        apples = 3
        print(learner)
        print(apples)
        ```

        This displays Mira, then 3 on a new line. `learner` holds text; `apples` holds a whole number. The quotes mark where the text starts and ends; they are not part of the text itself. Python calls text a **string** and a whole number an **integer**. Single quotes such as `'Mira'` also work: use the same kind at both ends. Use straight quotes, not curly quotation marks. Numbers used for arithmetic have no quotes. `"3"` is text, while `3` is a number. A decimal number such as `1.5` is called a **float**.

        Names are case-sensitive: `apples` and `Apples` are different. Use letters and underscores, with no spaces; a name cannot start with a digit. `apple_count` is a useful descriptive name. In exercises, use exactly the requested names because the checker looks for them.

        ## Calculate with saved numbers

        Python first calculates the right side of an assignment. `+` adds, `-` subtracts, `*` multiplies, and `/` divides. Multiplication and division happen before addition and subtraction; parentheses group a calculation to do first.

        ```python
        boxes = 3
        apples_per_box = 4
        total_apples = boxes * apples_per_box
        remaining = total_apples - 2
        shared = remaining / 2
        print(total_apples)
        print(shared)
        ```

        The results displayed are 12 and 5.0. The earlier lines must run before the lines that use their names. You can assign a new value to an existing variable; the new value replaces the old one. No special declaration is needed.

        ## Join text

        With two strings, `+` joins the text instead of adding numbers. Python does not automatically insert spaces. Include a space inside quotes when you want one. An empty string, `""`, contains no characters.

        ```python
        greeting = "Hello"
        learner = "Mira"
        message = greeting + " " + learner
        print(message)
        ```

        This displays Hello Mira. Do not join a string and a number with `+` yet: these are different types of value. This chapter's text exercises use strings only.

        ## Work in the editor

        `print(message)` displays a value. The word `print` names a built-in operation; parentheses contain the value to display. Printing does not save a result under a name. Our exercises check saved variables, so `answer = 5` and `print(5)` are not interchangeable.

        `print` can display several values at once: separate them with commas inside the parentheses. They appear on one line, in order, with one space between each pair. The values may be different types, such as a string and a number, because `print` is only displaying them, not joining them into one saved value.

        ```python
        learner = "Mira"
        apples = 3
        print(learner, apples)
        print("Apples:", apples)
        ```

        This displays `Mira 3`, then `Apples: 3` on a new line. The commas are not part of the output; `print` adds the single space itself.

        Open a practice exercise and read its Goal and Starting code sections. Keep the given input lines. Replace the starter's placeholder values, such as `0` or `''`, on the requested result lines; do not leave a later placeholder that overwrites your work. Write Python in the editor without the lesson's triple-backtick fence markers. You may add `print` lines to inspect values, but still save every required result. Choose **Check solution** to run the checks. A failed check is feedback, not a penalty: compare the exact names, values, spaces, and types with Expected result, edit, and check again. If Python reports `NameError`, look for a misspelling or a name used before its assignment. `SyntaxError` often means missing quotes or punctuation. Practice hints explain the next idea; the chapter assessment is independent work without hints or solutions.
        """,
        exercises: [
            exercise("basics-name", "Save a learner name", "Goal:\nSave a name as text in a variable.\n\nStarting code:\nlearner_name = '' is an empty-text placeholder. There are no input lines to preserve.\n\nYour task:\n1. Replace the placeholder so learner_name holds the string 'Mira'. Keep the exact variable name and capital M.\n\nExpected result:\nlearner_name is 'Mira' (a string, without quote characters in the value).\n\nCheck:\nChoose Check solution. The check reads learner_name; printing alone does not count.",
                     "learner_name = ''\n",
                     "learner_name = 'Mira'\n",
                     "assert type(learner_name) is str\nassert learner_name == 'Mira'\n",
                     ["An assignment saves the right-hand value under the name on the left.", "Text needs matching quotes; replace the empty text between the starter's quotes.", "Names and text are case-sensitive: keep learner_name and the capital M."]),
            exercise("basics-total", "Add two fruit counts", "Goal:\nFind how many pieces of fruit you have altogether.\n\nStarting code:\napples = 3 and pears = 2 are inputs. total_fruit = 0 is a placeholder, not the answer.\n\nYour task:\n1. Keep apples and pears unchanged.\n2. Replace the total_fruit placeholder with an addition using the two input names. Save the result as an integer, not quoted text.\n\nExpected result:\ntotal_fruit is 5.\n\nCheck:\nChoose Check solution. It checks the inputs and the saved total_fruit value; print is optional.",
                     "apples = 3\npears = 2\ntotal_fruit = 0\n",
                     "apples = 3\npears = 2\ntotal_fruit = apples + pears\n",
                     "assert apples == 3 and pears == 2\nassert type(total_fruit) is int\nassert total_fruit == 5\n",
                     ["Use the input names to read the numbers already saved above.", "The + operator adds two numbers. Numbers for arithmetic do not need quotes.", "Replace the existing total_fruit line rather than keeping a later assignment to zero."]),
            exercise("basics-message", "Join a greeting and a name", "Goal:\nMake a greeting by joining text.\n\nStarting code:\ngreeting = 'Hello' and learner = 'Mira' are inputs. message = '' is the result placeholder.\n\nYour task:\n1. Keep greeting and learner unchanged.\n2. Save a string in message by joining greeting, one space, and learner in that order. Do not add punctuation or extra spaces.\n\nExpected result:\nmessage is exactly 'Hello Mira'.\n\nCheck:\nChoose Check solution. It checks the inputs and message; displayed output is not the saved result.",
                     "greeting = 'Hello'\nlearner = 'Mira'\nmessage = ''\n",
                     "greeting = 'Hello'\nlearner = 'Mira'\nmessage = greeting + ' ' + learner\n",
                     "assert greeting == 'Hello' and learner == 'Mira'\nassert type(message) is str\nassert message == 'Hello Mira'\n",
                     ["The + operator joins strings without adding any spaces of its own.", "A single space inside matching quotes is a string you can join between the inputs.", "Save the joined text in message; a print call only displays it."])
        ],
        assessment: exercise("basics-assessment", "Prepare a simple picnic note", "Goal:\nSave a fruit total and a short picnic note.\n\nStarting code:\napples = 4, pears = 3, place = 'Park', and activity = 'picnic' are inputs. total_fruit and note are placeholders.\n\nYour task:\n1. Keep all four inputs unchanged and keep the exact result names.\n2. Set total_fruit to the integer number of fruit pieces altogether.\n3. Set note to a string containing the place, one space, and the activity, with no extra characters.\n\nExpected result:\ntotal_fruit is 7 and note is exactly 'Park picnic'.\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment to check the saved values. Printing is not required. Complete this assessment independently; hints and solutions are unavailable.",
                             "apples = 4\npears = 3\nplace = 'Park'\nactivity = 'picnic'\ntotal_fruit = 0\nnote = ''\n",
                             "apples = 4\npears = 3\nplace = 'Park'\nactivity = 'picnic'\ntotal_fruit = apples + pears\nnote = place + ' ' + activity\n",
                             "assert apples == 4 and pears == 3\nassert place == 'Park' and activity == 'picnic'\nassert type(total_fruit) is int and total_fruit == 7\nassert type(note) is str and note == 'Park picnic'\n",
                             []),
        quiz: [
            question("basics-q1", "What does learner = 'Mira' do?", ["Saves text under the name learner", "Displays Mira automatically", "Asks whether two values are equal"], 0, "An assignment saves the right-hand value under the variable name on the left. Displaying it requires print."),
            question("basics-q2", "What is saved by total = 3 + 2?", ["The string '32'", "The integer 5", "Nothing until it is printed"], 1, "Unquoted numbers are numeric values, so + adds them. Assignment saves the result without needing print."),
            question("basics-q3", "What does 'Good' + 'day' produce?", ["'Good day'", "'Good+day'", "'Goodday'"], 2, "Joining strings does not insert a space. A desired space must be included in the text.")
        ],
        sectionRoles: ["Code is a sequence of instructions": .overview])

    private static let values = Chapter(
        id: "values", title: "2. Values and expressions", subtitle: "Name data, calculate, and inspect strings", prerequisites: ["basics"],
        lesson: """
        # Build expressions one step at a time

        An expression is code that produces a value: `3 + 2`, a variable name, or an operation on text. Assignment saves that value. Python runs top to bottom, so create inputs before using them. This chapter adds tools for cleaning text, building messages, and dividing counts. Each code block below is a complete example you can run on its own.

        ## What the dot and parentheses mean

        A **method** is a named operation belonging to a value. A string offers methods for working with its text. In `raw.strip()`, `raw` is the string, the dot means “use an operation belonging to this value,” `strip` is the method's name, and `()` calls it: asks Python to do the operation now. Empty parentheses mean that no extra information is supplied. Without the parentheses, you have referred to the operation rather than performed it.

        `strip()` removes whitespace at the beginning and end. Whitespace includes spaces, tabs, and line breaks. It does not remove spaces between words. `lower()` returns text with uppercase letters changed to lowercase; spaces stay where they are. These methods return **new strings**. Returning means producing a value for the surrounding code to use; it does not mean printing it, or changing the original string.

        ```python
        raw = "  MOON Test  "
        trimmed = raw.strip()
        cleaned = trimmed.lower()
        print(raw)
        print(trimmed)
        print(cleaned)
        ```

        First `raw` stores the original text, including two spaces at each edge. Next `trimmed` becomes `"MOON Test"`. Finally `cleaned` becomes `"moon test"`. The original `raw` stays unchanged. Saving each returned value makes the steps easy to inspect.

        ```python
        name = "  DEMO  "
        name.strip()
        print(name)
        name = name.strip()
        print(name)
        ```

        The first print still includes the edge spaces: the earlier method result was not assigned anywhere. The second print shows DEMO without them because the assignment saved the returned text under `name`.

        ## Chaining is the same work written more compactly

        Once separate steps make sense, you can chain calls. Python evaluates `raw.strip()` first, then calls `.lower()` on that returned string. You can keep using separate variables in exercises; chaining is not required.

        ```python
        raw = "  MOON Test  "
        cleaned = raw.strip().lower()
        character_count = len(cleaned)
        print(cleaned)
        print(character_count)
        ```

        This displays moon test and 9. `len` is a built-in function, not a string method: write `len(cleaned)`, with the value inside the parentheses and no dot. That supplied value is called an **argument**. `len` returns an integer count of characters, including the internal space. Quotes that mark string boundaries are not characters inside the string.

        ## Put saved values into a message

        Text joining with `+` works for strings, but cannot directly join a string and an integer. An **f-string** can insert both. Put `f` immediately before the opening quote. Inside that quoted text, `{name}` means “look up this variable and insert its value as text here.” The braces and variable name are replaced; the surrounding punctuation and spaces remain literal text.

        ```python
        label = "moon test"
        attempt = 3
        report = f"{label} / attempt {attempt}"
        print(report)
        ```

        The result is exactly `moon test / attempt 3`. The slash here is inside a string, so it is a displayed character, not division. Without the `f`, braces are ordinary text and no substitution happens. Match both quotes and both braces. `report` is the saved string; `print(report)` only displays it.

        ## Numbers, rates, and units

        An integer is a whole number; a float is a decimal approximation. `int("12")` converts suitable numeric text into integer 12, but does not accept arbitrary words. Do not quote numeric inputs for arithmetic. Parentheses group additions before multiplication when needed.

        In our invented examples, a request is one submitted job; a token is a counted unit of text processed by that job. Input tokens go in and output tokens come back. A rate per 1,000 tokens charges proportionally, even for less than 1,000: it is not a charge rounded to whole packages.

        ```python
        jobs = 5
        input_each = 30
        output_each = 10
        total = jobs * (input_each + output_each)
        dollars = total / 1000 * 0.005
        print(total)
        print(dollars)
        ```

        There are 200 tokens and a cost of 0.001 dollars. Keep the unrounded numeric result; floating-point checks allow tiny representation differences.

        ## Complete groups, leftovers, and rounding up

        A sample is one item to process; a batch is a group with a fixed capacity. `/` is ordinary division. `//` gives the whole-number quotient for these nonnegative counts. `%` gives the leftover count, called the remainder. Integer inputs with `//` and `%` produce integers.

        ```python
        items = 14
        capacity = 4
        divided = items / capacity
        full = items // capacity
        remaining = items % capacity
        needed = (items + capacity - 1) // capacity
        print(divided)
        print(full)
        print(remaining)
        print(needed)
        ```

        The outputs are 3.5, 3, 2, and 4: three full groups use 12 items, leaving two items needing one more group. For a nonnegative count and positive capacity, adding `capacity - 1` before whole-number division rounds the number of groups up. Check exact multiples too: 12 items at capacity 4 gives `(12 + 3) // 4`, still 3, not 4. Zero items gives `(0 + 3) // 4`, which is 0. This rule avoids inventing an extra batch when none is needed.

        When checking your exercise, preserve the input lines and replace only the result placeholders. Inspect intermediate values with print if helpful, but assign all requested results. A `TypeError` can mean that text was used where a number was expected. Compare your predicted values and units before changing the final expression.
        """,
        exercises: [
            exercise("values-budget", "Synthetic token budget", "Goal:\nCalculate the text-processing total and cost of an invented run. A request is one job. Tokens are counted units of text; each job has input tokens going in and output tokens coming back.\n\nStarting code:\nrequests = 12, input_tokens = 80, and output_tokens = 20 are inputs. total_tokens = 0 and cost_dollars = 0 are result placeholders.\n\nYour task:\n1. Keep all three inputs unchanged. Replace the two result placeholders with calculations using those inputs.\n2. Set total_tokens to the integer number of input and output tokens across all requests, not just one request.\n3. Set cost_dollars to the numeric cost at $0.002 per 1,000 tokens. Charge proportionally and do not round. Use a number, not dollar-sign text.\n\nExpected result:\ntotal_tokens is 1200 and cost_dollars is 0.0024.\n\nCheck:\nChoose Check solution. It reads the saved result variables and allows tiny decimal representation differences in the cost; printing is optional.",
                     "requests = 12\ninput_tokens = 80\noutput_tokens = 20\ntotal_tokens = 0\ncost_dollars = 0\n",
                     "requests = 12\ninput_tokens = 80\noutput_tokens = 20\ntotal_tokens = requests * (input_tokens + output_tokens)\ncost_dollars = total_tokens / 1000 * 0.002\n",
                     "assert total_tokens == 1200\nassert abs(cost_dollars - 0.0024) < 1e-10\n",
                     ["input_tokens and output_tokens describe one request, not the entire run. Both contribute to each request's usage.", "Group the input-plus-output addition in parentheses so multiplication applies to the combined amount for each request.", "A per-1,000 rate applies proportionally: express the total in thousands, then apply the rate. Keep the numeric result unrounded and without a dollar sign."]),
            exercise("values-label", "Clean an experiment label", "Goal:\nClean an experiment's name and make a readable report. A label is simply a text name; a run number identifies one attempt.\n\nStarting code:\nraw_label = '  ORBIT Eval  ' and run_number = 7 are inputs. clean_label, report, and label_length are placeholders to replace.\n\nYour task:\n1. Keep raw_label, including its edge spaces, and run_number unchanged.\n2. Set clean_label to a new string with the edge whitespace removed and letters made lowercase. Preserve the space between the two words. The lesson explains strip() and lower(); save their returned text.\n3. Set report to a string containing the cleaned label, ' / run ', and the run number. Include exactly one space on each side of the slash and before the number.\n4. Set label_length to the integer character count of clean_label, including its internal space.\n\nExpected result:\nclean_label is 'orbit eval', report is exactly 'orbit eval / run 7', and label_length is 10.\n\nCheck:\nChoose Check solution. It checks the three saved results; printing the right text alone is not enough.",
                     "raw_label = '  ORBIT Eval  '\nrun_number = 7\nclean_label = raw_label\nreport = ''\nlabel_length = 0\n",
                     "raw_label = '  ORBIT Eval  '\nrun_number = 7\nclean_label = raw_label.strip().lower()\nreport = f'{clean_label} / run {run_number}'\nlabel_length = len(clean_label)\n",
                     "assert clean_label == 'orbit eval'\nassert report == 'orbit eval / run 7'\nassert label_length == 10\n",
                     ["First save cleaned text, then build the report from it; raw_label should retain its original spaces and capitals.", "strip() removes only edge whitespace; lower() returns lowercase text. You can save each result separately or chain the calls. len(clean_label) counts the internal space too.", "An f-string begins with f before the quote. Braces insert a saved value, including a number; text outside braces stays literal. Check the spaces around the slash."]),
            exercise("values-batches", "Pack evaluation batches", "Goal:\nFind how many groups are needed to process some items. A sample is one item; a batch is a group holding at most batch_size items.\n\nStarting code:\nsample_count = 53 and batch_size = 8 are inputs. full_batches, leftover, and scheduled_batches are zero placeholders.\n\nYour task:\n1. Keep both inputs unchanged and replace the three result placeholders with calculations.\n2. Set full_batches to the number of completely filled groups. Set leftover to the number of items remaining after those groups are filled.\n3. Set scheduled_batches to the number of groups needed for every item, including a partially filled final group. An exact multiple needs no extra group; zero items would need zero groups. Assume nonnegative item counts and a positive batch size.\n4. Save all three results as integers, not decimal numbers or text. The lesson distinguishes whole-number division, remainder, and rounding up.\n\nExpected result:\nfull_batches is 6, leftover is 5, and scheduled_batches is 7. Six groups hold 48 items; five more items need one group.\n\nCheck:\nChoose Check solution. It checks the saved integer results and that full groups plus leftovers account for all samples.",
                     "sample_count = 53\nbatch_size = 8\nfull_batches = 0\nleftover = 0\nscheduled_batches = 0\n",
                     "sample_count = 53\nbatch_size = 8\nfull_batches = sample_count // batch_size\nleftover = sample_count % batch_size\nscheduled_batches = (sample_count + batch_size - 1) // batch_size\n",
                     "assert full_batches == 6 and type(full_batches) is int\nassert leftover == 5 and type(leftover) is int\nassert scheduled_batches == 7 and type(scheduled_batches) is int\nassert full_batches * batch_size + leftover == sample_count\n",
                     ["A complete batch uses every space. Items left after full groups still need one group, even though it is only partially filled.", "With nonnegative integer inputs, // gives the number of complete groups and % gives the remaining items. Ordinary / gives a possibly fractional quotient instead.", "The lesson's round-up rule shifts the count by one less than the capacity before whole-number division. Check that the rule gives no extra group for an exact multiple or zero items."])
        ],
        assessment: exercise("values-assessment", "Summarize a synthetic run", "Goal:\nSummarize an invented evaluation run: a set of attempts checking a model, which is just a named system in this scenario.\n\nStarting code:\nmodel_name = '  NOVA  ', successful = 18, and attempted = 24 are inputs. model_label, success_percent, failed, and summary are result placeholders.\n\nYour task:\n1. Keep all three inputs unchanged. Save results under the four exact placeholder names.\n2. model_label must be a string containing the model name without edge whitespace and with lowercase letters.\n3. success_percent must be the numeric percentage of attempts that succeeded, on a 0-to-100 scale, without rounding. failed must be the integer number of attempts that did not succeed.\n4. summary must contain the cleaned model label, a colon and one space, the failed count, one space, and 'failed', with no other characters.\n\nExpected result:\nmodel_label is 'nova', success_percent is 75.0, failed is 6, and summary is exactly 'nova: 6 failed'.\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment. It checks saved results, with a small tolerance for the percentage. Printing is not required. Work independently without hints or solutions.",
                             "model_name = '  NOVA  '\nsuccessful = 18\nattempted = 24\nmodel_label = ''\nsuccess_percent = 0\nfailed = 0\nsummary = ''\n",
                             "model_name = '  NOVA  '\nsuccessful = 18\nattempted = 24\nmodel_label = model_name.strip().lower()\nsuccess_percent = successful / attempted * 100\nfailed = attempted - successful\nsummary = f'{model_label}: {failed} failed'\n",
                             "assert model_label == 'nova'\nassert abs(success_percent - 75.0) < 1e-10\nassert failed == 6\nassert summary == 'nova: 6 failed'\n",
                             []),
        quiz: [
            question("values-q1", "Why does '12' + '3' produce '123'?", ["Python always joins numbers", "Both operands are strings", "Assignment converts values to text"], 1, "Quotes create strings; + concatenates two strings rather than adding numbers."),
            question("values-q2", "For 17 samples in batches of 5, which expression gives leftovers?", ["17 / 5", "17 // 5", "17 % 5"], 2, "% gives the remainder, 2; // gives the three complete batches."),
            question("values-q3", "After name = ' DEMO ' and name.strip(), what does name contain?", ["' DEMO '", "'DEMO'", "Nothing"], 0, "strip returns a new string. Assign that result to a name to retain it.")
        ],
        sectionRoles: ["Build expressions one step at a time": .overview])

    private static let decisions = Chapter(
        id: "decisions", title: "3. Decisions and boundaries", subtitle: "Translate rules into precise branches", prerequisites: ["values"],
        lesson: """
        # Make the rule visible

        A conditional chooses which statements execute. Its condition produces a **Boolean**, one of the two values `True` or `False`, written with capital first letters and no quotes. `>` means greater than, `<` less than, `>=` at least, and `<=` at most. `==` asks whether values are equal; `!=` asks whether they differ. Assignment uses one equals sign; equality testing uses two. For example, `score = 0.8` saves a number, while `score >= 0.8` asks a yes/no question about it.

        `if` begins a decision. A colon ends its condition line. The indented lines below it are its body: the work performed if the condition is true. Use four spaces per indentation level, consistently; indentation is part of Python's meaning. `elif` means “otherwise, if” and `else` means “otherwise.” Neither runs if an earlier branch matched. The example's confidence is an invented score from 0 to 1; blocked means the item must not proceed.

        ```python
        confidence = 0.82
        blocked = False
        if blocked:
            route = "reject"
        elif confidence >= 0.8:
            route = "automatic"
        else:
            route = "review"
        print(route)
        ```

        This displays automatic. Python checks an `if`/`elif` chain in order and runs only the first matching branch. This makes priority part of the program: a blocked item must be rejected even with high confidence. Separate `if` statements are different; several may execute and overwrite the same result. An `else` handles everything not already matched. A chain may have any number of `elif` branches, and the `else` is optional; without it, no branch runs when nothing matches. Make sure every path assigns the result name you need, or a later line may raise `NameError`.

        ## Debug the boundaries

        Write a small decision table before coding: ordinary input, exact threshold, just below it, and conflicting conditions. Predict the route for each row. If a test fails only at the threshold, inspect `<` versus `<=` rather than rewriting everything. In the example above, route is `"automatic"`; if blocked were True, it would be `"reject"` even at the same confidence. With confidence 0.8 exactly it is still automatic, because `>=` includes equality; with 0.79 it is review. Exercise output words may differ from lesson examples: copy the specification's spelling exactly.

        To test a different row of your table, temporarily change an input line, run the code, read the printed result, then restore the original input before choosing Check solution. The checker expects the original input values.

        ## Combine conditions with and, or, and not

        Real rules often have more than one requirement. `and` produces True only when both sides are True. `or` produces True when at least one side is True; it is False only when both sides are False. `not` flips one Boolean: `not True` is False and `not False` is True. Comparisons are calculated first, then combined, so `members >= 2 and has_room` compares members with 2 before applying `and`.

        ```python
        members = 3
        has_room = True
        member_night = False
        can_open = members >= 2 and has_room
        special_price = member_night or members >= 10
        closed = not can_open
        print(can_open)
        print(special_price)
        print(closed)
        ```

        This displays True, False, and False. can_open needs both parts; special_price would need either part, and neither holds. When a rule mixes `and` with `or`, add parentheses to show the grouping you mean: `(admin or used < limit) and not suspended` checks the first pair together. Without parentheses Python performs `and` before `or`, which may differ from what you intended.

        ```python
        used = 100
        limit = 100
        admin = True
        suspended = False
        allowed = (admin or used < limit) and not suspended
        print(allowed)
        ```

        This displays True: the user is at the limit, but admin makes the parenthesized part True, and the user is not suspended. If admin were False, `used < limit` would also be False at equal values, so allowed would be False.

        ## Save a yes/no answer as a Boolean

        A comparison produces a value, so you can save it: `passed = score >= 0.6` stores True or False, not text. Do not quote it; `'True'` is a string, not a Boolean. Saving the answer under a descriptive name lets a later decision reuse it: write `if passed:` rather than `if passed == True:`.

        A range check such as `0 <= score <= 1` is a chained comparison. It means `0 <= score and score <= 1`, so both endpoints are included. `not 0 <= score <= 1` is True only for scores outside that range. Put a validity check before other rules when an invalid value could accidentally satisfy them.

        ```python
        score = 1.2
        in_range = 0 <= score <= 1
        if not in_range:
            label = "out of range"
        elif score >= 0.6:
            label = "high"
        else:
            label = "low"
        print(in_range)
        print(label)
        ```

        This displays False, then out of range. If the `score >= 0.6` branch came first, 1.2 would wrongly be labeled high. With score 0.6 the results would be True and high; with 0 they would be True and low. A decision can also sit inside another branch's body, indented four more spaces, but a single ordered chain is often clearer. Empty strings are false in a condition and nonempty strings are true, but explicit comparisons are clearer while learning. Each exercise in this chapter decides one case; the next chapter shows how to repeat a decision for many values.
        """,
        exercises: [
            exercise("decisions-route", "Route a confidence score", "Goal:\nChoose where an invented result should go. confidence is a score from 0 to 1; blocked means it must not proceed. route is a text label for the decision, not a network address.\n\nStarting code:\nconfidence = 0.80 and blocked = False are inputs. route = '' is an empty-text placeholder.\n\nYour task:\n1. Keep both inputs unchanged. Replace the route placeholder with decision code that saves a string in route.\n2. If blocked is True, the route must be 'reject', regardless of confidence.\n3. Otherwise, confidence of at least 0.80 gets 'auto'; lower confidence gets 'review'. Exactly 0.80 is included in 'auto'.\n4. Express all three rules, not just a fixed answer for this input. An if/elif/else chain chooses one branch in order.\n\nExpected result:\nroute is 'auto' for the given inputs. With blocked True it would be 'reject', even at confidence 0.99. With blocked False and confidence 0.79 it would be 'review'.\n\nCheck:\nChoose Check solution. The supplied check uses the original inputs at the exact 0.80 boundary and reads route; printing is optional.",
                     "confidence = 0.80\nblocked = False\nroute = ''\n",
                     "confidence = 0.80\nblocked = False\nif blocked:\n    route = 'reject'\nelif confidence >= 0.80:\n    route = 'auto'\nelse:\n    route = 'review'\n",
                     "assert confidence == 0.80 and blocked is False\nassert route == 'auto'\n",
                     ["A blocked item cannot proceed even if its score is high. The first matching branch wins, so rule priority determines branch order.", "Check the Boolean blocked before comparing confidence. At least includes equality, which is what >= expresses.", "Every possible path should save a string in route. An else branch covers the cases that did not match earlier conditions."]),
            exercise("decisions-quota", "Spot a quota boundary", "Goal:\nDecide whether a user can do more work. A quota is a maximum amount of usage. An admin is a user permitted to bypass that maximum.\n\nStarting code:\nused = 100 is current usage, limit = 100 is the quota, and admin = False says this is not an administrator. allowed and message are placeholders.\n\nYour task:\n1. Keep used, limit, and admin unchanged.\n2. Set allowed to a Boolean, True or False, not quoted text. Admins are always allowed. Other users are allowed only when used is strictly less than limit. Equal usage and limit must be denied for non-admins.\n3. Set message to exactly 'continue' when allowed is True, otherwise 'quota reached'. Implement both outcomes rather than hard-coding this case.\n\nExpected result:\nallowed is False and message is 'quota reached'. For a non-admin at used 99 and limit 100, they would be True and 'continue'; an admin would be allowed even at the limit.\n\nCheck:\nChoose Check solution. It checks the unchanged inputs and saved outputs for the equal-to-limit case.",
                     "used = 100\nlimit = 100\nadmin = False\nallowed = True\nmessage = ''\n",
                     "used = 100\nlimit = 100\nadmin = False\nallowed = admin or used < limit\nif allowed:\n    message = 'continue'\nelse:\n    message = 'quota reached'\n",
                     "assert used == 100 and limit == 100 and admin is False\nassert allowed is False\nassert message == 'quota reached'\n",
                     ["When used equals limit, a non-admin has no spare capacity. Test that boundary in your reasoning before changing the starter.", "or produces True when either condition is true, so it can express the admin exception alongside the capacity rule.", "Strictly less than excludes equality; <= would include it. Once allowed holds a Boolean, an if/else can select the exact message for that saved decision."]),
            exercise("decisions-bands-v2", "Classify an evaluation score", "Goal:\nGive one invented evaluation score a label. Scores are only valid from 0 to 1. 'pass' means acceptable, 'retry' means try again, and 'invalid' means outside the permitted scale.\n\nStarting code:\nscore = 1.1 is the input. in_range = True and label = 'pass' are placeholders that currently give the wrong answer for this score.\n\nYour task:\n1. Keep score unchanged. Replace both placeholder lines with code that works for any number in score, not just 1.1.\n2. Set in_range to a Boolean, True or False without quotes: True when score is between 0 and 1, including both endpoints 0 and 1; otherwise False. The lesson's chained comparison expresses this range.\n3. Set label with one if/elif/else chain: 'invalid' when score is not in range; otherwise 'pass' when score is at least 0.6, including exactly 0.6; otherwise 'retry'.\n4. Check validity before the passing rule. A score above 1 is also at least 0.6, so the order of branches matters.\n\nExpected result:\nFor score 1.1: in_range is False and label is 'invalid'.\nIf you temporarily try other inputs: -0.1 gives False and 'invalid'; 0.0 gives True and 'retry'; 0.59 gives True and 'retry'; 0.6 and 1.0 give True and 'pass'. Restore score = 1.1 before checking.\n\nCheck:\nChoose Check solution. It checks the original score, the Boolean in_range, and the exact label; printing is optional.",
                     "score = 1.1\nin_range = True\nlabel = 'pass'\n",
                     "score = 1.1\nin_range = 0 <= score <= 1\nif not in_range:\n    label = 'invalid'\nelif score >= 0.6:\n    label = 'pass'\nelse:\n    label = 'retry'\n",
                     "assert score == 1.1\nassert in_range is False\nassert label == 'invalid'\n",
                     ["A score above 1 also exceeds the passing threshold, but it is invalid. Validate the scale before judging whether a score passes.", "A comparison is already a Boolean value, so in_range can be assigned the result of a range check directly. A chained comparison with <= on both sides includes both endpoints.", "Start the chain with not in_range so invalid scores are handled first. Then compare with 0.6 using >= so exactly 0.6 passes, and let else cover the remaining valid scores."])
        ],
        assessment: exercise("decisions-assessment-v2", "Choose a safe deployment action", "Goal:\nChoose an action for one invented release candidate. 'hold' means do not publish because of sensitive data, 'release' means ready to publish, and 'revise' means improve the candidate first. No real sensitive data is present.\n\nStarting code:\nhas_sensitive_data = False, quality = 0.9, and approvals = 1 are inputs. quality is a score from 0 to 1; approvals counts reviewers who approved. publishable = False and action = '' are placeholders.\n\nYour task:\n1. Keep the three inputs unchanged. Replace both placeholders with code that follows the rules for any inputs, not just these values.\n2. Set publishable to a Boolean, not quoted text. It is True only when all three hold: has_sensitive_data is False, quality is at least 0.9 (exactly 0.9 counts), and approvals is at least 1. Otherwise it is False.\n3. Set action to 'hold' whenever has_sensitive_data is True, whatever the other inputs are. Otherwise set it to 'release' when publishable is True, and 'revise' in every other case.\n\nExpected result:\nFor the given inputs: publishable is True and action is 'release'.\nWith has_sensitive_data True: False and 'hold', even at quality 0.99. With quality 0.899: False and 'revise'. With approvals 0: False and 'revise'.\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment. It checks the unchanged inputs, the Boolean publishable, and the exact action. Work independently without hints or solutions; printing is not required.",
                             "has_sensitive_data = False\nquality = 0.9\napprovals = 1\npublishable = False\naction = ''\n",
                             "has_sensitive_data = False\nquality = 0.9\napprovals = 1\npublishable = not has_sensitive_data and quality >= 0.9 and approvals >= 1\nif has_sensitive_data:\n    action = 'hold'\nelif publishable:\n    action = 'release'\nelse:\n    action = 'revise'\n",
                             "assert has_sensitive_data is False and quality == 0.9 and approvals == 1\nassert publishable is True\nassert action == 'release'\n",
                             []),
        quiz: [
            question("decisions-q1", "Why place an invalid-range check before a passing-score check?", ["To make the code run twice", "A score above 1 might otherwise pass", "Invalid values are always strings"], 1, "An out-of-range value such as 1.2 also meets a simple lower-bound pass check."),
            question("decisions-q2", "What changes when two independent if statements replace if/elif?", ["Both bodies can execute", "Neither body executes", "Equality becomes assignment"], 0, "Independent conditions are each checked, so the second body may overwrite the first result."),
            question("decisions-q3", "Which test best distinguishes score > 0.8 from score >= 0.8?", ["score = 0.2", "score = 0.9", "score = 0.8"], 2, "Exactly at the boundary, > is false while >= is true.")
        ])

    private static let loops = Chapter(
        id: "loops", title: "4. Loops and accumulators", subtitle: "Process every item without losing state", prerequisites: ["decisions"],
        lesson: """
        # Keep several values in a list

        Until now, each variable has held one value. A **list** holds several values in order under one name. Write it with square brackets, separating the items with commas: `[18, 24, 19]`. `[]` is an empty list with no items. A list can hold numbers, strings, or Booleans, and the same value may appear more than once.

        ```python
        temperatures = [18, 24, 19]
        first = temperatures[0]
        last = temperatures[2]
        count = len(temperatures)
        print(first)
        print(last)
        print(count)
        ```

        This displays 18, 19, and 3. Each item has a position number called an **index**. Indices start at zero: the first item has index 0 and the second has index 1, so the last of three items has index 2. Brackets after a list name read the item at that index. `len`, which you used for text, also counts the items in a list. Asking for an index that does not exist, such as `temperatures[3]` here, raises `IndexError`. Two lists are equal with `==` when they hold the same items in the same order.

        ```python
        names = []
        names.append("Mira")
        names.append("Theo")
        print(names)
        print(len(names))
        ```

        This displays `['Mira', 'Theo']` and 2. `append(value)` is a list method that adds one value to the end. Unlike string methods such as strip, which return a new string, append changes the list itself and returns None. Write `names.append("Mira")` on its own line; never write `names = names.append("Mira")`, which would replace your list with None.

        ## Visit every item with for

        A `for` loop runs the same indented body once for each item of a list, in order. In `for temperature in temperatures:`, Python assigns the first item to the loop variable temperature, runs the body, then assigns the next item, and so on. You choose the loop variable's name; you do not change an index yourself. The line ends with a colon, and the body is indented four spaces. A decision inside the body needs four more spaces. Lines dedented back to the level of `for` run once, after the loop finishes.

        ```python
        temperatures = [18, 24, 19]
        labels = []
        for temperature in temperatures:
            if temperature >= 20:
                labels.append("warm")
            else:
                labels.append("cool")
        print(labels)
        ```

        This produces `['cool', 'warm', 'cool']`. The comparison runs three times, once per item, and each selected branch adds one label. The input list stays unchanged; the output is built separately.

        ```python
        latencies = [12, 0, 18]
        total = 0
        positive_count = 0
        for latency in latencies:
            total += latency
            if latency > 0:
                positive_count += 1
        print(total)
        print(positive_count)
        ```

        An **iteration** is one visit through a loop's body. An **accumulator** is a variable that remembers work across those visits. Initialize it (give it a starting value) before the loop, update it inside, and use the final result afterward. `total += latency` is shorthand for `total = total + latency`: read the old total, add the current reading, and save the new total. A counter is an accumulator that increases by one. In the example, total changes from 0 to 12, stays 12 for the zero, then becomes 30. positive_count ends at 2 because this example counts only values greater than zero.

        Resetting total inside the body loses previous work. To collect selected values, start with an empty list and call `append` when the condition matches. Preserve input order and duplicates unless the specification explicitly says otherwise. Each exercise defines its own valid values: in the measurement practice, zero IS valid, unlike the positive-only example above.

        ## Finish calculations after visiting every item

        An average, also called an arithmetic mean, is a sum divided by the number of included items. You cannot divide by zero. An empty list makes no visits, so decide its answer explicitly. Notice how the final if below is aligned with for: it runs after the loop, not once per item.

        ```python
        readings = [4, 0, 8]
        total = 0
        count = 0
        for reading in readings:
            total += reading
            count += 1
        if count > 0:
            average = total / count
        else:
            average = 0.0
        print(average)
        ```

        The result is 4.0. `if count:` is a shorter check for a nonzero numeric count; zero is false in a condition. Lists are false when empty, so `if not readings:` means the list is empty. You may see `average = total / count if count else 0.0` in reference code. This conditional expression chooses the value before `if` when the condition is true, otherwise the value after `else`; only the chosen side is evaluated. The longer if/else above is equally valid and often clearer.

        ## Repeat a known number of times

        `range(4)` supplies 0, 1, 2, 3 to a loop: its stop is excluded. `range(1, 5)` supplies 1 through 4. `range(0)` supplies no values. A retry is another attempt after a failure; a schedule is just a list of planned delays, not an instruction to actually wait. `**` raises a number to a power: `2 ** 0` is 1, `2 ** 1` is 2, and `2 ** 3` is 8. It is not written `^`.

        ```python
        planned_delays = []
        for attempt in range(3):
            seconds = 3 * (2 ** attempt)
            planned_delays.append(seconds)
        print(planned_delays)
        ```

        This produces `[3, 6, 12]`. Each visit computes a new number and appends it. `append` changes the list itself; do not write `planned_delays = planned_delays.append(seconds)`, because append does not return the updated list. No waiting or network connection happens.

        ## Repeat while a condition holds

        Sometimes you do not know in advance how many visits are needed. A `while` loop repeats its indented body as long as its condition is True. Python checks the condition before every visit: if it is True, the body runs, then the condition is checked again. As soon as it is False, the loop ends and the next dedented line runs. If the condition is False at the start, the body never runs.

        ```python
        balance = 20
        weeks = 0
        while balance < 100:
            balance = balance * 2
            weeks += 1
        print(balance)
        print(weeks)
        ```

        balance goes from 20 to 40, 80, then 160; at 160 the condition `balance < 100` is False, so the loop stops. This displays 160 and 3. Something inside the body must change the values in the condition so that it eventually becomes False. If nothing changes, the loop repeats forever: an **infinite loop**. This app stops any run that takes longer than 8 seconds and reports a timeout; if that happens, look for a while condition that can never become False.

        ```python
        attempt = 0
        delays = []
        while attempt < 3:
            delays.append(5 * attempt)
            attempt += 1
        print(delays)
        ```

        This displays `[0, 5, 10]`. The counter attempt starts at 0 and increases on every visit; forgetting `attempt += 1` would make the condition stay True forever. When a list or a fixed count already determines the visits, a for loop is usually simpler and cannot run forever by accident.

        ## Stop early or skip an item

        `break` ends the nearest enclosing loop immediately; Python continues with the first line after the loop. `continue` skips the rest of the current visit only: a for loop moves on to its next item, and a while loop checks its condition again. Both normally sit inside an if, so they apply only in selected cases.

        ```python
        readings = [4, -1, 7, 0, 9]
        total = 0
        for reading in readings:
            if reading < 0:
                continue
            if reading == 0:
                break
            total += reading
        print(total)
        ```

        4 is added; -1 is skipped by continue; 7 is added, making 11; 0 triggers break, so 9 is never visited. This displays 11. A common use of break is stopping before a limit would be exceeded: check first, then update.

        ```python
        budget = 10
        costs = [3, 4, 5, 1]
        chosen = []
        spent = 0
        for cost in costs:
            if spent + cost > budget:
                break
            chosen.append(cost)
            spent += cost
        print(chosen)
        print(spent)
        ```

        This displays `[3, 4]` and 7. Adding 5 would make 12, more than the budget, so the loop stops; the final 1 is never considered because break ends the whole loop, not just one visit. Exactly reaching the budget would be allowed, because the test uses `>`. In a while loop, update the counter before any continue, or the skipped update can cause an infinite loop.

        ## Trace before guessing

        A **trace** records what each variable holds after every visit. You can make Python print one line per visit with an f-string, then compare it with your prediction.

        ```python
        values = [3, 0, 5]
        total = 0
        for value in values:
            total += value
            print(f"value {value}, total {total}")
        print(f"final {total}")
        ```

        This displays value 3, total 3; then value 0, total 3; then value 5, total 8; and finally final 8. On paper, make a table with columns for the current item, the condition result, and the accumulator after the update. Include zero, a threshold equality, and repeated values. Ask what happens when the input list is empty: the body never runs, so sensible initial values become the result. For while loops, also record the condition each time it is checked. Never remove items from the same list you are traversing; collect a new result instead. A correct program should match both its final answer and your step-by-step explanation.
        """,
        exercises: [
            exercise("loops-total", "Count usable measurements", "Goal:\nSummarize usable time measurements. Latency means how long a job took; ms means milliseconds. In this invented data, a negative number marks a missing reading, not a negative duration.\n\nStarting code:\nlatencies = [10, -1, 0, 25, -1, 5] is the input list. total_ms and valid_count start at 0, and mean_ms starts at 0.0. These are result variables to update.\n\nYour task:\n1. Keep latencies unchanged. Use a loop to visit its readings.\n2. Exclude negative readings. Include zero as a valid measurement. Save the sum of included readings in integer total_ms and their number in integer valid_count.\n3. Set mean_ms to the arithmetic mean of included readings as a number: their total divided by their count. If there are no valid readings, use 0.0 instead of dividing by zero. Compute the mean after the loop.\n\nExpected result:\ntotal_ms is 40, valid_count is 4, and mean_ms is 10.0. An empty list or a list with only negative readings would give 0, 0, and 0.0.\n\nCheck:\nChoose Check solution. It checks the unchanged input and three saved results for the supplied list. Printing is optional.",
                     "latencies = [10, -1, 0, 25, -1, 5]\ntotal_ms = 0\nvalid_count = 0\nmean_ms = 0.0\n",
                     "latencies = [10, -1, 0, 25, -1, 5]\ntotal_ms = 0\nvalid_count = 0\nfor latency in latencies:\n    if latency >= 0:\n        total_ms += latency\n        valid_count += 1\nmean_ms = total_ms / valid_count if valid_count else 0.0\n",
                     "assert latencies == [10, -1, 0, 25, -1, 5]\nassert total_ms == 40\nassert valid_count == 4\nassert mean_ms == 10.0\n",
                     ["The sum measures total time; the count measures how many valid readings contributed. Keep two accumulators initialized before the loop.", "Only nonnegative readings contribute to either accumulator. Zero contributes no time but still increases the number of valid readings by one.", "Calculate the average after the loop has collected all readings. Check whether the count is positive before division; when it is zero, the specified average is 0.0."]),
            exercise("loops-filter", "Queue long prompts", "Goal:\nSelect long text inputs and count only their extra length. A prompt is text sent to a model; its token count measures text units, not characters. The invented length allowance is 40 tokens per prompt.\n\nStarting code:\ntoken_counts = [0, 40, 41, 12, 80, 41] is the input list. long_counts starts as an empty list and excess_tokens starts at zero.\n\nYour task:\n1. Keep token_counts unchanged. Build long_counts as a new list of only the integer counts strictly greater than 40. A count of exactly 40 is not long.\n2. Preserve input order and repeated values; both appearances of 41 must remain.\n3. Set integer excess_tokens to the total amount above the 40-token allowance across selected prompts, not the sum of their full lengths. A 41-token prompt contributes 1 extra token.\n\nExpected result:\nlong_counts is [41, 80, 41] and excess_tokens is 42. With no counts above 40, the results would be [] and 0.\n\nCheck:\nChoose Check solution. It checks the original input, selected list, and saved extra-token total; no prompt text or network access is needed.",
                     "token_counts = [0, 40, 41, 12, 80, 41]\nlong_counts = []\nexcess_tokens = 0\n",
                     "token_counts = [0, 40, 41, 12, 80, 41]\nlong_counts = []\nexcess_tokens = 0\nfor count in token_counts:\n    if count > 40:\n        long_counts.append(count)\n        excess_tokens += count - 40\n",
                     "assert token_counts == [0, 40, 41, 12, 80, 41]\nassert long_counts == [41, 80, 41]\nassert excess_tokens == 42\n",
                     ["Strictly greater than excludes a count of exactly 40. Use the same selection condition for the output list and extra-token total.", "append adds a qualifying count at the end of a list, retaining order. Repeated qualifying inputs must each get a visit; do not remove duplicates.", "Only the portion beyond the allowance contributes to excess_tokens. For example, a count of 45 contributes 5 rather than 45; accumulate each selected item's extra portion."]),
            exercise("loops-retries-v2", "Build a retry schedule within a wait budget", "Goal:\nPlan delays before repeated attempts without going over a total waiting budget. A retry is another attempt after a failure. This schedule is only a list of numbers; your code must not actually wait or contact a service.\n\nStarting code:\nretry_count = 4, base_seconds = 2, and max_wait = 20 are inputs. delays = [] and total_wait = 0 are result starting values.\n\nYour task:\n1. Keep all three inputs unchanged. Use a loop to build delays as a list of integer seconds in retry order. A while loop with a counter, or a for loop over range, both work.\n2. Number retries from 0 up to, but not including, retry_count. Each delay is base_seconds multiplied by 2 raised to that retry number: the first delay is base_seconds and each next delay doubles. The lesson explains range and the power operator **.\n3. Before adding a delay, check the budget: if total_wait plus that delay would be greater than max_wait, stop planning immediately and add no further delays. Reaching exactly max_wait is allowed. The lesson shows how break or a while condition stops a loop early.\n4. Otherwise append the delay and add it to integer total_wait. If your loop is a while loop, make sure the retry number increases on every visit so the loop ends.\n\nExpected result:\ndelays is [2, 4, 8] and total_wait is 14. The next delay, 16, would make 30, which is over 20.\nIf you temporarily try other inputs: max_wait = 14 gives [2, 4, 8] and 14 (exactly reaching the budget); max_wait = 100 gives [2, 4, 8, 16] and 30; max_wait = 1 gives [] and 0. Restore max_wait = 20 before checking.\n\nCheck:\nChoose Check solution. It checks the unchanged inputs, ordered delays, and saved total; do not use a sleep operation.",
                     "retry_count = 4\nbase_seconds = 2\nmax_wait = 20\ndelays = []\ntotal_wait = 0\n",
                     "retry_count = 4\nbase_seconds = 2\nmax_wait = 20\ndelays = []\ntotal_wait = 0\nretry_number = 0\nwhile retry_number < retry_count:\n    delay = base_seconds * (2 ** retry_number)\n    if total_wait + delay > max_wait:\n        break\n    delays.append(delay)\n    total_wait += delay\n    retry_number += 1\n",
                     "assert retry_count == 4 and base_seconds == 2 and max_wait == 20\nassert delays == [2, 4, 8]\nassert total_wait == 14\n",
                     ["Retry numbers start at zero and stop before retry_count. range(retry_count) supplies them, or a while loop can count them with a variable that starts at 0 and increases by one each visit.", "** means raising to a power, not multiplication by the exponent. A power of zero gives 1, so the first delay is the base itself. ^ is a different operation and is not suitable here.", "Compute the delay first, then compare total_wait plus that delay with max_wait using > so an exact match is still allowed. When it is over the budget, break ends the loop; otherwise update both the list and the total."])
        ],
        assessment: exercise("loops-assessment", "Track consecutive passing checks", "Goal:\nDescribe passing checks in their original sequence. A streak means adjacent passing scores without a failed score between them; it is not the total number of passes.\n\nStarting code:\nscores = [0.8, 0.9, 0.4, 0.8, 0.8, 1.0, 0.2] is the input list. passing_count, longest_streak, and current_streak start at zero.\n\nYour task:\n1. Keep scores unchanged and in its original order. Use a loop to calculate three integer results under the supplied names.\n2. Scores at least 0.8 pass, including exactly 0.8; smaller scores fail. passing_count is the number of all passing scores.\n3. longest_streak is the largest number of adjacent passes anywhere in the list. current_streak is the number of adjacent passes at the very end; it is zero when the final score fails.\n4. An empty input would have all three results equal to zero.\n\nExamples:\nFor the supplied list: passing_count = 5, longest_streak = 3, current_streak = 0.\nFor [0.8, 0.2, 0.9, 1.0]: the results would be 3, 2, and 2.\nFor [0.1]: all three would be 0.\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment. It checks the original list and saved results for that list. Work independently without hints or solutions.",
                             "scores = [0.8, 0.9, 0.4, 0.8, 0.8, 1.0, 0.2]\npassing_count = 0\nlongest_streak = 0\ncurrent_streak = 0\n",
                             "scores = [0.8, 0.9, 0.4, 0.8, 0.8, 1.0, 0.2]\npassing_count = 0\nlongest_streak = 0\ncurrent_streak = 0\nfor score in scores:\n    if score >= 0.8:\n        passing_count += 1\n        current_streak += 1\n        if current_streak > longest_streak:\n            longest_streak = current_streak\n    else:\n        current_streak = 0\n",
                             "assert scores == [0.8, 0.9, 0.4, 0.8, 0.8, 1.0, 0.2]\nassert passing_count == 5\nassert longest_streak == 3\nassert current_streak == 0\n",
                             []),
        quiz: [
            question("loops-q1", "Why initialize a running sum before the loop?", ["So previous iterations are retained", "So the sum is always negative", "So an empty list raises an error"], 0, "Initializing inside the loop resets accumulated work each iteration."),
            question("loops-q2", "What values does range(1, 4) visit?", ["1, 2, 3, 4", "0, 1, 2, 3", "1, 2, 3"], 2, "The start is included and the stop is excluded."),
            question("loops-q3", "What is a useful first debugging step for an incorrect streak counter?", ["Change all comparison operators", "Trace counter values after each input", "Sort the inputs first"], 1, "A trace reveals the precise iteration where state diverges; sorting would change consecutive order.")
        ],
        sectionRoles: ["Trace before guessing": .troubleshooting])

    private static let functions = Chapter(
        id: "functions", title: "5. Functions and contracts", subtitle: "Turn working logic into reusable behavior", prerequisites: ["loops"],
        lesson: """
        # Separate inputs from results

        You have called built-in functions such as `len(text)`. Now you can define your own. A **function** gives a reusable name to a calculation, so the same rules can work with different inputs. `def` means “define a function.” It is followed by the function name, parentheses containing input names separated by commas, then a colon. The indented body contains the work. Input names in the definition are **parameters**; values supplied in a call are **arguments**.

        In the example below, requests and tokens_each are parameters. Calling `tokens_needed(3, 20)` supplies 3 as requests and 20 as tokens_each, in that order. `return` sends the resulting value back to the caller, which saves it in small_run. The next call supplies different values and produces a separate result. Local variables belong to that call, so calls do not share counters unless you deliberately use outside state.

        Defining a function does not run its body. The lines beginning with small_run and empty_run are calls; they are not indented because they are outside the function. `assert` is a check: Python continues silently if its condition is true and reports `AssertionError` if it is false. Here both checks pass. The app also uses checks to compare your function's actual result with the required result.

        ```python
        def tokens_needed(requests, tokens_each):
            return requests * tokens_each

        small_run = tokens_needed(3, 20)
        empty_run = tokens_needed(0, 20)
        assert small_run == 60
        assert empty_run == 0
        ```

        `print` displays information, but it does not substitute for `return`. A function that reaches its end without a return statement returns `None`. A return also ends the current call immediately: place it after a loop when you need to process every item. Indenting it inside the loop is a common reason only the first item is processed.

        `None` is Python's special “no value” result, not the string `'None'`, zero, or empty text. It has a capital N and no quotes. A function can deliberately return it when no answer exists. `return` stops only that function call, not the whole program.

        A **contract** describes accepted inputs, exact outputs, and boundary behavior. In this chapter, exercises promise valid input types and ranges; do not invent validation rules. A finite number is an ordinary number, excluding infinity and the special not-a-number value introduced later. A fraction such as 0.5 describes half; a percentage describes the same amount as 50. Read carefully which one is requested.

        Pure functions compute results without changing caller-owned data or depending on unrelated global variables (names outside the function). They are easy to test repeatedly. Create accumulators inside the function so every call starts fresh. “Do not modify the input” means leave the supplied list's order and items unchanged; reading, counting, and building a new list are fine.

        ## Read part of a string with a slice

        Strings, like lists, use zero-based indexing. In `text[0]`, brackets select the first character. A **slice** selects a range: `text[start:stop]` includes start but excludes stop. Leaving start out means begin at the first character. `text[:3]` takes at most the first three characters, indices 0, 1, and 2. A stop beyond the end is safe; a stop of zero gives empty text.

        ```python
        word = "Planet"
        first = word[0]
        beginning = word[:3]
        empty = word[:0]
        whole = word[:20]
        print(first)
        print(beginning)
        print(empty)
        print(whole)
        ```

        This displays P, Pla, an empty line, then Planet. A slice produces new text; it does not change word. Spaces and uppercase letters are characters too. A preview is a shortened display of some text, often followed by dots to show that more exists. The literal `'...'` contains three ordinary dots, not one special ellipsis character.

        Lists use the same brackets. A **negative index** counts from the end: `items[-1]` is the last item and `items[-2]` the one before it, whatever the length. A slice of a list returns a new, shorter list. Leaving stop out means continue to the end, so `items[1:]` is everything after the first item.

        ```python
        items = [10, 20, 30, 40]
        last = items[-1]
        middle = items[1:3]
        first_two = items[:2]
        rest = items[1:]
        print(last)
        print(middle)
        print(first_two)
        print(rest)
        print(items)
        ```

        This displays 40, `[20, 30]`, `[10, 20]`, `[20, 30, 40]`, then the unchanged `[10, 20, 30, 40]`. `items[1:3]` takes indices 1 and 2 because the stop, 3, is excluded. Negative indices work on strings too: `"Planet"[-1]` is `"t"`. On an empty list, `items[-1]` raises `IndexError`, but any slice safely returns `[]`.

        ## Replace a function's placeholder, not its interface

        Function exercises provide a starter definition with the exact name and parameters the checker calls. Keep that definition line. Replace its placeholder body, such as `return 0`, with your work, keeping four spaces per level. Add more indented lines as needed. Do not replace parameters with fixed example values: tests call the same function with different arguments. A local result alone is not enough; return the required value so the caller can inspect it.

        ## Default values and keyword arguments

        A parameter can have a **default value**, written `name=value` in the definition. If a call leaves that argument out, Python uses the default; if the call supplies it, the supplied value wins. Parameters with defaults must come after the parameters without them.

        ```python
        def label_score(score, threshold=0.5, pass_word="pass"):
            if score >= threshold:
                return pass_word
            return "retry"

        print(label_score(0.7))
        print(label_score(0.7, 0.8))
        print(label_score(0.9, pass_word="ok"))
        print(label_score(threshold=0.9, score=0.95))
        ```

        This displays pass, retry, ok, and pass. The first call uses both defaults. The second supplies 0.8 as threshold by position. The third uses a **keyword argument**: `pass_word="ok"` names the parameter it fills, so threshold keeps its default even though it comes earlier in the definition. Keyword arguments may appear in any order, as in the last call, but they must come after any positional arguments. By convention there are no spaces around `=` in a keyword argument or default. Built-in functions use keyword arguments for options too; later chapters show some.

        One pitfall: Python creates a default value once, when `def` runs, not freshly on every call. A changeable default such as an empty list would be shared by every call that omits it, so items from earlier calls would reappear. Use None as the default and create the fresh list inside the function. `tags is None` asks whether tags holds the None value; `is` is the usual way to compare with None.

        ```python
        def add_tag(tag, tags=None):
            if tags is None:
                tags = []
            tags.append(tag)
            return tags

        first = add_tag("new")
        second = add_tag("old")
        print(first)
        print(second)
        ```

        This displays `['new']` and then `['old']`: each call that omits tags gets its own new list. Text, numbers, Booleans, and None never change in place, so they are safe defaults.

        ## Test a hypothesis

        Call your function with a typical case, an empty or zero case, and an exact boundary. Run it twice with different inputs to uncover stale global state. When debugging, shrink a failing case to the smallest example that still fails. State your prediction, change one relevant line, and rerun all tests rather than only the previously failing one.
        """,
        exercises: [
            exercise("functions-batches", "Reusable batch sizing", "Goal:\nMake batch sizing reusable for different item counts. A sample is one item; a batch is a group holding at most batch_size items.\n\nStarting code:\ndef batches_needed(sample_count, batch_size): defines the required function. Its return 0 is a placeholder. Tests supply the two arguments; do not replace them with fixed values.\n\nYour task:\n1. Keep the function name and parameter order. Replace its body to use the arguments on every call, not global inputs. sample_count is a nonnegative integer and batch_size is a positive integer; no invalid-input handling is required.\n2. Return an integer number of batches sufficient for every sample, counting a partially filled final group. Zero samples must return 0. Exact multiples must not add an extra group.\n3. Return the result to the caller; printing it is not a substitute. The values lesson explains rounding up with whole-number division.\n\nExamples:\nbatches_needed(0, 8) returns 0.\nbatches_needed(16, 8) returns 2.\nbatches_needed(17, 8) returns 3.\nbatches_needed(3, 10) returns 1.\n\nCheck:\nChoose Check solution. It calls your function with zero, exact-multiple, partial-group, and one-item cases, and checks an integer result.",
                     "def batches_needed(sample_count, batch_size):\n    return 0\n",
                     "def batches_needed(sample_count, batch_size):\n    return (sample_count + batch_size - 1) // batch_size\n",
                     "assert batches_needed(0, 8) == 0\nassert batches_needed(16, 8) == 2\nassert batches_needed(17, 8) == 3\nassert batches_needed(1, 1) == 1\nassert batches_needed(3, 10) == 1\nassert type(batches_needed(17, 8)) is int\n",
                     ["A full final batch needs no extra group; a partial one needs exactly one more. Try predicting zero and exact-multiple cases first.", "Whole-number division gives only completely filled groups. The remainder tells you whether any items still need space.", "The values lesson's round-up rule adds one less than the group capacity before whole-number division. Keep the calculation inside the function and return its integer result."]),
            exercise("functions-rate", "Measure passing fraction", "Goal:\nMeasure the share of scores that pass. A threshold is the minimum passing value. A fraction uses a 0-to-1 scale: half is 0.5, not 50 percent.\n\nStarting code:\ndef pass_rate(scores, threshold): is the required function. return 0.0 is a placeholder. The checker supplies a list and threshold on each call.\n\nYour task:\n1. Keep the function name and parameters. scores is a list of finite numbers and threshold is a finite number; these are ordinary numbers, not infinity or NaN. They need not be limited to 0 through 1.\n2. Return the numeric fraction of scores at least threshold; a score equal to threshold passes. Count repeated scores as separate items.\n3. For an empty list, return 0.0. Leave scores, including its order, unchanged. Calculate from the arguments on each call, with no leftover state from earlier calls.\n4. Return the fraction, not printed text. Count matches before dividing by the number of scores.\n\nExamples:\npass_rate([], 0.5) returns 0.0.\npass_rate([0.5], 0.5) returns 1.0.\npass_rate([0.8, 0.2, 0.8], 0.8) returns two thirds, approximately 0.6666666667, without rounding.\npass_rate([1, 2, 3], 2) also returns two thirds.\n\nCheck:\nChoose Check solution. It calls your function on several lists, including empty and boundary cases, and checks that a supplied list remains unchanged.",
                     "def pass_rate(scores, threshold):\n    return 0.0\n",
                     "def pass_rate(scores, threshold):\n    if not scores:\n        return 0.0\n    passed = 0\n    for score in scores:\n        if score >= threshold:\n            passed += 1\n    return passed / len(scores)\n",
                     "assert pass_rate([], 0.5) == 0.0\nassert pass_rate([0.5], 0.5) == 1.0\nassert pass_rate([0.1, 0.2], 0.5) == 0.0\nsample = [0.8, 0.2, 0.8]\nassert abs(pass_rate(sample, 0.8) - 2 / 3) < 1e-10\nassert sample == [0.8, 0.2, 0.8]\nassert pass_rate([1, 2, 3], 2) == 2 / 3\n",
                     ["An empty list has length zero, so a division by its length would fail. Give that case the specified result before attempting division.", "A score equal to threshold passes. Count every qualifying item, including duplicates, and compare that count with the total number of items, not just the valid matches.", "A fraction is the passing count divided by the list length, without multiplying by 100. Return it after the loop; returning inside the loop would stop after the first visited score."]),
            exercise("functions-preview-v2", "Create prompt previews", "Goal:\nCreate a short display of text, called a preview. A marker, three dots by default, shows that some original text was omitted.\n\nStarting code:\ndef preview(text, max_chars, marker='...'): is the required function. marker has a default value, so callers may leave it out. return text is a placeholder that currently never shortens anything.\n\nYour task:\n1. Keep the function name, the parameter order, and the default marker='...'. text and marker are strings and max_chars is a nonnegative integer. Use each call's arguments, not fixed example values.\n2. Return text unchanged if its length is at most max_chars, including exact equality. No marker is added in that case.\n3. If it is longer, return its first max_chars characters followed by marker. The marker does not count toward max_chars. Use the lesson's slicing concept to take a beginning portion. When the caller omits marker, the default three ordinary dots '...' are used; when the caller supplies one, for example as the keyword argument marker='>', use it instead.\n4. Preserve all original spaces and letter case in the kept portion. Return a string; do not print instead. Empty text stays empty, and nonempty text with max_chars zero produces only the marker.\n\nExamples:\npreview('demo', 4) returns 'demo'.\npreview('demo', 2) returns 'de...'.\npreview('demo', 0) returns '...'.\npreview('', 0) returns ''.\npreview('  AI', 2) returns '  ...' with two spaces before the dots.\npreview('demo', 2, marker='>') returns 'de>'.\npreview(text='demo', max_chars=3) returns 'dem...'.\npreview('demo', 4, marker='!') returns 'demo'.\n\nCheck:\nChoose Check solution. It tests empty text, zero and oversized limits, exact length, preservation of spaces, the default marker, and calls using keyword arguments.",
                     "def preview(text, max_chars, marker='...'):\n    return text\n",
                     "def preview(text, max_chars, marker='...'):\n    if len(text) <= max_chars:\n        return text\n    return text[:max_chars] + marker\n",
                     "assert preview('', 0) == ''\nassert preview('demo', 4) == 'demo'\nassert preview('demo', 8) == 'demo'\nassert preview('demo', 0) == '...'\nassert preview('Synthetic prompt', 9) == 'Synthetic...'\nassert preview('  AI', 2) == '  ...'\nassert preview('demo', 2, marker='>') == 'de>'\nassert preview('demo', 2, '~') == 'de~'\nassert preview(text='demo', max_chars=3) == 'dem...'\nassert preview(marker='', max_chars=1, text='demo') == 'd'\nassert preview('demo', 4, marker='!') == 'demo'\n",
                     ["Text that already fits, including an exact-length match, must be returned unchanged without a marker. Separate that case from text that needs shortening.", "A slice with no start begins at the first character; its stop is excluded. Using the character limit as that stop takes at most that many characters without changing their spaces or case.", "Join the marker parameter, not a fixed '...', to a shortened result; the default in the definition supplies the dots when the caller omits it. With a zero character limit the kept portion is empty, but the marker is still needed if the original text was nonempty."])
        ],
        assessment: exercise("functions-assessment", "Find the first usable candidate", "Goal:\nSelect the first usable piece of text. A candidate is one possible text choice; usable means it meets the minimum length after edge whitespace is removed.\n\nStarting code:\ndef first_usable(candidates, min_chars): is the required function. return None is its placeholder body. The checker supplies different arguments for different calls.\n\nYour task:\n1. Keep the function name and parameter order. candidates is a list of strings and min_chars is a positive integer. Do not change the list or its original strings.\n2. Return the first candidate in input order whose text, without surrounding whitespace, has at least min_chars characters. Exactly min_chars qualifies. The returned string must have its edge whitespace removed, while preserving case and internal whitespace.\n3. If no candidate qualifies, including when the list is empty, return Python's None value, not the string 'None' or empty text.\n\nExamples:\nfirst_usable([], 1) returns None.\nfirst_usable([' ', 'ab'], 3) returns None.\nfirst_usable(['  AI  ', 'later'], 2) returns 'AI'.\nfirst_usable(['x', '  A B  ', 'longer'], 3) returns 'A B'.\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment. It checks different calls, first-match ordering, boundary length, absence of a match, and unchanged input. Work independently without hints or solutions.",
                             "def first_usable(candidates, min_chars):\n    return None\n",
                             "def first_usable(candidates, min_chars):\n    for candidate in candidates:\n        cleaned = candidate.strip()\n        if len(cleaned) >= min_chars:\n            return cleaned\n    return None\n",
                             "assert first_usable([], 1) is None\nassert first_usable([' ', 'ab'], 3) is None\nassert first_usable(['  AI  ', 'later'], 2) == 'AI'\nassert first_usable(['x', '  A B  ', 'longer'], 3) == 'A B'\nitems = ['  ', '  Orbit ', 'Nova']\nassert first_usable(items, 4) == 'Orbit'\nassert items == ['  ', '  Orbit ', 'Nova']\n",
                             []),
        quiz: [
            question("functions-q1", "A function only prints a score. What does its caller receive?", ["The printed string", "None", "The score automatically"], 1, "Without an explicit return value, a function returns None."),
            question("functions-q2", "Why test the same function with two different inputs in sequence?", ["To detect dependence on stale shared state", "To compile Python", "To remove the need for edge cases"], 0, "A reusable function should compute from each call's arguments, not retain an old accumulator."),
            question("functions-q3", "Where should return total go when summing every item?", ["Before initializing total", "Inside the loop unconditionally", "After the loop"], 2, "Returning inside the loop ends the function after its first visited item.")
        ],
        sectionRoles: ["Replace a function's placeholder, not its interface": .overview, "Test a hypothesis": .troubleshooting])

    private static let collections = Chapter(
        id: "collections", title: "6. Collections and JSON", subtitle: "Organize records and exchange structured data", prerequisites: ["functions"],
        lesson: """
        # Choose a structure that fits

        Lists store ordered items and retain duplicates. A **dictionary** stores named entries called key-value pairs. Curly braces create it; a colon separates each key from its value, and commas separate entries. For example, `{"name": "Mira", "points": 4}` has two string keys, name and points. The values can have different types. Unlike braces inside f-strings, these braces build a container; they do not insert text.

        A **record** is a group of related information about one item, often represented by a dictionary. A field is one named entry in that record. Brackets after a dictionary perform lookup by key, not by numeric position. Assignment to a key adds or replaces that entry. `{}` is an empty dictionary.

        ```python
        record = {"name": "Mira", "points": 4}
        name = record["name"]
        record["points"] = 6
        record["team"] = "blue"
        print(name)
        print(record["points"])
        ```

        This displays Mira and 6. A key can appear only once in a dictionary: assigning it again replaces its value. Reading a missing key with brackets raises `KeyError`, an error that stops normal execution. `record.get("bonus", 0)` instead returns the value if bonus exists, or the supplied default 0 if it does not. It does not add the missing key. Without a default argument, get returns None for a missing key.

        ## Count repeated categories

        A category label is just text used to group items. A dictionary can remember a count under each label. On its first appearance, the count starts at zero; later appearances read the accumulated count.

        ```python
        colors = ["blue", "red", "blue"]
        counts = {}
        for color in colors:
            previous = counts.get(color, 0)
            counts[color] = previous + 1
        print(counts)
        ```

        The result has blue mapped to 2 and red mapped to 1. The key comes from the variable color, not the literal string `'color'`. This is a suitable use of a default: an unseen category really does start at zero. Do not use defaults to hide missing required input fields.

        A `for` loop over a dictionary visits its **keys**, one per visit, in the order they were first added. Use each key with brackets to read its value. `counts.keys()` supplies the same keys explicitly, and `counts.values()` supplies only the values, which is handy when you need a total but not the labels.

        ```python
        counts = {"red": 1, "blue": 2}
        labels = []
        for color in counts:
            labels.append(color)
            print(color, counts[color])
        total = 0
        for count in counts.values():
            total += count
        print(labels)
        print(total)
        ```

        This displays red 1, then blue 2, then `['red', 'blue']` and 3. The loop variable color holds a key such as `'red'`, never the whole entry.

        ## Convert JSON text into Python values

        JSON is a text format for exchanging structured information, not a Python dictionary. A JSON array corresponds to a list; an object corresponds to a dictionary. A payload means the text supplied to an operation, not a filename. `import json` makes Python's built-in json module available under that name. A module is a collection of useful code. `json.loads(payload)` calls its loads function to parse (read and convert) JSON text into Python values. `json.dumps(value)` converts Python values back into JSON text. No installation, file access, or network request is involved.

        ```python
        import json

        payload = '[{"model": "orbit", "score": 0.8}]'
        records = json.loads(payload)
        counts = {}
        for record in records:
            name = record["model"]
            counts[name] = counts.get(name, 0) + 1
        encoded = json.dumps(counts, sort_keys=True)
        ```

        In this block, the outer single quotes make payload a Python string. The double quotes inside belong to JSON, which requires double-quoted object keys and text values. JSON spells Boolean values `true` and `false`, and its no-value marker is `null`; parsing turns these into Python True, False, and None. The argument `sort_keys=True` is a named option asking dumps to output dictionary keys in sorted order. This example saves encoded text; the exercises will say whether their result should be Python data or JSON text.

        Lists and dictionaries are **mutable**: operations can change their contents. If a function receives a list, changing it can surprise its caller. Build a fresh result when the specification promises unchanged input. Dictionary equality compares contents, not formatting or insertion order.

        ## Group fixed values in a tuple

        A **tuple** is an ordered group of values written with parentheses and commas, such as `("orbit", 0.8)`. Like a list, it uses zero-based indexing and works with `len`. Unlike a list, a tuple is **immutable**: after creating it you cannot replace, add, or remove items. It has no append, and `pair[0] = "nova"` raises `TypeError`. Use a tuple for a small fixed group where each position has a meaning, such as a name followed by a score.

        ```python
        pair = ("orbit", 0.8)
        name = pair[0]
        score = pair[1]
        size = len(pair)
        model, result = pair
        print(name)
        print(score)
        print(size)
        print(model)
        print(result)
        ```

        This displays orbit, 0.8, 2, orbit, and 0.8. The line `model, result = pair` is **unpacking**: it assigns the first item to model and the second to result in one step. The number of names on the left must match the number of items, otherwise Python raises `ValueError`. A tuple with one item needs a trailing comma, `(5,)`; without the comma, `(5)` is just the number 5 in parentheses. `in` asks whether a tuple contains a value: `"b" in ("a", "b")` is True.

        ```python
        print((1, "b") < (2, "a"))
        print((1, "a") < (1, "b"))
        print((2, "a") == (2, "a"))
        ```

        All three lines display True. Tuples compare item by item: Python compares the first items, and only if they are equal does it compare the second items, and so on. In the first line 1 is smaller than 2, so the letters are never compared. This ordering rule makes tuples useful for sorting by more than one value.

        ## Sort without changing the input

        `sorted(items)` returns a new list in ascending (smallest-first) order. `items.sort()` changes the original list and returns None, so it is unsuitable when inputs must stay unchanged. Text sorts by Python's character ordering, which is case-sensitive, not a language-aware alphabetical rule. Ascending names put `'A'` before `'a'`.

        Because a dictionary supplies its keys when visited, `sorted(counts)` returns a new list of the keys in ascending order, and `for key in sorted(counts):` visits the entries in a predictable key order no matter how they were added.

        ```python
        totals = {"orbit": 3, "atlas": 5}
        for model in sorted(totals):
            print(model, totals[model])
        print(sorted(totals))
        ```

        This displays atlas 5, then orbit 3, then `['atlas', 'orbit']`. The dictionary itself is unchanged.

        For records, tell sorted which value to compare by supplying a function with the named argument `key`. Python calls that function once per record. A tuple key supports tie-breaking: compare its first part, then its second part only if the first parts are equal. Negating a numeric value with `-` reverses its numeric order when sorted ascending.

        ```python
        parcels = [{"name": "blue", "weight": 2}, {"name": "amber", "weight": 2}, {"name": "red", "weight": 5}]
        def parcel_order(parcel):
            return (-parcel["weight"], parcel["name"])
        ordered = sorted(parcels, key=parcel_order)
        names = []
        for parcel in ordered:
            names.append(parcel["name"])
        print(names)
        ```

        This displays `['red', 'amber', 'blue']`: largest weight first, then ascending name for the tie. Pass the function name as key, without calling it yourself; sorted supplies each record. Reading the dictionaries is safe, but changing them would also change the original records.

        Reference code may use `lambda parcel: (-parcel['weight'], parcel['name'])` instead of a named helper. `lambda` creates a small unnamed function in one expression: the parameter is between `lambda` and the colon, and the value it returns is after the colon. There is no `def`, no name, and no `return` keyword. It is most useful exactly here, as a short key argument.

        ```python
        words = ["kiwi", "fig", "banana"]
        by_length = sorted(words, key=lambda word: len(word))
        by_text = sorted(words)
        print(by_length)
        print(by_text)
        print(words)
        ```

        This displays `['fig', 'kiwi', 'banana']`, then `['banana', 'fig', 'kiwi']`, then the unchanged original `['kiwi', 'fig', 'banana']`. A lambda is never required: a def helper, as in the parcel example, does the same job.

        ## Keep unique names when requested

        A **set** holds distinct values without duplicates. Create an empty one with `set()`, not `{}` (which is a dictionary). `add` inserts a value; adding it again has no effect. `len` counts the distinct values, and `in` or `not in` asks whether a value is present. Sets do not promise any order and cannot be indexed. Convert one with sorted when you need a predictable ordered list.

        ```python
        teams = set()
        teams.add("blue")
        teams.add("amber")
        teams.add("blue")
        print(len(teams))
        print("blue" in teams)
        print("red" in teams)
        ordered_teams = sorted(teams)
        print(ordered_teams)
        ```

        This displays 2, True, False, then `['amber', 'blue']`. The second "blue" was ignored. `set(items)` builds a set from a list's items, which removes duplicates in one step but loses the original order. To remove duplicates while keeping first-appearance order, remember what you have seen in a set and build a new list with a loop:

        ```python
        labels = ["chat", "embed", "chat", "rank"]
        seen = set()
        unique_in_order = []
        for label in labels:
            if label not in seen:
                seen.add(label)
                unique_in_order.append(label)
        print(unique_in_order)
        print(sorted(set(labels)))
        ```

        This displays `['chat', 'embed', 'rank']` and `['chat', 'embed', 'rank']`; the first comes from input order, the second from sorting. `in` also works with lists, and with dictionaries it checks keys: `"name" in record`. Use a set only when duplicates should disappear; several exercises explicitly require retaining them.

        ## Debug the shape

        Before calculating, inspect the structure: is this JSON text, a list of records, or one dictionary? Follow one record through parsing, key lookup, aggregation, and output. Test repeated categories, missing categories in your accumulator, empty collections, and ties. Keep representation errors separate from arithmetic errors. The next chapter adds explicit validation for untrusted shapes and values.
        """,
        exercises: [
            exercise("collections-count", "Count synthetic task labels", "Goal:\nCount how often each task label appears. A label is just a string used as a category name; its occurrence count is how many list items have that exact text.\n\nStarting code:\ndef count_labels(labels): is the required function. return {} currently returns an empty dictionary for every input and is a placeholder.\n\nYour task:\n1. Keep the function name and parameter. labels is a list of strings. Leave that list and all of its text unchanged.\n2. Return a new dictionary whose keys are the exact labels and whose values are integer occurrence counts. Merge repeated identical labels into one key with their combined count.\n3. Treat different case and whitespace as different labels. The empty string is an ordinary label and must be counted. An empty list returns an empty dictionary.\n4. Compute fresh results for every call. The lesson explains how a dictionary can start an unseen category at zero.\n\nExamples:\ncount_labels([]) returns {}.\ncount_labels(['chat', 'embed', 'chat']) returns {'chat': 2, 'embed': 1}.\ncount_labels(['', 'AI', 'ai', '', ' AI']) returns {'': 2, 'AI': 1, 'ai': 1, ' AI': 1}. Dictionary key order is not important.\n\nCheck:\nChoose Check solution. It checks empty and repeated labels, exact text, repeated calls, and unchanged input. Return a dictionary, not printed output or JSON text.",
                     "def count_labels(labels):\n    return {}\n",
                     "def count_labels(labels):\n    counts = {}\n    for label in labels:\n        counts[label] = counts.get(label, 0) + 1\n    return counts\n",
                     "assert count_labels([]) == {}\nassert count_labels(['chat', 'embed', 'chat']) == {'chat': 2, 'embed': 1}\nlabels = ['', 'AI', 'ai', '', ' AI']\nassert count_labels(labels) == {'': 2, 'AI': 1, 'ai': 1, ' AI': 1}\nassert labels == ['', 'AI', 'ai', '', ' AI']\nassert count_labels(['new']) == {'new': 1}\n",
                     ["Use the actual label text as a dictionary key so identical labels share a count; do not strip or lowercase the input.", "A label not yet seen needs a starting count of zero. Dictionary get can return that default without a missing-key error.", "On each visit, read the previous count, increase it by one, and save the new count under the same key. Return the completed dictionary only after all labels have been visited."]),
            exercise("collections-json", "Select models from JSON", "Goal:\nSelect names from invented model evaluation records. A model is a named system; its score describes one evaluation. A threshold is the minimum score required to pass.\n\nStarting code:\nimport json makes Python's built-in JSON tools available. def passing_models(payload, threshold): is the required function; return [] is its placeholder. payload means the supplied JSON text, not a path to a file.\n\nYour task:\n1. Keep the import, function name, and parameter order. payload is valid JSON text containing an array of objects. Each object has a string 'model' field and a finite numeric 'score' field. threshold is a finite number. No malformed-input validation is required.\n2. Return a Python list of the model-name strings whose scores are at least threshold. Exactly equal scores qualify. Read the JSON into Python values before working with its records.\n3. Keep the records' original order and repeated names. Preserve names exactly, including case and spaces. An empty JSON array must return an empty list. Do not change input data or return JSON text.\n\nExamples:\npayload '[]' with threshold 0.8 returns [].\npayload '[{\"model\":\"orbit\",\"score\":0.8},{\"model\":\"nova\",\"score\":0.79},{\"model\":\"orbit\",\"score\":1}]' with threshold 0.8 returns ['orbit', 'orbit'].\n\nCheck:\nChoose Check solution. It checks empty input, exact-threshold inclusion, excluded scores, order, and repeated names. Return the list; printing is optional.",
                     "import json\n\ndef passing_models(payload, threshold):\n    return []\n",
                     "import json\n\ndef passing_models(payload, threshold):\n    records = json.loads(payload)\n    names = []\n    for record in records:\n        if record['score'] >= threshold:\n            names.append(record['model'])\n    return names\n",
                     "assert passing_models('[]', 0.8) == []\nassert passing_models('[{\"model\":\"orbit\",\"score\":0.8},{\"model\":\"nova\",\"score\":0.79},{\"model\":\"orbit\",\"score\":1}]', 0.8) == ['orbit', 'orbit']\nassert passing_models('[{\"model\":\"z\",\"score\":0}]', 0) == ['z']\nassert passing_models('[{\"model\":\"z\",\"score\":0}]', 0.1) == []\n",
                     ["payload is a string. json.loads converts its JSON array into a Python list of record dictionaries; looping over the original string would visit characters instead.", "Within each record, brackets with a string key read that field. Compare the score field with the supplied threshold, including equality.", "Build a new list by appending the model field for each qualifying record. Appending in visit order preserves duplicates and ordering; return the finished list after the loop."]),
            exercise("collections-rank", "Rank synthetic evaluation records", "Goal:\nRank invented model evaluation records from best score to worst. Each record is a dictionary describing one named model and its score.\n\nStarting code:\ndef rank_models(records): is the required function. return [] is a placeholder. The checker supplies a list of dictionaries, not JSON text.\n\nYour task:\n1. Keep the function name and parameter. Each record has a unique string 'model' and a finite numeric 'score'. Scores may be negative. Other fields may exist; ignore them.\n2. Return a new list containing only the model-name strings, ordered by descending score (highest first). For equal scores, order names ascending using Python's normal case-sensitive string ordering, not a custom lowercase ordering.\n3. Leave the input list and its dictionaries unchanged. Preserve the exact names. Return [] for an empty list.\n4. Use the lesson's sort-key concept: a key function returning a tuple can express both ordering rules. An ordinary def helper is fine, and lambda is optional. Then build the list of names with a loop over the sorted records.\n\nExamples:\nFor [{'model': 'zeta', 'score': 0.8}, {'model': 'beta', 'score': 0.9}, {'model': 'alpha', 'score': 0.8}], return ['beta', 'alpha', 'zeta'].\nFor [{'model': 'only', 'score': -1, 'tag': 'demo'}], return ['only'].\n\nCheck:\nChoose Check solution. It checks ordering, equal-score ties, empty input, extra fields, and unchanged records. Return names, not dictionaries or printed text.",
                     "def rank_models(records):\n    return []\n",
                     "def rank_models(records):\n    ordered = sorted(records, key=lambda record: (-record['score'], record['model']))\n    names = []\n    for record in ordered:\n        names.append(record['model'])\n    return names\n",
                     "assert rank_models([]) == []\nrecords = [{'model': 'zeta', 'score': 0.8}, {'model': 'beta', 'score': 0.9}, {'model': 'alpha', 'score': 0.8}]\nassert rank_models(records) == ['beta', 'alpha', 'zeta']\nassert records == [{'model': 'zeta', 'score': 0.8}, {'model': 'beta', 'score': 0.9}, {'model': 'alpha', 'score': 0.8}]\nassert rank_models([{'model': 'only', 'score': -1, 'tag': 'demo'}]) == ['only']\n",
                     ["The score is the primary ordering rule; the name is consulted only when scores tie. A tuple key compares its parts in that order.", "sorted returns a fresh list and can call a helper function for each record via its key argument. A lambda is merely a shorter way to write that helper.", "Ascending sorting of negated scores puts larger original scores first. Keep the name part in normal ascending order, then build a separate list of names from the ordered records."])
        ],
        assessment: exercise("collections-assessment", "Aggregate token usage by model", "Goal:\nReport total text-processing usage for each invented model. Tokens are counted text units. Each record describes some usage by a named model; the same name can appear in several records.\n\nStarting code:\nimport json and def usage_totals(payload): are supplied. return {} is the placeholder body. payload is JSON text, not a file path.\n\nYour task:\n1. Keep the function name and parameter. Input is valid JSON containing a list of records, each with string 'model' and nonnegative integer 'tokens' fields. No malformed-input validation is required. Preserve the supplied data.\n2. Return a Python dictionary mapping each exact model-name string to its integer total tokens across all its records. Repeated names belong to the same total. Case and whitespace are significant; do not clean or rename models.\n3. Include names with zero total. An empty input array must return {}. Return the dictionary itself, not JSON text or printed output.\n\nExamples:\nusage_totals('[]') returns {}.\nFor '[{\"model\":\"orbit\",\"tokens\":12},{\"model\":\"nova\",\"tokens\":0},{\"model\":\"orbit\",\"tokens\":8}]', return {'orbit': 20, 'nova': 0}.\nFor '[{\"model\":\"A\",\"tokens\":1},{\"model\":\"a\",\"tokens\":2}]', return {'A': 1, 'a': 2}. Key order is not important.\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment. It checks empty input, repeated names, zero totals, and case-sensitive grouping. Work independently without hints or solutions.",
                             "import json\n\ndef usage_totals(payload):\n    return {}\n",
                             "import json\n\ndef usage_totals(payload):\n    totals = {}\n    for record in json.loads(payload):\n        model = record['model']\n        totals[model] = totals.get(model, 0) + record['tokens']\n    return totals\n",
                             "assert usage_totals('[]') == {}\nassert usage_totals('[{\"model\":\"orbit\",\"tokens\":12},{\"model\":\"nova\",\"tokens\":0},{\"model\":\"orbit\",\"tokens\":8}]') == {'orbit': 20, 'nova': 0}\nassert usage_totals('[{\"model\":\"A\",\"tokens\":1},{\"model\":\"a\",\"tokens\":2}]') == {'A': 1, 'a': 2}\nassert usage_totals('[{\"model\":\"solo\",\"tokens\":0}]') == {'solo': 0}\n",
                             []),
        quiz: [
            question("collections-q1", "What does json.loads return for the text '[1, 2]'?", ["A Python list", "A filename", "Always a dictionary"], 0, "JSON arrays become Python lists; JSON objects become dictionaries."),
            question("collections-q2", "Why use sorted(records) rather than records.sort() in a non-mutating function?", ["sort never works on lists", "sorted returns a new list", "sorted removes duplicates"], 1, "sorted builds a new list; list.sort changes the original and returns None."),
            question("collections-q3", "When is counts.get(label, 0) appropriate?", ["Whenever malformed input should be ignored", "Only when label already exists", "When an unseen label should start at zero"], 2, "The default explicitly models the first occurrence rather than hiding a required missing field.")
        ],
        sectionRoles: ["Debug the shape": .troubleshooting])

    private static let reliability = Chapter(
        id: "reliability", title: "7. Validation and a small analysis tool", subtitle: "Reject bad data and prove useful behavior", prerequisites: ["collections"],
        lesson: """
        # Make failure part of the contract

        So far, functions have been promised suitable inputs. Real data may violate those assumptions. **Validation** checks whether an input meets a contract before using it. The boundary is where data enters your function. A wrong type, a missing required field, or an out-of-range number should cause a clear failure rather than an invented result.

        An **exception** is an error signal that interrupts normal execution. You have seen names such as NameError and KeyError. `raise ValueError("message")` deliberately signals that an input is unacceptable. ValueError is an exception type; the string in parentheses is its explanation. Raising is not returning: the caller does not receive a normal result. Unless code catches the exception, Python stops and displays the error. Use a nonempty message that describes the problem.

        ## Check types before using operations

        `type(value)` returns a value's exact Python type. `type(value) is int` accepts an integer, not a float or Boolean. `is` compares identity; it is appropriate for exact type objects and None, not ordinary number or text comparisons (use `==` for those). `is not` means the identities differ. `isinstance(value, str)` asks whether value is a string, including a specialized subtype of string. Similarly, list and dict identify list and dictionary values.

        `in` tests membership and `not in` tests non-membership. In `type(value) not in (int, float)`, the parentheses hold a tuple of two accepted type objects, not quoted type names. The condition is true if the exact type is neither int nor float.

        The math module is part of Python. `import math` makes it available, and `math.isfinite(number)` returns True for a finite number, False for infinity or NaN (“not a number”). `float(value)` converts an accepted number to a float. Type checking must happen before operations that assume a number. Range checking can reject huge out-of-range integers before trying to convert them for a floating-point operation.

        ```python
        import math

        def checked_score(value):
            if type(value) not in (int, float):
                raise ValueError("score must be numeric")
            if not 0 <= value <= 1 or not math.isfinite(value):
                raise ValueError("score must be finite and between 0 and 1")
            return float(value)
        ```

        This block defines a function; calling `checked_score(0.5)` would return 0.5, while calling it with `'0.5'` would raise ValueError rather than converting the text. The `or` operator short-circuits: if its left condition is true, Python does not evaluate its right condition. `and` also short-circuits, stopping when its left condition is false. This lets validation avoid unsafe operations. For example, check that a value is text before calling a string method on it.

        Booleans deserve attention: `isinstance(True, int)` is True because bool is a subtype of int in Python. Exact type checks exclude them when measurements are required. Infinity is an unbounded floating-point value; NaN represents an undefined numeric result. They are not finite measurements. `float('inf')` and `float('nan')` create them for testing. NaN is not an ordinary ordered number, so do not rely only on a single lower-bound comparison.

        ## Catch an expected failure

        A `try` block contains an operation that may fail. A following `except ValueError as error:` block handles that specific exception and makes it available under the local name error. If no exception occurs, the except body is skipped. `str(error)` produces the message as text; `bool(text)` is False for empty text and True for nonempty text.

        ```python
        def require_positive(value):
            if type(value) is not int or value <= 0:
                raise ValueError("expected a positive integer")
            return value

        print(require_positive(3))
        try:
            require_positive(0)
        except ValueError as error:
            print(str(error))
        ```

        This prints 3, then expected a positive integer, and finishes normally because the error is caught. In validation exercises, your function should raise the error for the caller to handle, not catch its own error and return zero. Avoid a broad `except Exception`: it also catches unrelated programming errors and can turn broken code into apparently successful output.

        ## Validate formats, not just conversions

        `int(text)` accepts several numeric spellings, so conversion alone does not enforce a strict text format. First check the type, then remove permitted edge whitespace, then check membership in the allowed strings. For example, `choice in ('A', 'B')` permits just two exact strings. ASCII digits are the ordinary characters 0 through 9; other scripts can have digit characters that look similar but are different text. Python string escapes `\\t` and `\\n` represent a tab and a line break. strip removes these at the edges too, not inside the value.

        JSON parsing also has failure rules. `json.loads` raises `json.JSONDecodeError` for malformed JSON text; that exception is a kind of ValueError and already supplies a message. Successful parsing does not guarantee the shape you need: JSON `null` becomes None, `{}` becomes a dictionary, and `[]` becomes a list. A valid list can still contain invalid records. Check required dictionary fields and all items, including late ones; extra fields can be ignored only if the contract permits them.

        ## Tests are evidence, not validation code

        An `assert` states an expected property in a test. It is not a substitute for public input validation because Python can disable assertions. Test both successful results and expected exceptions. An exception test should fail if the operation unexpectedly succeeds.

        ```python
        def require_text(value):
            if not isinstance(value, str):
                raise ValueError("expected text")
            return value

        assert require_text("demo") == "demo"
        raised = False
        try:
            require_text(7)
        except ValueError as error:
            raised = bool(str(error))
        assert raised
        ```

        Both checks pass silently. The flag starts False and changes only when the expected error with a nonempty message occurs. Calling the function is essential: merely defining it does not test it. When repairing a function, follow its indentation: a return inside a loop ends the call before later records can be checked.

        ## Build a small trustworthy tool

        Separate parsing, validation, and aggregation in your reasoning, even when the final function is short. Define the empty-data result, whether extra keys are accepted, and whether the caller's data remains unchanged. When a regression appears, first add a minimal failing test, then repair the cause and rerun the suite. Your final assessment combines JSON input, complete record validation, and a deterministic summary. No network, external dependencies, or private data are necessary.
        """,
        exercises: [
            exercise("reliability-score", "Validate a confidence value", "Goal:\nAccept a numeric confidence score only when it fits a strict contract. A confidence score here is a finite number between 0 and 1, not text that happens to look numeric.\n\nStarting code:\ndef validate_score(value): is the required function. return 0.0 is a placeholder. You may add import math above the function to use Python's built-in math tools.\n\nYour task:\n1. Keep the function name and parameter. Accept only exact Python int or float values. Reject Booleans even though Python treats bool as an integer subtype. Do not convert strings into accepted scores.\n2. Accept both endpoints 0 and 1. Reject numbers below 0 or above 1, infinity, and NaN (not a number). Use math.isfinite as explained in the lesson, after checking that numeric operations are appropriate.\n3. Return each accepted score converted to a float, without rounding. For every rejected input, raise ValueError with any nonempty message instead of returning a fallback value. Do not modify the input.\n\nExamples:\nvalidate_score(0) returns 0.0.\nvalidate_score(1) returns 1.0 as a float.\nvalidate_score(0.75) returns 0.75.\nTrue, '0.5', None, [], -0.01, 1.01, NaN, infinities, and an enormous out-of-range integer must all raise ValueError.\n\nCheck:\nChoose Check solution. It checks accepted values and float output, then invalid types and numeric boundaries. Invalid cases must raise ValueError with a message, not TypeError or OverflowError.",
                     "def validate_score(value):\n    return 0.0\n",
                     "import math\n\ndef validate_score(value):\n    if type(value) not in (int, float):\n        raise ValueError('score must be numeric')\n    if not 0 <= value <= 1 or not math.isfinite(value):\n        raise ValueError('score must be finite and between 0 and 1')\n    return float(value)\n",
                     "assert validate_score(0) == 0.0\nassert type(validate_score(1)) is float\nassert validate_score(0.75) == 0.75\nfor invalid in [True, False, '0.5', None, [], -0.01, 1.01, float('nan'), float('inf'), -float('inf'), 10 ** 400]:\n    raised = False\n    try:\n        validate_score(invalid)\n    except ValueError as error:\n        raised = bool(str(error))\n    assert raised, 'invalid score must raise ValueError with a message'\n",
                     ["Reject unsuitable types before comparing ranges or calling numeric tools. A string method or numeric operation on the wrong type may raise an unintended exception.", "An exact type check distinguishes bool from int. Check the allowed range before math.isfinite so an enormous out-of-range integer cannot cause a float-conversion overflow; then exclude nonfinite values as well.", "Invalid input should interrupt the call with ValueError and a nonempty explanation. Only after all checks pass should the accepted number be converted to a float and returned."]),
            exercise("reliability-parse", "Parse an explicit retry setting", "Goal:\nRead a strict retry setting from text. A retry is another attempt after a failure; this setting chooses how many are permitted. Parsing means turning the accepted text into a useful value, not actually performing retries.\n\nStarting code:\ndef parse_retry_count(text): is the required function. return 0 is a placeholder. Tests provide both valid and invalid inputs.\n\nYour task:\n1. Keep the function name and parameter. Accept only strings whose content, after removing surrounding whitespace, is exactly one of '0', '1', '2', '3', '4', '5'. Edge spaces, tabs, and line breaks are allowed; do not remove internal characters.\n2. Return the corresponding integer from 0 through 5. Leave the original input unchanged.\n3. For every other input raise ValueError with any nonempty message. Reject non-strings, empty text, signs, decimal points, multiple digits such as '01', and non-ASCII digits (digit characters other than ordinary 0 through 9).\n4. Validate the allowed text before converting it; int alone accepts formats that this contract rejects.\n\nExamples:\nparse_retry_count('0') returns 0.\nparse_retry_count(' 5 ') returns 5.\nA tab, then '3', then a line break returns 3.\n'', '6', '-1', '+2', '01', '1.0', '１２', '²', integer 3, None, and True all raise ValueError.\n\nCheck:\nChoose Check solution. It checks accepted edge whitespace, integer output, and rejected spellings and types. A printed error or fallback zero does not satisfy the error contract.",
                     "def parse_retry_count(text):\n    return 0\n",
                     "def parse_retry_count(text):\n    if not isinstance(text, str):\n        raise ValueError('retry count must be text')\n    cleaned = text.strip()\n    if cleaned not in ('0', '1', '2', '3', '4', '5'):\n        raise ValueError('retry count must be a digit from 0 to 5')\n    return int(cleaned)\n",
                     "assert parse_retry_count('0') == 0\nassert parse_retry_count(' 5 ') == 5\nassert parse_retry_count('\\t3\\n') == 3\nassert type(parse_retry_count('2')) is int\nfor invalid in ['', ' ', '6', '-1', '+2', '01', '1.0', '１２', '²', 3, None, True]:\n    raised = False\n    try:\n        parse_retry_count(invalid)\n    except ValueError as error:\n        raised = bool(str(error))\n    assert raised, 'invalid retry setting must raise ValueError with a message'\n",
                     ["int can accept forms such as signed or multi-digit text, but this setting allows only six exact spellings. Conversion alone cannot enforce the contract.", "Check that the input is text before calling strip. Save a cleaned copy so edge whitespace is permitted without changing the caller's original value.", "Membership in a tuple of the six allowed strings can express the format rule. Convert to an integer only after that rule passes; rejected values need ValueError rather than a fallback result."]),
            exercise("reliability-summary", "Repair a latency summary", "Goal:\nRepair a function that summarizes durations. Latency is elapsed time; ms means milliseconds. Unlike the earlier missing-reading exercise, negative values here are invalid and must cause an error, not be skipped.\n\nStarting code:\ndef summarize_latencies(values): contains a deliberately faulty implementation. It adds to total, but its return is inside the loop and it performs no validation. Keep the function name and parameter; repair the body.\n\nYour task:\n1. Accept only a list whose every item is an exact Python integer at least zero. Reject Booleans, floats, and other item types. Zero is valid. Leave the list unchanged.\n2. Raise ValueError with any nonempty message for an invalid outer input or any invalid item, including an invalid item after valid ones.\n3. Return a dictionary with exactly 'count' (integer number of readings), 'total_ms' (integer sum), and 'mean_ms' (numeric arithmetic mean without rounding).\n4. For an empty list return {'count': 0, 'total_ms': 0, 'mean_ms': 0.0}. Ensure the final result accounts for every item, not only the first.\n\nExamples:\nsummarize_latencies([10, 0, 20]) returns {'count': 3, 'total_ms': 30, 'mean_ms': 10.0}.\nsummarize_latencies([7]) returns {'count': 1, 'total_ms': 7, 'mean_ms': 7.0}.\nNone, '12', the tuple (1, 2), [1, -1], [1, True], and [1, 2.0] must raise ValueError.\n\nCheck:\nChoose Check solution. It checks empty, single, and multiple readings, input preservation, and invalid outer types and later items. Return the dictionary; do not print it instead.",
                     "def summarize_latencies(values):\n    total = 0\n    for value in values:\n        total += value\n        return {'count': len(values), 'total_ms': total, 'mean_ms': total / len(values)}\n",
                     "def summarize_latencies(values):\n    if not isinstance(values, list):\n        raise ValueError('latencies must be a list')\n    total = 0\n    for value in values:\n        if type(value) is not int or value < 0:\n            raise ValueError('latencies must be nonnegative integers')\n        total += value\n    count = len(values)\n    return {'count': count, 'total_ms': total, 'mean_ms': total / count if count else 0.0}\n",
                     "assert summarize_latencies([]) == {'count': 0, 'total_ms': 0, 'mean_ms': 0.0}\nvalues = [10, 0, 20]\nassert summarize_latencies(values) == {'count': 3, 'total_ms': 30, 'mean_ms': 10.0}\nassert values == [10, 0, 20]\nassert summarize_latencies([7]) == {'count': 1, 'total_ms': 7, 'mean_ms': 7.0}\nfor invalid in [None, '12', (1, 2), [1, -1], [1, True], [1, 2.0], [1, '2']]:\n    raised = False\n    try:\n        summarize_latencies(invalid)\n    except ValueError as error:\n        raised = bool(str(error))\n    assert raised, 'invalid latencies must raise ValueError with a message'\n",
                     ["return ends the function call immediately. In the starter it runs during the first loop visit, so later readings are neither summed nor checked.", "Check that the outer input is a list before looping, then require every item to be an exact nonnegative integer. A valid first item does not make later items valid.", "The final report belongs after all visits. For the mean, an empty list needs its explicit 0.0 result rather than division by its zero length; nonempty input uses the full total and count."])
        ],
        assessment: exercise("reliability-assessment", "Analyze a synthetic evaluation file", "Goal:\nAnalyze invented model evaluation data and reject invalid input. An evaluation record describes one named model and its score. The title says file, but payload is supplied text: do not open any file or contact a service.\n\nStarting code:\nimport json and def analyze_evaluations(payload): are supplied. return {} is a placeholder. Keep the function name and parameter; use only Python's standard library.\n\nYour task:\n1. Accept only a string containing JSON whose top-level value is a list. Every list item must be an object with both 'model' and 'score' fields. Leave the supplied input unchanged.\n2. model must be a string containing at least one non-whitespace character. score must have exact Python type int or float, not bool, be finite, and lie between 0 and 1 inclusive. Extra object fields are allowed and ignored.\n3. Any invalid input, malformed JSON, wrong shape, missing required field, or invalid record must raise ValueError with a nonempty message. This applies even if earlier records were valid. Do not return a partial summary.\n4. Return a Python dictionary with exactly these keys: 'count', the integer number of records; 'passed', the integer number with scores at least 0.8, including exactly 0.8; 'mean_score', the unrounded numeric arithmetic mean of all scores; and 'models', a list of distinct model-name strings without edge whitespace, sorted in Python's normal ascending string order. Preserve name case and internal whitespace; repeated cleaned names appear only once in models but their records still contribute to all numeric results.\n5. An empty array returns {'count': 0, 'passed': 0, 'mean_score': 0.0, 'models': []}. Return Python data, not JSON text or printed output.\n\nExamples:\nFor '[{\"model\":\" orbit \",\"score\":0.8},{\"model\":\"Nova\",\"score\":0},{\"model\":\"orbit\",\"score\":1,\"tag\":\"synthetic\"}]', return {'count': 3, 'passed': 2, 'mean_score': 0.6, 'models': ['Nova', 'orbit']}.\nFor '[{\"model\":\"a\",\"score\":0.79}]', passed is 0.\nNone, empty text, '{', '{}', 'null', '[1]', '[{}]', blank model names, Boolean or string scores, out-of-range scores, NaN, and infinities must raise ValueError.\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment. It checks valid and empty summaries, exact keys, the passing boundary, unique sorted names, and invalid inputs including a bad record after a valid one. Work independently without hints or solutions.",
                             "import json\n\ndef analyze_evaluations(payload):\n    return {}\n",
                             "import json\nimport math\n\ndef analyze_evaluations(payload):\n    if not isinstance(payload, str):\n        raise ValueError('payload must be JSON text')\n    records = json.loads(payload)\n    if not isinstance(records, list):\n        raise ValueError('payload must contain a list')\n    total = 0.0\n    passed = 0\n    models = set()\n    for record in records:\n        if not isinstance(record, dict):\n            raise ValueError('each record must be an object')\n        model = record.get('model')\n        score = record.get('score')\n        if not isinstance(model, str) or not model.strip():\n            raise ValueError('model must be nonempty text')\n        if type(score) not in (int, float):\n            raise ValueError('score must be numeric')\n        if not 0 <= score <= 1 or not math.isfinite(score):\n            raise ValueError('score must be finite and in range')\n        models.add(model.strip())\n        total += score\n        if score >= 0.8:\n            passed += 1\n    count = len(records)\n    return {'count': count, 'passed': passed, 'mean_score': total / count if count else 0.0, 'models': sorted(models)}\n",
                             "assert analyze_evaluations('[]') == {'count': 0, 'passed': 0, 'mean_score': 0.0, 'models': []}\nreport = analyze_evaluations('[{\"model\":\" orbit \",\"score\":0.8},{\"model\":\"Nova\",\"score\":0},{\"model\":\"orbit\",\"score\":1,\"tag\":\"synthetic\"}]')\nassert set(report) == {'count', 'passed', 'mean_score', 'models'}\nassert report['count'] == 3 and report['passed'] == 2\nassert abs(report['mean_score'] - 0.6) < 1e-10\nassert report['models'] == ['Nova', 'orbit']\nassert analyze_evaluations('[{\"model\":\"a\",\"score\":0.79}]')['passed'] == 0\nfor invalid in [None, b'[]', '', '{', '{}', 'null', '[1]', '[{}]', '[{\"model\":\" \",\"score\":0.5}]', '[{\"model\":3,\"score\":0.5}]', '[{\"model\":\"a\",\"score\":true}]', '[{\"model\":\"a\",\"score\":\"0.5\"}]', '[{\"model\":\"a\",\"score\":-0.1}]', '[{\"model\":\"a\",\"score\":1.1}]', '[{\"model\":\"a\",\"score\":NaN}]', '[{\"model\":\"a\",\"score\":Infinity}]', '[{\"model\":\"ok\",\"score\":1},{\"model\":\"bad\"}]']:\n    raised = False\n    try:\n        analyze_evaluations(invalid)\n    except ValueError as error:\n        raised = bool(str(error))\n    assert raised, 'invalid payload must raise ValueError with a message'\n",
                             []),
        quiz: [
            question("reliability-q1", "Why can isinstance(value, int) accidentally accept a Boolean score?", ["All strings are integers", "bool is a subclass of int", "JSON has no Booleans"], 1, "Python treats bool as an int subclass; an exact type check excludes True and False."),
            question("reliability-q2", "Why avoid except Exception: return 0 around an entire analysis?", ["It can hide bugs and report invalid data as success", "Exceptions cannot be caught", "It makes all calculations nondeterministic"], 0, "Catch only expected failures you can handle; a fabricated zero hides the reason analysis failed."),
            question("reliability-q3", "Which test exposes validation that stops after the first valid record?", ["An empty array only", "One valid record", "A valid record followed by an invalid one"], 2, "A later invalid record ensures the function traverses and validates the entire input.")
        ])
}
