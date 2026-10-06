import Foundation

extension Curriculum {
    static let dsAggregation = Chapter(
        id: "ds-aggregation", title: "Aggregating, joining and reporting tables", subtitle: "Count, group, join, pivot and format summaries with the standard library",
        track: .dataScience, prerequisites: ["ds-statistics", "classes"],
        lesson: """
        # Turn rows into summaries

        Cleaned data is usually a **table**: a list of rows, where each row is a dictionary with the same field names. Statistics describe one column. Most real questions, though, are about categories: *Which label appears most often? What is the mean latency for each model? How many tokens did each team use per day?* Answering them means **aggregating**: collapsing many rows into one summary value per category.

        This chapter builds those summaries with Python's standard library only. Later, the pandas library automates the same ideas: `value_counts` counts categories, `groupby` groups rows, `merge` joins tables, `pivot_table` builds pivot summaries, and `nlargest` picks the top rows. Knowing how to do each step by hand makes those tools far less mysterious. All data here is invented.

        ## Count categories with Counter and pick the top n

        The `collections` module (part of Python, nothing to install) contains specialised containers. Despite the similar name, it has nothing to do with the earlier chapter called "Collections and JSON" beyond the word itself: that chapter taught built-in containers such as lists and dictionaries, while `collections` is a separate standard-library module you must import before use. `from collections import Counter` makes its **Counter** available. `Counter(items)` visits every item of a list and builds a dictionary-like object mapping each distinct item to how many times it appears. Reading a missing key from a Counter gives 0 instead of a KeyError. `counts.most_common(n)` returns a list of the n most frequent `(item, count)` tuples, largest count first.

        ```python
        from collections import Counter

        labels = ["chat", "embed", "chat", "vision", "chat", "embed"]
        counts = Counter(labels)
        print(counts)
        print(counts["chat"])
        print(counts["audio"])
        print(counts.most_common(2))
        assert counts["embed"] == 2
        ```

        This prints `Counter({'chat': 3, 'embed': 2, 'vision': 1})`, then `3`, then `0` (audio never appeared), then `[('chat', 3), ('embed', 2)]`. A Counter can also grow one item at a time: `counts[label] += 1` works even for a brand-new label, because the missing count starts at 0. A Counter compares equal to an ordinary dictionary with the same contents.

        A **top-n** list means the n categories with the largest values. `most_common` settles ties by the order items were first seen, which depends on input order. When a task needs a predictable tie rule, sort the counter's pairs yourself. `counts.items()` gives every `(key, value)` pair. As in the collections chapter, `sorted` with a `key` function and a tuple key gives a primary and a secondary rule; negating the count puts large counts first. A slice `[:n]` then keeps at most the first n items (and simply returns everything when fewer exist; `[:0]` is empty).

        ```python
        from collections import Counter

        counts = Counter(["nova", "orbit", "atlas", "orbit", "nova", "zest"])
        ranked = sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))
        top_two = ranked[:2]
        print(top_two)
        assert top_two == [("nova", 2), ("orbit", 2)]
        assert ranked[:10] == [("nova", 2), ("orbit", 2), ("atlas", 1), ("zest", 1)]
        ```

        This prints `[('nova', 2), ('orbit', 2)]`. In the lambda, `pair[1]` is the count and `pair[0]` is the label, so equal counts fall back to ascending label order.

        ## Group rows with defaultdict

        **Group-by** means: split rows into groups that share a key value, then compute one summary per group. A **defaultdict** is a dictionary that creates a starting value the first time a missing key is used. `defaultdict(list)` starts each new key with an empty list; `defaultdict(int)` starts each new key with 0 (calling `int()` returns 0). You pass the type itself, without parentheses after it.

        ```python
        from collections import defaultdict
        from statistics import mean

        rows = [
            {"model": "orbit", "ms": 120},
            {"model": "nova", "ms": 95},
            {"model": "orbit", "ms": 140},
        ]
        groups = defaultdict(list)
        for row in rows:
            groups[row["model"]].append(row["ms"])
        print(dict(groups))
        means = {}
        for model, values in groups.items():
            means[model] = mean(values)
        print(means)
        assert means == {"orbit": 130, "nova": 95}
        ```

        This prints `{'orbit': [120, 140], 'nova': [95]}`, then `{'orbit': 130, 'nova': 95}`. Step one collects each group's values; step two applies any statistic you already know (`mean`, `median`, `len`, `sum`) to each list. `dict(groups)` copies a defaultdict into an ordinary dictionary, which prints more simply and stops creating keys by accident. When you only need a running total, `totals = defaultdict(int)` followed by `totals[key] += amount` skips the list entirely.

        Be careful: merely *reading* `groups["missing"]` on a defaultdict inserts that key with an empty starting value. Use `.get(key)` or `key in groups` when you only want to look.

        ## Group by several keys and build a pivot summary

        Sometimes a group is defined by two fields together, such as model *and* day. Tuples can be dictionary keys because they cannot change, so `(row["model"], row["day"])` works as one combined key. This is **multi-key grouping**. In a `for` loop, `(model, day), total` unpacks each item's tuple key and its value in one step.

        ```python
        from collections import defaultdict

        rows = [
            {"model": "orbit", "day": "mon", "tokens": 1200},
            {"model": "orbit", "day": "tue", "tokens": 800},
            {"model": "nova", "day": "mon", "tokens": 500},
            {"model": "orbit", "day": "mon", "tokens": 300},
        ]
        totals = defaultdict(int)
        for row in rows:
            key = (row["model"], row["day"])
            totals[key] += row["tokens"]
        print(dict(totals))
        for (model, day), total in sorted(totals.items()):
            print(model, day, total)
        assert totals[("orbit", "mon")] == 1500
        ```

        The first print shows `{('orbit', 'mon'): 1500, ('orbit', 'tue'): 800, ('nova', 'mon'): 500}`. The loop prints `nova mon 500`, `orbit mon 1500` and `orbit tue 800`, because tuples sort by their first part, then their second.

        A **pivot summary** (or pivot table) rearranges such results into a grid: one row per value of the first key, one column per value of the second key, and the aggregate in each cell. In plain Python it is a dictionary of dictionaries. A combination with no rows still needs a cell, usually filled with 0, so every row has the same columns. A set comprehension such as `{row["day"] for row in rows}` collects each distinct value once; sorting it gives stable column order.

        ```python
        rows = [
            {"model": "orbit", "day": "mon", "tokens": 1500},
            {"model": "orbit", "day": "tue", "tokens": 800},
            {"model": "nova", "day": "mon", "tokens": 500},
        ]
        models = sorted({row["model"] for row in rows})
        days = sorted({row["day"] for row in rows})
        pivot = {}
        for model in models:
            pivot[model] = {}
            for day in days:
                pivot[model][day] = 0
        for row in rows:
            pivot[row["model"]][row["day"]] += row["tokens"]
        print(pivot)
        assert pivot["nova"]["tue"] == 0
        ```

        This prints `{'nova': {'mon': 500, 'tue': 0}, 'orbit': {'mon': 1500, 'tue': 800}}`. First every cell is created with 0, then each row adds to its own cell. pandas calls this `pivot_table(..., fill_value=0)`.

        ## Join two tables by key

        Information is often split across tables: runs record a `model_id`, while a separate model table records each model's name. **Joining** combines rows from two tables whose **key** field matches. An **inner join** keeps only rows that found a match. A **left join** keeps every row of the first (left) table and fills in a marker such as None or `'unassigned'` when no match exists. Rows without a partner are called **unmatched rows**; reporting them is how you notice typos and missing reference data.

        The efficient technique is an **index**: first build a dictionary from key to row for the lookup table, then visit the main table once and look each key up. `.get(key)` returns None when the key is absent, and `.get(key, default)` returns your chosen default instead.

        ```python
        runs = [
            {"run_id": "r1", "model_id": "m1", "tokens": 900},
            {"run_id": "r2", "model_id": "m9", "tokens": 400},
            {"run_id": "r3", "model_id": "m2", "tokens": 650},
        ]
        models = [
            {"model_id": "m1", "name": "orbit"},
            {"model_id": "m2", "name": "nova"},
            {"model_id": "m3", "name": "atlas"},
        ]
        by_id = {}
        for model in models:
            by_id[model["model_id"]] = model
        joined = []
        for run in runs:
            match = by_id.get(run["model_id"])
            if match is None:
                name = None
            else:
                name = match["name"]
            joined.append({"run_id": run["run_id"], "name": name, "tokens": run["tokens"]})
        print(joined)
        used = {run["model_id"] for run in runs}
        unused = sorted(set(by_id) - used)
        print(unused)
        assert joined[1]["name"] is None
        assert unused == ["m3"]
        ```

        The joined list keeps all three runs in their original order; run r2 has name None because m9 is not in the model table, so this is a left join. Skipping rows whose match is None would make it an inner join. `set(by_id)` is the set of index keys, and `-` between two sets gives the items in the first set but not the second, so `unused` lists models no run referred to: `['m3']`. This pattern assumes each key appears at most once in the lookup table; a repeated key would overwrite the earlier entry. pandas calls this `merge(..., how="left")`.

        ## Dataclass records and formatted reports

        Dictionaries with string keys are easy to mistype. For summary rows with a fixed shape, a dataclass (from the classes chapter) gives named fields, a readable repr, and field-by-field `==` comparison. `from dataclasses import dataclass` makes the decorator available; each annotated line inside the class becomes a field, and calling the class with values in field order creates a record.

        Reports then turn numbers into aligned text. Inside an f-string, a **format spec** after a colon controls how a value is shown: `{value:.2f}` shows exactly two decimal places, `{value:,}` adds thousands separators, `{text:>8}` right-aligns in a column 8 characters wide, and `{text:<8}` left-aligns (pads on the right). Specs combine in this order: alignment, width, comma, precision, as in `{value:>10,.2f}`. A value longer than its width is not cut off; the column just grows. Formatting produces text and never changes the number itself. To keep a *number* with two decimals, use `round(value, 2)`; for example `round(130.456, 2)` gives `130.46`.

        ```python
        from dataclasses import dataclass

        @dataclass
        class ModelTotal:
            model: str
            tokens: int
            mean_ms: float

        print(f"{3.14159:.2f}", f"{1234567:,}", f"[{'ab':>5}]", f"[{'ab':<5}]")
        rows = [ModelTotal("orbit", 1234567, 130.456), ModelTotal("nova", 980, 95.0)]
        for row in rows:
            print(f"{row.model:<8}|{row.tokens:>10,}|{row.mean_ms:>8.2f}")
        line = f"{rows[0].model:<8}|{rows[0].tokens:>10,}|{rows[0].mean_ms:>8.2f}"
        assert line == "orbit   | 1,234,567|  130.46"
        assert ModelTotal("nova", 980, 95.0) == rows[1]
        assert round(130.456, 2) == 130.46
        ```

        The first line prints `3.14 1,234,567 [   ab] [ab   ]`. The report lines are `orbit   | 1,234,567|  130.46` and `nova    |       980|   95.00`: names padded to 8 characters, token counts right-aligned in 10 with commas, and means right-aligned in 8 with two decimals.

        ## Common mistakes and debugging

        - **Forgetting unmatched rows.** After a join, count how many rows found no match. A silent inner join can drop data you meant to keep.
        - **Unpredictable ties.** `most_common` and set iteration do not give a tie rule you control. Sort with an explicit tuple key.
        - **Accidental keys.** Reading a missing key on a defaultdict inserts it. Use `.get` to look without changing anything.
        - **Ragged pivots.** If some cells are missing, rows have different columns. Create every cell first, then fill it.
        - **Exact float comparisons.** Means such as `0.1 + 0.2` are not exactly `0.3`; round results when the task says to, and compare with a tolerance like `abs(a - b) < 1e-9` in tests.
        - **Format specs on the wrong type.** `:,` and `:.2f` need numbers; applying `:.2f` to the text `'3.5'` raises ValueError. Convert first.

        To debug, print one intermediate structure at a time: the counter, the groups, the index dictionary, then the final rows. Check an empty table, a single row, a key that appears only on one side of a join, and a tie.
        """,
        exercises: [
            exercise("ds-aggregation-top-labels", "Rank the most frequent labels", """
            Goal:
            Find the most common labels in an invented list of task labels and return the top n, with a predictable rule for ties. A top-n list holds the n categories with the largest counts.

            Starting code:
            from collections import Counter is supplied. def top_labels(labels, n): is the required function. return [] is a placeholder: replace that line with your own body.

            Your task:
            1. Keep the import, the function name and both parameters. labels is a list of strings; n is a nonnegative integer. Leave the labels list unchanged.
            2. Count how often each exact label appears (case and spaces matter). Counter is the intended tool.
            3. Return a list of (label, count) tuples ordered by count from largest to smallest. When counts are equal, order those labels in Python's normal ascending string order.
            4. Return at most n tuples. If there are fewer distinct labels than n, return them all. n equal to 0 returns []. An empty labels list returns [].

            Expected result:
            For labels ['chat', 'embed', 'chat', 'vision', 'embed', 'chat', 'audio']:
            top_labels(labels, 2) returns [('chat', 3), ('embed', 2)].
            top_labels(labels, 10) returns [('chat', 3), ('embed', 2), ('audio', 1), ('vision', 1)].
            top_labels(['b', 'a', 'B', 'a', 'b'], 2) returns [('a', 2), ('b', 2)].

            Check:
            Choose Check solution. It checks empty input, ties, n larger than the number of labels, n equal to 0, case-sensitive labels and unchanged input. Return the list of tuples; printing is optional.
            """,
                     """
                     from collections import Counter

                     def top_labels(labels, n):
                         return []
                     """,
                     """
                     from collections import Counter

                     def top_labels(labels, n):
                         counts = Counter(labels)
                         ranked = sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))
                         return ranked[:n]
                     """,
                     """
                     assert top_labels([], 3) == []
                     labels = ['chat', 'embed', 'chat', 'vision', 'embed', 'chat', 'audio']
                     assert top_labels(labels, 2) == [('chat', 3), ('embed', 2)]
                     assert labels == ['chat', 'embed', 'chat', 'vision', 'embed', 'chat', 'audio']
                     assert top_labels(labels, 10) == [('chat', 3), ('embed', 2), ('audio', 1), ('vision', 1)]
                     assert top_labels(['b', 'a', 'B', 'a', 'b'], 2) == [('a', 2), ('b', 2)]
                     assert top_labels(['solo'], 0) == []
                     assert top_labels(['x', 'x'], 1) == [('x', 2)]
                     """,
                     ["Two separate jobs: first count every label, then order and trim the counted pairs. Counter does the first job in one call.", "most_common breaks ties by first appearance, not by name. Sort the counter's (label, count) pairs yourself with a tuple key: count first, label second.", "Negating the count in the key makes larger counts come first while labels still sort ascending; a slice up to n then keeps at most n pairs."],
                     effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("ds-aggregation-pivot", "Pivot token usage by model and day", """
            Goal:
            Summarise invented token-usage rows in two shapes: totals grouped by the pair (model, day), and a pivot summary with one row per model and one column per day. Tokens are counted units of text.

            Starting code:
            from collections import defaultdict is supplied. def pair_totals(rows): and def token_pivot(rows): both currently return {} as placeholders. Replace each placeholder body.

            Your task:
            1. Keep both function names and parameters. rows is a list of dictionaries, each with a string 'model', a string 'day' and a nonnegative integer 'tokens'. Do not change the list or its dictionaries.
            2. pair_totals(rows) returns a dictionary whose keys are (model, day) tuples and whose values are the total tokens of all rows with that model and day. Every pair that appears in any row has a key, even if its total is 0. A defaultdict(int) is a suitable accumulator; returning it directly or as dict(...) are both fine.
            3. token_pivot(rows) returns a dictionary mapping each model to an inner dictionary that maps each day to that pair's total. Every model must have a cell for every day that appears anywhere in rows; fill pairs that never appear with 0. You may call pair_totals inside token_pivot.
            4. An empty rows list returns {} from both functions. Key order is not important.

            Expected result:
            For rows [{'model': 'orbit', 'day': 'mon', 'tokens': 1200}, {'model': 'nova', 'day': 'tue', 'tokens': 500}, {'model': 'orbit', 'day': 'mon', 'tokens': 300}, {'model': 'orbit', 'day': 'tue', 'tokens': 0}]:
            pair_totals(rows) returns {('orbit', 'mon'): 1500, ('nova', 'tue'): 500, ('orbit', 'tue'): 0}.
            token_pivot(rows) returns {'orbit': {'mon': 1500, 'tue': 0}, 'nova': {'mon': 0, 'tue': 500}}.

            Check:
            Choose Check solution. It checks empty input, repeated pairs, zero totals, missing cells filled with 0, a single row and unchanged input. Return dictionaries, not printed tables.
            """,
                     """
                     from collections import defaultdict

                     def pair_totals(rows):
                         return {}

                     def token_pivot(rows):
                         return {}
                     """,
                     """
                     from collections import defaultdict

                     def pair_totals(rows):
                         totals = defaultdict(int)
                         for row in rows:
                             totals[(row['model'], row['day'])] += row['tokens']
                         return dict(totals)

                     def token_pivot(rows):
                         models = sorted({row['model'] for row in rows})
                         days = sorted({row['day'] for row in rows})
                         totals = pair_totals(rows)
                         pivot = {}
                         for model in models:
                             pivot[model] = {}
                             for day in days:
                                 pivot[model][day] = totals.get((model, day), 0)
                         return pivot
                     """,
                     """
                     rows = [
                         {'model': 'orbit', 'day': 'mon', 'tokens': 1200},
                         {'model': 'nova', 'day': 'tue', 'tokens': 500},
                         {'model': 'orbit', 'day': 'mon', 'tokens': 300},
                         {'model': 'orbit', 'day': 'tue', 'tokens': 0},
                     ]
                     assert pair_totals([]) == {}
                     assert pair_totals(rows) == {('orbit', 'mon'): 1500, ('nova', 'tue'): 500, ('orbit', 'tue'): 0}
                     assert token_pivot([]) == {}
                     assert token_pivot(rows) == {'orbit': {'mon': 1500, 'tue': 0}, 'nova': {'mon': 0, 'tue': 500}}
                     assert rows[0] == {'model': 'orbit', 'day': 'mon', 'tokens': 1200} and len(rows) == 4
                     assert token_pivot([{'model': 'a', 'day': 'sun', 'tokens': 7}]) == {'a': {'sun': 7}}
                     assert pair_totals([{'model': 'a', 'day': 'x', 'tokens': 2}, {'model': 'x', 'day': 'a', 'tokens': 3}]) == {('a', 'x'): 2, ('x', 'a'): 3}
                     """,
                     ["A tuple of model and day can be a single dictionary key, so each pair gets its own running total.", "With defaultdict(int), adding to a key that does not exist yet starts from 0, so a zero-token row still creates its pair. For the pivot, first collect the distinct models and the distinct days.", "Build the pivot cell by cell: for each model and each day, look up the pair total with .get and a default of 0, so missing combinations still get a cell."],
                     effort: .init(difficulty: .similar, scopeUnits: 3)),
            exercise("ds-aggregation-join", "Join runs to owning teams", """
            Goal:
            Combine two invented tables with a left join and format each joined record as a fixed-width report line. The runs table records which model each run used; the owners table records which team owns each model.

            Starting code:
            The supplied @dataclass UsageLine has the fields run_id (str), team (str) and tokens (int); keep it unchanged. def join_usage(runs, owners): returns [] and def usage_label(line): returns '' as placeholders. Replace both bodies.

            Your task:
            1. runs is a list of dictionaries with string 'run_id', string 'model' and nonnegative integer 'tokens'. owners is a list of dictionaries with string 'model' and string 'team'; each model appears at most once in owners. Do not change either list.
            2. join_usage(runs, owners) returns a list with one UsageLine per run, in the same order as runs. team is the team that owns the run's model. A run whose model has no owner is an unmatched row: keep it, with team 'unassigned'. Owners that no run uses are ignored. Empty runs returns [].
            3. usage_label(line) returns one string built from a UsageLine: run_id left-aligned in width 6, then team right-aligned in width 10, then tokens right-aligned in width 9 with thousands separators, then a space and, in parentheses, tokens divided by 1000 with exactly two decimals followed by k. In f-string terms: run_id with :<6, team with :>10, tokens with :>9, and tokens / 1000 with :.2f.

            Expected result:
            For runs [{'run_id': 'r1', 'model': 'orbit', 'tokens': 12500}, {'run_id': 'r2', 'model': 'ghost', 'tokens': 40}] and owners [{'model': 'orbit', 'team': 'vision'}, {'model': 'atlas', 'team': 'audio'}], join_usage returns [UsageLine('r1', 'vision', 12500), UsageLine('r2', 'unassigned', 40)].
            usage_label(UsageLine('r1', 'vision', 12500)) returns 'r1        vision   12,500 (12.50k)'.
            usage_label(UsageLine('r2', 'unassigned', 40)) returns 'r2    unassigned       40 (0.04k)'.

            Check:
            Choose Check solution. It checks empty runs, an empty owners table, unmatched runs, run order, unused owners, exact label text including long numbers, and unchanged inputs.
            """,
                     """
                     from dataclasses import dataclass

                     @dataclass
                     class UsageLine:
                         run_id: str
                         team: str
                         tokens: int

                     def join_usage(runs, owners):
                         return []

                     def usage_label(line):
                         return ''
                     """,
                     """
                     from dataclasses import dataclass

                     @dataclass
                     class UsageLine:
                         run_id: str
                         team: str
                         tokens: int

                     def join_usage(runs, owners):
                         team_by_model = {}
                         for owner in owners:
                             team_by_model[owner['model']] = owner['team']
                         lines = []
                         for run in runs:
                             team = team_by_model.get(run['model'], 'unassigned')
                             lines.append(UsageLine(run['run_id'], team, run['tokens']))
                         return lines

                     def usage_label(line):
                         return f"{line.run_id:<6}{line.team:>10}{line.tokens:>9,} ({line.tokens / 1000:.2f}k)"
                     """,
                     """
                     runs = [
                         {'run_id': 'r1', 'model': 'orbit', 'tokens': 12500},
                         {'run_id': 'r2', 'model': 'ghost', 'tokens': 40},
                         {'run_id': 'r3', 'model': 'nova', 'tokens': 1234567},
                     ]
                     owners = [{'model': 'nova', 'team': 'search'}, {'model': 'orbit', 'team': 'vision'}, {'model': 'atlas', 'team': 'audio'}]
                     assert join_usage([], owners) == []
                     lines = join_usage(runs, owners)
                     assert lines == [UsageLine('r1', 'vision', 12500), UsageLine('r2', 'unassigned', 40), UsageLine('r3', 'search', 1234567)]
                     assert len(runs) == 3 and len(owners) == 3 and runs[0] == {'run_id': 'r1', 'model': 'orbit', 'tokens': 12500}
                     assert join_usage(runs[:1], []) == [UsageLine('r1', 'unassigned', 12500)]
                     assert usage_label(UsageLine('r1', 'vision', 12500)) == 'r1        vision   12,500 (12.50k)'
                     assert usage_label(UsageLine('r3', 'search', 1234567)) == 'r3        search1,234,567 (1234.57k)'
                     assert usage_label(UsageLine('r2', 'unassigned', 40)) == 'r2    unassigned       40 (0.04k)'
                     """,
                     ["Looking through the whole owners list for every run works but is slow and fiddly. Build an index dictionary from model to team once, then visit runs once.", "The index's .get method accepts a default, which is exactly what an unmatched run needs. Create each record by calling UsageLine with run_id, team and tokens in field order.", "For the label, put each field in its own pair of braces with a format spec after a colon: alignment and width for text, width plus a comma for tokens, and .2f for the thousands value inside the parentheses."],
                     effort: .init(difficulty: .harder, scopeUnits: 3))
        ],
        assessment: exercise("ds-aggregation-assessment", "Report mean scores by provider", """
        Goal:
        Build a ranked provider report from two invented tables. The evaluations table holds one score per evaluation run of a model; the models table says which provider (company) supplies each model. You will join the tables, group by provider, keep the top n, and format report lines.

        Starting code:
        from collections import defaultdict and from dataclasses import dataclass are supplied. The @dataclass ProviderSummary has the fields provider (str), runs (int) and mean_score (float); keep it unchanged. def summarize_providers(evaluations, models, n): returns [] and def report_line(summary): returns '' as placeholders. Replace both bodies.

        Your task:
        1. evaluations is a list of dictionaries with string 'model' and numeric 'score'. models is a list of dictionaries with string 'model' and string 'provider'; each model appears at most once. n is a nonnegative integer. Do not change the inputs.
        2. Join each evaluation to its provider by model. An evaluation whose model is not in models is unmatched: count it under the provider 'unknown'. Providers with no evaluations do not appear in the result.
        3. For each provider, create one ProviderSummary with runs equal to its number of evaluations and mean_score equal to the arithmetic mean of its scores rounded with round(value, 2).
        4. Order the summaries by mean_score from highest to lowest (using the rounded value); for equal mean_score order by provider in ascending string order. Return a list of at most n summaries. Empty evaluations or n equal to 0 returns [].
        5. report_line(summary) returns provider left-aligned in width 10, then runs right-aligned in width 6 with thousands separators, then mean_score right-aligned in width 8 with exactly two decimals.

        Expected result:
        With models [{'model': 'orbit', 'provider': 'acme'}, {'model': 'nova', 'provider': 'zenith'}, {'model': 'atlas', 'provider': 'acme'}] and evaluations with scores orbit 0.9, nova 0.7, atlas 0.6, ghost 0.75 and nova 0.8, summarize_providers(evaluations, models, 3) returns summaries for acme (2 runs, 0.75), unknown (1 run, 0.75) and zenith (2 runs, 0.75), in that order because the means tie.
        report_line(ProviderSummary('acme', 2, 0.75)) returns 'acme           2    0.75'.
        report_line(ProviderSummary('unknown', 12345, 0.5)) returns 'unknown   12,345    0.50'.

        Check:
        Complete the theory questions and written explanation, then choose Submit assessment. It checks empty input, unmatched models, unused providers, rounding, ties, ordering, the n limit and exact report text. Means are compared with a small tolerance. Work independently without hints or solutions.
        """,
                                 """
                                 from collections import defaultdict
                                 from dataclasses import dataclass

                                 @dataclass
                                 class ProviderSummary:
                                     provider: str
                                     runs: int
                                     mean_score: float

                                 def summarize_providers(evaluations, models, n):
                                     return []

                                 def report_line(summary):
                                     return ''
                                 """,
                                 """
                                 from collections import defaultdict
                                 from dataclasses import dataclass

                                 @dataclass
                                 class ProviderSummary:
                                     provider: str
                                     runs: int
                                     mean_score: float

                                 def summarize_providers(evaluations, models, n):
                                     provider_by_model = {}
                                     for model in models:
                                         provider_by_model[model['model']] = model['provider']
                                     scores = defaultdict(list)
                                     for row in evaluations:
                                         provider = provider_by_model.get(row['model'], 'unknown')
                                         scores[provider].append(row['score'])
                                     summaries = []
                                     for provider, values in scores.items():
                                         summaries.append(ProviderSummary(provider, len(values), round(sum(values) / len(values), 2)))
                                     ranked = sorted(summaries, key=lambda summary: (-summary.mean_score, summary.provider))
                                     return ranked[:n]

                                 def report_line(summary):
                                     return f"{summary.provider:<10}{summary.runs:>6,}{summary.mean_score:>8.2f}"
                                 """,
                                 """
                                 models = [{'model': 'orbit', 'provider': 'acme'}, {'model': 'nova', 'provider': 'zenith'}, {'model': 'atlas', 'provider': 'acme'}, {'model': 'idle', 'provider': 'quiet'}]
                                 evaluations = [
                                     {'model': 'orbit', 'score': 0.9},
                                     {'model': 'nova', 'score': 0.7},
                                     {'model': 'atlas', 'score': 0.6},
                                     {'model': 'ghost', 'score': 0.75},
                                     {'model': 'nova', 'score': 0.8},
                                 ]
                                 assert summarize_providers([], models, 3) == []
                                 result = summarize_providers(evaluations, models, 3)
                                 assert [s.provider for s in result] == ['acme', 'unknown', 'zenith']
                                 assert [s.runs for s in result] == [2, 1, 2]
                                 assert all(abs(s.mean_score - 0.75) < 1e-9 for s in result)
                                 top = summarize_providers(evaluations, models, 1)
                                 assert len(top) == 1 and top[0].provider == 'acme'
                                 assert summarize_providers(evaluations, models, 0) == []
                                 solo = summarize_providers([{'model': 'x', 'score': 1}, {'model': 'y', 'score': 0.333}], [], 5)
                                 assert len(solo) == 1 and solo[0].provider == 'unknown' and solo[0].runs == 2 and abs(solo[0].mean_score - 0.67) < 1e-9
                                 ranked = summarize_providers([{'model': 'nova', 'score': 0.9}, {'model': 'orbit', 'score': 0.5}, {'model': 'atlas', 'score': 0.2}], models, 5)
                                 assert [s.provider for s in ranked] == ['zenith', 'acme']
                                 assert abs(ranked[1].mean_score - 0.35) < 1e-9 and ranked[1].runs == 2
                                 assert report_line(ProviderSummary('acme', 2, 0.75)) == 'acme           2    0.75'
                                 assert report_line(ProviderSummary('unknown', 12345, 0.5)) == 'unknown   12,345    0.50'
                                 assert len(models) == 4 and len(evaluations) == 5 and evaluations[3] == {'model': 'ghost', 'score': 0.75}
                                 """,
                                 [],
                                 effort: .init(difficulty: .similar, scopeUnits: 4)),
        quiz: [
            question("ds-aggregation-q1", "Why might you sort counter.items() with a tuple key instead of using most_common(n) directly?", ["most_common cannot count strings", "most_common breaks ties by first appearance, so a tuple key gives a tie rule you control", "Sorting is the only way to read a Counter's values"], 1, "most_common orders equal counts by insertion order. Sorting by (-count, label) makes the top-n list predictable regardless of input order."),
            question("ds-aggregation-q2", "In a left join of runs to a model table, what happens to a run whose model_id is missing from the model table?", ["It is dropped silently", "It raises an error automatically", "It is kept, with a marker such as None for the missing fields"], 2, "A left join keeps every row of the left table; unmatched rows get a placeholder. An inner join would drop them."),
            question("ds-aggregation-q3", "What does f\"{1234.5:>10,.2f}\" produce?", ["'  1,234.50' (right-aligned in 10 characters)", "'1234.5' (format specs are ignored)", "'1,234.50  ' (left-aligned in 10 characters)"], 0, "> right-aligns in width 10, the comma adds a thousands separator, and .2f shows exactly two decimals. The result is text; the number is unchanged.")
        ],
        sectionRoles: [
            "Turn rows into summaries": .overview,
            "Common mistakes and debugging": .troubleshooting
        ],
        generationNotes: """
        Whenever output is ranked, limited to a top n, or listed from groups, sets or dictionary keys, state an explicit \
        order and tie rule in the steps (for example larger value first, then ascending name) and make tests include a tie. \
        Do not let expected results depend on Counter.most_common tie order or set iteration order.
        """)
}
