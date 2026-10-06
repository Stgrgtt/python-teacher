import Foundation

extension Curriculum {
    static let iteration = Chapter(
        id: "iteration", title: "Iteration patterns", subtitle: "Loop with positions, pairs, and comprehensions",
        track: .corePython, prerequisites: ["reliability"],
        lesson: #"""
        # Loop over pairs of values

        You already know that a `for` loop visits the items of a list one at a time. This chapter teaches shorter, clearer patterns for the loops you write most often: numbering items, walking two lists side by side, building new collections in one line, and asking questions about a whole collection at once.

        Start with **unpacking**. In the collections chapter you saw that a tuple such as `("orbit", 0.9)` can be split into separate names: `name, score = ("orbit", 0.9)` saves `"orbit"` in name and `0.9` in score. The number of names on the left must match the number of values in the tuple. A `for` loop can unpack too. When every item in a list is a tuple, put several names between `for` and `in`, separated by commas. Each visit unpacks the current tuple into those names.

        ```python
        pairs = [("orbit", 0.9), ("nova", 0.7)]
        lines = []
        for name, score in pairs:
            lines.append(f"{name} scored {score}")
        print(lines)
        assert lines == ["orbit scored 0.9", "nova scored 0.7"]
        ```

        This displays `['orbit scored 0.9', 'nova scored 0.7']`. On the first visit name is `"orbit"` and score is `0.9`; on the second visit they are `"nova"` and `0.7`.

        Dictionaries offer the same pattern. The method `.items()` produces the dictionary's entries as (key, value) pairs, in the order the keys were first added. Unpacking them gives you both the key and its value on every visit:

        ```python
        usage = {"orbit": 120, "nova": 80}
        lines = []
        for model, tokens in usage.items():
            lines.append(f"{model}: {tokens}")
        assert lines == ["orbit: 120", "nova: 80"]
        ```

        If the item has a different number of values than the names you wrote, Python raises `ValueError` with a message such as “too many values to unpack” or “not enough values to unpack”.

        ## Number items with enumerate

        Sometimes you need each item's **position** (its index) as well as the item. `enumerate(items)` produces pairs of (position, item). Positions start at 0, just like list indexes. The named argument `start=1` makes the numbering start at 1 instead, which is useful for human-friendly numbered lists. enumerate does not change the list; it only reads it.

        `list(...)` collects every value something produces into a new list, which is a handy way to look at what enumerate gives you:

        ```python
        tasks = ["clean data", "train", "evaluate"]
        assert list(enumerate(tasks)) == [(0, "clean data"), (1, "train"), (2, "evaluate")]
        numbered = []
        for number, task in enumerate(tasks, start=1):
            numbered.append(f"{number}. {task}")
        print(numbered)
        ```

        This displays `['1. clean data', '2. train', '3. evaluate']`. Inside the loop, number holds the position and task holds the item, because each pair is unpacked. A common use is remembering where something happened: the loop below collects the indexes of low scores.

        ```python
        scores = [0.9, 0.3, 0.8, 0.1]
        low_positions = []
        for index, score in enumerate(scores):
            if score < 0.5:
                low_positions.append(index)
        assert low_positions == [1, 3]
        ```

        Writing `for index in range(len(scores))` and then reading `scores[index]` works too, but enumerate says what you mean more directly and avoids indexing mistakes.

        ## Walk two lists side by side with zip

        `zip(first, second)` pairs up items from two lists by position: the first item of each, then the second item of each, and so on. Each pair is a tuple. zip **stops at the end of the shorter list**: leftover items in the longer list are silently ignored.

        ```python
        models = ["orbit", "nova", "pico"]
        scores = [0.91, 0.78]
        pairs = list(zip(models, scores))
        print(pairs)
        assert pairs == [("orbit", 0.91), ("nova", 0.78)]
        lookup = dict(zip(models, scores))
        assert lookup == {"orbit": 0.91, "nova": 0.78}
        ```

        This displays `[('orbit', 0.91), ('nova', 0.78)]`; "pico" has no partner, so it is left out. `dict(...)` turns a sequence of (key, value) pairs into a dictionary.

        You can combine enumerate and zip. enumerate then produces (position, pair) tuples, where the pair itself is a tuple. Use parentheses in the loop to unpack the inner pair: `for position, (model, score) in ...`. The parentheses mirror the shape of the data.

        ```python
        models = ["orbit", "nova"]
        scores = [0.91, 0.78]
        lines = []
        for position, (model, score) in enumerate(zip(models, scores), start=1):
            lines.append(f"{position}. {model}: {score}")
        assert lines == ["1. orbit: 0.91", "2. nova: 0.78"]
        ```

        ## Build collections with comprehensions

        Many loops follow one recipe: start with an empty list, visit each item, and append something. A **list comprehension** writes that recipe in a single expression: `[expression for item in items if condition]`. Read it as “the expression, for each item in items, keeping only the items where the condition is true.” The `if condition` part is optional. A comprehension always builds a new list and leaves the input unchanged.

        ```python
        latencies = [120, 0, 340, 90]
        slow = []
        for value in latencies:
            if value > 100:
                slow.append(value)
        slow_again = [value for value in latencies if value > 100]
        doubled = [value * 2 for value in latencies]
        assert slow == [120, 340]
        assert slow_again == slow
        assert doubled == [240, 0, 680, 180]
        ```

        Both versions of slow produce `[120, 340]`. The comprehension is shorter, but the plain loop is still correct; use whichever you can read confidently.

        Curly braces make two more kinds. A **dictionary comprehension** `{key: value for item in items if condition}` builds a dictionary; a **set comprehension** `{expression for item in items if condition}` builds a set, so duplicates disappear. Remember that `{}` on its own is an empty dictionary, and an empty set is written `set()`. Comprehensions can unpack tuples just like for loops:

        ```python
        runs = [("orbit", 0.91), ("nova", 0.42), ("pico", 0.91)]
        passing = {name: score for name, score in runs if score >= 0.8}
        distinct_scores = {score for name, score in runs}
        passing_scores = {score for name, score in runs if score >= 0.8}
        names = [name for name, score in runs]
        assert passing == {"orbit": 0.91, "pico": 0.91}
        assert distinct_scores == {0.91, 0.42}
        assert passing_scores == {0.91}
        assert names == ["orbit", "nova", "pico"]
        ```

        All three kinds accept the optional filtering `if`: passing_scores keeps only scores of at least 0.8, and because it is a set, the two 0.91 scores become one. The filtering `if` goes at the end. Do not confuse it with the conditional expression from the loops chapter, `a if condition else b`, which chooses a value for every item instead of skipping items. Use comprehensions to build values, not to print things or change other lists.

        ## Ask questions about a whole collection

        `any(values)` returns True if at least one value is true; `all(values)` returns True only if every value is true. Combine them with a comprehension that produces True/False values. With an empty list, `any([])` is False (nothing is true) and `all([])` is True (nothing breaks the rule). Decide whether that empty-case answer matches your specification. Their results are already Booleans, so use them directly, as the decisions chapter recommends: write `assert any(...)` or `assert not any(...)` rather than comparing with `== True` or `== False`.

        ```python
        latencies = [120, 0, 340]
        assert any([value > 300 for value in latencies])
        assert all([value >= 0 for value in latencies])
        assert not any([value > 1000 for value in latencies])
        assert not any([])
        assert all([])
        ```

        `sum(numbers)` adds a list of numbers; `sum([])` is 0. `min(items)` and `max(items)` return the smallest and largest item. Like sorted, they accept a named `key` argument: a function, often a lambda, that Python calls for each item to get the value to compare. Importantly, min and max still return the **whole item**, not the key value. When several items tie, they return the first one. With an empty list they raise `ValueError`, so check for emptiness first.

        ```python
        records = [{"model": "orbit", "score": 0.8}, {"model": "nova", "score": 0.95}, {"model": "pico", "score": 0.95}]
        best = max(records, key=lambda record: record["score"])
        shortest = min(["prompt", "hi", "summary"], key=len)
        high_count = sum([1 for record in records if record["score"] > 0.9])
        assert best == {"model": "nova", "score": 0.95}
        assert shortest == "hi"
        assert high_count == 2
        ```

        best is the nova record because it is the first of the two tied highest scores. Passing `len` as the key compares texts by length. high_count adds a 1 for every record that matches the condition, which counts the matches. To find **where** the largest value is, apply max to enumerate pairs and compare the second part of each pair: `max(enumerate(totals), key=lambda pair: pair[1])` returns a (position, value) tuple, such as `(2, 50)` for `totals = [10, 30, 50, 50]`.

        ## Work with nested lists

        A list can contain other lists. A **nested list** like `grid = [[12, 30, 8], [40, 5, 0]]` behaves like a table: each inner list is a row. `grid[1]` is the second row, `[40, 5, 0]`, and `grid[1][0]` reads the first value of that row, 40. `len(grid)` counts rows, and `len(grid[0])` counts values in the first row. Rows can have different lengths, and a row can even be empty.

        ```python
        grid = [[12, 30, 8], [40, 5, 0]]
        assert grid[1][0] == 40
        row_totals = [sum(row) for row in grid]
        second_column = [row[1] for row in grid]
        every_value = [value for row in grid for value in row]
        zeros = [[0 for column in range(3)] for row in range(2)]
        assert row_totals == [50, 45]
        assert second_column == [30, 5]
        assert every_value == [12, 30, 8, 40, 5, 0]
        assert zeros == [[0, 0, 0], [0, 0, 0]]
        ```

        `every_value` uses two `for` parts. They run in the same order as nested loops: for each row, then for each value in that row. This **flattens** the grid into one list, which is convenient for any, all, sum, min, and max over every reading. The last comprehension builds a fresh two-row, three-column grid; each row is a separate new list.

        Common mistakes and debugging: unpacking with the wrong number of names raises ValueError; zip silently drops extra items, so check lengths yourself when they must match; an empty list makes `all` True and `any` False; min and max raise ValueError for an empty list and return whole items when given a key; and a filtering `if` belongs at the end of a comprehension. When a result surprises you, look at the intermediate values, such as `print(list(zip(models, scores)))` or the flattened list, before changing your logic.
        """#,
        exercises: [
            exercise("iteration-leaderboard", "Number a leaderboard", #"""
                Goal:
                Turn two parallel lists into numbered leaderboard lines. Parallel lists hold related data at the same positions: models[0] belongs with scores[0], and so on.

                Starting code:
                def leaderboard_lines(models, scores): is the required function. return [] is a placeholder that returns an empty list for every input; replace it.

                Your task:
                1. Keep the function name and both parameters. models is a list of strings and scores is a list of numbers. Do not change either list.
                2. Pair each model with the score at the same position, in the given order. Do not sort. If one list is longer, ignore its extra items (zip does this for you).
                3. Number the pairs starting at 1 (enumerate with start=1).
                4. Return a new list of strings, one per pair, in the exact form '<number>. <model>: <score>', using an f-string. An empty list in either parameter returns [].

                Expected result:
                leaderboard_lines(['orbit', 'nova'], [0.91, 0.78]) returns ['1. orbit: 0.91', '2. nova: 0.78'].
                leaderboard_lines(['a', 'b', 'c'], [1, 2]) returns ['1. a: 1', '2. b: 2'].
                leaderboard_lines([], [0.5]) returns [].

                Check:
                Choose Check solution. It checks numbering from 1, exact text, unequal lengths, empty input, and that the inputs stay unchanged. Return the list; printing is optional.
                """#,
                #"""
                def leaderboard_lines(models, scores):
                    return []
                """#,
                #"""
                def leaderboard_lines(models, scores):
                    lines = []
                    for position, (model, score) in enumerate(zip(models, scores), start=1):
                        lines.append(f'{position}. {model}: {score}')
                    return lines
                """#,
                #"""
                models = ['orbit', 'nova']
                scores = [0.91, 0.78]
                assert leaderboard_lines(models, scores) == ['1. orbit: 0.91', '2. nova: 0.78']
                assert models == ['orbit', 'nova'] and scores == [0.91, 0.78]
                assert leaderboard_lines(['a', 'b', 'c'], [1, 2]) == ['1. a: 1', '2. b: 2']
                assert leaderboard_lines(['solo'], [0.5, 0.6]) == ['1. solo: 0.5']
                assert leaderboard_lines([], [0.5]) == []
                assert leaderboard_lines([], []) == []
                """#,
                ["Two things vary on each visit: the position number and a (model, score) pair. Look for the lesson tools that produce each of those.",
                 "zip pairs items from two lists by position and stops at the shorter list. enumerate numbers whatever it is given, and its start=1 argument makes the numbers begin at 1. Decide which call goes inside the other.",
                 "Each visit then supplies a number and a pair. The lesson's combined enumerate and zip example shows how a loop target can unpack an inner pair with parentheses, so that every value you need for the f-string has its own name."],
                effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("iteration-index", "Index prompts with comprehensions", #"""
                Goal:
                Build three summaries of invented prompt sizes. A prompt is text sent to a model; its token count measures its size in text units. Each prompt is described by a (prompt_id, tokens) tuple.

                Starting code:
                def index_prompts(prompts, limit): is the required function. return {} is a placeholder; replace it with your work.

                Your task:
                1. Keep the function name and parameters. prompts is a list of (prompt_id, tokens) tuples: prompt_id is a unique string and tokens is a nonnegative integer. limit is an integer. Do not change the input list.
                2. Build 'long_ids': a list of the prompt_id strings whose tokens are strictly greater than limit, in input order. A count equal to limit is not long.
                3. Build 'tokens_by_id': a dictionary mapping prompt_id to tokens for every prompt with more than 0 tokens. Leave out zero-token prompts.
                4. Build 'distinct_sizes': a set of every distinct token count across all prompts, including 0.
                5. Return a dictionary with exactly those three keys. Build each value with a comprehension (list, dictionary, and set comprehension respectively), unpacking each tuple into two names.

                Expected result:
                index_prompts([('p1', 120), ('p2', 0), ('p3', 45), ('p4', 120)], 100) returns {'long_ids': ['p1', 'p4'], 'tokens_by_id': {'p1': 120, 'p3': 45, 'p4': 120}, 'distinct_sizes': {0, 45, 120}}.
                index_prompts([], 100) returns {'long_ids': [], 'tokens_by_id': {}, 'distinct_sizes': set()}.

                Check:
                Choose Check solution. It checks the three values, the strict limit, zero-token prompts, empty input, and that the input list stays unchanged.
                """#,
                #"""
                def index_prompts(prompts, limit):
                    return {}
                """#,
                #"""
                def index_prompts(prompts, limit):
                    long_ids = [prompt_id for prompt_id, tokens in prompts if tokens > limit]
                    tokens_by_id = {prompt_id: tokens for prompt_id, tokens in prompts if tokens > 0}
                    distinct_sizes = {tokens for prompt_id, tokens in prompts}
                    return {'long_ids': long_ids, 'tokens_by_id': tokens_by_id, 'distinct_sizes': distinct_sizes}
                """#,
                #"""
                prompts = [('p1', 120), ('p2', 0), ('p3', 45), ('p4', 120)]
                result = index_prompts(prompts, 100)
                assert set(result) == {'long_ids', 'tokens_by_id', 'distinct_sizes'}
                assert result['long_ids'] == ['p1', 'p4']
                assert result['tokens_by_id'] == {'p1': 120, 'p3': 45, 'p4': 120}
                assert result['distinct_sizes'] == {0, 45, 120}
                assert prompts == [('p1', 120), ('p2', 0), ('p3', 45), ('p4', 120)]
                assert index_prompts([('edge', 100)], 100) == {'long_ids': [], 'tokens_by_id': {'edge': 100}, 'distinct_sizes': {100}}
                assert index_prompts([('empty', 0)], 0) == {'long_ids': [], 'tokens_by_id': {}, 'distinct_sizes': {0}}
                assert index_prompts([], 100) == {'long_ids': [], 'tokens_by_id': {}, 'distinct_sizes': set()}
                """#,
                ["Each of the three values is a separate small loop-and-collect job. A comprehension can express each one, and each can unpack the tuple as prompt_id, tokens.",
                 "Square brackets build a list, braces with key: value build a dictionary, and braces with a single expression build a set. A filtering if at the end keeps only matching prompts.",
                 "long_ids filters with tokens > limit, tokens_by_id filters with tokens > 0, and distinct_sizes has no filter. Return a dictionary literal containing the three results under the exact key names."],
                effort: .init(difficulty: .similar, scopeUnits: 3)),
            exercise("iteration-grid", "Review a latency grid", #"""
                Goal:
                Summarize a grid of invented response times. Latency is how long a request took, in ms (milliseconds). The grid is a nested list: each inner list is one service's readings.

                Starting code:
                def review_grid(grid, limit): is the required function. return {} is a placeholder; replace it.

                Your task:
                1. Keep the function name and parameters. grid is a list of rows; each row is a list of nonnegative integers. Rows may be empty and grid itself may be empty. limit is an integer. Do not change the grid.
                2. 'row_totals': a list with the sum of each row, in row order. An empty row totals 0.
                3. 'slowest_row': the 0-based index of the row with the largest total. If several rows tie, use the first of them. For an empty grid use None. (The lesson shows how max with a key over enumerate pairs finds a position.)
                4. 'any_over': True if any single reading anywhere in the grid is strictly greater than limit, otherwise False. A reading equal to limit is not over.
                5. 'all_filled': True if every row contains at least one reading, otherwise False. For an empty grid this is True, matching all([]).
                6. Return a dictionary with exactly those four keys.

                Expected result:
                review_grid([[120, 80], [300, 20, 10], []], 250) returns {'row_totals': [200, 330, 0], 'slowest_row': 1, 'any_over': True, 'all_filled': False}.
                review_grid([], 250) returns {'row_totals': [], 'slowest_row': None, 'any_over': False, 'all_filled': True}.

                Check:
                Choose Check solution. It checks totals, tie-breaking, exact-limit readings, empty rows, an empty grid, and that the grid stays unchanged.
                """#,
                #"""
                def review_grid(grid, limit):
                    return {}
                """#,
                #"""
                def review_grid(grid, limit):
                    row_totals = [sum(row) for row in grid]
                    slowest_row = None
                    if row_totals:
                        slowest_row = max(enumerate(row_totals), key=lambda pair: pair[1])[0]
                    readings = [value for row in grid for value in row]
                    any_over = any([value > limit for value in readings])
                    all_filled = all([len(row) > 0 for row in grid])
                    return {'row_totals': row_totals, 'slowest_row': slowest_row, 'any_over': any_over, 'all_filled': all_filled}
                """#,
                #"""
                grid = [[120, 80], [300, 20, 10], []]
                assert review_grid(grid, 250) == {'row_totals': [200, 330, 0], 'slowest_row': 1, 'any_over': True, 'all_filled': False}
                assert grid == [[120, 80], [300, 20, 10], []]
                assert review_grid([[5], [5]], 5) == {'row_totals': [5, 5], 'slowest_row': 0, 'any_over': False, 'all_filled': True}
                assert review_grid([[1, 2], [0, 9, 0]], 8)['any_over'] is True
                assert review_grid([[], []], 0) == {'row_totals': [0, 0], 'slowest_row': 0, 'any_over': False, 'all_filled': False}
                assert review_grid([], 250) == {'row_totals': [], 'slowest_row': None, 'any_over': False, 'all_filled': True}
                """#,
                ["Work row by row for the totals and the filled check, and over every single reading for the limit check. A comprehension can do each job.",
                 "sum handles empty rows. A two-part comprehension (for row in grid for value in row) flattens the grid, and any/all accept lists of True/False values.",
                 "Only call max when there is at least one row total; give it enumerate(row_totals) with a key that compares the second part of each pair, then take the position from the returned pair."],
                effort: .init(difficulty: .harder, scopeUnits: 3))
        ],
        assessment: exercise("iteration-assessment", "Choose the best checkpoint per run", #"""
            Goal:
            Pick the best checkpoint for each invented training run. A run is one training attempt; a checkpoint is a saved version of the model during that run, and each checkpoint has an evaluation score.

            Starting code:
            def best_checkpoints(run_names, score_rows, threshold): is the required function. return {} is a placeholder.

            Your task:
            1. Keep the function name and parameters. run_names is a list of unique strings. score_rows is a nested list: score_rows[i] is the list of checkpoint scores (numbers) for run_names[i], in checkpoint order. Rows may be empty. threshold is a number. Do not change the inputs.
            2. Pair each run name with the row at the same position. If one list is longer, ignore its extra items.
            3. Include a run only if at least one of its scores is greater than or equal to threshold. Runs with no such score, including runs with an empty row, are left out.
            4. For each included run, find its highest score. Checkpoints are numbered from 1 in row order; if the highest score appears more than once, use the earliest checkpoint.
            5. Return a dictionary mapping each included run name to a tuple (checkpoint_number, score). Return {} when no run qualifies.

            Expected result:
            best_checkpoints(['alpha', 'beta', 'gamma'], [[0.6, 0.9, 0.9], [0.4, 0.5], [0.85]], 0.8) returns {'alpha': (2, 0.9), 'gamma': (1, 0.85)}.
            best_checkpoints(['solo'], [[]], 0.5) returns {}.

            Check:
            Complete the theory questions and written explanation, then choose Submit assessment. It checks pairing, the threshold boundary, ties, empty rows, unequal lengths, and unchanged inputs. Work independently without hints or solutions.
            """#,
            #"""
            def best_checkpoints(run_names, score_rows, threshold):
                return {}
            """#,
            #"""
            def best_checkpoint(row):
                return max(enumerate(row, start=1), key=lambda pair: pair[1])

            def best_checkpoints(run_names, score_rows, threshold):
                return {name: best_checkpoint(row) for name, row in zip(run_names, score_rows) if any([score >= threshold for score in row])}
            """#,
            #"""
            names = ['alpha', 'beta', 'gamma']
            rows = [[0.6, 0.9, 0.9], [0.4, 0.5], [0.85]]
            assert best_checkpoints(names, rows, 0.8) == {'alpha': (2, 0.9), 'gamma': (1, 0.85)}
            assert names == ['alpha', 'beta', 'gamma'] and rows == [[0.6, 0.9, 0.9], [0.4, 0.5], [0.85]]
            assert best_checkpoints(['edge'], [[0.2, 0.8, 0.1]], 0.8) == {'edge': (2, 0.8)}
            assert best_checkpoints(['solo'], [[]], 0.5) == {}
            assert best_checkpoints(['a', 'b'], [[1, 3, 2]], 0) == {'a': (2, 3)}
            assert best_checkpoints(['a'], [[0.1], [0.9]], 0.5) == {}
            assert best_checkpoints([], [], 0.5) == {}
            """#,
            [],
            effort: .init(difficulty: .harder, scopeUnits: 4)),
        quiz: [
            question("iteration-q1", "What does list(zip(['a', 'b', 'c'], [1, 2])) produce?", ["[('a', 1), ('b', 2)]", "[('a', 1), ('b', 2), ('c', None)]", "A ValueError because the lengths differ"], 0, "zip pairs items by position and stops at the end of the shorter input; the extra 'c' is ignored."),
            question("iteration-q2", "What does all([]) return?", ["False", "True", "It raises ValueError"], 1, "all is True when no value breaks the rule, and an empty list contains no false values. any([]) is False."),
            question("iteration-q3", "What does max(records, key=lambda r: r['score']) return?", ["The largest score number", "The index of the best record", "The whole record with the largest score"], 2, "The key only decides how items are compared; min and max return the item itself, the first one on ties.")
        ])

    static let files = Chapter(
        id: "files", title: "Files, modules, and dates", subtitle: "Read and write data that outlives a single run",
        track: .corePython, prerequisites: ["iteration"],
        lesson: #"""
        # Bring in tools with import

        Until now your data has lived only in variables, which disappear when the program ends. This chapter saves and reads files, works with dates, and organizes a file so it can be run as a program. All of these use tools from Python's **standard library**: modules that come with Python, so nothing needs to be installed.

        A **module** is a file of ready-made Python code. You met `import json` and `import math`. There are three common forms of import:

        - `import math` makes the module available under its name; you write `math.sqrt(16)` with the module name and a dot.
        - `from math import floor` copies one name out of the module, so you can call `floor(2.7)` directly.
        - `import json as js` gives the module a shorter local nickname, called an **alias**; you then write `js.dumps(...)`. The `as` part also works with from: `from math import floor as round_down`.

        ```python
        import math
        from math import floor
        import json as js

        assert math.sqrt(16) == 4.0
        assert floor(2.7) == 2
        text = js.dumps({"tokens": 3})
        print(text)
        assert text == '{"tokens": 3}'
        ```

        This displays `{"tokens": 3}`. Put imports at the top of your file. After `import json as js`, the name `json` is not defined: only the alias is. Avoid naming your own variables after modules you use, such as `csv = 3`, because that replaces the module name.

        ## Point at files with pathlib

        A **path** is the text that locates a file, such as `notes.txt` or `reports/week1.txt`. A **relative path** is interpreted starting from the program's current folder, called the working directory. In this app every run gets its own fresh, empty, temporary working folder, so the files you create are yours alone and vanish afterwards. Always use relative paths in exercises.

        The `pathlib` module provides `Path`, an object that represents a path and has useful methods. The `/` operator joins path parts, which is clearer than gluing text with `+`. Useful parts: `.name` is the final part, `.suffix` is the extension such as `.txt`, `.stem` is the name without its suffix, and `.parent` is the containing folder. These four are **attributes**: values stored on the Path that you read without parentheses, so write `report.name`, not `report.name()`. `.exists()` and `.mkdir()` are methods, operations you call with parentheses: `.exists()` returns True if something is at that path, and `.mkdir(exist_ok=True)` creates a folder and does nothing if it already exists. `str(value)` turns most values, including a Path, into text; the example uses it to compare the path with a string.

        ```python
        from pathlib import Path

        folder = Path("reports")
        folder.mkdir(exist_ok=True)
        report = folder / "week1.txt"
        assert str(report) == "reports/week1.txt"
        assert report.name == "week1.txt"
        assert report.suffix == ".txt"
        assert report.stem == "week1"
        assert report.parent == folder
        assert folder.exists()
        assert not report.exists()
        print(report)
        ```

        This displays reports/week1.txt. Creating a Path object does not create a file: report does not exist until something writes to it. Functions that open files accept either a plain string or a Path.

        ## Open files safely with with

        `open(path, mode, encoding="utf-8")` connects your program to a file and returns a **file object**. The **mode** says what you intend to do:

        - `"r"` reads an existing file. It is the default if you leave the mode out. A missing file raises `FileNotFoundError`.
        - `"w"` writes. It creates the file, or **erases** an existing file first.
        - `"a"` appends: it adds to the end of the file, creating it if needed.

        Files store bytes, not letters. An **encoding** is the rule for turning text into bytes and back. UTF-8 is the standard encoding and can store any character, including accents and emoji. Always pass `encoding="utf-8"` so your file reads back the same on every computer.

        The `with` statement opens a file for an indented block and closes it automatically when the block ends, even if an error happens. `file.write(text)` adds text and does not add a line break for you, so include `"\n"` yourself. `file.read()` returns the whole file as one string. A `for` loop over a file visits one line at a time; each line still ends with `"\n"`, and `line.rstrip("\n")` returns a copy without that line break at its end.

        ```python
        from pathlib import Path

        path = Path("notes.txt")
        with open(path, "w", encoding="utf-8") as file:
            file.write("first note\n")
            file.write("café visit\n")
        with open(path, "a", encoding="utf-8") as file:
            file.write("third note\n")
        lines = []
        with open(path, encoding="utf-8") as file:
            for line in file:
                lines.append(line.rstrip("\n"))
        print(lines)
        assert lines == ["first note", "café visit", "third note"]
        ```

        This displays `['first note', 'café visit', 'third note']`. The second `with` used `"a"`, so the earlier lines survived. `FileNotFoundError` is an exception, just like ValueError, so you can catch it with try/except when a missing file has a sensible meaning in your specification:

        ```python
        try:
            with open("missing.txt", encoding="utf-8") as file:
                text = file.read()
        except FileNotFoundError:
            text = ""
        assert text == ""
        ```

        Checking `Path("missing.txt").exists()` first is another way to make the same decision.

        ## Read and write CSV tables

        **CSV** (comma-separated values) is a plain-text table format: each line is a row, and commas separate its fields. The first line is often a **header** naming the columns. Fields that contain a comma are wrapped in double quotes, which is why you should let the `csv` module read and write rows rather than splitting text yourself. Open CSV files with the extra argument `newline=""`; the csv module then handles line endings itself.

        - `csv.reader(file)` produces each row as a list of strings.
        - `csv.DictReader(file)` uses the header row as keys and produces each later row as a dictionary.
        - `csv.DictWriter(file, fieldnames=[...])` writes dictionaries. `writer.writeheader()` writes the header line, `writer.writerow(record)` writes one dictionary, and `writer.writerows(records)` writes a list of them. Numbers are converted to text automatically.

        ```python
        import csv

        with open("runs.csv", "w", encoding="utf-8", newline="") as file:
            writer = csv.DictWriter(file, fieldnames=["model", "tokens"])
            writer.writeheader()
            writer.writerow({"model": "orbit", "tokens": 120})
            writer.writerows([{"model": "nova", "tokens": 80}, {"model": "pico, mini", "tokens": 5}])

        with open("runs.csv", encoding="utf-8", newline="") as file:
            rows = list(csv.reader(file))
        print(rows)
        assert rows[3] == ["pico, mini", "5"]

        with open("runs.csv", encoding="utf-8", newline="") as file:
            records = list(csv.DictReader(file))
        total = sum([int(record["tokens"]) for record in records])
        assert records[0] == {"model": "orbit", "tokens": "120"}
        assert total == 205
        ```

        The print displays `[['model', 'tokens'], ['orbit', '120'], ['nova', '80'], ['pico, mini', '5']]`. Notice two things. First, every value read from a CSV file is a **string**, even `'120'`; convert with `int(...)` or `float(...)` before doing arithmetic. Second, the comma inside "pico, mini" survived because the csv module quoted it. Read the rows (here with `list(...)`) inside the with block; once the file is closed it cannot be read. A plain `for row in csv.reader(file):` loop inside the block works too, and can unpack each row, as in `for model, tokens in csv.reader(file):` for a file whose rows have exactly two fields.

        ## Work with dates and durations

        Comparing or adding dates as text is error-prone: months have different lengths and leap years add February 29. The `datetime` module provides `date`, a calendar day, and `timedelta`, a length of time.

        - `date(2024, 2, 27)` creates a date from year, month, and day. An impossible date such as `date(2023, 2, 29)` raises ValueError.
        - `date.fromisoformat("2024-03-15")` converts ISO-format text (year-month-day with dashes) into a date, and `day.isoformat()` turns a date back into that text.
        - `timedelta(days=3)` is a duration of three days; `timedelta(weeks=1)` is seven days. Adding a timedelta to a date gives a new date.
        - Subtracting two dates gives a timedelta; its `.days` attribute, read without parentheses like a Path's `.name`, is the whole number of days between them, negative if the second date is later. Dates compare with `<`, `<=`, and `==`.

        ```python
        from datetime import date, timedelta

        start = date(2024, 2, 27)
        later = start + timedelta(days=3)
        print(later.isoformat())
        deadline = date.fromisoformat("2024-03-15")
        gap = deadline - start
        print(gap.days)
        assert later == date(2024, 3, 1)
        assert later < deadline
        assert (start - deadline).days == -17
        ```

        This displays 2024-03-01, then 17. Because 2024 is a leap year, three days after February 27 passes February 28 and 29. `date.today()` returns the current day, but its value changes every day, so exercises use fixed dates instead.

        You can also import the whole module under a short alias, as in the imports section. After `import datetime as dt`, write the module alias first: `dt.date(...)`, `dt.date.fromisoformat(...)`, and `dt.timedelta(...)`. The names `date` and `timedelta` on their own are then not defined.

        ```python
        import datetime as dt

        start = dt.date(2024, 2, 27)
        deadline = dt.date.fromisoformat("2024-03-15")
        later = start + dt.timedelta(days=3)
        print(later.isoformat())
        assert later == dt.date(2024, 3, 1)
        assert (deadline - start).days == 17
        ```

        This displays 2024-03-01, exactly like the first example. Only the way of naming the tools changed.

        ## Run a file as a script

        Python sets a special variable, `__name__`, in every file. When you run a file directly, its `__name__` is the text `"__main__"`. When another file imports it as a module, `__name__` is the module's name instead. The guard `if __name__ == "__main__":` therefore means “only do this when the file is run as the main program”. Put reusable definitions above it and the code that actually starts the work inside it, often a call to a function named main. Then other files can import your functions without triggering that work.

        ```python
        def greeting(name):
            return f"Hello, {name}"

        def main():
            message = greeting("Mira")
            print(message)
            return message

        if __name__ == "__main__":
            result = main()
            assert result == "Hello, Mira"
        ```

        This displays Hello, Mira. In this app, Run, Check solution, and Submit assessment all execute your file as the main program, so the guarded block runs and the checks can read any names it saves.

        Common mistakes and debugging: `"w"` erases an existing file, so use `"a"` to add to it; write needs explicit `"\n"` line breaks, and lines you read still contain them; forgetting `encoding="utf-8"` can break accented text; CSV values are strings until you convert them; reading after the with block fails because the file is closed; and a `FileNotFoundError` usually means a misspelled name or a file that has not been written yet. When stuck, check `Path(name).exists()` and print what you read before processing it.
        """#,
        exercises: [
            exercise("files-notes", "Keep a notes file", #"""
                Goal:
                Save, extend, and reload a small text file of notes, one note per line.

                Starting code:
                from pathlib import Path is supplied (the checks also pass Path objects). Three functions are supplied with placeholder bodies: save_lines returns 0, append_line returns None without writing, and load_lines returns []. Replace each body; keep the names and parameters.

                Your task:
                1. save_lines(path, lines): path is a string or Path; lines is a list of strings without line breaks. Open the file in write mode with encoding='utf-8', replacing any earlier contents, and write each line followed by '\n'. Return the integer number of lines written. An empty list still creates an empty file and returns 0.
                2. append_line(path, line): open the file in append mode with encoding='utf-8' and add line followed by '\n' at the end. Create the file if it does not exist. It needs no return value.
                3. load_lines(path): read the file with encoding='utf-8' and return a list of its lines in order, with the '\n' at the end of each line removed. Keep empty lines as ''. If the file does not exist, return [] instead of letting FileNotFoundError stop the program.

                Expected result:
                After save_lines('notes.txt', ['first', 'café visit']) returns 2, the file contains exactly 'first\ncafé visit\n' and load_lines('notes.txt') returns ['first', 'café visit']. After append_line('notes.txt', 'third'), load_lines returns ['first', 'café visit', 'third']. load_lines('missing.txt') returns [].

                Check:
                Choose Check solution. It checks exact file contents, overwriting, appending, accented text, empty lines, Path arguments, and a missing file. Files are written in the temporary run folder.
                """#,
                #"""
                from pathlib import Path

                def save_lines(path, lines):
                    return 0

                def append_line(path, line):
                    return None

                def load_lines(path):
                    return []
                """#,
                #"""
                from pathlib import Path

                def save_lines(path, lines):
                    with open(path, 'w', encoding='utf-8') as file:
                        for line in lines:
                            file.write(line + '\n')
                    return len(lines)

                def append_line(path, line):
                    with open(path, 'a', encoding='utf-8') as file:
                        file.write(line + '\n')

                def load_lines(path):
                    try:
                        with open(path, encoding='utf-8') as file:
                            return [line.rstrip('\n') for line in file]
                    except FileNotFoundError:
                        return []
                """#,
                #"""
                from pathlib import Path
                assert save_lines('notes.txt', ['first', 'café visit']) == 2
                with open('notes.txt', encoding='utf-8') as check_file:
                    assert check_file.read() == 'first\ncafé visit\n'
                assert load_lines('notes.txt') == ['first', 'café visit']
                append_line(Path('notes.txt'), 'third')
                assert load_lines(Path('notes.txt')) == ['first', 'café visit', 'third']
                assert save_lines('notes.txt', ['fresh']) == 1
                assert load_lines('notes.txt') == ['fresh']
                assert save_lines(Path('gaps.txt'), ['a', '', 'b']) == 3
                assert load_lines('gaps.txt') == ['a', '', 'b']
                assert save_lines('empty.txt', []) == 0
                assert Path('empty.txt').exists() and load_lines('empty.txt') == []
                assert load_lines('missing.txt') == []
                append_line('new.txt', 'only')
                assert load_lines('new.txt') == ['only']
                """#,
                ["Each function opens the file once inside a with block; what differs is the mode: 'w' to replace, 'a' to add, and the default read mode to load.",
                 "write does not add line breaks, so add '\\n' after every line. When reading, each visited line still ends with '\\n', which rstrip('\\n') removes.",
                 "Wrap the reading with block in try and catch FileNotFoundError to return []. For save_lines, the number of lines written is simply the length of the list."],
                effort: .init(difficulty: .similar, scopeUnits: 3)),
            exercise("files-csv", "Filter an evaluation CSV", #"""
                Goal:
                Read invented model evaluation scores from a CSV file and write the passing ones to a new CSV file.

                Starting code:
                import csv is supplied. read_scores(path) returns [] and write_passing(path, records, threshold) returns 0 as placeholders. Replace both bodies; keep the names and parameters.

                Your task:
                1. read_scores(path): open the file with encoding='utf-8' and newline=''. The first row is a header that includes the columns model and score; there may be extra columns, which you ignore. Use csv.DictReader.
                2. Return a list with one dictionary per data row, in file order, with exactly the keys 'model' (the text unchanged) and 'score' (converted to a float). A file with only a header returns [].
                3. write_passing(path, records, threshold): records is a list of dictionaries with 'model' and 'score' keys, like read_scores returns. Open path in write mode with encoding='utf-8' and newline=''. Use csv.DictWriter with fieldnames ['model', 'score'], write the header, then one row for each record whose score is at least threshold (equal counts), in the original order.
                4. Return the integer number of data rows written. When no record passes, the file contains just the header and the result is 0. Let the csv module handle quoting: a model name may contain a comma.

                Expected result:
                For a file containing 'model,score,notes', 'orbit,0.91,first', 'nova,0.8,tie', 'pico,0.42,' on separate lines, read_scores returns [{'model': 'orbit', 'score': 0.91}, {'model': 'nova', 'score': 0.8}, {'model': 'pico', 'score': 0.42}]. write_passing('passing.csv', those_records, 0.8) returns 2, and reading passing.csv with csv.reader gives [['model', 'score'], ['orbit', '0.91'], ['nova', '0.8']].

                Check:
                Choose Check solution. It writes test CSV files, then checks float conversion, ignored extra columns, the threshold boundary, header-only files, and a model name containing a comma.
                """#,
                #"""
                import csv

                def read_scores(path):
                    return []

                def write_passing(path, records, threshold):
                    return 0
                """#,
                #"""
                import csv

                def read_scores(path):
                    with open(path, encoding='utf-8', newline='') as file:
                        return [{'model': row['model'], 'score': float(row['score'])} for row in csv.DictReader(file)]

                def write_passing(path, records, threshold):
                    passing = [record for record in records if record['score'] >= threshold]
                    with open(path, 'w', encoding='utf-8', newline='') as file:
                        writer = csv.DictWriter(file, fieldnames=['model', 'score'])
                        writer.writeheader()
                        writer.writerows(passing)
                    return len(passing)
                """#,
                #"""
                import csv
                with open('evals.csv', 'w', encoding='utf-8', newline='') as source:
                    source.write('model,score,notes\norbit,0.91,first\nnova,0.8,tie\npico,0.42,\n')
                records = read_scores('evals.csv')
                assert records == [{'model': 'orbit', 'score': 0.91}, {'model': 'nova', 'score': 0.8}, {'model': 'pico', 'score': 0.42}]
                assert type(records[0]['score']) is float
                assert write_passing('passing.csv', records, 0.8) == 2
                with open('passing.csv', encoding='utf-8', newline='') as result:
                    assert list(csv.reader(result)) == [['model', 'score'], ['orbit', '0.91'], ['nova', '0.8']]
                assert read_scores('passing.csv') == [{'model': 'orbit', 'score': 0.91}, {'model': 'nova', 'score': 0.8}]
                assert write_passing('none.csv', records, 0.95) == 0
                with open('none.csv', encoding='utf-8', newline='') as result:
                    assert list(csv.reader(result)) == [['model', 'score']]
                with open('header.csv', 'w', encoding='utf-8', newline='') as source:
                    source.write('score,model\n')
                assert read_scores('header.csv') == []
                assert write_passing('comma.csv', [{'model': 'mini, v2', 'score': 1.0}], 0.5) == 1
                assert read_scores('comma.csv') == [{'model': 'mini, v2', 'score': 1.0}]
                """#,
                ["DictReader turns each data row into a dictionary keyed by the header, but every value is a string. Build a new dictionary with just the two keys you need.",
                 "float(row['score']) converts the score text. For writing, first choose the passing records, then let a DictWriter with the two fieldnames write the header and the rows.",
                 "Inside a with block opened in 'w' mode with newline='', call writeheader once and writerow for each passing record (or writerows for the whole filtered list), then return how many you wrote."],
                effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("files-dates", "Plan dataset refresh dates", #"""
                Goal:
                Plan when an invented dataset is refreshed and measure gaps between dates, then run a preview only when the file is the main program.

                Starting code:
                import datetime as dt is supplied: use the alias, as in dt.date and dt.timedelta. refresh_schedule returns [] and days_between returns 0 as placeholders. At the bottom, an if __name__ == '__main__': guard contains the placeholder preview = [].

                Your task:
                1. Keep the import, the function names, and their parameters.
                2. refresh_schedule(start_text, every_days, count): start_text is an ISO date string such as '2024-02-27'; every_days is a positive integer; count is a nonnegative integer. Return a list of count ISO date strings: the first is the start date and each next one is every_days later. count 0 returns []. Use real calendar arithmetic, so month ends and February 29 in leap years are handled.
                3. days_between(start_text, end_text): return the integer number of days from the start date to the end date. It is negative when the end is earlier and 0 for the same day.
                4. Inside the guard, replace the placeholder so preview is the result of refresh_schedule('2024-02-27', 2, 3). Keep that line indented inside the guard.

                Expected result:
                preview is ['2024-02-27', '2024-02-29', '2024-03-02'].
                refresh_schedule('2023-12-30', 1, 3) returns ['2023-12-30', '2023-12-31', '2024-01-01'].
                days_between('2024-02-01', '2024-03-01') returns 29, and days_between('2024-03-01', '2024-02-01') returns -29.

                Check:
                Choose Check solution. Your file runs as the main program, so the guarded preview is created; then the checks test year and month boundaries, leap years, count 0, negative gaps, and integer results.
                """#,
                #"""
                import datetime as dt

                def refresh_schedule(start_text, every_days, count):
                    return []

                def days_between(start_text, end_text):
                    return 0

                if __name__ == '__main__':
                    preview = []
                """#,
                #"""
                import datetime as dt

                def refresh_schedule(start_text, every_days, count):
                    start = dt.date.fromisoformat(start_text)
                    return [(start + dt.timedelta(days=every_days * step)).isoformat() for step in range(count)]

                def days_between(start_text, end_text):
                    return (dt.date.fromisoformat(end_text) - dt.date.fromisoformat(start_text)).days

                if __name__ == '__main__':
                    preview = refresh_schedule('2024-02-27', 2, 3)
                """#,
                #"""
                assert preview == ['2024-02-27', '2024-02-29', '2024-03-02']
                assert refresh_schedule('2023-12-30', 1, 3) == ['2023-12-30', '2023-12-31', '2024-01-01']
                assert refresh_schedule('2023-02-27', 2, 2) == ['2023-02-27', '2023-03-01']
                assert refresh_schedule('2024-05-01', 7, 0) == []
                assert refresh_schedule('2024-05-01', 7, 1) == ['2024-05-01']
                assert days_between('2024-02-01', '2024-03-01') == 29
                assert days_between('2023-02-01', '2023-03-01') == 28
                assert days_between('2024-03-01', '2024-02-01') == -29
                assert days_between('2024-03-01', '2024-03-01') == 0
                assert type(days_between('2024-01-01', '2024-01-02')) is int
                """#,
                ["Convert text to dates first, do the calendar arithmetic with dates and timedeltas, and convert back to text only for the result.",
                 "With the alias, dt.date.fromisoformat reads ISO text and dt.timedelta(days=...) is a duration. The k-th date (counting from 0) is the start plus every_days * k days; range(count) supplies k.",
                 "Subtracting one date from another gives a timedelta whose .days is the integer gap. In the guard, assign preview to the call with the exact arguments given."],
                effort: .init(difficulty: .harder, scopeUnits: 3))
        ],
        assessment: exercise("files-assessment", "Summarize a weekly token log", #"""
            Goal:
            Read an invented token-usage log from a CSV file, total one week's usage per model, and write the summary as a new CSV file. Tokens are counted units of text processed by a model.

            Starting code:
            import csv, from datetime import date, timedelta, and from pathlib import Path are supplied. def weekly_totals(source, target, week_start): returns 0 as a placeholder. Keep the imports, name, and parameters.

            Your task:
            1. source and target are relative paths (strings). week_start is an ISO date string. If no file exists at source, return 0 immediately and do not create the target file.
            2. Read source with encoding='utf-8' and newline=''. It has no header row: every row has exactly three fields, an ISO date, a model name, and a nonnegative integer token count written as text. Model names may contain commas, so use csv.reader rather than splitting lines yourself.
            3. Include only rows whose date is on or after week_start and before week_start plus 7 days (the 7-day week starting on week_start). Add up the token counts for each model as integers.
            4. Write target with encoding='utf-8' and newline='' using csv.DictWriter with fieldnames ['model', 'tokens']: the header, then one row per model that had at least one included row, ordered by model name using Python's normal ascending string order. A model whose included rows total 0 still appears.
            5. Return the integer number of model rows written. If the week has no rows, write just the header and return 0.

            Expected result:
            For a log with rows 2024-02-26,orbit,100 / 2024-02-27,"mini, v2",3 / 2024-02-29,nova,40 / 2024-03-03,orbit,5 / 2024-03-04,orbit,999 / 2024-02-25,nova,7 / 2024-03-01,nova,0, calling weekly_totals('usage.csv', 'week.csv', '2024-02-26') returns 3, and week.csv read with csv.reader is [['model', 'tokens'], ['mini, v2', '3'], ['nova', '40'], ['orbit', '105']].

            Check:
            Complete the theory questions and written explanation, then choose Submit assessment. It writes test logs, then checks week boundaries, sorting, quoted names, zero totals, an empty week, and a missing source file. Work independently without hints or solutions.
            """#,
            #"""
            import csv
            from datetime import date, timedelta
            from pathlib import Path

            def weekly_totals(source, target, week_start):
                return 0
            """#,
            #"""
            import csv
            from datetime import date, timedelta
            from pathlib import Path

            def weekly_totals(source, target, week_start):
                if not Path(source).exists():
                    return 0
                start = date.fromisoformat(week_start)
                end = start + timedelta(days=7)
                totals = {}
                with open(source, encoding='utf-8', newline='') as file:
                    for day_text, model, tokens in csv.reader(file):
                        if start <= date.fromisoformat(day_text) < end:
                            totals[model] = totals.get(model, 0) + int(tokens)
                with open(target, 'w', encoding='utf-8', newline='') as file:
                    writer = csv.DictWriter(file, fieldnames=['model', 'tokens'])
                    writer.writeheader()
                    for model in sorted(totals):
                        writer.writerow({'model': model, 'tokens': totals[model]})
                return len(totals)
            """#,
            #"""
            import csv
            from pathlib import Path
            with open('usage.csv', 'w', encoding='utf-8', newline='') as log:
                log.write('2024-02-26,orbit,100\n2024-02-27,"mini, v2",3\n2024-02-29,nova,40\n2024-03-03,orbit,5\n2024-03-04,orbit,999\n2024-02-25,nova,7\n2024-03-01,nova,0\n')
            assert weekly_totals('usage.csv', 'week.csv', '2024-02-26') == 3
            with open('week.csv', encoding='utf-8', newline='') as summary:
                assert list(csv.reader(summary)) == [['model', 'tokens'], ['mini, v2', '3'], ['nova', '40'], ['orbit', '105']]
            assert weekly_totals('usage.csv', 'late.csv', '2024-03-01') == 2
            with open('late.csv', encoding='utf-8', newline='') as summary:
                assert list(csv.reader(summary)) == [['model', 'tokens'], ['nova', '0'], ['orbit', '1004']]
            assert weekly_totals('usage.csv', 'quiet.csv', '2024-01-01') == 0
            with open('quiet.csv', encoding='utf-8', newline='') as summary:
                assert list(csv.reader(summary)) == [['model', 'tokens']]
            assert weekly_totals('absent.csv', 'unused.csv', '2024-02-26') == 0
            assert not Path('unused.csv').exists()
            """#,
            [],
            effort: .init(difficulty: .harder, scopeUnits: 4)),
        quiz: [
            question("files-q1", "What happens to an existing file opened with open(path, 'w', encoding='utf-8')?", ["Its old contents are erased before writing", "New text is added after the old contents", "Python raises FileNotFoundError"], 0, "Write mode creates or truncates the file; append mode 'a' keeps existing contents and adds to the end."),
            question("files-q2", "A CSV row has tokens 120. What is row['tokens'] when read with csv.DictReader?", ["The integer 120", "The string '120'", "The float 120.0"], 1, "The csv module reads every field as text; convert with int or float before arithmetic."),
            question("files-q3", "When is the body of if __name__ == '__main__': skipped?", ["Whenever the file defines functions", "When the file is run directly", "When the file is imported by another file as a module"], 2, "An imported module's __name__ is its module name, so only direct runs execute the guarded code.")
        ],
        generationNotes: "Pass file paths into functions as parameters instead of hard-coding them. Each run starts in a fresh folder that holds only a tmp directory, so top-level reference code must not read a file it did not create first, and tests must never list or count the folder's contents. In test code, create every input file with a relative name, encoding='utf-8' and, for CSV, newline='' before calling the learner's functions. Verify written files by reopening them the same way and comparing exact text or csv.reader rows, not only return values. Test a missing file only with a name the tests never create. Use plain relative names in the current folder; do not use tempfile, absolute paths or os.chdir. Use fixed dates instead of date.today().")
}
