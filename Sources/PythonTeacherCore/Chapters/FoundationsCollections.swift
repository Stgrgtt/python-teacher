import Foundation

extension Curriculum {
    static let collections = Chapter(
        id: "collections", title: "6. Collections and JSON", subtitle: "Organize records and exchange structured data", prerequisites: ["functions"],
        lesson: """
        # Choose a structure that fits

        Lists store ordered items and retain duplicates. Sometimes you need something different: values you can look up by name.

        ### Dictionaries

        A **dictionary** stores named entries called **key-value pairs**.

        - Curly braces `{}` create it.
        - A colon separates each key from its value.
        - Commas separate entries.

        For example, `{"name": "Mira", "points": 4}` has two string keys, `name` and `points`. The values can have different types.

        > **Note:** Unlike braces inside f-strings, these braces build a container; they do not insert text.

        ### Records and fields

        A **record** is a group of related information about one item, often represented by a dictionary. A **field** is one named entry in that record.

        - Brackets after a dictionary perform lookup by key, not by numeric position.
        - Assignment to a key adds or replaces that entry.
        - `{}` on its own is an empty dictionary.

        ```python
        record = {"name": "Mira", "points": 4}
        name = record["name"]
        record["points"] = 6
        record["team"] = "blue"
        print(name)
        print(record["points"])
        ```

        ```text
        Mira
        6
        ```

        A key can appear only once in a dictionary: assigning it again replaces its value.

        ### Missing keys

        - Reading a missing key with brackets raises `KeyError`, an error that stops normal execution.
        - `record.get("bonus", 0)` instead returns the value if `bonus` exists, or the supplied default `0` if it does not. It does not add the missing key.
        - Without a default argument, `get` returns `None` for a missing key.

        ## Count repeated categories

        A category label is just text used to group items. A dictionary can remember a count under each label.

        On a label's first appearance, its count starts at zero; later appearances read the accumulated count.

        ```python
        colors = ["blue", "red", "blue"]
        counts = {}
        for color in colors:
            previous = counts.get(color, 0)
            counts[color] = previous + 1
        print(counts)
        ```

        ```text
        {'blue': 2, 'red': 1}
        ```

        - `blue` is mapped to 2 and `red` to 1.
        - The key comes from the variable `color`, not the literal string `'color'`.

        > **Tip:** This is a suitable use of a default, because an unseen category really does start at zero. Do not use defaults to hide missing required input fields.

        ### Looping over a dictionary

        A `for` loop over a dictionary visits its **keys**, one per visit, in the order they were first added. Use each key with brackets to read its value.

        - `counts.keys()` supplies the same keys explicitly.
        - `counts.values()` supplies only the values, which is handy when you need a total but not the labels.

        ```python
        counts = {"red": 1, "blue": 2}
        labels = []
        for color in counts:
            labels.append(color)
            print(color, counts[color])
        total = 0
        for count in counts.values():
            total += count
        print(labels)
        print(total)
        ```

        ```text
        red 1
        blue 2
        ['red', 'blue']
        3
        ```

        The loop variable `color` holds a key such as `'red'`, never the whole entry.

        ## Convert JSON text into Python values

        **JSON** is a text format for exchanging structured information. It is text, not a Python dictionary.

        - A JSON **array** corresponds to a Python list.
        - A JSON **object** corresponds to a Python dictionary.

        A **payload** means the text supplied to an operation, not a filename.

        ### The json module

        A **module** is a collection of useful code. `import json` makes Python's built-in `json` module available under that name.

        - `json.loads(payload)` calls its `loads` function to **parse** (read and convert) JSON text into Python values.
        - `json.dumps(value)` converts Python values back into JSON text.

        No installation, file access, or network request is involved.

        ```python
        import json

        payload = '[{"model": "orbit", "score": 0.8}]'
        records = json.loads(payload)
        counts = {}
        for record in records:
            name = record["model"]
            counts[name] = counts.get(name, 0) + 1
        encoded = json.dumps(counts, sort_keys=True)
        ```

        This block prints nothing; it saves the JSON text `{"orbit": 1}` in `encoded`.

        ### Reading the example

        - The outer single quotes make `payload` a Python string.
        - The double quotes inside belong to JSON, which requires double-quoted object keys and text values.
        - JSON spells Boolean values `true` and `false`, and its no-value marker is `null`. Parsing turns these into Python `True`, `False`, and `None`.
        - The argument `sort_keys=True` is a named option asking `dumps` to output dictionary keys in sorted order.

        The exercises will say whether their result should be Python data or JSON text.

        ### Mutable containers

        Lists and dictionaries are **mutable**: operations can change their contents. If a function receives a list, changing it can surprise its caller.

        > **Remember:** Build a fresh result when the specification promises unchanged input.

        Dictionary equality compares contents, not formatting or insertion order.

        ## Group fixed values in a tuple

        A **tuple** is an ordered group of values written with parentheses and commas, such as `("orbit", 0.8)`.

        Like a list, it uses zero-based indexing and works with `len`. Unlike a list, a tuple is **immutable**: after creating it you cannot replace, add, or remove items.

        - A tuple has no `append`.
        - `pair[0] = "nova"` raises `TypeError`.

        Use a tuple for a small fixed group where each position has a meaning, such as a name followed by a score.

        ```python
        pair = ("orbit", 0.8)
        name = pair[0]
        score = pair[1]
        size = len(pair)
        model, result = pair
        print(name)
        print(score)
        print(size)
        print(model)
        print(result)
        ```

        ```text
        orbit
        0.8
        2
        orbit
        0.8
        ```

        ### Unpacking

        The line `model, result = pair` is **unpacking**: it assigns the first item to `model` and the second to `result` in one step.

        > **Watch out:** The number of names on the left must match the number of items, otherwise Python raises `ValueError`.

        ### Other tuple details

        - A tuple with one item needs a trailing comma: `(5,)`. Without the comma, `(5)` is just the number 5 in parentheses.
        - `in` asks whether a tuple contains a value: `"b" in ("a", "b")` is `True`.

        ### Comparing tuples

        ```python
        print((1, "b") < (2, "a"))
        print((1, "a") < (1, "b"))
        print((2, "a") == (2, "a"))
        ```

        ```text
        True
        True
        True
        ```

        Tuples compare item by item. Python compares the first items, and only if they are equal does it compare the second items, and so on.

        In the first line, 1 is smaller than 2, so the letters are never compared. This ordering rule makes tuples useful for sorting by more than one value.

        ## Sort without changing the input

        - `sorted(items)` returns a new list in ascending (smallest-first) order.
        - `items.sort()` changes the original list and returns `None`, so it is unsuitable when inputs must stay unchanged.

        Text sorts by Python's character ordering, which is case-sensitive, not a language-aware alphabetical rule. Ascending names put `'A'` before `'a'`.

        ### Sorting dictionary keys

        Because a dictionary supplies its keys when visited, `sorted(counts)` returns a new list of the keys in ascending order. `for key in sorted(counts):` visits the entries in a predictable key order, no matter how they were added.

        ```python
        totals = {"orbit": 3, "atlas": 5}
        for model in sorted(totals):
            print(model, totals[model])
        print(sorted(totals))
        ```

        ```text
        atlas 5
        orbit 3
        ['atlas', 'orbit']
        ```

        The dictionary itself is unchanged.

        ### Sorting records with a key function

        For records, tell `sorted` which value to compare by supplying a function with the named argument `key`. Python calls that function once per record.

        - A tuple key supports tie-breaking: compare its first part, then its second part only if the first parts are equal.
        - Negating a numeric value with `-` reverses its numeric order when sorted ascending.

        ```python
        parcels = [{"name": "blue", "weight": 2}, {"name": "amber", "weight": 2}, {"name": "red", "weight": 5}]
        def parcel_order(parcel):
            return (-parcel["weight"], parcel["name"])
        ordered = sorted(parcels, key=parcel_order)
        names = []
        for parcel in ordered:
            names.append(parcel["name"])
        print(names)
        ```

        ```text
        ['red', 'amber', 'blue']
        ```

        The result is largest weight first, then ascending name for the tie.

        - Pass the function name as `key=parcel_order`, without calling it yourself; `sorted` supplies each record.
        - Reading the dictionaries is safe, but changing them would also change the original records.

        ### Short key functions with lambda

        Reference code may use `lambda parcel: (-parcel['weight'], parcel['name'])` instead of a named helper.

        `lambda` creates a small unnamed function in one expression:

        - The parameter goes between `lambda` and the colon.
        - The value it returns goes after the colon.
        - There is no `def`, no name, and no `return` keyword.

        It is most useful exactly here, as a short key argument.

        ```python
        words = ["kiwi", "fig", "banana"]
        by_length = sorted(words, key=lambda word: len(word))
        by_text = sorted(words)
        print(by_length)
        print(by_text)
        print(words)
        ```

        ```text
        ['fig', 'kiwi', 'banana']
        ['banana', 'fig', 'kiwi']
        ['kiwi', 'fig', 'banana']
        ```

        The last line shows the original list is unchanged.

        > **Note:** A lambda is never required. A `def` helper, as in the parcel example, does the same job.

        ## Keep unique names when requested

        A **set** holds distinct values without duplicates.

        - Create an empty one with `set()`, not `{}` (which is a dictionary).
        - `add` inserts a value; adding it again has no effect.
        - `len` counts the distinct values.
        - `in` or `not in` asks whether a value is present.
        - Sets do not promise any order and cannot be indexed. Convert one with `sorted` when you need a predictable ordered list.

        ```python
        teams = set()
        teams.add("blue")
        teams.add("amber")
        teams.add("blue")
        print(len(teams))
        print("blue" in teams)
        print("red" in teams)
        ordered_teams = sorted(teams)
        print(ordered_teams)
        ```

        ```text
        2
        True
        False
        ['amber', 'blue']
        ```

        The second `"blue"` was ignored.

        ### Removing duplicates

        `set(items)` builds a set from a list's items. This removes duplicates in one step but loses the original order.

        To remove duplicates while keeping first-appearance order, remember what you have seen in a set and build a new list with a loop:

        ```python
        labels = ["chat", "embed", "chat", "rank"]
        seen = set()
        unique_in_order = []
        for label in labels:
            if label not in seen:
                seen.add(label)
                unique_in_order.append(label)
        print(unique_in_order)
        print(sorted(set(labels)))
        ```

        ```text
        ['chat', 'embed', 'rank']
        ['chat', 'embed', 'rank']
        ```

        The first line comes from input order, the second from sorting.

        `in` also works with lists, and with dictionaries it checks keys: `"name" in record`.

        > **Watch out:** Use a set only when duplicates should disappear. Several exercises explicitly require retaining them.

        ## Debug the shape

        Before calculating, inspect the structure. Is this JSON text, a list of records, or one dictionary?

        Follow one record through each stage:

        1. parsing
        2. key lookup
        3. aggregation
        4. output

        Test these cases:

        - repeated categories
        - categories missing from your accumulator
        - empty collections
        - ties

        Keep representation errors separate from arithmetic errors. The next chapter adds explicit validation for untrusted shapes and values.

        ### Inspect without changing the evidence

        Keep the failing record small. Compare its keys with the contract: which fields are required, and which are optional? An empty accumulator is different from a record missing required data. Choose a default only when the contract gives that absence a meaning.

        A labeled print can show one record and the result of a lookup. `repr(value)` produces a text representation: quotes make an empty string or edge spaces visible, unlike printing the string directly. It is an observation tool, not a way to parse JSON.

        ```python
        record = {"name": " Mira ", "points": 4}
        print("record:", record)
        print("name:", repr(record["name"]))
        print("optional bonus:", record.get("bonus", 0))
        print("after lookup:", record)
        ```

        ```text
        record: {'name': ' Mira ', 'points': 4}
        name: ' Mira '
        optional bonus: 0
        after lookup: {'name': ' Mira ', 'points': 4}
        ```

        The lookup did not insert a key. After a repair, check both the returned value and the original records, then call the function again with different data. A correct-looking result must not hide unexpected input changes.
        """,
        exercises: [
            exercise("collections-count", "Count synthetic task labels", """
                     Goal:
                     Count how often each task label appears. A **label** is a string used as a category name; its **occurrence count** is how many list items have exactly that text.

                     Starting code:
                     - `def count_labels(labels):` is the required function. Keep this line unchanged.
                     - `return {}` is a placeholder that returns an empty dictionary for every input. Replace it with your work.

                     Your task:
                     1. Keep the function name `count_labels` and its parameter.
                     2. Assume `labels` is a list of strings. Leave that list and all of its text unchanged.
                     3. Build a new dictionary whose keys are the exact labels and whose values are integer occurrence counts. The lesson explains how a dictionary can start an unseen category at zero.
                     4. Merge repeated identical labels into one key with their combined count.
                     5. Treat different case and whitespace as different labels. The empty string `''` is an ordinary label and must be counted.
                     6. Return an empty dictionary for an empty list.
                     7. Compute fresh results on every call, and return the dictionary.

                     Examples:
                     - `count_labels([])` returns `{}`
                     - `count_labels(['chat', 'embed', 'chat'])` returns `{'chat': 2, 'embed': 1}`
                     - `count_labels(['', 'AI', 'ai', '', ' AI'])` returns `{'': 2, 'AI': 1, 'ai': 1, ' AI': 1}`

                     Dictionary key order is not important.

                     Check:
                     Choose **Check solution**. It checks empty and repeated labels, exact text, repeated calls, and unchanged input. Return a dictionary, not printed output or JSON text.
                     """,
                     "def count_labels(labels):\n    return {}\n",
                     "def count_labels(labels):\n    counts = {}\n    for label in labels:\n        counts[label] = counts.get(label, 0) + 1\n    return counts\n",
                     "assert count_labels([]) == {}\nassert count_labels(['chat', 'embed', 'chat']) == {'chat': 2, 'embed': 1}\nlabels = ['', 'AI', 'ai', '', ' AI']\nassert count_labels(labels) == {'': 2, 'AI': 1, 'ai': 1, ' AI': 1}\nassert labels == ['', 'AI', 'ai', '', ' AI']\nassert count_labels(['new']) == {'new': 1}\n",
                     ["Use the actual label text as a dictionary key so identical labels share a count; do not strip or lowercase the input.", "A label not yet seen needs a starting count of zero. Dictionary `get` can return that default without a missing-key error.", "On each visit, read the previous count, increase it by one, and save the new count under the same key. Return the completed dictionary only after all labels have been visited."]),
            exercise("collections-json", "Select models from JSON", """
                     Goal:
                     Select names from invented model evaluation records. A **model** is a named system; its **score** describes one evaluation. A **threshold** is the minimum score required to pass.

                     Starting code:
                     - `import json` makes Python's built-in JSON tools available. Keep it.
                     - `def passing_models(payload, threshold):` is the required function. Keep this line unchanged.
                     - `return []` is its placeholder. Replace it with your work.
                     - `payload` means the supplied JSON text, not a path to a file.

                     Your task:
                     1. Keep the import, the function name `passing_models`, and the parameter order.
                     2. Assume `payload` is valid JSON text containing an array of objects. Each object has a string `'model'` field and a finite numeric `'score'` field, and `threshold` is a finite number. No malformed-input validation is required.
                     3. Read the JSON into Python values before working with its records.
                     4. Collect the model-name strings whose scores are at least `threshold`. Exactly equal scores qualify.
                     5. Keep the records' original order and repeated names. Preserve names exactly, including case and spaces.
                     6. Return a Python list. An empty JSON array must return an empty list. Do not change input data or return JSON text.

                     Examples:
                     - Payload `'[]'` with threshold `0.8` returns `[]`
                     - Payload `'[{"model":"orbit","score":0.8},{"model":"nova","score":0.79},{"model":"orbit","score":1}]'` with threshold `0.8` returns `['orbit', 'orbit']`

                     Check:
                     Choose **Check solution**. It checks empty input, exact-threshold inclusion, excluded scores, order, and repeated names. Return the list; printing is optional.
                     """,
                     "import json\n\ndef passing_models(payload, threshold):\n    return []\n",
                     "import json\n\ndef passing_models(payload, threshold):\n    records = json.loads(payload)\n    names = []\n    for record in records:\n        if record['score'] >= threshold:\n            names.append(record['model'])\n    return names\n",
                     "assert passing_models('[]', 0.8) == []\nassert passing_models('[{\"model\":\"orbit\",\"score\":0.8},{\"model\":\"nova\",\"score\":0.79},{\"model\":\"orbit\",\"score\":1}]', 0.8) == ['orbit', 'orbit']\nassert passing_models('[{\"model\":\"z\",\"score\":0}]', 0) == ['z']\nassert passing_models('[{\"model\":\"z\",\"score\":0}]', 0.1) == []\n",
                     ["`payload` is a string. `json.loads` converts its JSON array into a Python list of record dictionaries; looping over the original string would visit characters instead.", "Within each record, brackets with a string key read that field. Compare the score field with the supplied threshold, including equality.", "Build a new list by appending the model field for each qualifying record. Appending in visit order preserves duplicates and ordering; return the finished list after the loop."]),
            exercise("collections-rank", "Rank synthetic evaluation records", """
                     Goal:
                     Rank invented model evaluation records from best score to worst. Each record is a dictionary describing one named model and its score.

                     Starting code:
                     - `def rank_models(records):` is the required function. Keep this line unchanged.
                     - `return []` is a placeholder. Replace it with your work.
                     - The checker supplies a list of dictionaries, not JSON text.

                     Your task:
                     1. Keep the function name `rank_models` and its parameter.
                     2. Assume each record has a unique string `'model'` and a finite numeric `'score'`. Scores may be negative. Other fields may exist; ignore them.
                     3. Sort the records by descending score (highest first).
                     4. For equal scores, order names ascending using Python's normal case-sensitive string ordering, not a custom lowercase ordering.
                     5. Use the lesson's sort-key concept: a key function returning a tuple can express both ordering rules. An ordinary `def` helper is fine, and `lambda` is optional.
                     6. Build a new list containing only the model-name strings, with a loop over the sorted records. Preserve the exact names.
                     7. Leave the input list and its dictionaries unchanged. Return `[]` for an empty list.

                     Examples:
                     - For `[{'model': 'zeta', 'score': 0.8}, {'model': 'beta', 'score': 0.9}, {'model': 'alpha', 'score': 0.8}]`, return `['beta', 'alpha', 'zeta']`
                     - For `[{'model': 'only', 'score': -1, 'tag': 'demo'}]`, return `['only']`

                     Check:
                     Choose **Check solution**. It checks ordering, equal-score ties, empty input, extra fields, and unchanged records. Return names, not dictionaries or printed text.
                     """,
                     "def rank_models(records):\n    return []\n",
                     "def rank_models(records):\n    ordered = sorted(records, key=lambda record: (-record['score'], record['model']))\n    names = []\n    for record in ordered:\n        names.append(record['model'])\n    return names\n",
                     "assert rank_models([]) == []\nrecords = [{'model': 'zeta', 'score': 0.8}, {'model': 'beta', 'score': 0.9}, {'model': 'alpha', 'score': 0.8}]\nassert rank_models(records) == ['beta', 'alpha', 'zeta']\nassert records == [{'model': 'zeta', 'score': 0.8}, {'model': 'beta', 'score': 0.9}, {'model': 'alpha', 'score': 0.8}]\nassert rank_models([{'model': 'only', 'score': -1, 'tag': 'demo'}]) == ['only']\n",
                     ["The score is the primary ordering rule; the name is consulted only when scores tie. A tuple key compares its parts in that order.", "`sorted` returns a fresh list and can call a helper function for each record via its `key` argument. A lambda is merely a shorter way to write that helper.", "Ascending sorting of negated scores puts larger original scores first. Keep the name part in normal ascending order, then build a separate list of names from the ordered records."]),
            exercise("collections-debug-optional-field", "Diagnose an optional record field", """
                     Goal:
                     Repair a function that calculates one integer point total per record. Each record has required integer `points` and may have integer `bonus`; an absent bonus means zero.

                     Starting code:
                     - Keep `def point_totals(records):` and repair its attempted implementation.
                     - `point_totals([{'points': 3, 'bonus': 2}])` returns `[5]`, but `point_totals([{'points': 3}])` stops with `KeyError` instead of returning `[3]`.
                     - The input is already a Python list of dictionaries, not JSON text. All supplied points and bonuses are nonnegative integers. Required `points` is always present.

                     Your task:
                     1. Reproduce the one-record failure and inspect that record's shape without changing it.
                     2. Compare the contract's required and optional fields and form a hypothesis about the failing operation.
                     3. Repair the function so each result is the record's points plus its bonus, using zero only when the optional bonus is absent.
                     4. Return a new Python list of integer totals in input order. Keep repeated totals and include zero totals.
                     5. Leave the original list and every dictionary unchanged, including any extra fields. Ignore extra fields in the calculation.
                     6. Return `[]` for empty input and compute fresh results on repeated calls. No invalid-input validation is required.

                     Expected result:
                     - `point_totals([{'points': 3}])` returns `[3]`, a list containing an integer.
                     - `point_totals([{'points': 3, 'bonus': 2}, {'points': 0}, {'points': 5, 'bonus': 0}])` returns `[5, 0, 5]`.
                     - `point_totals([])` returns `[]`.
                     - No missing key is added to the input records as a side effect.

                     Check:
                     Choose **Check solution**. The starter's intentional failure is `KeyError`. Checks require returned lists of integers for absent, present, and zero bonuses, preserve records and extra fields, and test empty input and repeated calls.
                     """,
                     "def point_totals(records):\n    totals = []\n    for record in records:\n        totals.append(record['points'] + record['bonus'])\n    return totals\n",
                     "def point_totals(records):\n    totals = []\n    for record in records:\n        totals.append(record['points'] + record.get('bonus', 0))\n    return totals\n",
                     "assert point_totals([{'points': 3}]) == [3]\nassert point_totals([]) == []\nrecords = [{'points': 3, 'bonus': 2}, {'points': 0, 'tag': 'keep'}, {'points': 5, 'bonus': 0}, {'points': 3, 'bonus': 2}]\ntotals = point_totals(records)\nassert type(totals) is list\nassert totals == [5, 0, 5, 5]\nfor total in totals:\n    assert type(total) is int\nassert records == [{'points': 3, 'bonus': 2}, {'points': 0, 'tag': 'keep'}, {'points': 5, 'bonus': 0}, {'points': 3, 'bonus': 2}]\ntotals.append(99)\nassert point_totals([{'points': 1, 'bonus': 4}]) == [5]\nassert point_totals(records) == [5, 0, 5, 5]\nassert point_totals([{'points': 0, 'bonus': 0}]) == [0]\nassert records == [{'points': 3, 'bonus': 2}, {'points': 0, 'tag': 'keep'}, {'points': 5, 'bonus': 0}, {'points': 3, 'bonus': 2}]\n",
                     ["The failing input is a list containing one dictionary. Trace the lookup within that dictionary rather than changing the outer structure or parsing it as JSON.", "Compare the record that succeeds with the one that fails. Which field may be absent according to the contract, and what value should its absence contribute?", "Keep bracket lookup for required points. Read the optional bonus with get and a default of 0, then append the sum to a fresh result list; do not insert a default into the caller's dictionary."],
                     effort: .init(scopeUnits: 2), expectedStarterError: "KeyError")
        ],
        assessment: exercise("collections-assessment", "Aggregate token usage by model", """
                             Goal:
                             Report total text-processing usage for each invented model. **Tokens** are counted units of text. Each record describes some usage by a named model, and the same name can appear in several records.

                             Starting code:
                             - `import json` and `def usage_totals(payload):` are supplied. Keep both lines unchanged.
                             - `return {}` is the placeholder body. Replace it with your work.
                             - `payload` is JSON text, not a file path.

                             Your task:
                             1. Keep the function name `usage_totals` and its parameter.
                             2. Assume the input is valid JSON containing a list of records, each with a string `'model'` field and a nonnegative integer `'tokens'` field. No malformed-input validation is required. Preserve the supplied data.
                             3. Build a Python dictionary mapping each exact model-name string to its integer total tokens across all its records. Repeated names belong to the same total.
                             4. Treat case and whitespace as significant; do not clean or rename models.
                             5. Include names whose total is zero. An empty input array must return `{}`.
                             6. Return the dictionary itself, not JSON text or printed output.

                             Examples:
                             - `usage_totals('[]')` returns `{}`
                             - For `'[{"model":"orbit","tokens":12},{"model":"nova","tokens":0},{"model":"orbit","tokens":8}]'`, return `{'orbit': 20, 'nova': 0}`
                             - For `'[{"model":"A","tokens":1},{"model":"a","tokens":2}]'`, return `{'A': 1, 'a': 2}`

                             Key order is not important.

                             Check:
                             Complete the theory questions and written explanation, then choose **Submit assessment**. It checks empty input, repeated names, zero totals, and case-sensitive grouping. Work independently, without hints or solutions.
                             """,
                             "import json\n\ndef usage_totals(payload):\n    return {}\n",
                             "import json\n\ndef usage_totals(payload):\n    totals = {}\n    for record in json.loads(payload):\n        model = record['model']\n        totals[model] = totals.get(model, 0) + record['tokens']\n    return totals\n",
                             "assert usage_totals('[]') == {}\nassert usage_totals('[{\"model\":\"orbit\",\"tokens\":12},{\"model\":\"nova\",\"tokens\":0},{\"model\":\"orbit\",\"tokens\":8}]') == {'orbit': 20, 'nova': 0}\nassert usage_totals('[{\"model\":\"A\",\"tokens\":1},{\"model\":\"a\",\"tokens\":2}]') == {'A': 1, 'a': 2}\nassert usage_totals('[{\"model\":\"solo\",\"tokens\":0}]') == {'solo': 0}\n",
                             []),
        quiz: [
            question("collections-q1", "What does json.loads return for the text '[1, 2]'?", ["A Python list", "A filename", "Always a dictionary"], 0, "JSON arrays become Python lists; JSON objects become dictionaries."),
            question("collections-q2", "Why use sorted(records) rather than records.sort() in a non-mutating function?", ["sort never works on lists", "sorted returns a new list", "sorted removes duplicates"], 1, "sorted builds a new list; list.sort changes the original and returns None."),
            question("collections-q3", "When is counts.get(label, 0) appropriate?", ["Whenever malformed input should be ignored", "Only when label already exists", "When an unseen label should start at zero"], 2, "The default explicitly models the first occurrence rather than hiding a required missing field.")
        ],
        sectionRoles: ["Debug the shape": .troubleshooting])
}
