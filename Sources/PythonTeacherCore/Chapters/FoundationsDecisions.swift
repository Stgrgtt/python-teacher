import Foundation

extension Curriculum {
    static let decisions = Chapter(
        id: "decisions", title: "3. Decisions and boundaries", subtitle: "Translate rules into precise branches", prerequisites: ["values"],
        lesson: """
        # Make the rule visible

        A **conditional** chooses which statements execute. It asks a yes/no question, called its **condition**, and acts on the answer.

        ### Yes/no values

        A condition produces a **Boolean**: one of the two values `True` or `False`. Write them with capital first letters and no quotes.

        ### Comparison operators

        Comparisons ask a question about values and produce a Boolean:

        - `>` means greater than.
        - `<` means less than.
        - `>=` means at least (greater than or equal to).
        - `<=` means at most (less than or equal to).
        - `==` asks whether two values are equal.
        - `!=` asks whether two values differ.

        > **Watch out:** Assignment uses one equals sign; equality testing uses two. For example, `score = 0.8` saves a number, while `score >= 0.8` asks a yes/no question about it.

        ### Writing a decision

        - `if` begins a decision. A colon ends its condition line.
        - The indented lines below it are its **body**: the work performed if the condition is true.
        - Use four spaces per indentation level, consistently. Indentation is part of Python's meaning.
        - `elif` means “otherwise, if” and `else` means “otherwise.” Neither runs if an earlier branch matched.

        In the example below, `confidence` is an invented score from 0 to 1, and `blocked` means the item must not proceed.

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

        ```text
        automatic
        ```

        ### How the chain is checked

        Python checks an `if`/`elif` chain in order and runs only the first matching branch. This makes priority part of the program: a blocked item must be rejected even with high confidence.

        - Separate `if` statements are different: several may execute and overwrite the same result.
        - An `else` handles everything not already matched.
        - A chain may have any number of `elif` branches.
        - The `else` is optional. Without it, no branch runs when nothing matches.

        > **Remember:** Make sure every path assigns the result name you need, or a later line may raise `NameError`.

        ## Debug the boundaries

        Before coding, write a small **decision table**: a few sample inputs, each with the result you predict. Include these rows:

        - an ordinary input
        - the exact threshold
        - a value just below the threshold
        - conflicting conditions

        Here is that table for the example above:

        - With the original inputs, `route` is `"automatic"`.
        - If `blocked` were `True`, it would be `"reject"` even at the same confidence.
        - With confidence `0.8` exactly, it is still `"automatic"`, because `>=` includes equality.
        - With `0.79`, it is `"review"`.

        > **Tip:** If a test fails only at the threshold, inspect `<` versus `<=` rather than rewriting everything.

        Exercise output words may differ from lesson examples. Copy the specification's spelling exactly.

        ### Try another row of your table

        1. Temporarily change an input line.
        2. Run the code and read the printed result.
        3. Restore the original input before choosing **Check solution**.

        The checker expects the original input values.

        ## Combine conditions with and, or, and not

        Real rules often have more than one requirement. Three words combine Booleans:

        - `and` produces `True` only when both sides are `True`.
        - `or` produces `True` when at least one side is `True`. It is `False` only when both sides are `False`.
        - `not` flips one Boolean: `not True` is `False` and `not False` is `True`.

        Comparisons are calculated first, then combined. So `members >= 2 and has_room` compares `members` with `2` before applying `and`.

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

        ```text
        True
        False
        False
        ```

        - `can_open` needs both parts, and both hold.
        - `special_price` would need either part, and neither holds.
        - `closed` flips `can_open`, so it is `False`.

        ### Group conditions with parentheses

        When a rule mixes `and` with `or`, add parentheses to show the grouping you mean. `(admin or used < limit) and not suspended` checks the first pair together.

        > **Watch out:** Without parentheses, Python performs `and` before `or`, which may differ from what you intended.

        ```python
        used = 100
        limit = 100
        admin = True
        suspended = False
        allowed = (admin or used < limit) and not suspended
        print(allowed)
        ```

        ```text
        True
        ```

        The user is at the limit, but `admin` makes the parenthesized part `True`, and the user is not suspended.

        If `admin` were `False`, `used < limit` would also be `False` at equal values, so `allowed` would be `False`.

        ## Save a yes/no answer as a Boolean

        A comparison produces a value, so you can save it. `passed = score >= 0.6` stores `True` or `False`, not text.

        - Do not quote it: `'True'` is a string, not a Boolean.
        - Saving the answer under a descriptive name lets a later decision reuse it.
        - Write `if passed:` rather than `if passed == True:`.

        ### Check a range

        A range check such as `0 <= score <= 1` is a **chained comparison**. It means `0 <= score and score <= 1`, so both endpoints are included.

        `not 0 <= score <= 1` is `True` only for scores outside that range.

        > **Key idea:** Put a validity check before other rules when an invalid value could accidentally satisfy them.

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

        ```text
        False
        out of range
        ```

        - If the `score >= 0.6` branch came first, `1.2` would wrongly be labeled high.
        - With score `0.6`, the results would be `True` and high.
        - With score `0`, they would be `True` and low.

        ### Other forms you may see

        - A decision can also sit inside another branch's body, indented four more spaces. A single ordered chain is often clearer.
        - Empty strings are false in a condition and nonempty strings are true. Explicit comparisons are clearer while learning.

        Each exercise in this chapter decides one case; the next chapter shows how to repeat a decision for many values.
        """,
        exercises: [
            exercise("decisions-route", "Route a confidence score", """
                Goal:
                Choose where an invented result should go. `route` is a text label for the decision, not a network address.

                Starting code:
                - `confidence = 0.80` is an input: a score from 0 to 1. Keep it unchanged.
                - `blocked = False` is an input: `True` would mean the result must not proceed. Keep it unchanged.
                - `route = ''` is an empty-text placeholder. Replace it.

                Your task:
                1. Keep both inputs unchanged.
                2. Replace the `route` placeholder with decision code that saves a string in `route`.
                3. If `blocked` is `True`, the route must be `'reject'`, regardless of confidence.
                4. Otherwise, confidence of at least `0.80` gets `'auto'`. Exactly `0.80` is included in `'auto'`.
                5. Lower confidence gets `'review'`.
                6. Express all three rules, not just a fixed answer for this input. An `if`/`elif`/`else` chain chooses one branch in order.

                Expected result:
                - `route` is `'auto'` for the given inputs.
                - With `blocked` set to `True`, it would be `'reject'`, even at confidence `0.99`.
                - With `blocked` set to `False` and confidence `0.79`, it would be `'review'`.

                Check:
                Choose **Check solution**. The supplied check uses the original inputs at the exact `0.80` boundary and reads `route`; printing is optional.
                """,
                     "confidence = 0.80\nblocked = False\nroute = ''\n",
                     "confidence = 0.80\nblocked = False\nif blocked:\n    route = 'reject'\nelif confidence >= 0.80:\n    route = 'auto'\nelse:\n    route = 'review'\n",
                     "assert confidence == 0.80 and blocked is False\nassert route == 'auto'\n",
                     ["A blocked item cannot proceed even if its score is high. The first matching branch wins, so rule priority determines branch order.", "Check the Boolean `blocked` before comparing `confidence`. At least includes equality, which is what `>=` expresses.", "Every possible path should save a string in `route`. An `else` branch covers the cases that did not match earlier conditions."]),
            exercise("decisions-quota", "Spot a quota boundary", """
                Goal:
                Decide whether a user can do more work. A **quota** is a maximum amount of usage; an **admin** is a user permitted to bypass that maximum.

                Starting code:
                - `used = 100` is current usage. Keep it unchanged.
                - `limit = 100` is the quota. Keep it unchanged.
                - `admin = False` says this is not an administrator. Keep it unchanged.
                - `allowed = True` is a placeholder. Replace it.
                - `message = ''` is a placeholder. Replace it.

                Your task:
                1. Keep `used`, `limit`, and `admin` unchanged.
                2. Set `allowed` to a Boolean, `True` or `False`, not quoted text.
                3. Admins are always allowed.
                4. Other users are allowed only when `used` is strictly less than `limit`. Equal usage and limit must be denied for non-admins.
                5. Set `message` to exactly `'continue'` when `allowed` is `True`, otherwise `'quota reached'`.
                6. Implement both outcomes rather than hard-coding this case.

                Expected result:
                - `allowed` is `False`.
                - `message` is `'quota reached'`.
                - For a non-admin at `used` `99` and `limit` `100`, they would be `True` and `'continue'`.
                - An admin would be allowed even at the limit.

                Check:
                Choose **Check solution**. It checks the unchanged inputs and saved outputs for the equal-to-limit case.
                """,
                     "used = 100\nlimit = 100\nadmin = False\nallowed = True\nmessage = ''\n",
                     "used = 100\nlimit = 100\nadmin = False\nallowed = admin or used < limit\nif allowed:\n    message = 'continue'\nelse:\n    message = 'quota reached'\n",
                     "assert used == 100 and limit == 100 and admin is False\nassert allowed is False\nassert message == 'quota reached'\n",
                     ["When `used` equals `limit`, a non-admin has no spare capacity. Test that boundary in your reasoning before changing the starter.", "`or` produces `True` when either condition is true, so it can express the admin exception alongside the capacity rule.", "Strictly less than excludes equality; `<=` would include it. Once `allowed` holds a Boolean, an `if`/`else` can select the exact message for that saved decision."]),
            exercise("decisions-bands-v2", "Classify an evaluation score", """
                Goal:
                Give one invented evaluation score a label. Scores are only valid from 0 to 1.

                Starting code:
                - `score = 1.1` is the input. Keep it unchanged.
                - `in_range = True` is a placeholder that currently gives the wrong answer for this score. Replace it.
                - `label = 'pass'` is a placeholder that currently gives the wrong answer for this score. Replace it.

                Your task:
                1. Keep `score` unchanged. Replace both placeholder lines with code that works for any number in `score`, not just `1.1`.
                2. Set `in_range` to a Boolean, `True` or `False` without quotes: `True` when `score` is between 0 and 1, including both endpoints `0` and `1`; otherwise `False`. The lesson's chained comparison expresses this range.
                3. Set `label` with one `if`/`elif`/`else` chain. First, use `'invalid'` (outside the permitted scale) when `score` is not in range.
                4. Otherwise, use `'pass'` (acceptable) when `score` is at least `0.6`, including exactly `0.6`.
                5. Otherwise, use `'retry'` (try again).
                6. Check validity before the passing rule. A score above 1 is also at least 0.6, so the order of branches matters.

                Expected result:
                - For `score = 1.1`: `in_range` is `False` and `label` is `'invalid'`.

                If you temporarily try other inputs:
                - `-0.1` gives `False` and `'invalid'`.
                - `0.0` gives `True` and `'retry'`.
                - `0.59` gives `True` and `'retry'`.
                - `0.6` and `1.0` give `True` and `'pass'`.

                Restore `score = 1.1` before checking.

                Check:
                Choose **Check solution**. It checks the original score, the Boolean `in_range`, and the exact label; printing is optional.
                """,
                     "score = 1.1\nin_range = True\nlabel = 'pass'\n",
                     "score = 1.1\nin_range = 0 <= score <= 1\nif not in_range:\n    label = 'invalid'\nelif score >= 0.6:\n    label = 'pass'\nelse:\n    label = 'retry'\n",
                     "assert score == 1.1\nassert in_range is False\nassert label == 'invalid'\n",
                     ["A score above 1 also exceeds the passing threshold, but it is invalid. Validate the scale before judging whether a score passes.", "A comparison is already a Boolean value, so `in_range` can be assigned the result of a range check directly. A chained comparison with `<=` on both sides includes both endpoints.", "Start the chain with `not in_range` so invalid scores are handled first. Then compare with `0.6` using `>=` so exactly `0.6` passes, and let `else` cover the remaining valid scores."])
        ],
        assessment: exercise("decisions-assessment-v2", "Choose a safe deployment action", """
            Goal:
            Choose an action for one invented release candidate, a version that might be published. No real sensitive data is present.

            Starting code:
            - `has_sensitive_data = False` is an input. Keep it unchanged.
            - `quality = 0.9` is an input: a score from 0 to 1. Keep it unchanged.
            - `approvals = 1` is an input: it counts reviewers who approved. Keep it unchanged.
            - `publishable = False` is a placeholder. Replace it.
            - `action = ''` is a placeholder. Replace it.

            Your task:
            1. Keep the three inputs unchanged. Replace both placeholders with code that follows the rules for any inputs, not just these values.
            2. Set `publishable` to a Boolean, not quoted text. It is `True` only when all three hold: `has_sensitive_data` is `False`, `quality` is at least `0.9` (exactly `0.9` counts), and `approvals` is at least `1`. Otherwise it is `False`.
            3. Set `action` to `'hold'` (do not publish because of sensitive data) whenever `has_sensitive_data` is `True`, whatever the other inputs are.
            4. Otherwise, set `action` to `'release'` (ready to publish) when `publishable` is `True`.
            5. In every other case, set `action` to `'revise'` (improve the candidate first).

            Expected result:
            - For the given inputs: `publishable` is `True` and `action` is `'release'`.
            - With `has_sensitive_data` set to `True`: `False` and `'hold'`, even at quality `0.99`.
            - With `quality` set to `0.899`: `False` and `'revise'`.
            - With `approvals` set to `0`: `False` and `'revise'`.

            Check:
            Complete the theory questions and written explanation, then choose **Submit assessment**. It checks the unchanged inputs, the Boolean `publishable`, and the exact `action`. Work independently without hints or solutions; printing is not required.
            """,
                             "has_sensitive_data = False\nquality = 0.9\napprovals = 1\npublishable = False\naction = ''\n",
                             "has_sensitive_data = False\nquality = 0.9\napprovals = 1\npublishable = not has_sensitive_data and quality >= 0.9 and approvals >= 1\nif has_sensitive_data:\n    action = 'hold'\nelif publishable:\n    action = 'release'\nelse:\n    action = 'revise'\n",
                             "assert has_sensitive_data is False and quality == 0.9 and approvals == 1\nassert publishable is True\nassert action == 'release'\n",
                             []),
        quiz: [
            question("decisions-q1", "Why place an invalid-range check before a passing-score check?", ["To make the code run twice", "A score above 1 might otherwise pass", "Invalid values are always strings"], 1, "An out-of-range value such as 1.2 also meets a simple lower-bound pass check."),
            question("decisions-q2", "What changes when two independent if statements replace if/elif?", ["Both bodies can execute", "Neither body executes", "Equality becomes assignment"], 0, "Independent conditions are each checked, so the second body may overwrite the first result."),
            question("decisions-q3", "Which test best distinguishes score > 0.8 from score >= 0.8?", ["score = 0.2", "score = 0.9", "score = 0.8"], 2, "Exactly at the boundary, > is false while >= is true.")
        ])
}
