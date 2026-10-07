import Foundation

extension Curriculum {
    static let functions = Chapter(
        id: "functions", title: "5. Functions and contracts", subtitle: "Turn working logic into reusable behavior", prerequisites: ["loops"],
        lesson: """
        # Separate inputs from results

        You have already called built-in functions such as `len(text)`. Now you can define your own.

        A **function** gives a reusable name to a calculation, so the same rules can work with different inputs.

        ### Define a function

        `def` means "define a function." A definition line has four parts:

        - the keyword `def`
        - the function name
        - parentheses containing input names, separated by commas
        - a colon at the end

        The indented lines below it form the **body**, which contains the work.

        Two words describe the inputs:

        - **Parameters** are the input names in the definition.
        - **Arguments** are the values supplied in a call.

        ```python
        def tokens_needed(requests, tokens_each):
            return requests * tokens_each

        small_run = tokens_needed(3, 20)
        empty_run = tokens_needed(0, 20)
        assert small_run == 60
        assert empty_run == 0
        ```

        ### What happens when it runs

        - `requests` and `tokens_each` are parameters.
        - Calling `tokens_needed(3, 20)` supplies `3` as `requests` and `20` as `tokens_each`, in that order.
        - `return` sends the resulting value back to the caller, which saves it in `small_run`.
        - The next call supplies different values and produces a separate result.

        Local variables belong to that call, so calls do not share counters unless you deliberately use outside state.

        > **Key idea:** Defining a function does not run its body. The body runs only when the function is called.

        The lines beginning with `small_run` and `empty_run` are calls. They are not indented because they are outside the function.

        ### Check results with assert

        `assert` is a check. Python continues silently if its condition is true and reports `AssertionError` if it is false.

        Here both checks pass. The app also uses checks like these to compare your function's actual result with the required result.

        ### Return is not print

        `print` displays information, but it does not substitute for `return`. A function that reaches its end without a `return` statement returns `None`.

        A `return` also ends the current call immediately. It stops only that function call, not the whole program.

        > **Watch out:** When you need to process every item, place `return` after the loop. Indenting it inside the loop is a common reason only the first item is processed.

        ### The None value

        `None` is Python's special "no value" result. It has a capital N and no quotes.

        It is not the same as:

        - the string `'None'`
        - zero
        - empty text

        A function can deliberately return `None` when no answer exists.

        ### Contracts

        A **contract** describes what a function promises:

        - the accepted inputs
        - the exact outputs
        - the behavior at boundaries

        In this chapter, exercises promise valid input types and ranges, so do not invent validation rules.

        A **finite number** is an ordinary number. It excludes infinity and the special not-a-number value introduced later.

        Read carefully whether a fraction or a percentage is requested. A fraction such as `0.5` describes half; a percentage describes the same amount as `50`.

        ### Pure functions

        **Pure functions** compute results without changing caller-owned data and without depending on unrelated global variables (names outside the function). They are easy to test repeatedly.

        Create accumulators inside the function so every call starts fresh.

        > **Note:** "Do not modify the input" means leave the supplied list's order and items unchanged. Reading, counting, and building a new list are fine.

        ## Read part of a string with a slice

        Strings, like lists, use zero-based indexing. In `text[0]`, the brackets select the first character.

        ### Slices

        A **slice** selects a range of characters: `text[start:stop]`.

        - It includes `start` but excludes `stop`.
        - Leaving `start` out means begin at the first character.
        - `text[:3]` takes at most the first three characters: indices 0, 1, and 2.
        - A stop beyond the end is safe.
        - A stop of zero gives empty text.

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

        ```text
        P
        Pla

        Planet
        ```

        The third line of output is empty because `word[:0]` is empty text.

        - A slice produces new text; it does not change `word`.
        - Spaces and uppercase letters are characters too.

        A **preview** is a shortened display of some text, often followed by dots to show that more exists. The literal `'...'` contains three ordinary dots, not one special ellipsis character.

        ### Indexes and slices on lists

        Lists use the same brackets.

        - A **negative index** counts from the end: `items[-1]` is the last item and `items[-2]` the one before it, whatever the length.
        - A slice of a list returns a new, shorter list.
        - Leaving `stop` out means continue to the end, so `items[1:]` is everything after the first item.

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

        ```text
        40
        [20, 30]
        [10, 20]
        [20, 30, 40]
        [10, 20, 30, 40]
        ```

        - `items[1:3]` takes indices 1 and 2 because the stop, 3, is excluded.
        - The last line shows that `items` itself is unchanged.
        - Negative indices work on strings too: `"Planet"[-1]` is `"t"`.

        > **Watch out:** On an empty list, `items[-1]` raises `IndexError`, but any slice safely returns `[]`.

        ## Replace a function's placeholder, not its interface

        Function exercises provide a starter definition with the exact name and parameters the checker calls.

        1. Keep that definition line.
        2. Replace its placeholder body, such as `return 0`, with your work.
        3. Keep four spaces per indentation level, and add more indented lines as needed.
        4. Return the required value so the caller can inspect it. A local result alone is not enough.

        > **Watch out:** Do not replace parameters with fixed example values. Tests call the same function with different arguments.

        ## Default values and keyword arguments

        A parameter can have a **default value**, written `name=value` in the definition.

        - If a call leaves that argument out, Python uses the default.
        - If the call supplies it, the supplied value wins.
        - Parameters with defaults must come after the parameters without them.

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

        ```text
        pass
        retry
        ok
        pass
        ```

        ### Reading each call

        1. The first call uses both defaults.
        2. The second supplies `0.8` as `threshold` by position.
        3. The third uses a **keyword argument**: `pass_word="ok"` names the parameter it fills, so `threshold` keeps its default even though it comes earlier in the definition.
        4. The last call shows that keyword arguments may appear in any order.

        Keyword arguments must come after any positional arguments. By convention there are no spaces around `=` in a keyword argument or default.

        Built-in functions use keyword arguments for options too; later chapters show some.

        ### A pitfall with changeable defaults

        Python creates a default value once, when `def` runs, not freshly on every call.

        A changeable default such as an empty list would be shared by every call that omits it, so items from earlier calls would reappear. Instead, use `None` as the default and create the fresh list inside the function.

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

        ```text
        ['new']
        ['old']
        ```

        - `tags is None` asks whether `tags` holds the `None` value. `is` is the usual way to compare with `None`.
        - Each call that omits `tags` gets its own new list.

        > **Remember:** Text, numbers, Booleans, and `None` never change in place, so they are safe defaults.

        ## Test a hypothesis

        Call your function with at least three kinds of input:

        - a typical case
        - an empty or zero case
        - an exact boundary

        Run it twice with different inputs to uncover stale global state.

        ### When a test fails

        1. Shrink the failing case to the smallest example that still fails.
        2. State your prediction.
        3. Change one relevant line.
        4. Rerun all tests, not only the previously failing one.
        """,
        exercises: [
            exercise("functions-batches", "Reusable batch sizing", """
                     Goal:
                     Make batch sizing reusable for different item counts. A **sample** is one item; a **batch** is a group holding at most `batch_size` items.

                     Starting code:
                     - `def batches_needed(sample_count, batch_size):` defines the required function. Keep this line unchanged.
                     - `return 0` is a placeholder. Replace it with your work.
                     - Tests supply the two arguments on each call; do not replace them with fixed values.

                     Your task:
                     1. Keep the function name `batches_needed` and the parameter order.
                     2. Replace the body so it uses the arguments on every call, not global inputs.
                     3. Assume `sample_count` is a nonnegative integer and `batch_size` is a positive integer. No invalid-input handling is required.
                     4. Calculate an integer number of batches sufficient for every sample, counting a partially filled final group.
                     5. Make sure zero samples gives `0`, and exact multiples do not add an extra group.
                     6. Return the result to the caller; printing it is not a substitute. The values lesson explains rounding up with whole-number division.

                     Examples:
                     - `batches_needed(0, 8)` returns `0`
                     - `batches_needed(16, 8)` returns `2`
                     - `batches_needed(17, 8)` returns `3`
                     - `batches_needed(3, 10)` returns `1`

                     Check:
                     Choose **Check solution**. It calls your function with zero, exact-multiple, partial-group, and one-item cases, and checks for an integer result.
                     """,
                     "def batches_needed(sample_count, batch_size):\n    return 0\n",
                     "def batches_needed(sample_count, batch_size):\n    return (sample_count + batch_size - 1) // batch_size\n",
                     "assert batches_needed(0, 8) == 0\nassert batches_needed(16, 8) == 2\nassert batches_needed(17, 8) == 3\nassert batches_needed(1, 1) == 1\nassert batches_needed(3, 10) == 1\nassert type(batches_needed(17, 8)) is int\n",
                     ["A full final batch needs no extra group; a partial one needs exactly one more. Try predicting zero and exact-multiple cases first.", "Whole-number division gives only completely filled groups. The remainder tells you whether any items still need space.", "The values lesson's round-up rule adds one less than the group capacity before whole-number division. Keep the calculation inside the function and return its integer result."]),
            exercise("functions-rate", "Measure passing fraction", """
                     Goal:
                     Measure the share of scores that pass. A **threshold** is the minimum passing value. A **fraction** uses a 0-to-1 scale: half is `0.5`, not 50 percent.

                     Starting code:
                     - `def pass_rate(scores, threshold):` is the required function. Keep this line unchanged.
                     - `return 0.0` is a placeholder. Replace it with your work.
                     - The checker supplies a list and a threshold on each call.

                     Your task:
                     1. Keep the function name `pass_rate` and its parameters.
                     2. Assume `scores` is a list of finite numbers and `threshold` is a finite number. These are ordinary numbers, not infinity or NaN, and they need not be limited to 0 through 1.
                     3. Count the scores that are at least `threshold`. A score equal to `threshold` passes, and repeated scores count as separate items.
                     4. Divide that count by the number of scores, after counting all matches.
                     5. For an empty list, return `0.0`.
                     6. Leave `scores`, including its order, unchanged. Calculate from the arguments on each call, with no leftover state from earlier calls.
                     7. Return the numeric fraction, not printed text.

                     Examples:
                     - `pass_rate([], 0.5)` returns `0.0`
                     - `pass_rate([0.5], 0.5)` returns `1.0`
                     - `pass_rate([0.8, 0.2, 0.8], 0.8)` returns two thirds, approximately `0.6666666667`, without rounding
                     - `pass_rate([1, 2, 3], 2)` also returns two thirds

                     Check:
                     Choose **Check solution**. It calls your function on several lists, including empty and boundary cases, and checks that a supplied list remains unchanged.
                     """,
                     "def pass_rate(scores, threshold):\n    return 0.0\n",
                     "def pass_rate(scores, threshold):\n    if not scores:\n        return 0.0\n    passed = 0\n    for score in scores:\n        if score >= threshold:\n            passed += 1\n    return passed / len(scores)\n",
                     "assert pass_rate([], 0.5) == 0.0\nassert pass_rate([0.5], 0.5) == 1.0\nassert pass_rate([0.1, 0.2], 0.5) == 0.0\nsample = [0.8, 0.2, 0.8]\nassert abs(pass_rate(sample, 0.8) - 2 / 3) < 1e-10\nassert sample == [0.8, 0.2, 0.8]\nassert pass_rate([1, 2, 3], 2) == 2 / 3\n",
                     ["An empty list has length zero, so a division by its length would fail. Give that case the specified result before attempting division.", "A score equal to `threshold` passes. Count every qualifying item, including duplicates, and compare that count with the total number of items, not just the valid matches.", "A fraction is the passing count divided by the list length, without multiplying by 100. Return it after the loop; returning inside the loop would stop after the first visited score."]),
            exercise("functions-preview-v2", "Create prompt previews", """
                     Goal:
                     Create a short display of text, called a **preview**. A **marker**, three dots by default, shows that some of the original text was left out.

                     Starting code:
                     - `def preview(text, max_chars, marker='...'):` is the required function. Keep this line unchanged.
                     - `marker` has a default value, so callers may leave it out.
                     - `return text` is a placeholder that currently never shortens anything. Replace it with your work.

                     Your task:
                     1. Keep the function name `preview`, the parameter order, and the default `marker='...'`.
                     2. Assume `text` and `marker` are strings and `max_chars` is a nonnegative integer. Use each call's arguments, not fixed example values.
                     3. If the length of `text` is at most `max_chars`, including exact equality, return `text` unchanged with no marker.
                     4. Otherwise, return the first `max_chars` characters followed by `marker`. Use the lesson's slicing concept to take this beginning portion. The marker does not count toward `max_chars`.
                     5. Use the `marker` parameter: when the caller omits it, the default three ordinary dots `'...'` are used; when the caller supplies one, for example as the keyword argument `marker='>'`, use it instead.
                     6. Preserve all original spaces and letter case in the kept portion.
                     7. Return a string; do not print instead. Empty text stays empty, and nonempty text with `max_chars` zero produces only the marker.

                     Examples:
                     - `preview('demo', 4)` returns `'demo'`
                     - `preview('demo', 2)` returns `'de...'`
                     - `preview('demo', 0)` returns `'...'`
                     - `preview('', 0)` returns `''`
                     - `preview('  AI', 2)` returns `'  ...'`, with two spaces before the dots
                     - `preview('demo', 2, marker='>')` returns `'de>'`
                     - `preview(text='demo', max_chars=3)` returns `'dem...'`
                     - `preview('demo', 4, marker='!')` returns `'demo'`

                     Check:
                     Choose **Check solution**. It tests empty text, zero and oversized limits, exact length, preservation of spaces, the default marker, and calls using keyword arguments.
                     """,
                     "def preview(text, max_chars, marker='...'):\n    return text\n",
                     "def preview(text, max_chars, marker='...'):\n    if len(text) <= max_chars:\n        return text\n    return text[:max_chars] + marker\n",
                     "assert preview('', 0) == ''\nassert preview('demo', 4) == 'demo'\nassert preview('demo', 8) == 'demo'\nassert preview('demo', 0) == '...'\nassert preview('Synthetic prompt', 9) == 'Synthetic...'\nassert preview('  AI', 2) == '  ...'\nassert preview('demo', 2, marker='>') == 'de>'\nassert preview('demo', 2, '~') == 'de~'\nassert preview(text='demo', max_chars=3) == 'dem...'\nassert preview(marker='', max_chars=1, text='demo') == 'd'\nassert preview('demo', 4, marker='!') == 'demo'\n",
                     ["Text that already fits, including an exact-length match, must be returned unchanged without a marker. Separate that case from text that needs shortening.", "A slice with no start begins at the first character; its stop is excluded. Using the character limit as that stop takes at most that many characters without changing their spaces or case.", "Join the `marker` parameter, not a fixed `'...'`, to a shortened result; the default in the definition supplies the dots when the caller omits it. With a zero character limit the kept portion is empty, but the marker is still needed if the original text was nonempty."])
        ],
        assessment: exercise("functions-assessment", "Find the first usable candidate", """
                             Goal:
                             Select the first usable piece of text. A **candidate** is one possible text choice; **usable** means it meets the minimum length after whitespace at both edges is removed.

                             Starting code:
                             - `def first_usable(candidates, min_chars):` is the required function. Keep this line unchanged.
                             - `return None` is its placeholder body. Replace it with your work.
                             - The checker supplies different arguments for different calls.

                             Your task:
                             1. Keep the function name `first_usable` and the parameter order.
                             2. Assume `candidates` is a list of strings and `min_chars` is a positive integer. Do not change the list or its original strings.
                             3. Visit the candidates in input order and find the first one whose text, without surrounding whitespace, has at least `min_chars` characters. Exactly `min_chars` qualifies.
                             4. Return that candidate with its edge whitespace removed, preserving case and internal whitespace.
                             5. If no candidate qualifies, including when the list is empty, return Python's `None` value, not the string `'None'` or empty text.

                             Examples:
                             - `first_usable([], 1)` returns `None`
                             - `first_usable([' ', 'ab'], 3)` returns `None`
                             - `first_usable(['  AI  ', 'later'], 2)` returns `'AI'`
                             - `first_usable(['x', '  A B  ', 'longer'], 3)` returns `'A B'`

                             Check:
                             Complete the theory questions and written explanation, then choose **Submit assessment**. It checks different calls, first-match ordering, boundary length, absence of a match, and unchanged input. Work independently, without hints or solutions.
                             """,
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
