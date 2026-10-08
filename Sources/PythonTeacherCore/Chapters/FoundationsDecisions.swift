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

        Some debugging labs provide **Experiment** fields for their declared inputs: the input names the app can vary safely.

        1. Keep the supplied input lines unchanged in your code.
        2. Enter a Python literal value in an Experiment field, such as `11` or `False`. A literal is a value written directly, not a calculation or a command.
        3. Choose **Run experiment** and read the saved result. Each experiment starts fresh, without changing your draft or awarding XP or completion.

        **Check solution** runs the named cases afresh, compares expected and actual values, then checks the original example. A failed case stops the check; later cases are marked not reached. Passing several cases is useful evidence, not proof for every possible input.

        For exercises without Experiment fields, temporarily change an input line, run the code, then restore the original input before choosing **Check solution**.

        ### Find one counterexample

        A **counterexample** is an input where an attempted rule disagrees with the intended rule. It can be more informative than several ordinary cases that happen to work.

        Suppose a group may start with at least three people. Inspect the comparison at the exact boundary:

        ```python
        people = 3
        attempted = people > 3
        required = people >= 3
        print(attempted)
        print(required)
        ```

        ```text
        False
        True
        ```

        Both comparisons run successfully. Three people distinguish the rules; four would not. For a priority rule, choose inputs where both conditions hold, then trace every assignment to the result. A later independent `if` can replace an earlier decision.

        A fixed-input check confirms that example only. After repairing a rule, try a nearby value and a conflicting case. Use Experiment fields when available so the supplied input lines stay unchanged; otherwise restore the supplied inputs before checking.

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
                     ["A score above 1 also exceeds the passing threshold, but it is invalid. Validate the scale before judging whether a score passes.", "A comparison is already a Boolean value, so `in_range` can be assigned the result of a range check directly. A chained comparison with `<=` on both sides includes both endpoints.", "Start the chain with `not in_range` so invalid scores are handled first. Then compare with `0.6` using `>=` so exactly `0.6` passes, and let `else` cover the remaining valid scores."]),
            exercise("decisions-debug-priority", "Debug: a closed room opens", """
                Goal:
                Repair a room-status decision. The starter runs and saves `'open'`, although this room is under maintenance.

                Starting code:
                - `maintenance = True` and `guests = 6` are inputs. Keep them unchanged.
                - The decision code attempts to save a string in `status`.

                Your task:
                1. Trace the value saved in `status` after each decision with the given inputs.
                2. Repair the decision so maintenance always means `'closed'`, regardless of the guest count.
                3. Without maintenance, at least two guests means `'open'`; otherwise the status must be `'waiting'`.
                4. Express all outcomes in decision code, not a fixed status for this room.

                Expected result:
                - `status` is `'closed'` for the supplied inputs.
                - Without maintenance, six guests would give `'open'` and one guest would give `'waiting'`.

                Check:
                Choose **Check solution**. Named cases check maintenance with six and one guests, then no maintenance with one, two, and six guests. Each case reruns your code from a fresh start and compares `status` with the expected text. A failure stops the check and leaves later cases not reached; the original checks must pass too.

                Keep the supplied input lines unchanged. To try your own case, enter Python literal values in the Experiment fields `maintenance` and `guests`, such as `False` and `2`, then choose **Run experiment**. This shows the result without changing your draft, awarding XP, or completing the exercise.
                """,
                     "maintenance = True\nguests = 6\nif maintenance:\n    status = 'closed'\nif guests >= 2:\n    status = 'open'\nelse:\n    status = 'waiting'\n",
                     "maintenance = True\nguests = 6\nif maintenance:\n    status = 'closed'\nelif guests >= 2:\n    status = 'open'\nelse:\n    status = 'waiting'\n",
                     "assert maintenance is True and guests == 6\nassert status == 'closed'\n",
                     ["Both conditions are true for these inputs. Follow the entire program rather than stopping at the first saved status.", "Independent `if` statements are each checked. An `if`/`elif` chain chooses only the first matching branch.", "Keep the maintenance branch first and make the guest comparison an `elif`, with the waiting `else` attached to that single chain."],
                     effort: .init(difficulty: .similar, scopeUnits: 1),
                     checkPlan: .init(inputs: [
                        .init(name: "maintenance", defaultLiteral: "True"),
                        .init(name: "guests", defaultLiteral: "6")
                     ], checks: [
                        .init(id: "maintenance-many", title: "Maintenance with six guests: closed", target: "status", expectedLiteral: "'closed'"),
                        .init(id: "maintenance-few", title: "Maintenance with one guest: closed", inputs: ["guests": "1"], target: "status", expectedLiteral: "'closed'"),
                        .init(id: "no-maintenance-few", title: "One guest without maintenance: waiting", inputs: ["maintenance": "False", "guests": "1"], target: "status", expectedLiteral: "'waiting'"),
                        .init(id: "no-maintenance-boundary", title: "Exactly two guests: open", inputs: ["maintenance": "False", "guests": "2"], target: "status", expectedLiteral: "'open'"),
                        .init(id: "no-maintenance-many", title: "Six guests without maintenance: open", inputs: ["maintenance": "False"], target: "status", expectedLiteral: "'open'")
                     ])),
            exercise("decisions-debug-entry-boundary", "Debug: entry at the boundary", """
                Goal:
                Repair an entry decision that saves `False` for an approved learner exactly at the minimum age, although the rule permits entry.

                Starting code:
                - `age = 12`, `minimum_age = 12`, and `approved = True` are fixed inputs.
                - `can_enter` is an attempted Boolean decision, not a placeholder.

                Your task:
                1. Explain to yourself why the given inputs are a counterexample: compare the observed decision with the rule.
                2. Repair `can_enter` so it is `True` only when the learner is at least `minimum_age` and has approval. Otherwise it must be `False`.
                3. Use the input names to express both requirements, not a fixed Boolean answer.

                Expected result:
                - `can_enter` is `True` for the supplied inputs.
                - At age `11` with approval, it would be `False`.
                - At age `13` without approval, it would also be `False`.

                Check:
                Choose **Check solution**. Named cases check equality, an age below the minimum, missing approval above the minimum, and ages below and above a changed minimum of `18`. Each case reruns your code from a fresh start and compares the Boolean `can_enter` with the expected value. A failure stops the check and leaves later cases not reached; the original checks must pass too.

                Keep the supplied input lines unchanged. To try your own case, enter Python literal values in the Experiment fields `age`, `minimum_age`, and `approved`, such as `13`, `12`, and `False`, then choose **Run experiment**. This shows the result without changing your draft, awarding XP, or completing the exercise. One passing case does not establish the whole rule.
                """,
                     "age = 12\nminimum_age = 12\napproved = True\ncan_enter = age > minimum_age and approved\n",
                     "age = 12\nminimum_age = 12\napproved = True\ncan_enter = age >= minimum_age and approved\n",
                     "assert age == 12 and minimum_age == 12 and approved is True\nassert can_enter is True\n",
                     ["At least includes the minimum itself. Check the age comparison separately from the approval requirement.", "Exactly equal inputs distinguish `>` from `>=`. Both requirements must still hold, so keep the approval check.", "Use `age >= minimum_age and approved` to include equality while still rejecting learners without approval."],
                     effort: .init(difficulty: .easier, scopeUnits: 1),
                     checkPlan: .init(inputs: [
                        .init(name: "age", defaultLiteral: "12"),
                        .init(name: "minimum_age", defaultLiteral: "12"),
                        .init(name: "approved", defaultLiteral: "True")
                     ], checks: [
                        .init(id: "at-minimum", title: "At the minimum with approval: entry allowed", target: "can_enter", expectedLiteral: "True"),
                        .init(id: "below-minimum", title: "Below the minimum: entry denied", inputs: ["age": "11"], target: "can_enter", expectedLiteral: "False"),
                        .init(id: "without-approval", title: "Above the minimum without approval: entry denied", inputs: ["age": "13", "approved": "False"], target: "can_enter", expectedLiteral: "False"),
                        .init(id: "changed-minimum-below", title: "Age 17 with a minimum of 18: entry denied", inputs: ["age": "17", "minimum_age": "18"], target: "can_enter", expectedLiteral: "False"),
                        .init(id: "changed-minimum-above", title: "Age 19 with a minimum of 18 and approval: entry allowed", inputs: ["age": "19", "minimum_age": "18"], target: "can_enter", expectedLiteral: "True")
                     ])),
            exercise("decisions-transfer-library-entry", "Decide library entry", """
                     Goal:
                     Decide whether one more visitor may enter an invented library room. Choose how to express the rule using the decisions and Boolean operations you have learned.

                     Starting code:
                     - Keep the supplied input lines unchanged: `visitors = 3`, `capacity = 4`, `has_pass = True`, and `is_open = True`.
                     - Visitors and capacity are nonnegative integers; both permission inputs are Booleans. Inputs are suitable values, with no invalid data to handle.
                     - Replace the `can_enter = False` placeholder. You may add names or decision branches.

                     Your task:
                     1. Save the Boolean `can_enter`: entry is allowed only when the room is open, the arriving visitor has a pass, and the current visitor count is strictly below capacity. Otherwise save `False`. A pass cannot bypass either room rule.

                     Expected result:
                     - The supplied inputs give `True`.
                     - Four visitors at capacity four give `False`, even with a pass and an open room.
                     - With space available, either a missing pass or a closed room gives `False`.
                     - Zero visitors at capacity one can enter with a pass when open; capacity zero never has space.

                     Check:
                     Choose **Check solution**. Fresh named cases include a full room, a room already above capacity, each missing permission, and changed capacities including zero. The original typed checks must pass too. A failed case leaves later cases not reached.

                     To explore without changing your draft, awarding XP, or completing the exercise, enter Python literal values (directly written values such as `0` or `False`) in the Experiment fields and choose **Run experiment**. Keep the supplied input lines unchanged for checking.
                     """,
                     "visitors = 3\ncapacity = 4\nhas_pass = True\nis_open = True\ncan_enter = False\n",
                     "visitors = 3\ncapacity = 4\nhas_pass = True\nis_open = True\ncan_enter = visitors < capacity and has_pass and is_open\n",
                     "assert visitors == 3 and capacity == 4\nassert has_pass is True and is_open is True\nassert type(can_enter) is bool and can_enter is True\n",
                     ["Try a small decision table. Start with space available, then change just one requirement at a time.", "Every requirement must hold. Test the exact capacity separately from a visitor count just below it.", "The comparison `visitors < capacity` excludes a full room. Combine it with `has_pass` and `is_open` using `and`, or use branches that enforce the same three requirements."],
                     effort: .init(difficulty: .similar, scopeUnits: 1),
                     checkPlan: .init(inputs: [
                        .init(name: "visitors", defaultLiteral: "3"),
                        .init(name: "capacity", defaultLiteral: "4"),
                        .init(name: "has_pass", defaultLiteral: "True"),
                        .init(name: "is_open", defaultLiteral: "True")
                     ], checks: [
                        .init(id: "original-entry", title: "Open room with a pass and space", target: "can_enter", expectedLiteral: "True"),
                        .init(id: "full-room", title: "Exactly at capacity", inputs: ["visitors": "4"], target: "can_enter", expectedLiteral: "False"),
                        .init(id: "above-capacity", title: "Already above capacity", inputs: ["visitors": "5"], target: "can_enter", expectedLiteral: "False"),
                        .init(id: "missing-pass", title: "Space available but no pass", inputs: ["has_pass": "False"], target: "can_enter", expectedLiteral: "False"),
                        .init(id: "closed-room", title: "Space and a pass but the room is closed", inputs: ["is_open": "False"], target: "can_enter", expectedLiteral: "False"),
                        .init(id: "changed-capacity", title: "A larger room has space for the next visitor", inputs: ["visitors": "4", "capacity": "5"], target: "can_enter", expectedLiteral: "True"),
                        .init(id: "zero-capacity", title: "An empty room with no capacity", inputs: ["visitors": "0", "capacity": "0"], target: "can_enter", expectedLiteral: "False"),
                        .init(id: "empty-room", title: "An empty one-person room", inputs: ["visitors": "0", "capacity": "1"], target: "can_enter", expectedLiteral: "True")
                     ]),
                     practiceProfile: .init(form: .transfer, scaffolding: .independent,
                                            skillIDs: ["decisions-section-1", "decisions-section-2", "decisions-section-3", "decisions-section-4"],
                                            reflectionPrompts: ["Which input distinguishes a full room from one with space?", "How did you check that a pass cannot bypass a closed room?"]))
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
