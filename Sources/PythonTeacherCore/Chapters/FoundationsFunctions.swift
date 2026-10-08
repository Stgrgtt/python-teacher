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

        ### Plan from a specification

        A **specification** describes the required behavior, not the code to write. Before editing, separate its inputs, result, and boundary cases. Then choose small steps whose results you can check separately. This is **decomposition**: dividing a problem into understandable pieces.

        For a delivery charge, the inputs might be item count, box capacity, and price per box; the result is a total price. Small steps could find the number of boxes and then their charge. Write down what zero items and an exactly full box should do before choosing expressions.

        ### Choose meaningful names

        Names should explain what a value represents. `box_count` distinguishes a count from `price_per_box`; `x` and `y` do not. Including units, such as `price_cents`, helps prevent mixing money with counts. Renaming a local variable consistently should not change the returned result.

        ### Refactor without changing behavior

        **Refactoring** changes how working code is organized without changing its promised behavior. A **helper function** handles one smaller part for another function, its caller. Here is a working calculation before refactoring:

        ```python
        def delivery_charge(item_count, box_capacity, price_per_box):
            return ((item_count + box_capacity - 1) // box_capacity) * price_per_box

        print(delivery_charge(7, 3, 4))
        print(delivery_charge(0, 3, 4))
        ```

        ```text
        12
        0
        ```

        Here two small helper functions give names to the steps. Define each helper before the caller uses it. The same checks must still pass after the change:

        ```python
        def boxes_needed(item_count, box_capacity):
            return (item_count + box_capacity - 1) // box_capacity

        def boxes_charge(box_count, price_per_box):
            return box_count * price_per_box

        def delivery_charge(item_count, box_capacity, price_per_box):
            box_count = boxes_needed(item_count, box_capacity)
            return boxes_charge(box_count, price_per_box)

        print(delivery_charge(7, 3, 4))
        print(delivery_charge(0, 3, 4))
        assert delivery_charge(6, 3, 4) == 8
        ```

        ```text
        12
        0
        ```

        A shared helper is especially useful when several callers repeat a rule: they can call that helper instead of maintaining separate copies. Shorter code is not the goal; a clear responsibility and preserved behavior are.

        ### Read a signature and docstring

        The **signature** is the definition line: it tells you the function's name and parameter order. A **docstring** is a string placed first inside the function body to document its contract. Triple quotes, such as three single quotes `'''`, surround a string that can span several lines. They do not run a calculation or replace `return`.

        ```python
        def boxes_needed(item_count, box_capacity):
            '''Return an integer box count for nonnegative items and positive capacity.
            Count a partial box; zero items needs zero boxes.
            '''
            return (item_count + box_capacity - 1) // box_capacity

        print(boxes_needed(7, 3))
        ```

        ```text
        3
        ```

        Read the signature to know how to call `boxes_needed(7, 3)`, then the docstring to know what it promises. Checks can establish whether particular calls meet that contract; the presence of documentation alone does not establish its accuracy.

        ### Comments explain why

        A **comment** begins with `#`; Python ignores the rest of that line. Unlike a docstring, it is not a string belonging to a function. Use a comment to explain a reason that the code cannot express clearly, rather than merely repeating the operation. These illustrations are text, not runnable lesson examples:

        ```text
        Less useful: total += charge  # Add charge to total
        More useful: # Charge each booking separately because boxes cannot be shared.
        ```

        Prefer meaningful names and a clear contract first. Comments and docstrings help a reader; neither substitutes for checks or proves that an explanation is good.

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

        ### Debugging systematically

        Debugging means gathering evidence about why a program breaks its contract, not changing lines at random. Start with two separate statements: **expected** behavior from the contract and **observed** behavior from the run.

        Suppose a function promises the integer total of a list of integers, including `0` for an empty list. This faulty example is shown as text, not as a runnable lesson block:

        ```text
        def reading_total(values):
            return values[0] + values[1]

        def report_total(values):
            return reading_total(values)

        report_total([])
        ```

        Expected: the call returns the integer `0`. Observed: it stops with `IndexError` and returns no result. That is different from returning a wrong number or returning `None` normally.

        ### Find a minimal failing call

        A **reproduction** is a call that reliably shows the problem. Remove unrelated items while checking that the failure still happens. Here `report_total([])` already fails with no items: it is a minimal failing call. Keep it as evidence, rather than replacing it with a large example that is harder to trace.

        ### Read a multi-frame traceback

        A traceback lists the calls still active when an exception occurred. Each file-and-line entry is a **frame**. For the faulty example above, a traceback can look like this:

        ```text
        Traceback (most recent call last):
          File "learner.py", line 7, in <module>
            report_total([])
          File "learner.py", line 5, in report_total
            return reading_total(values)
          File "learner.py", line 2, in reading_total
            return values[0] + values[1]
        IndexError: list index out of range
        ```

        1. Read the final line for the exception type and message: an index does not exist.
        2. Find the last learner frame: line 2 is where this run failed.
        3. Walk upward to see how execution arrived there: `report_total` called `reading_total`, starting from the top-level call. `<module>` means code outside a function.
        4. Inspect the arguments and local values at the failing operation. With `values` equal to `[]`, even index `0` is unavailable.

        Line numbers refer to that exact source version. App checks may also appear in a traceback; their lines are not lines to edit in your function. An `AssertionError` in a check means the observed result did not meet its expectation, so compare the call and returned value before guessing at the cause.

        ### Follow arguments, local state, and return

        A **probe** is a small observation used to test an idea. `print("arguments:", values)` labels the value it displays, making several observations easier to tell apart. Multiple arguments to `print` are separated by spaces in the output.

        This standalone, working example shows the input, changing local accumulator, and the value received by the caller:

        ```python
        def reading_total(values):
            print("arguments:", values)
            total = 0
            for value in values:
                total += value
                print("local value:", value, "total:", total)
            return total

        result = reading_total([6, 2])
        print("returned:", result)
        assert result == 8
        ```

        ```text
        arguments: [6, 2]
        local value: 6 total: 6
        local value: 2 total: 8
        returned: 8
        ```

        Printing a local total is not proof that the caller received it. Save the call's result and inspect that too. Each call has its own local `total`; the original input list stays unchanged.

        For a list, an empty value is treated as false in a condition and a nonempty value as true. When `readings` is a list, `if not readings:` therefore checks the same empty case as `if len(readings) == 0:`. Follow that branch separately from calls that enter a loop.

        ### One hypothesis, one focused change

        A **hypothesis** is a specific explanation you can test: "The faulty function assumes two items exist, but the contract permits any list length." Predict that a loop starting with a zero total will handle both empty and longer lists. Use the smallest call to check that prediction, then make that focused repair rather than changing unrelated behavior.

        ### Keep regression checks

        A **regression** is a previously working case broken by a later change. After a repair, keep the failing example and rerun typical, empty, and boundary cases. Repeated calls with different arguments can expose leftover global state. Remove temporary probe prints once they have answered your question.

        ```python
        def reading_total(values):
            total = 0
            for value in values:
                total += value
            return total

        assert reading_total([]) == 0
        assert reading_total([0]) == 0
        values = [6, 2, 3]
        assert reading_total(values) == 11
        assert values == [6, 2, 3]
        assert reading_total([4]) == 4
        assert reading_total(values) == 11
        ```

        These checks pass silently. They support the contract beyond the one call that originally failed.
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
                     ["Text that already fits, including an exact-length match, must be returned unchanged without a marker. Separate that case from text that needs shortening.", "A slice with no start begins at the first character; its stop is excluded. Using the character limit as that stop takes at most that many characters without changing their spaces or case.", "Join the `marker` parameter, not a fixed `'...'`, to a shortened result; the default in the definition supplies the dots when the caller omits it. With a zero character limit the kept portion is empty, but the marker is still needed if the original text was nonempty."]),
            exercise("functions-debug-return", "Diagnose a caller's missing result", """
                     Goal:
                     Repair `count_ready(readings, minimum)` so its caller receives the integer number of readings at least `minimum`.

                     Starting code:
                     - Keep the function name and both parameters. The body is an attempted implementation, not a placeholder.
                     - The empty-list call returns `0`, but `count_ready([4], 4)` unexpectedly returns `None` instead of `1`.
                     - The checker supplies valid lists of integers and an integer minimum. No invalid-input validation is needed.

                     Your task:
                     1. Reproduce the reported call and compare the expected result with the value received by the caller.
                     2. Use a labeled print as a temporary probe if needed to compare the local count with the returned value.
                     3. Form one hypothesis and repair the function without replacing its arguments with example data.
                     4. Count every reading at least `minimum`, including equality and repeated readings. Return an integer; printing does not satisfy the contract.
                     5. Return `0` for an empty list and leave the supplied list's items and order unchanged.
                     6. Remove temporary probes and rerun empty, boundary, and repeated-call checks.

                     Expected result:
                     - `count_ready([4], 4)` returns the integer `1`.
                     - `count_ready([3, 4, 5, 4], 4)` returns the integer `3`.
                     - `count_ready([], 4)` and `count_ready([3], 4)` both return the integer `0`.
                     - `count_ready([-2, 0, -2], -2)` returns the integer `3`.

                     Check:
                     Choose **Check solution**. It checks actual returned integers, empty and exact-boundary cases, mixed and repeated values, unchanged input, and fresh results across calls.
                     """,
                     "def count_ready(readings, minimum):\n    if not readings:\n        return 0\n    count = 0\n    for reading in readings:\n        if reading >= minimum:\n            count += 1\n",
                     "def count_ready(readings, minimum):\n    if not readings:\n        return 0\n    count = 0\n    for reading in readings:\n        if reading >= minimum:\n            count += 1\n    return count\n",
                     "assert count_ready([4], 4) == 1\nassert type(count_ready([4], 4)) is int\nassert count_ready([], 4) == 0\nassert type(count_ready([], 4)) is int\nassert count_ready([3], 4) == 0\nreadings = [3, 4, 5, 4]\nassert count_ready(readings, 4) == 3\nassert type(count_ready(readings, 4)) is int\nassert readings == [3, 4, 5, 4]\nassert count_ready([-2, 0, -2], -2) == 3\nassert count_ready([0], 1) == 0\nassert count_ready(readings, 5) == 1\nassert count_ready(readings, 4) == 3\nassert readings == [3, 4, 5, 4]\n",
                     ["Separate the local calculation from the caller's result. Does the reported one-item call take the same path as the empty-list call?", "Save the call in a variable and print it with a label. A local count can be correct even when the caller receives None.", "Follow every path to the end of the function. After all loop visits, send the accumulated count back with return; keep the empty-list result and do not stop after only one reading."],
                     effort: .init(scopeUnits: 1)),
            exercise("functions-predict-counterexample", "Predict a minimal counterexample", """
                     Goal:
                     Find evidence against an attempted title-length counter, predict its result, and then repair it. `count_short_titles(titles, max_chars)` must return the integer number of strings whose length is at most `max_chars`.

                     Starting code:
                     - Keep the function name and parameters. Inputs are a list of strings and a nonnegative integer limit; spaces count as characters.
                     - The starter returns the expected results for `count_short_titles([], 0)` and `count_short_titles(['a'], 2)`, but a reviewer reports incorrect counts for other valid calls.
                     - `counterexample`, `predicted_count`, and `expected_count` are evidence placeholders to replace, not inputs to hardcode inside the function.

                     Your task:
                     1. Before repairing the function, find a smallest failing list when `max_chars` is `0`: use the fewest strings and then the fewest total characters. Save that list as `counterexample`.
                     2. Set integer `predicted_count` to what the original starter function would return for that list and limit `0`.
                     3. Set integer `expected_count` to what the contract requires for the same call. These two saved counts must differ; keep this evidence after your repair.
                     4. Repair the function to count every string with length at most the supplied limit. Include duplicates, preserve spaces and case, and do not change the input list.
                     5. Return an integer count on every call, including `0` for an empty list. Use fresh local state each time.

                     Expected result:
                     - Your evidence describes a minimal failing call to the original starter; the repaired call returns `expected_count`.
                     - `count_short_titles(['a', 'bb', 'ccc', 'bb'], 2)` returns the integer `3`.
                     - `count_short_titles([' ', ''], 0)` returns the integer `1`.
                     - `count_short_titles([], 3)` returns the integer `0`.

                     Check:
                     Choose **Check solution**. It checks the minimal counterexample and both predictions, then calls the repaired function with empty, exact-length, longer, duplicate, whitespace, and repeated-call cases while checking unchanged input.
                     """,
                     "def count_short_titles(titles, max_chars):\n    count = 0\n    for title in titles:\n        if len(title) < max_chars:\n            count += 1\n    return count\n\ncounterexample = []\npredicted_count = 0\nexpected_count = 0\n",
                     "def count_short_titles(titles, max_chars):\n    count = 0\n    for title in titles:\n        if len(title) <= max_chars:\n            count += 1\n    return count\n\ncounterexample = ['']\npredicted_count = 0\nexpected_count = 1\n",
                     "assert counterexample == [''], 'keep the smallest failing list as evidence'\nassert type(predicted_count) is int and predicted_count == 0\nassert type(expected_count) is int and expected_count == 1\nassert count_short_titles(counterexample, 0) == expected_count\nassert counterexample == ['']\nassert type(count_short_titles(counterexample, 0)) is int\nassert count_short_titles([], 3) == 0\nassert type(count_short_titles([], 3)) is int\ntitles = ['a', 'bb', 'ccc', 'bb']\nassert count_short_titles(titles, 2) == 3\nassert type(count_short_titles(titles, 2)) is int\nassert titles == ['a', 'bb', 'ccc', 'bb']\nassert count_short_titles([' ', ''], 0) == 1\nassert count_short_titles(['A B', '  ', 'AB'], 2) == 2\nassert count_short_titles(['abcd'], 3) == 0\nassert count_short_titles([''], 5) == 1\nassert count_short_titles(titles, 1) == 1\nassert count_short_titles(titles, 2) == 3\nassert titles == ['a', 'bb', 'ccc', 'bb']\n",
                     ["A counterexample must make the observed and required results differ. The empty list gives zero under both rules, so it is not evidence of a failure.", "With a zero-character limit, try one string with no characters. Predict the original comparison before looking at the required phrase 'at most'.", "The minimal evidence list is ['']: save 0 as the original prediction and 1 as the required count. Then make the function include exact-length matches as well as shorter strings, without changing that evidence."],
                     effort: .init(scopeUnits: 2)),
            exercise("functions-transfer-ticket-total", "Price a group visit", """
                     Goal:
                     Turn a ticket office's pricing specification into a reusable function. Choose your own decomposition using the functions, conditions, and loops you have learned.

                     Starting code:
                     - Keep `def ticket_total(ages, child_price, adult_price, child_boundary):` unchanged.
                     - Replace `return 0` with your solution. You may add helpers, but none are required.
                     - All inputs are valid: `ages` is a list of nonnegative integer ages; both prices and `child_boundary` are nonnegative integers. Prices are whole credits, not fractional money.

                     Your task:
                     1. Return the integer total ticket price for the group. Each age strictly below `child_boundary` costs `child_price`; each age equal to or above it costs `adult_price`.
                     2. Count repeated ages as separate visitors. An empty group costs the integer `0`.
                     3. Leave the supplied list's items and order unchanged. Each call must use its own arguments, with no leftover result from a previous group. Return the total rather than printing it; no invalid-input handling is needed.

                     Expected result:
                     - `ticket_total([5, 12, 30, 5], 4, 9, 12)` returns `26`.
                     - `ticket_total([11, 12, 13], 4, 9, 12)` returns `22`.
                     - `ticket_total([], 4, 9, 12)` returns `0`.
                     - `ticket_total([0, 2], 3, 8, 0)` returns `16`.
                     - `ticket_total([4, 4], 0, 7, 10)` returns `0`.

                     Check:
                     Choose **Check solution**. It makes multiple calls with changed prices and boundaries, empty groups, repeated ages, and free tickets, and checks integer results and unchanged input. The examples specify behavior, not a required algorithm.
                     """,
                     "def ticket_total(ages, child_price, adult_price, child_boundary):\n    return 0\n",
                     """
                     def ticket_total(ages, child_price, adult_price, child_boundary):
                         total = 0
                         for age in ages:
                             if age < child_boundary:
                                 total += child_price
                             else:
                                 total += adult_price
                         return total
                     """,
                     """
                     assert ticket_total([5, 12, 30, 5], 4, 9, 12) == 26
                     assert type(ticket_total([5, 12, 30, 5], 4, 9, 12)) is int
                     assert ticket_total([], 4, 9, 12) == 0
                     assert type(ticket_total([], 4, 9, 12)) is int
                     assert ticket_total([11, 12, 13], 4, 9, 12) == 22
                     assert ticket_total([12], 4, 9, 12) == 9
                     assert ticket_total([0, 2], 3, 8, 0) == 16
                     assert ticket_total([4, 4], 0, 7, 10) == 0
                     assert ticket_total([11, 12], 4, 0, 12) == 4
                     assert ticket_total([7, 8, 9], 8, 2, 8) == 12
                     ages = [5, 12, 30, 5]
                     assert ticket_total(ages, 4, 9, 12) == 26
                     assert ages == [5, 12, 30, 5]
                     assert ticket_total([1], 6, 11, 2) == 6
                     assert ticket_total(ages, 2, 5, 13) == 11
                     assert ages == [5, 12, 30, 5]
                     assert ticket_total(ages, 4, 9, 12) == 26
                     assert ages == [5, 12, 30, 5]
                     """,
                     ["Separate the input contract from the result. What price applies to a visitor exactly at the boundary, and what should an empty group cost?", "A repeated age represents another ticket, not a duplicate to discard. Consider how you can keep a total local to each call while reading every visitor.", "One approach starts a local total at 0, visits each age, and adds child_price for age < child_boundary or adult_price otherwise. Return only after every visitor has been processed."],
                     effort: .init(scopeUnits: 2),
                     practiceProfile: .init(form: .transfer, scaffolding: .independent,
                                            skillIDs: ["functions-section-1", "loops-section-3"],
                                            reflectionPrompts: ["How did you turn the ticket rules into smaller responsibilities without being given an algorithm?", "Which call distinguishes an age at child_boundary from one just below it?"])),
            exercise("functions-refactor-batch-cost", "Share a batch pricing rule", """
                     Goal:
                     Refactor working duplicated calculations into a shared helper without changing the total cost of two separate orders. A batch holds at most `batch_size` items; each started batch costs `price_per_batch` whole credits. Orders cannot share a batch.

                     Starting code:
                     - `total_batch_cost(first_count, second_count, batch_size, price_per_batch)` already returns correct totals, but repeats the batch calculation.
                     - `batch_cost(item_count, batch_size, price_per_batch)` has a placeholder body. Keep both definition lines and replace the placeholder; then change the total function to reuse it.
                     - All counts and prices are nonnegative integers; `batch_size` is a positive integer. No invalid-input validation is required.

                     Your task:
                     1. Make `batch_cost` return an integer charge for one order, including a partly filled last batch. Zero items costs `0`; an exact multiple adds no extra batch.
                     2. Put a docstring first in the helper body describing its inputs and returned charge, including zero and partial batches. Triple-quoted strings are explained in the lesson.
                     3. Make `total_batch_cost` call `batch_cost` once for each order, including a zero-item order, using the supplied size and price. Return the integer total of those two helper results, with fresh results on every call.
                     4. Preserve the existing public totals. Do not combine both orders' items before pricing: the orders need separate batches.

                     Expected result:
                     - `batch_cost(0, 4, 6)` returns `0`, `batch_cost(4, 4, 6)` returns `6`, and `batch_cost(5, 4, 6)` returns `12`.
                     - `total_batch_cost(5, 3, 4, 6)` still returns `18`.
                     - `total_batch_cost(1, 1, 4, 6)` still returns `12`, not `6`.
                     - `total_batch_cost(0, 8, 4, 6)` still returns `12`.

                     Check:
                     Choose **Check solution**. It checks helper and total results across zero, exact, partial, and changed-price cases. To verify actual helper reuse, the checker temporarily replaces `batch_cost` in the caller's function namespace (`__globals__`) with a recording helper, then restores it. You do not implement this inspection: just call the named helper normally and use its returned charges. The checker verifies helper reuse, not code length, style, or AI judgment. A nonempty docstring check confirms documentation exists; it does not grade explanation quality.
                     """,
                     """
                     def batch_cost(item_count, batch_size, price_per_batch):
                         '''Describe the one-order charge contract here.'''
                         return 0

                     def total_batch_cost(first_count, second_count, batch_size, price_per_batch):
                         first_cost = ((first_count + batch_size - 1) // batch_size) * price_per_batch
                         second_cost = ((second_count + batch_size - 1) // batch_size) * price_per_batch
                         return first_cost + second_cost
                     """,
                     """
                     def batch_cost(item_count, batch_size, price_per_batch):
                         '''Return an integer charge for a nonnegative item count and price.
                         The batch size is positive. Count a partial batch; zero items costs zero.
                         '''
                         batch_count = (item_count + batch_size - 1) // batch_size
                         return batch_count * price_per_batch

                     def total_batch_cost(first_count, second_count, batch_size, price_per_batch):
                         first_cost = batch_cost(first_count, batch_size, price_per_batch)
                         second_cost = batch_cost(second_count, batch_size, price_per_batch)
                         return first_cost + second_cost
                     """,
                     """
                     assert batch_cost(5, 4, 6) == 12
                     assert type(batch_cost(5, 4, 6)) is int
                     assert batch_cost(0, 4, 6) == 0
                     assert type(batch_cost(0, 4, 6)) is int
                     assert batch_cost(3, 4, 6) == 6
                     assert batch_cost(4, 4, 6) == 6
                     assert batch_cost(8, 4, 6) == 12
                     assert batch_cost(7, 3, 2) == 6
                     assert batch_cost(2, 1, 9) == 18
                     assert batch_cost(5, 4, 0) == 0
                     assert total_batch_cost(5, 3, 4, 6) == 18
                     assert type(total_batch_cost(5, 3, 4, 6)) is int
                     assert total_batch_cost(1, 1, 4, 6) == 12
                     assert total_batch_cost(0, 8, 4, 6) == 12
                     assert total_batch_cost(8, 0, 4, 6) == 12
                     assert total_batch_cost(0, 0, 4, 6) == 0
                     assert type(total_batch_cost(0, 0, 4, 6)) is int
                     assert total_batch_cost(7, 3, 3, 2) == 8
                     assert total_batch_cost(5, 3, 4, 0) == 0
                     assert total_batch_cost(5, 3, 4, 6) == 18
                     assert isinstance(batch_cost.__doc__, str) and batch_cost.__doc__.strip(), 'Add a nonempty helper docstring.'
                     helper_calls = []
                     def recording_batch_cost(item_count, batch_size, price_per_batch):
                         helper_calls.append([item_count, batch_size, price_per_batch])
                         return item_count * 11 + 7
                     caller_names = total_batch_cost.__globals__
                     saved_helper = caller_names['batch_cost']
                     try:
                         caller_names['batch_cost'] = recording_batch_cost
                         assert total_batch_cost(5, 3, 4, 6) == 102, 'Return the total of both helper results.'
                         assert sorted(helper_calls) == [[3, 4, 6], [5, 4, 6]], 'Call the helper once per order with its inputs.'
                         helper_calls.clear()
                         assert total_batch_cost(0, 2, 3, 9) == 36
                         assert sorted(helper_calls) == [[0, 3, 9], [2, 3, 9]]
                     finally:
                         caller_names['batch_cost'] = saved_helper
                     assert total_batch_cost(5, 3, 4, 6) == 18
                     """,
                     ["The two existing calculations already behave correctly. Identify the changing item count and the size and price that both calculations use.", "Give the single-order calculation to batch_cost. Keep the counts separate: two one-item orders still require two batches even when both would fit into one.", "Inside total_batch_cost, call batch_cost(first_count, batch_size, price_per_batch) and batch_cost(second_count, batch_size, price_per_batch), then return their total. In the helper, round up the batch count before multiplying by the price."],
                     effort: .init(scopeUnits: 2),
                     practiceProfile: .init(form: .refactor, scaffolding: .light,
                                            skillIDs: ["functions-section-1", "functions-section-5"],
                                            reflectionPrompts: ["Which batch-cost examples showed that moving the duplicated calculation preserved behavior?", "Why must total_batch_cost use both helper results instead of pricing the combined item count?", "What does your helper docstring tell a caller about zero items and a partial batch?"]))
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
