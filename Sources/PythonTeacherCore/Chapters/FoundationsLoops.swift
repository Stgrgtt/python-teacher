import Foundation

extension Curriculum {
    static let loops = Chapter(
        id: "loops", title: "4. Loops and accumulators", subtitle: "Process every item without losing state", prerequisites: ["decisions"],
        lesson: """
        # Keep several values in a list

        Until now, each variable has held one value. A **list** holds several values in order under one name.

        - Write it with square brackets, separating the items with commas: `[18, 24, 19]`.
        - `[]` is an empty list with no items.
        - A list can hold numbers, strings, or Booleans.
        - The same value may appear more than once.

        ### Read items by position

        Each item has a position number called an **index**. Indices start at zero: the first item has index 0 and the second has index 1, so the last of three items has index 2.

        Brackets after a list name read the item at that index. `len`, which you used for text, also counts the items in a list.

        ```python
        temperatures = [18, 24, 19]
        first = temperatures[0]
        last = temperatures[2]
        count = len(temperatures)
        print(first)
        print(last)
        print(count)
        ```

        ```text
        18
        19
        3
        ```

        - `temperatures[0]` is the first item, `18`.
        - `temperatures[2]` is the last of the three items, `19`.
        - `len(temperatures)` is `3`.
        - Two lists are equal with `==` when they hold the same items in the same order.

        > **Watch out:** Asking for an index that does not exist, such as `temperatures[3]` here, raises `IndexError`.

        ### Add items to the end

        `append(value)` is a list method that adds one value to the end. Unlike string methods such as `strip`, which return a new string, `append` changes the list itself and returns `None`.

        ```python
        names = []
        names.append("Mira")
        names.append("Theo")
        print(names)
        print(len(names))
        ```

        ```text
        ['Mira', 'Theo']
        2
        ```

        > **Remember:** Write `names.append("Mira")` on its own line. Never write `names = names.append("Mira")`, which would replace your list with `None`.

        ## Visit every item with for

        A `for` loop runs the same indented body once for each item of a list, in order. In `for temperature in temperatures:`, Python:

        1. assigns the first item to the **loop variable** `temperature`,
        2. runs the body,
        3. then assigns the next item and runs the body again, and so on until every item has been visited.

        A few rules about the layout:

        - You choose the loop variable's name; you do not change an index yourself.
        - The `for` line ends with a colon, and the body is indented four spaces.
        - A decision inside the body needs four more spaces.
        - Lines dedented back to the level of `for` run once, after the loop finishes.

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

        ```text
        ['cool', 'warm', 'cool']
        ```

        The comparison runs three times, once per item, and each selected branch adds one label. The input list stays unchanged; the output is built separately.

        ### Keep a running total

        An **iteration** is one visit through a loop's body. An **accumulator** is a variable that remembers work across those visits. To use one:

        1. Initialize it (give it a starting value) before the loop.
        2. Update it inside the loop.
        3. Use the final result afterward.

        `total += latency` is shorthand for `total = total + latency`: read the old total, add the current reading, and save the new total. A **counter** is an accumulator that increases by one.

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

        ```text
        30
        2
        ```

        - `total` changes from 0 to 12, stays 12 for the zero, then becomes 30.
        - `positive_count` ends at 2 because this example counts only values greater than zero.

        > **Watch out:** Resetting `total` inside the body loses previous work.

        ### Collect selected values

        To collect selected values, start with an empty list and call `append` when the condition matches. Preserve input order and duplicates unless the specification explicitly says otherwise.

        Each exercise defines its own valid values: in the measurement practice, zero *is* valid, unlike the positive-only example above.

        ## Finish calculations after visiting every item

        An **average**, also called an arithmetic mean, is a sum divided by the number of included items.

        - You cannot divide by zero.
        - An empty list makes no visits, so decide its answer explicitly.

        Notice how the final `if` below is aligned with `for`: it runs after the loop, not once per item.

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

        ```text
        4.0
        ```

        ### Shorter checks

        - `if count:` is a shorter check for a nonzero numeric count; zero is false in a condition.
        - Lists are false when empty, so `if not readings:` means the list is empty.

        ### Conditional expressions

        You may see `average = total / count if count else 0.0` in reference code. This **conditional expression** chooses the value before `if` when the condition is true, otherwise the value after `else`. Only the chosen side is evaluated.

        The longer `if`/`else` above is equally valid and often clearer.

        ## Repeat a known number of times

        `range` supplies whole numbers to a loop:

        - `range(4)` supplies 0, 1, 2, 3: its stop is excluded.
        - `range(1, 5)` supplies 1 through 4.
        - `range(0)` supplies no values.

        `**` raises a number to a power:

        - `2 ** 0` is 1.
        - `2 ** 1` is 2.
        - `2 ** 3` is 8.

        > **Watch out:** The power operator is written `**`. It is not written `^`.

        The next example plans retries. A **retry** is another attempt after a failure. A **schedule** is just a list of planned delays, not an instruction to actually wait.

        ```python
        planned_delays = []
        for attempt in range(3):
            seconds = 3 * (2 ** attempt)
            planned_delays.append(seconds)
        print(planned_delays)
        ```

        ```text
        [3, 6, 12]
        ```

        Each visit computes a new number and appends it. No waiting or network connection happens.

        `append` changes the list itself. Do not write `planned_delays = planned_delays.append(seconds)`, because `append` does not return the updated list.

        ## Repeat while a condition holds

        Sometimes you do not know in advance how many visits are needed. A `while` loop repeats its indented body as long as its condition is `True`.

        1. Python checks the condition before every visit.
        2. If it is `True`, the body runs, then the condition is checked again.
        3. As soon as it is `False`, the loop ends and the next dedented line runs.

        If the condition is `False` at the start, the body never runs.

        ```python
        balance = 20
        weeks = 0
        while balance < 100:
            balance = balance * 2
            weeks += 1
        print(balance)
        print(weeks)
        ```

        ```text
        160
        3
        ```

        `balance` goes from 20 to 40, 80, then 160. At 160 the condition `balance < 100` is `False`, so the loop stops after 3 visits.

        ### Avoid infinite loops

        Something inside the body must change the values in the condition so that it eventually becomes `False`. If nothing changes, the loop repeats forever: an **infinite loop**.

        > **Note:** This app stops any run that takes longer than 8 seconds and reports a timeout. If that happens, look for a `while` condition that can never become `False`.

        ```python
        attempt = 0
        delays = []
        while attempt < 3:
            delays.append(5 * attempt)
            attempt += 1
        print(delays)
        ```

        ```text
        [0, 5, 10]
        ```

        The counter `attempt` starts at 0 and increases on every visit. Forgetting `attempt += 1` would make the condition stay `True` forever.

        When a list or a fixed count already determines the visits, a `for` loop is usually simpler and cannot run forever by accident.

        ## Stop early or skip an item

        - `break` ends the nearest enclosing loop immediately; Python continues with the first line after the loop.
        - `continue` skips the rest of the current visit only: a `for` loop moves on to its next item, and a `while` loop checks its condition again.

        Both normally sit inside an `if`, so they apply only in selected cases.

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

        ```text
        11
        ```

        - `4` is added.
        - `-1` is skipped by `continue`.
        - `7` is added, making 11.
        - `0` triggers `break`, so `9` is never visited.

        ### Stop before a limit

        A common use of `break` is stopping before a limit would be exceeded: check first, then update.

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

        ```text
        [3, 4]
        7
        ```

        - Adding 5 would make 12, more than the budget, so the loop stops.
        - The final 1 is never considered, because `break` ends the whole loop, not just one visit.
        - Exactly reaching the budget would be allowed, because the test uses `>`.

        > **Watch out:** In a `while` loop, update the counter before any `continue`, or the skipped update can cause an infinite loop.

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

        ```text
        value 3, total 3
        value 0, total 3
        value 5, total 8
        final 8
        ```

        ### Trace on paper

        Make a table with a column for each of these:

        - the current item
        - the condition result
        - the accumulator after the update

        Choose inputs that include:

        - zero
        - a threshold equality
        - repeated values
        - an empty input list: the body never runs, so sensible initial values become the result

        For `while` loops, also record the condition each time it is checked.

        > **Watch out:** Never remove items from the same list you are traversing; collect a new result instead.

        A correct program should match both its final answer and your step-by-step explanation.

        ### Locate the first divergence

        The **first divergence** is the earliest step where the observed state differs from the expected state. Number visits starting at 1 when explaining a trace; this is different from list indices, which start at 0.

        You can save a trace as a list as well as print it. Append the current total after each update:

        ```python
        amounts = [2, 0, 5]
        total = 0
        totals_after = []
        for amount in amounts:
            total += amount
            totals_after.append(total)
        print(totals_after)
        print(total)
        ```

        ```text
        [2, 2, 7]
        7
        ```

        If an attempted version produced `2`, `0`, `5` after those visits, the first divergence would be visit 2: adding zero should preserve the earlier 2. Inspect what ran during that visit, including any assignments before the update. Repair the earliest mismatch, then check later visits too.

        ### Predict a stopping condition

        For a `while` trace, write down the starting value, the condition before each visit, and the value after each update. Decide whether an exactly reached threshold should allow another visit. A condition checked before the body and a value recorded after the update describe different moments.

        Prediction labs ask you to keep a separate prediction of the original sequence while repairing the loop. A saved prediction is evidence about reading the original starter with its supplied inputs, not proof of a general algorithm. Keep that prediction fixed even when trying other inputs. Keep the update that moves the loop toward stopping.

        In labs with **Experiment** fields, leave the supplied input lines unchanged in your code. Enter Python literal values in the fields, such as `5` or `[2, 0, 5]`: values written directly, not calculations or commands. Choose **Run experiment** to observe a fresh run without changing your draft or awarding XP or completion.

        **Check solution** runs each named case afresh and compares expected and actual values. It stops at the first failed case and marks later cases not reached. The original checks still verify your prediction for the original starter. Other input cases check the repaired calculation, not a new prediction.
        """,
        exercises: [
            exercise("loops-total", "Count usable measurements", """
                Goal:
                Summarize usable time measurements. **Latency** means how long a job took, and `ms` means milliseconds.

                Starting code:
                - `latencies = [10, -1, 0, 25, -1, 5]` is the input list. Keep it unchanged. In this invented data, a negative number marks a missing reading, not a negative duration.
                - `total_ms = 0` is a result variable to update.
                - `valid_count = 0` is a result variable to update.
                - `mean_ms = 0.0` is a result variable to update.

                Your task:
                1. Keep `latencies` unchanged. Use a loop to visit its readings.
                2. Exclude negative readings. Include zero as a valid measurement.
                3. Save the sum of included readings in the integer `total_ms`.
                4. Save the number of included readings in the integer `valid_count`.
                5. After the loop, set `mean_ms` to the arithmetic mean of included readings as a number: their total divided by their count.
                6. If there are no valid readings, use `0.0` for `mean_ms` instead of dividing by zero.

                Expected result:
                - `total_ms` is `40`.
                - `valid_count` is `4`.
                - `mean_ms` is `10.0`.
                - An empty list, or a list with only negative readings, would give `0`, `0`, and `0.0`.

                Check:
                Choose **Check solution**. It checks the unchanged input and the three saved results for the supplied list. Printing is optional.
                """,
                     "latencies = [10, -1, 0, 25, -1, 5]\ntotal_ms = 0\nvalid_count = 0\nmean_ms = 0.0\n",
                     "latencies = [10, -1, 0, 25, -1, 5]\ntotal_ms = 0\nvalid_count = 0\nfor latency in latencies:\n    if latency >= 0:\n        total_ms += latency\n        valid_count += 1\nmean_ms = total_ms / valid_count if valid_count else 0.0\n",
                     "assert latencies == [10, -1, 0, 25, -1, 5]\nassert total_ms == 40\nassert valid_count == 4\nassert mean_ms == 10.0\n",
                     ["The sum measures total time; the count measures how many valid readings contributed. Keep two accumulators initialized before the loop.", "Only nonnegative readings contribute to either accumulator. Zero contributes no time but still increases the number of valid readings by one.", "Calculate the average after the loop has collected all readings. Check whether the count is positive before division; when it is zero, the specified average is `0.0`."]),
            exercise("loops-filter", "Queue long prompts", """
                Goal:
                Select long text inputs and count only their extra length. A **prompt** is text sent to a model; its **token count** measures text units, not characters.

                Starting code:
                - `token_counts = [0, 40, 41, 12, 80, 41]` is the input list. Keep it unchanged.
                - `long_counts = []` is an empty result list to fill.
                - `excess_tokens = 0` is a result total to update.

                Your task:
                1. Keep `token_counts` unchanged.
                2. Build `long_counts` as a new list of only the integer counts strictly greater than `40`. A count of exactly `40` is not long.
                3. Preserve input order and repeated values; both appearances of `41` must remain.
                4. The invented length allowance is 40 tokens per prompt. Set the integer `excess_tokens` to the total amount above that allowance across selected prompts, not the sum of their full lengths. A 41-token prompt contributes 1 extra token.

                Expected result:
                - `long_counts` is `[41, 80, 41]`.
                - `excess_tokens` is `42`.
                - With no counts above 40, the results would be `[]` and `0`.

                Check:
                Choose **Check solution**. It checks the original input, the selected list, and the saved extra-token total; no prompt text or network access is needed.
                """,
                     "token_counts = [0, 40, 41, 12, 80, 41]\nlong_counts = []\nexcess_tokens = 0\n",
                     "token_counts = [0, 40, 41, 12, 80, 41]\nlong_counts = []\nexcess_tokens = 0\nfor count in token_counts:\n    if count > 40:\n        long_counts.append(count)\n        excess_tokens += count - 40\n",
                     "assert token_counts == [0, 40, 41, 12, 80, 41]\nassert long_counts == [41, 80, 41]\nassert excess_tokens == 42\n",
                     ["Strictly greater than excludes a count of exactly 40. Use the same selection condition for the output list and the extra-token total.", "`append` adds a qualifying count at the end of a list, retaining order. Repeated qualifying inputs must each get a visit; do not remove duplicates.", "Only the portion beyond the allowance contributes to `excess_tokens`. For example, a count of 45 contributes 5 rather than 45; accumulate each selected item's extra portion."]),
            exercise("loops-retries-v2", "Build a retry schedule within a wait budget", """
                Goal:
                Plan delays before repeated attempts without going over a total waiting budget. A **retry** is another attempt after a failure.

                Starting code:
                - `retry_count = 4` is an input. Keep it unchanged.
                - `base_seconds = 2` is an input. Keep it unchanged.
                - `max_wait = 20` is an input: the waiting budget. Keep it unchanged.
                - `delays = []` is the starting value for the result list.
                - `total_wait = 0` is the starting value for the result total.

                Your task:
                1. Keep all three inputs unchanged.
                2. Use a loop to build `delays` as a list of integer seconds in retry order. A `while` loop with a counter, or a `for` loop over `range`, both work.
                3. Number retries from `0` up to, but not including, `retry_count`.
                4. Make each delay `base_seconds` multiplied by 2 raised to that retry number: the first delay is `base_seconds` and each next delay doubles. The lesson explains `range` and the power operator `**`.
                5. Before adding a delay, check the budget: if `total_wait` plus that delay would be greater than `max_wait`, stop planning immediately and add no further delays. Reaching exactly `max_wait` is allowed. The lesson shows how `break` or a `while` condition stops a loop early.
                6. Otherwise, append the delay to `delays` and add it to the integer `total_wait`.
                7. If your loop is a `while` loop, make sure the retry number increases on every visit so the loop ends.
                8. Do not actually wait or contact a service: this schedule is only a list of numbers.

                Expected result:
                - `delays` is `[2, 4, 8]`.
                - `total_wait` is `14`.
                - The next delay, `16`, would make `30`, which is over `20`.

                If you temporarily try other inputs:
                - `max_wait = 14` gives `[2, 4, 8]` and `14` (exactly reaching the budget).
                - `max_wait = 100` gives `[2, 4, 8, 16]` and `30`.
                - `max_wait = 1` gives `[]` and `0`.

                Restore `max_wait = 20` before checking.

                Check:
                Choose **Check solution**. It checks the unchanged inputs, the ordered delays, and the saved total; do not use a sleep operation.
                """,
                     "retry_count = 4\nbase_seconds = 2\nmax_wait = 20\ndelays = []\ntotal_wait = 0\n",
                     "retry_count = 4\nbase_seconds = 2\nmax_wait = 20\ndelays = []\ntotal_wait = 0\nretry_number = 0\nwhile retry_number < retry_count:\n    delay = base_seconds * (2 ** retry_number)\n    if total_wait + delay > max_wait:\n        break\n    delays.append(delay)\n    total_wait += delay\n    retry_number += 1\n",
                     "assert retry_count == 4 and base_seconds == 2 and max_wait == 20\nassert delays == [2, 4, 8]\nassert total_wait == 14\n",
                     ["Retry numbers start at zero and stop before `retry_count`. `range(retry_count)` supplies them, or a `while` loop can count them with a variable that starts at 0 and increases by one each visit.", "`**` means raising to a power, not multiplication by the exponent. A power of zero gives 1, so the first delay is the base itself. `^` is a different operation and is not suitable here.", "Compute the delay first, then compare `total_wait` plus that delay with `max_wait` using `>` so an exact match is still allowed. When it is over the budget, `break` ends the loop; otherwise update both the list and the total."]),
            exercise("loops-debug-running-total", "Debug: find the first wrong total", """
                Goal:
                Repair a running total. The starter finishes with `2` rather than the total of all three amounts.

                Starting code:
                - `amounts = [4, 3, 2]` is the input list. Keep its values and order unchanged.
                - `total` and `totals_after` attempt to record the sum and the sum after each visit.
                - `first_wrong_visit = 0` is a placeholder for the first visit where the original trace disagrees with the intended running total. Count visits from 1.

                Your task:
                1. Predict the intended running total after each amount, then run the original code and inspect `totals_after`.
                2. Save the number of the first mismatching visit in `first_wrong_visit`. Keep this diagnosis of the original even after the repair.
                3. Repair the loop so `total` includes every amount and `totals_after` records the total after each update.
                4. Use the loop to compute the results rather than assigning a fixed total or trace. An empty input would leave `total` at zero and the trace empty.

                Expected result:
                - The repaired `total` is the integer `9` and `totals_after` is `[4, 7, 9]`.
                - `first_wrong_visit` identifies the earliest difference in the original trace, not the repaired one.

                Check:
                Choose **Check solution**. Named cases check the original amounts, an empty list, one amount, and negative and zero amounts. Separate rows compare the integer `total` and the ordered `totals_after` trace. Every row reruns your code from a fresh start. A failure stops the check and leaves later rows not reached; the original checks must pass too.

                Keep `first_wrong_visit` as your diagnosis of the original starter with `[4, 3, 2]`, regardless of the other cases or experiments. Only the original checks assess that prediction; the visit number alone does not demonstrate a working accumulator.

                Keep the supplied input line unchanged. To try your own case, enter a Python literal list in the Experiment field `amounts`, such as `[2, 0, 5]`, then choose **Run experiment**. This shows results without changing your draft, awarding XP, or completing the exercise.
                """,
                     "amounts = [4, 3, 2]\nfirst_wrong_visit = 0\ntotal = 0\ntotals_after = []\nfor amount in amounts:\n    total = 0\n    total += amount\n    totals_after.append(total)\n",
                     "amounts = [4, 3, 2]\nfirst_wrong_visit = 2\ntotal = 0\ntotals_after = []\nfor amount in amounts:\n    total += amount\n    totals_after.append(total)\n",
                     "assert amounts == [4, 3, 2]\nassert type(first_wrong_visit) is int and first_wrong_visit == 2\nassert type(total) is int and total == 9\nassert totals_after == [4, 7, 9]\n",
                     ["Compare one visit at a time. The first amount alone cannot reveal whether earlier work will survive the next visit.", "The first visit correctly produces 4. The second should produce 7, but the original produces 3: inspect every assignment made during visit 2.", "Save `2` as the original first wrong visit. Initialize `total` only before the loop, remove its reset inside the loop, and keep appending after each addition."],
                     effort: .init(difficulty: .similar, scopeUnits: 2),
                     checkPlan: .init(inputs: [
                        .init(name: "amounts", defaultLiteral: "[4, 3, 2]")
                     ], checks: [
                        .init(id: "original-total", title: "Original amounts: total", target: "total", expectedLiteral: "9"),
                        .init(id: "original-trace", title: "Original amounts: totals after each visit", target: "totals_after", expectedLiteral: "[4, 7, 9]"),
                        .init(id: "empty-total", title: "Empty input: total", inputs: ["amounts": "[]"], target: "total", expectedLiteral: "0"),
                        .init(id: "empty-trace", title: "Empty input: totals after each visit", inputs: ["amounts": "[]"], target: "totals_after", expectedLiteral: "[]"),
                        .init(id: "single-total", title: "One amount: total", inputs: ["amounts": "[5]"], target: "total", expectedLiteral: "5"),
                        .init(id: "single-trace", title: "One amount: totals after each visit", inputs: ["amounts": "[5]"], target: "totals_after", expectedLiteral: "[5]"),
                        .init(id: "negative-zero-total", title: "Negative and zero amounts: total", inputs: ["amounts": "[4, -3, 0, 2]"], target: "total", expectedLiteral: "3"),
                        .init(id: "negative-zero-trace", title: "Negative and zero amounts: totals after each visit", inputs: ["amounts": "[4, -3, 0, 2]"], target: "totals_after", expectedLiteral: "[4, 1, 1, 3]")
                     ])),
            exercise("loops-predict-threshold", "Predict and debug: stop at the target", """
                Goal:
                Predict a loop's sequence and repair its stopping behavior. The starter finishes above the target even though it reached that target on an earlier visit.

                Starting code:
                - `start_value = 2` and `target = 8` are fixed inputs, both positive integers.
                - The loop doubles `value` and appends each new value to `visited`.
                - `predicted_before = []` is a placeholder for your prediction of the original loop's recorded sequence.

                Your task:
                1. Before running, save your predicted original sequence in `predicted_before` as a list of integers.
                2. Run the original and compare that prediction with `visited`.
                3. Keep the original prediction and repair the loop: double only while the current value is below the target, stopping once it reaches or exceeds it.
                4. Record each value after doubling in `visited`, not the starting value. Keep the update that makes the loop progress, and calculate the sequence rather than hard-coding it.

                Expected result:
                - `predicted_before` records the original sequence, including any visit beyond the intended stop.
                - After repair, `visited` is `[4, 8]` and `value` is `8`.
                - With `target = 2`, the repaired loop would make no visits: `visited` would be `[]` and `value` would stay `2`.
                - With `target = 5`, it would record `[4, 8]` and stop at `8`.

                Check:
                Choose **Check solution**. Named cases check the original inputs, an already reached target of `2`, an overshoot with target `5`, start `3` with target `12`, and start `10` already above target `8`. Separate rows compare the integer `value` and the ordered `visited` sequence. Every row reruns your code from a fresh start. A failure stops the check and leaves later rows not reached; the original checks must pass too.

                Keep `predicted_before` as your prediction of the original starter with start `2` and target `8`, regardless of other cases or experiments. Only the original checks assess that prediction; a correct prediction alone does not prove the repair works generally.

                Keep the supplied input lines unchanged. To try your own case, enter positive integer Python literal values in the Experiment fields `start_value` and `target`, such as `3` and `12`, then choose **Run experiment**. This shows results without changing your draft, awarding XP, or completing the exercise.
                """,
                     "start_value = 2\ntarget = 8\npredicted_before = []\nvalue = start_value\nvisited = []\nwhile value <= target:\n    value = value * 2\n    visited.append(value)\n",
                     "start_value = 2\ntarget = 8\npredicted_before = [4, 8, 16]\nvalue = start_value\nvisited = []\nwhile value < target:\n    value = value * 2\n    visited.append(value)\n",
                     "assert start_value == 2 and target == 8\nassert predicted_before == [4, 8, 16]\nassert visited == [4, 8]\nassert type(value) is int and value == 8\n",
                     ["Trace the condition before each visit and the appended value after the update; those are different moments.", "In the original loop, equality at 8 still allows a visit. That visit doubles before appending, so the recorded sequence goes beyond 8.", "Keep `[4, 8, 16]` as the original prediction. Change the loop condition to `value < target` and retain the doubling and append inside the body."],
                     effort: .init(difficulty: .similar, scopeUnits: 2),
                     checkPlan: .init(inputs: [
                        .init(name: "start_value", defaultLiteral: "2"),
                        .init(name: "target", defaultLiteral: "8")
                     ], checks: [
                        .init(id: "original-value", title: "Original target: final value", target: "value", expectedLiteral: "8"),
                        .init(id: "original-visited", title: "Original target: values visited", target: "visited", expectedLiteral: "[4, 8]"),
                        .init(id: "already-reached-value", title: "Already at the target: final value", inputs: ["target": "2"], target: "value", expectedLiteral: "2"),
                        .init(id: "already-reached-visited", title: "Already at the target: values visited", inputs: ["target": "2"], target: "visited", expectedLiteral: "[]"),
                        .init(id: "overshoot-value", title: "Target between doublings: final value", inputs: ["target": "5"], target: "value", expectedLiteral: "8"),
                        .init(id: "overshoot-visited", title: "Target between doublings: values visited", inputs: ["target": "5"], target: "visited", expectedLiteral: "[4, 8]"),
                        .init(id: "different-start-value", title: "Start 3 with target 12: final value", inputs: ["start_value": "3", "target": "12"], target: "value", expectedLiteral: "12"),
                        .init(id: "different-start-visited", title: "Start 3 with target 12: values visited", inputs: ["start_value": "3", "target": "12"], target: "visited", expectedLiteral: "[6, 12]"),
                        .init(id: "above-target-value", title: "Start above the target: final value", inputs: ["start_value": "10"], target: "value", expectedLiteral: "10"),
                        .init(id: "above-target-visited", title: "Start above the target: values visited", inputs: ["start_value": "10"], target: "visited", expectedLiteral: "[]")
                     ])),
            exercise("loops-transfer-water-log", "Summarize a garden water log", """
                     Goal:
                     Summarize an invented garden's watering records and collect the amounts meeting a chosen threshold. Choose your approach from the loops, decisions, and lists already taught.

                     Starting code:
                     - Keep the supplied input lines unchanged: `water_liters = [3, 7, 2, 7]` and `minimum_liters = 5`.
                     - The log is a finite list of nonnegative integers, possibly empty, and the threshold is a nonnegative integer. No invalid values need handling.
                     - Replace or extend the result placeholders `total_liters = 0`, `qualifying_count = 0`, and `qualifying_liters = []`. Keep the input list unchanged.

                     Your task:
                     1. Save the integer `total_liters` for every log entry, including amounts below the threshold.
                     2. Save the integer `qualifying_count` and a new list `qualifying_liters` for entries at least `minimum_liters`, preserving their order and repeated values. Zero qualifies when the threshold is zero.

                     Expected result:
                     - The supplied inputs give `total_liters` equal to `19`, `qualifying_count` equal to `2`, and `qualifying_liters` equal to `[7, 7]`.
                     - An empty log gives `0`, `0`, and `[]`.
                     - Log `[0, 2, 0, 1]` with threshold `0` gives `3`, `4`, and `[0, 2, 0, 1]`.
                     - Log `[1, 2]` with threshold `3` gives `3`, `0`, and `[]`.

                     Check:
                     Choose **Check solution**. Fresh named cases check the original total, each empty-log result, each zero-threshold result, and a list with no qualifying entries. Separate rows compare separate result variables; the original typed checks must pass too. A failed case leaves later cases not reached.

                     To explore without changing your draft, awarding XP, or completing the exercise, enter Python literal values (directly written values such as `[0, 2]` and `0`) in the Experiment fields and choose **Run experiment**. Keep the supplied input lines unchanged for checking.
                     """,
                     "water_liters = [3, 7, 2, 7]\nminimum_liters = 5\ntotal_liters = 0\nqualifying_count = 0\nqualifying_liters = []\n",
                     "water_liters = [3, 7, 2, 7]\nminimum_liters = 5\ntotal_liters = 0\nqualifying_count = 0\nqualifying_liters = []\nfor liters in water_liters:\n    total_liters += liters\n    if liters >= minimum_liters:\n        qualifying_count += 1\n        qualifying_liters.append(liters)\n",
                     "assert water_liters == [3, 7, 2, 7] and minimum_liters == 5\nassert type(total_liters) is int and total_liters == 19\nassert type(qualifying_count) is int and qualifying_count == 2\nassert type(qualifying_liters) is list and qualifying_liters == [7, 7]\n",
                     ["The total describes the whole log, while the count and list describe only qualifying entries. What should each result be before any entry is visited?", "Keep accumulated work between visits. The threshold comparison includes equality, and repeated entries are separate records.", "Initialize the total, count, and empty result list before a `for` loop. Add every amount to the total; when `liters >= minimum_liters`, increase the count and append that amount to the result list."],
                     effort: .init(difficulty: .similar, scopeUnits: 2),
                     checkPlan: .init(inputs: [
                        .init(name: "water_liters", defaultLiteral: "[3, 7, 2, 7]"),
                        .init(name: "minimum_liters", defaultLiteral: "5")
                     ], checks: [
                        .init(id: "original-total", title: "Original log: total includes small entries", target: "total_liters", expectedLiteral: "19"),
                        .init(id: "empty-total", title: "Empty log: total", inputs: ["water_liters": "[]"], target: "total_liters", expectedLiteral: "0"),
                        .init(id: "empty-count", title: "Empty log: qualifying count", inputs: ["water_liters": "[]"], target: "qualifying_count", expectedLiteral: "0"),
                        .init(id: "empty-list", title: "Empty log: qualifying amounts", inputs: ["water_liters": "[]"], target: "qualifying_liters", expectedLiteral: "[]"),
                        .init(id: "zero-threshold-total", title: "Zero threshold: total", inputs: ["water_liters": "[0, 2, 0, 1]", "minimum_liters": "0"], target: "total_liters", expectedLiteral: "3"),
                        .init(id: "zero-threshold-count", title: "Zero threshold: zero entries also count", inputs: ["water_liters": "[0, 2, 0, 1]", "minimum_liters": "0"], target: "qualifying_count", expectedLiteral: "4"),
                        .init(id: "zero-threshold-list", title: "Zero threshold: preserve order and repetitions", inputs: ["water_liters": "[0, 2, 0, 1]", "minimum_liters": "0"], target: "qualifying_liters", expectedLiteral: "[0, 2, 0, 1]"),
                        .init(id: "no-qualifying-list", title: "All entries below the threshold", inputs: ["water_liters": "[1, 2]", "minimum_liters": "3"], target: "qualifying_liters", expectedLiteral: "[]")
                     ]),
                     practiceProfile: .init(form: .transfer, scaffolding: .independent,
                                            skillIDs: ["loops-section-1", "loops-section-2", "decisions-section-1"],
                                            reflectionPrompts: ["Which results depend on the threshold, and which do not?", "Why must a zero entry be counted when the threshold is zero?"]))
        ],
        assessment: exercise("loops-assessment", "Track consecutive passing checks", """
            Goal:
            Describe passing checks in their original sequence. A **streak** means adjacent passing scores without a failed score between them; it is not the total number of passes.

            Starting code:
            - `scores = [0.8, 0.9, 0.4, 0.8, 0.8, 1.0, 0.2]` is the input list. Keep it unchanged.
            - `passing_count = 0` is a result to update.
            - `longest_streak = 0` is a result to update.
            - `current_streak = 0` is a result to update.

            Your task:
            1. Keep `scores` unchanged and in its original order.
            2. Use a loop to calculate three integer results under the supplied names.
            3. Treat scores of at least `0.8` as passing, including exactly `0.8`; smaller scores fail.
            4. Set `passing_count` to the number of all passing scores.
            5. Set `longest_streak` to the largest number of adjacent passes anywhere in the list.
            6. Set `current_streak` to the number of adjacent passes at the very end; it is `0` when the final score fails.
            7. Make sure an empty input would leave all three results equal to `0`.

            Examples:
            - For the supplied list: `passing_count` is `5`, `longest_streak` is `3`, and `current_streak` is `0`.
            - For `[0.8, 0.2, 0.9, 1.0]`: the results would be `3`, `2`, and `2`.
            - For `[0.1]`: all three would be `0`.

            Check:
            Complete the theory questions and written explanation, then choose **Submit assessment**. It checks the original list and the saved results for that list. Work independently without hints or solutions.
            """,
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
}
