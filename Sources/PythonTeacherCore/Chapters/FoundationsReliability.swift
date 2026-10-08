import Foundation

extension Curriculum {
    static let reliability = Chapter(
        id: "reliability", title: "7. Validation and a small analysis tool", subtitle: "Reject bad data and prove useful behavior", prerequisites: ["collections"],
        lesson: """
        # Make failure part of the contract

        So far, your functions have been promised suitable inputs. Real data may violate those assumptions.

        **Validation** checks whether an input meets a contract before using it. The boundary is where data enters your function.

        A wrong type, a missing required field, or an out-of-range number should cause a clear failure rather than an invented result.

        ### Raising an exception

        An **exception** is an error signal that interrupts normal execution. You have already seen names such as `NameError` and `KeyError`.

        `raise ValueError("message")` deliberately signals that an input is unacceptable:

        - `ValueError` is an exception type.
        - The string in parentheses is its explanation. Use a nonempty message that describes the problem.

        > **Key idea:** Raising is not returning. The caller does not receive a normal result. Unless code catches the exception, Python stops and displays the error.

        ## Check types before using operations

        ### Exact types with `type` and `is`

        `type(value)` returns a value's exact Python type. `type(value) is int` accepts an integer, but not a float or a Boolean.

        - `is` compares identity. It is appropriate for exact type objects and `None`, not for ordinary number or text comparisons (use `==` for those).
        - `is not` means the identities differ.
        - `isinstance(value, str)` asks whether `value` is a string, including a specialized subtype of string.
        - Similarly, `list` and `dict` identify list and dictionary values.

        ### Membership with `in` and `not in`

        `in` tests membership and `not in` tests non-membership.

        In `type(value) not in (int, float)`, the parentheses hold a tuple of two accepted type objects, not quoted type names. The condition is true if the exact type is neither `int` nor `float`.

        ### Finite numbers with the `math` module

        The `math` module is part of Python. `import math` makes it available.

        - `math.isfinite(number)` returns `True` for a finite number, and `False` for infinity or NaN ("not a number").
        - `float(value)` converts an accepted number to a float.

        Type checking must happen before operations that assume a number. Range checking can reject huge out-of-range integers before trying to convert them for a floating-point operation.

        ```python
        import math

        def checked_score(value):
            if type(value) not in (int, float):
                raise ValueError("score must be numeric")
            if not 0 <= value <= 1 or not math.isfinite(value):
                raise ValueError("score must be finite and between 0 and 1")
            return float(value)
        ```

        This block only defines a function, so it prints nothing. If you called it:

        - `checked_score(0.5)` would return `0.5`.
        - `checked_score('0.5')` would raise `ValueError` rather than converting the text.

        ### Short-circuit evaluation

        The `or` operator short-circuits: if its left condition is true, Python does not evaluate its right condition. `and` also short-circuits, stopping when its left condition is false.

        This lets validation avoid unsafe operations. For example, check that a value is text before calling a string method on it.

        ### Booleans, infinity, and NaN

        > **Watch out:** `isinstance(True, int)` is `True`, because `bool` is a subtype of `int` in Python. Exact type checks exclude Booleans when measurements are required.

        - Infinity is an unbounded floating-point value.
        - NaN represents an undefined numeric result.
        - Neither is a finite measurement. `float('inf')` and `float('nan')` create them for testing.
        - NaN is not an ordinary ordered number, so do not rely only on a single lower-bound comparison.

        ## Catch an expected failure

        A `try` block contains an operation that may fail. A following `except ValueError as error:` block handles that specific exception and makes it available under the local name `error`.

        - If no exception occurs, the `except` body is skipped.
        - `str(error)` produces the message as text.
        - `bool(text)` is `False` for empty text and `True` for nonempty text.

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

        ```text
        3
        expected a positive integer
        ```

        The program finishes normally because the error is caught.

        In validation exercises, your function should raise the error for the caller to handle. Do not catch your own error and return zero.

        > **Watch out:** Avoid a broad `except Exception`. It also catches unrelated programming errors and can turn broken code into apparently successful output.

        ## Validate formats, not just conversions

        `int(text)` accepts several numeric spellings, so conversion alone does not enforce a strict text format. Instead, work in three steps:

        1. Check the type.
        2. Remove permitted edge whitespace.
        3. Check membership in the allowed strings. For example, `choice in ('A', 'B')` permits just two exact strings.

        A few details matter here:

        - **ASCII digits** are the ordinary characters 0 through 9. Other scripts can have digit characters that look similar but are different text.
        - The Python string escapes `\\t` and `\\n` represent a tab and a line break.
        - `strip` removes these at the edges too, but not inside the value.

        ### JSON failure rules

        JSON parsing also has failure rules. `json.loads` raises `json.JSONDecodeError` for malformed JSON text. That exception is a kind of `ValueError` and already supplies a message.

        Successful parsing does not guarantee the shape you need:

        - JSON `null` becomes `None`.
        - `{}` becomes a dictionary.
        - `[]` becomes a list.

        A valid list can still contain invalid records. Check required dictionary fields and all items, including late ones.

        > **Note:** Extra fields can be ignored only if the contract permits them.

        ## Tests are evidence, not validation code

        An `assert` states an expected property in a test. It is not a substitute for public input validation, because Python can disable assertions.

        Test both successful results and expected exceptions. An exception test should fail if the operation unexpectedly succeeds.

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

        Both checks pass silently, so this prints nothing.

        - The flag `raised` starts `False`.
        - It changes only when the expected error with a nonempty message occurs.

        > **Remember:** Calling the function is essential. Merely defining it does not test it.

        When repairing a function, follow its indentation: a `return` inside a loop ends the call before later records can be checked.

        ### Preserve the failing sequence

        If one valid record works but a longer input fails its contract, keep a valid record followed by the smallest bad record. Checking the bad record alone may miss a problem that depends on its position.

        State the expected failure as precisely as a successful result: which exception type, and whether its message must be nonempty. Receiving a partial total is not the same as rejecting the input. After a focused repair, rerun both the failing sequence and all-valid sequences, then make another valid call to check that the failure left no shared state behind.

        ## Build a small trustworthy tool

        Separate parsing, validation, and aggregation in your reasoning, even when the final function is short.

        Before writing code, decide:

        - what result empty data produces;
        - whether extra keys are accepted;
        - whether the caller's data remains unchanged.

        When a regression appears, first add a minimal failing test, then repair the cause and rerun the suite.

        Your final assessment combines JSON input, complete record validation, and a deterministic summary. No network, external dependencies, or private data are necessary.
        """,
        exercises: [
            exercise("reliability-score", "Validate a confidence value", """
                     Goal:
                     Accept a numeric confidence score only when it fits a strict contract.
                     A confidence score here is a finite number between 0 and 1, not text that happens to look numeric.

                     Starting code:
                     - `def validate_score(value):` is the required function. Keep its name and parameter.
                     - `return 0.0` is a placeholder to replace.
                     - You may add `import math` above the function to use Python's built-in math tools.

                     Your task:
                     1. Keep the function name `validate_score` and its parameter `value`.
                     2. Accept only exact Python `int` or `float` values. Reject Booleans, even though Python treats `bool` as an integer subtype.
                     3. Do not convert strings into accepted scores.
                     4. Accept both endpoints, `0` and `1`. Reject numbers below `0` or above `1`.
                     5. Reject infinity and NaN (not a number). Use `math.isfinite` as explained in the lesson, after checking that numeric operations are appropriate.
                     6. Return each accepted score converted to a `float`, without rounding. Do not modify the input.
                     7. For every rejected input, raise `ValueError` with any nonempty message instead of returning a fallback value.

                     Examples:
                     - `validate_score(0)` returns `0.0`.
                     - `validate_score(1)` returns `1.0` as a float.
                     - `validate_score(0.75)` returns `0.75`.
                     - `True`, `'0.5'`, `None`, `[]`, `-0.01`, `1.01`, NaN, infinities, and an enormous out-of-range integer must all raise `ValueError`.

                     Check:
                     Choose Check solution. It checks accepted values and float output, then invalid types and numeric boundaries; invalid cases must raise `ValueError` with a message, not `TypeError` or `OverflowError`.
                     """,
                     "def validate_score(value):\n    return 0.0\n",
                     "import math\n\ndef validate_score(value):\n    if type(value) not in (int, float):\n        raise ValueError('score must be numeric')\n    if not 0 <= value <= 1 or not math.isfinite(value):\n        raise ValueError('score must be finite and between 0 and 1')\n    return float(value)\n",
                     "assert validate_score(0) == 0.0\nassert type(validate_score(1)) is float\nassert validate_score(0.75) == 0.75\nfor invalid in [True, False, '0.5', None, [], -0.01, 1.01, float('nan'), float('inf'), -float('inf'), 10 ** 400]:\n    raised = False\n    try:\n        validate_score(invalid)\n    except ValueError as error:\n        raised = bool(str(error))\n    assert raised, 'invalid score must raise ValueError with a message'\n",
                     ["Reject unsuitable types before comparing ranges or calling numeric tools. A string method or numeric operation on the wrong type may raise an unintended exception.", "An exact type check distinguishes `bool` from `int`. Check the allowed range before `math.isfinite` so an enormous out-of-range integer cannot cause a float-conversion overflow; then exclude nonfinite values as well.", "Invalid input should interrupt the call with `ValueError` and a nonempty explanation. Only after all checks pass should the accepted number be converted to a float and returned."]),
            exercise("reliability-parse", "Parse an explicit retry setting", """
                     Goal:
                     Read a strict retry setting from text. A **retry** is another attempt after a failure; this setting chooses how many are permitted.
                     **Parsing** means turning the accepted text into a useful value, not actually performing retries.

                     Starting code:
                     - `def parse_retry_count(text):` is the required function. Keep its name and parameter.
                     - `return 0` is a placeholder to replace.
                     - The tests provide both valid and invalid inputs.

                     Your task:
                     1. Keep the function name `parse_retry_count` and its parameter `text`.
                     2. Accept only strings whose content, after removing surrounding whitespace, is exactly one of `'0'`, `'1'`, `'2'`, `'3'`, `'4'`, `'5'`.
                     3. Allow edge spaces, tabs, and line breaks, but do not remove internal characters.
                     4. Return the corresponding integer from `0` through `5`. Leave the original input unchanged.
                     5. For every other input, raise `ValueError` with any nonempty message. Reject non-strings, empty text, signs, decimal points, multiple digits such as `'01'`, and non-ASCII digits (digit characters other than ordinary 0 through 9).
                     6. Validate the allowed text before converting it. `int` alone accepts formats that this contract rejects.

                     Examples:
                     - `parse_retry_count('0')` returns `0`.
                     - `parse_retry_count(' 5 ')` returns `5`.
                     - A tab, then `'3'`, then a line break returns `3`.
                     - `''`, `'6'`, `'-1'`, `'+2'`, `'01'`, `'1.0'`, `'１２'`, `'²'`, the integer `3`, `None`, and `True` all raise `ValueError`.

                     Check:
                     Choose Check solution. It checks accepted edge whitespace, integer output, and rejected spellings and types; a printed error or a fallback zero does not satisfy the error contract.
                     """,
                     "def parse_retry_count(text):\n    return 0\n",
                     "def parse_retry_count(text):\n    if not isinstance(text, str):\n        raise ValueError('retry count must be text')\n    cleaned = text.strip()\n    if cleaned not in ('0', '1', '2', '3', '4', '5'):\n        raise ValueError('retry count must be a digit from 0 to 5')\n    return int(cleaned)\n",
                     "assert parse_retry_count('0') == 0\nassert parse_retry_count(' 5 ') == 5\nassert parse_retry_count('\\t3\\n') == 3\nassert type(parse_retry_count('2')) is int\nfor invalid in ['', ' ', '6', '-1', '+2', '01', '1.0', '１２', '²', 3, None, True]:\n    raised = False\n    try:\n        parse_retry_count(invalid)\n    except ValueError as error:\n        raised = bool(str(error))\n    assert raised, 'invalid retry setting must raise ValueError with a message'\n",
                     ["`int` can accept forms such as signed or multi-digit text, but this setting allows only six exact spellings. Conversion alone cannot enforce the contract.", "Check that the input is text before calling `strip`. Save a cleaned copy so edge whitespace is permitted without changing the caller's original value.", "Membership in a tuple of the six allowed strings can express the format rule. Convert to an integer only after that rule passes; rejected values need `ValueError` rather than a fallback result."]),
            exercise("reliability-summary", "Repair a latency summary", """
                     Goal:
                     Repair a function that summarizes durations. **Latency** is elapsed time; **ms** means milliseconds.
                     Unlike the earlier missing-reading exercise, negative values here are invalid and must cause an error, not be skipped.

                     Starting code:
                     - `def summarize_latencies(values):` contains a deliberately faulty implementation. Keep the function name and parameter; repair the body.
                     - It adds to `total`, but its `return` is inside the loop.
                     - It performs no validation.

                     Your task:
                     1. Accept only a `list` whose every item is an exact Python integer at least zero. Zero is valid.
                     2. Reject Booleans, floats, and other item types. Leave the list unchanged.
                     3. Raise `ValueError` with any nonempty message for an invalid outer input or any invalid item, including an invalid item after valid ones.
                     4. Return a dictionary with exactly these keys: `'count'` (integer number of readings), `'total_ms'` (integer sum), and `'mean_ms'` (numeric arithmetic mean without rounding).
                     5. For an empty list, return `{'count': 0, 'total_ms': 0, 'mean_ms': 0.0}`.
                     6. Make sure the final result accounts for every item, not only the first.

                     Examples:
                     - `summarize_latencies([10, 0, 20])` returns `{'count': 3, 'total_ms': 30, 'mean_ms': 10.0}`.
                     - `summarize_latencies([7])` returns `{'count': 1, 'total_ms': 7, 'mean_ms': 7.0}`.
                     - `None`, `'12'`, the tuple `(1, 2)`, `[1, -1]`, `[1, True]`, and `[1, 2.0]` must raise `ValueError`.

                     Check:
                     Choose Check solution. It checks empty, single, and multiple readings, input preservation, and invalid outer types and later items; return the dictionary rather than printing it.
                     """,
                     "def summarize_latencies(values):\n    total = 0\n    for value in values:\n        total += value\n        return {'count': len(values), 'total_ms': total, 'mean_ms': total / len(values)}\n",
                     "def summarize_latencies(values):\n    if not isinstance(values, list):\n        raise ValueError('latencies must be a list')\n    total = 0\n    for value in values:\n        if type(value) is not int or value < 0:\n            raise ValueError('latencies must be nonnegative integers')\n        total += value\n    count = len(values)\n    return {'count': count, 'total_ms': total, 'mean_ms': total / count if count else 0.0}\n",
                     "assert summarize_latencies([]) == {'count': 0, 'total_ms': 0, 'mean_ms': 0.0}\nvalues = [10, 0, 20]\nassert summarize_latencies(values) == {'count': 3, 'total_ms': 30, 'mean_ms': 10.0}\nassert values == [10, 0, 20]\nassert summarize_latencies([7]) == {'count': 1, 'total_ms': 7, 'mean_ms': 7.0}\nfor invalid in [None, '12', (1, 2), [1, -1], [1, True], [1, 2.0], [1, '2']]:\n    raised = False\n    try:\n        summarize_latencies(invalid)\n    except ValueError as error:\n        raised = bool(str(error))\n    assert raised, 'invalid latencies must raise ValueError with a message'\n",
                     ["`return` ends the function call immediately. In the starter it runs during the first loop visit, so later readings are neither summed nor checked.", "Check that the outer input is a list before looping, then require every item to be an exact nonnegative integer. A valid first item does not make later items valid.", "The final report belongs after all visits. For the mean, an empty list needs its explicit `0.0` result rather than division by its zero length; nonempty input uses the full total and count."]),
            exercise("reliability-debug-later-record", "Reject a bad record after good ones", """
                     Goal:
                     Repair `total_retries(records)` so it totals planned retries only when every record is valid. A retry is an additional attempt; this function only calculates a number and never performs an attempt.

                     Starting code:
                     - Keep the function name and parameter. The attempted implementation already includes validation and aggregation.
                     - `total_retries([{'retries': -1}])` raises `ValueError`, but `total_retries([{'retries': 2}, {'retries': -1}])` unexpectedly returns `1` instead of rejecting the input.
                     - Use that difference as evidence, without assuming all existing checks are effective.

                     Your task:
                     1. Reproduce the two-record failure and keep it as a regression case: the correct outcome is `ValueError`, not a partial or adjusted total.
                     2. Accept a Python list whose every item is a dictionary with a required `retries` field. Ignore extra fields without changing them.
                     3. Require each `retries` value to have exact type `int` and be from `0` through `5`, including both endpoints. Reject Booleans, floats, numeric strings, and other values rather than converting them.
                     4. Raise `ValueError` with any nonempty message for invalid outer input, a non-dictionary item, a missing field, or any invalid retry value, wherever that record occurs.
                     5. Form one hypothesis, make a focused repair, and return the integer sum only when all records pass validation. Empty input returns the integer `0`.
                     6. Preserve the original list and dictionaries on both success and failure. Rerun valid, invalid, boundary, and repeated-call checks; do not catch an error merely to return a fallback number.

                     Expected result:
                     - `total_retries([{'retries': 2}, {'retries': 0}, {'retries': 5}])` returns the integer `7`.
                     - `total_retries([])` returns the integer `0`.
                     - `total_retries([{'retries': 2}, {'retries': -1}])` raises `ValueError` with a nonempty message.
                     - The same error contract applies to `None`, `[{}]`, `[{'retries': True}]`, and a missing or invalid field after any number of valid records.

                     Check:
                     Choose **Check solution**. It checks exact integer totals and both endpoints, then invalid outer types and records in first and later positions. It also checks unchanged data and valid calls after failures. The starter reaches an assertion failure because it accepts a later invalid value.
                     """,
                     "def total_retries(records):\n    if not isinstance(records, list):\n        raise ValueError('records must be a list')\n    for record in records[:1]:\n        if not isinstance(record, dict) or 'retries' not in record:\n            raise ValueError('each record needs retries')\n        retries = record['retries']\n        if type(retries) is not int or not 0 <= retries <= 5:\n            raise ValueError('retries must be an integer from 0 to 5')\n    total = 0\n    for record in records:\n        total += record['retries']\n    return total\n",
                     "def total_retries(records):\n    if not isinstance(records, list):\n        raise ValueError('records must be a list')\n    for record in records:\n        if not isinstance(record, dict) or 'retries' not in record:\n            raise ValueError('each record needs retries')\n        retries = record['retries']\n        if type(retries) is not int or not 0 <= retries <= 5:\n            raise ValueError('retries must be an integer from 0 to 5')\n    total = 0\n    for record in records:\n        total += record['retries']\n    return total\n",
                     "assert total_retries([]) == 0\nassert type(total_retries([])) is int\nrecords = [{'retries': 2}, {'retries': 0, 'tag': 'keep'}, {'retries': 5}, {'retries': 2}]\nassert total_retries(records) == 9\nassert type(total_retries(records)) is int\nassert records == [{'retries': 2}, {'retries': 0, 'tag': 'keep'}, {'retries': 5}, {'retries': 2}]\ninvalid_records = [{'retries': 2}, {'retries': -1, 'tag': 'keep'}]\nraised = False\ntry:\n    total_retries(invalid_records)\nexcept ValueError as error:\n    raised = bool(str(error))\nassert raised, 'a later invalid record must raise ValueError with a message'\nassert invalid_records == [{'retries': 2}, {'retries': -1, 'tag': 'keep'}]\nfor invalid in [None, 'records', {}, ({'retries': 1},)]:\n    raised = False\n    try:\n        total_retries(invalid)\n    except ValueError as error:\n        raised = bool(str(error))\n    assert raised, 'invalid outer input must raise ValueError with a message'\nfor bad_record in [None, [], 1, {}, {'other': 2}, {'retries': -1}, {'retries': 6}, {'retries': True}, {'retries': False}, {'retries': 2.0}, {'retries': '2'}, {'retries': None}, {'retries': float('nan')}, {'retries': float('inf')}]:\n    for prefix in [[], [{'retries': 2}], [{'retries': 0}, {'retries': 5}]]:\n        raised = False\n        try:\n            total_retries(prefix + [bad_record])\n        except ValueError as error:\n            raised = bool(str(error))\n        assert raised, 'every invalid record must raise ValueError with a message'\nassert total_retries([{'retries': 5}]) == 5\nassert total_retries([{'retries': 0}]) == 0\nassert total_retries(records) == 9\nassert total_retries([]) == 0\nassert records == [{'retries': 2}, {'retries': 0, 'tag': 'keep'}, {'retries': 5}, {'retries': 2}]\n",
                     ["Compare the same invalid record alone and after a valid one. What changes about the work performed before the function returns?", "Trace which records reach the validation checks and which reach the summing loop. Every record used in the total needs the same checks first.", "The validation loop currently visits only the slice records[:1]. Visit the complete records list instead, keeping the type, required-field, and range checks before any accepted total is returned. Then rerun the later-record failure and valid-input regressions."],
                     effort: .init(scopeUnits: 2))
        ],
        assessment: exercise("reliability-assessment", "Analyze a synthetic evaluation file", """
                             Goal:
                             Analyze invented model evaluation data and reject invalid input. An **evaluation record** describes one named model and its score.
                             The title says file, but `payload` is supplied text: do not open any file or contact a service.

                             Starting code:
                             - `import json` is supplied.
                             - `def analyze_evaluations(payload):` is the required function. Keep its name and parameter.
                             - `return {}` is a placeholder to replace.
                             - Use only Python's standard library.

                             Your task:
                             1. Accept only a string containing JSON whose top-level value is a list. Leave the supplied input unchanged.
                             2. Require every list item to be an object with both `'model'` and `'score'` fields. Extra object fields are allowed and ignored.
                             3. Require `model` to be a string containing at least one non-whitespace character.
                             4. Require `score` to have exact Python type `int` or `float` (not `bool`), be finite, and lie between `0` and `1` inclusive.
                             5. Raise `ValueError` with a nonempty message for any invalid input, malformed JSON, wrong shape, missing required field, or invalid record. This applies even if earlier records were valid. Do not return a partial summary.
                             6. Return a Python dictionary with exactly four keys: `'count'`, `'passed'`, `'mean_score'`, and `'models'`.
                             7. Set `'count'` to the integer number of records.
                             8. Set `'passed'` to the integer number of records with scores at least `0.8`, including exactly `0.8`.
                             9. Set `'mean_score'` to the unrounded numeric arithmetic mean of all scores.
                             10. Set `'models'` to a list of distinct model-name strings without edge whitespace, sorted in Python's normal ascending string order.
                             11. Preserve name case and internal whitespace. Repeated cleaned names appear only once in `models`, but their records still contribute to all numeric results.
                             12. For an empty array, return `{'count': 0, 'passed': 0, 'mean_score': 0.0, 'models': []}`. Return Python data, not JSON text or printed output.

                             Examples:
                             - For `'[{"model":" orbit ","score":0.8},{"model":"Nova","score":0},{"model":"orbit","score":1,"tag":"synthetic"}]'`, return `{'count': 3, 'passed': 2, 'mean_score': 0.6, 'models': ['Nova', 'orbit']}`.
                             - For `'[{"model":"a","score":0.79}]'`, `passed` is `0`.
                             - `None`, empty text, `'{'`, `'{}'`, `'null'`, `'[1]'`, `'[{}]'`, blank model names, Boolean or string scores, out-of-range scores, NaN, and infinities must raise `ValueError`.

                             Check:
                             Complete the theory questions and written explanation, then choose Submit assessment. It checks valid and empty summaries, exact keys, the passing boundary, unique sorted names, and invalid inputs including a bad record after a valid one; work independently without hints or solutions.
                             """,
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
