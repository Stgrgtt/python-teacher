import Foundation

extension Curriculum {
    static let loops = Chapter(
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
}
