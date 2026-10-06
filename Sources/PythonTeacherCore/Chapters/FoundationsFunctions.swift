import Foundation

extension Curriculum {
    static let functions = Chapter(
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
}
