import Foundation

extension Curriculum {
    static let values = Chapter(
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
}
