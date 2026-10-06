import Foundation

extension Curriculum {
    static let decisions = Chapter(
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
}
