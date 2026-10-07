import Foundation

extension Curriculum {
    static let generators = Chapter(
        id: "generators", title: "Iterators and generators", subtitle: "Produce values lazily, one at a time",
        track: .softwareCraft, prerequisites: ["classes"],
        lesson: """
        # Produce values one at a time

        A list holds all of its values at once. That is convenient, but sometimes you want values one at a time instead.

        Three common reasons:

        - A log may be too large to keep in memory.
        - Each result may be expensive to compute.
        - A sequence (such as "request 1, request 2, request 3, …") may have no natural end.

        This chapter shows the machinery that every `for` loop already uses, and how to build it yourself with a class. Then it introduces the shorter `yield` syntax that Python offers for the same job.

        It finishes with ready-made tools from the standard-library module `itertools`. Every code block runs on its own.

        ## Iterables and iterators: iter and next

        ### Two kinds of object

        - An **iterable** is any value a `for` loop can visit. Lists, strings, tuples, dictionaries, sets, and `range(...)` are all iterables.
        - An **iterator** is a separate helper object that remembers a position and hands out the next value each time you ask.

        Two built-in functions connect them:

        - `iter(iterable)` returns a fresh iterator for an iterable.
        - `next(iterator)` asks that iterator for its next value.

        When nothing is left, `next` raises the exception **StopIteration**.

        > **Key idea:** StopIteration is not a bug. It is the agreed signal for "finished".

        ```python
        models = ["orbit", "nova"]
        cursor = iter(models)
        print(next(cursor))
        print(next(cursor))
        try:
            next(cursor)
        except StopIteration:
            print("no more models")
        print(models)
        ```

        ```text
        orbit
        nova
        no more models
        ['orbit', 'nova']
        ```

        - Reading through an iterator does not change the list it came from.
        - `next` also accepts a second argument: a default value returned instead of raising StopIteration. Here, `next(cursor, "done")` would return `"done"`.

        ### What a for loop really does

        A `for` loop is shorthand for exactly this conversation:

        1. Python calls `iter` once.
        2. It calls `next` repeatedly.
        3. It stops quietly when StopIteration arrives.

        The following `while` loop does the same work as `for score in scores: seen.append(score)`:

        ```python
        scores = [0.7, 0.9]
        cursor = iter(scores)
        seen = []
        while True:
            try:
                score = next(cursor)
            except StopIteration:
                break
            seen.append(score)
        assert seen == [0.7, 0.9]
        print(seen)
        ```

        ```text
        [0.7, 0.9]
        ```

        ### Iterators are single-use

        An iterator is **single-use**. Once it has handed out every value, it is **exhausted** and stays empty.

        - The list itself can produce any number of fresh iterators.
        - Calling `iter` on an iterator returns that same iterator, so a loop over an exhausted iterator simply sees nothing.

        ```python
        cursor = iter([1, 2, 3])
        first_pass = list(cursor)
        second_pass = list(cursor)
        print(first_pass)
        print(second_pass)
        print(iter(cursor) is cursor)
        ```

        ```text
        [1, 2, 3]
        []
        True
        ```

        `list(...)` works by looping, so it used up the iterator the first time.

        ## Write an iterator class

        You already know special double-underscore methods such as `__init__` and `__repr__`, which Python calls for you.

        Two more make an object an iterator. Together they are called the **iterator protocol** (an agreed set of method names):

        1. `__iter__(self)` must return the iterator. For an object that remembers its own position, that is simply `self`. `iter(obj)` calls it.
        2. `__next__(self)` must return the next value, or `raise StopIteration` when there are no more values. `next(obj)` calls it.

        ### Example: training checkpoints

        Here is an iterator for invented evaluation checkpoints: every `every` training steps, up to and including `stop`.

        ```python
        class Checkpoints:
            def __init__(self, stop, every):
                self.stop = stop
                self.every = every
                self.current = every

            def __iter__(self):
                return self

            def __next__(self):
                if self.current > self.stop:
                    raise StopIteration
                value = self.current
                self.current = self.current + self.every
                return value

        steps = Checkpoints(10, 4)
        print(list(steps))
        print(list(steps))
        for step in Checkpoints(6, 3):
            print("save at step", step)
        ```

        ```text
        [4, 8]
        []
        save at step 3
        save at step 6
        ```

        ### How it works

        - The attribute `self.current` is the remembered position.
        - `__next__` saves the value to return, moves the position forward, then returns the saved value.
        - The second `list(steps)` is empty because the same object is already exhausted. A new `Checkpoints(...)` object starts again.

        > **Tip:** Inside `__next__`, check for the end first. Then every later call keeps raising StopIteration instead of producing a stray value.

        ## Generator functions with yield

        Writing a class with two methods is a lot of ceremony. A **generator function** is a `def` whose body contains the keyword `yield`.

        ### How a generator runs

        - Calling a generator function does **not** run the body. Instead it returns a **generator**: a ready-made iterator object.
        - Each `next` runs the body until it reaches `yield value`, hands out that value, and pauses there, remembering every local variable.
        - The next `next` resumes right after the `yield`.
        - When the body finishes (falls off the end or reaches `return`), Python raises StopIteration for you.

        ```python
        def checkpoints(stop, every):
            current = every
            while current <= stop:
                yield current
                current = current + every

        print(list(checkpoints(10, 4)))
        gen = checkpoints(6, 3)
        print(next(gen))
        print(next(gen))
        print(next(gen, "done"))
        ```

        ```text
        [4, 8]
        3
        6
        done
        ```

        Six lines replace the whole Checkpoints class. A generator is still single-use: call `checkpoints(...)` again for a fresh one.

        ### Watching the pauses

        The pausing is easiest to see by recording events:

        ```python
        events = []

        def trace():
            events.append("started")
            yield 1
            events.append("resumed")
            yield 2
            events.append("finished")

        gen = trace()
        print(events)
        print(next(gen))
        print(events)
        print(list(gen))
        print(events)
        ```

        ```text
        []
        1
        ['started']
        [2]
        ['started', 'resumed', 'finished']
        ```

        - The first `[]` shows that creating the generator ran nothing.
        - The final `list(gen)` resumed the body, collected 2, then let it finish.

        ### Infinite generators

        Because nothing runs until someone asks, a generator may describe an **infinite** sequence. A `while True` loop with a `yield` inside is safe as long as the code that consumes it decides when to stop, for example with `break`:

        ```python
        def request_numbers(start):
            number = start
            while True:
                yield number
                number = number + 1

        taken = []
        for number in request_numbers(100):
            if number > 102:
                break
            taken.append(number)
        print(taken)
        ```

        ```text
        [100, 101, 102]
        ```

        > **Watch out:** Never call `list(...)` on an infinite generator. It would try to collect values forever, and the exercise runner stops any program after 8 seconds.

        ## Generator expressions and laziness

        A **generator expression** looks like a list comprehension written with parentheses instead of square brackets: `(ms for ms in latencies if ms > 200)`.

        - A list comprehension is **eager**: it computes every value immediately and stores them all.
        - A generator expression is **lazy**: it produces a generator that computes each value only when someone asks for it.

        ### Seeing when work happens

        The function `is_slow` below records every latency (response time in milliseconds) it checks, so you can see when work happens.

        ```python
        checked = []

        def is_slow(latency):
            checked.append(latency)
            return latency > 200

        latencies = [120, 340, 90, 510]
        lazy = (ms for ms in latencies if is_slow(ms))
        print(len(checked))
        print(next(lazy))
        print(checked)
        eager = [ms for ms in latencies if is_slow(ms)]
        print(eager)
        print(len(checked))
        ```

        ```text
        0
        340
        [120, 340]
        [340, 510]
        6
        ```

        - `0`: creating the generator checked nothing.
        - `340` and `[120, 340]`: it did only enough work to find the first slow value.
        - `[340, 510]` and `6`: the list comprehension checked all four latencies at once.

        > **Key idea:** Laziness saves work when you only need some values, and saves memory because a generator holds only its current state, not every result.

        ### Passing generators to functions

        Functions that consume iterables, such as `sum`, `min`, `max`, `any`, `all`, and `list`, accept a generator expression directly.

        - When it is the only argument, you may drop its own parentheses: `sum(ms for ms in latencies)`.
        - `any` and `all` stop asking as soon as the answer is known.
        - Like every generator, a generator expression is single-use.

        ```python
        latencies = [120, 340, 90, 510]
        slow = (ms for ms in latencies if ms > 200)
        print(sum(slow))
        print(sum(slow))
        print(max(ms for ms in latencies if ms < 200))
        print(any(ms > 500 for ms in latencies))
        ```

        ```text
        850
        0
        120
        True
        ```

        The second sum is 0 because the first sum exhausted the generator.

        Use a list when you need the values more than once. Use a generator when you pass through them once.

        ## Ready-made tools in itertools

        `itertools` is a standard-library module of iterator tools. There are two ways to import it:

        - `import itertools` makes the module available, and you write `itertools.islice(...)`.
        - `from itertools import islice, count` imports just those names, so you can write `islice(...)` directly.

        Both forms load the same tools. All four tools below are lazy and accept any iterable.

        ### The four tools

        - `itertools.islice(iterable, stop)` yields the first `stop` values. `itertools.islice(iterable, start, stop)` skips to position `start` first. It is the lazy cousin of slicing (`items[start:stop]`), works on generators, and does not accept negative positions.
        - `itertools.count(start, step)` yields start, start + step, start + 2 × step, and so on **forever**. Both arguments are optional (defaults 0 and 1). Always bound it with `islice`, `break`, or `zip`.
        - `itertools.chain(first, second, ...)` yields every value of the first iterable, then every value of the next, as one stream, without building a combined list.
        - `itertools.groupby(iterable)` groups **consecutive** equal values. It yields pairs `(key, group)`, where `group` is an iterator over that run of values. An optional `key=` function, like the one `sorted` accepts, decides what counts as equal.

        ### islice and count

        ```python
        import itertools

        numbers = itertools.count(10, 5)
        print(list(itertools.islice(numbers, 3)))
        print(next(numbers))
        print(list(itertools.islice("abcdef", 1, 4)))
        ```

        ```text
        [10, 15, 20]
        25
        ['b', 'c', 'd']
        ```

        The counter continues where islice stopped, so the next value is 25.

        ### chain and zip

        `zip` stops at its shortest input, so pairing an infinite counter with a finite list is safe:

        ```python
        from itertools import chain, count

        morning = ["orbit", "nova"]
        evening = ["lumen"]
        labels = []
        for number, model in zip(count(1), chain(morning, evening)):
            labels.append(f"{number}:{model}")
        print(labels)
        ```

        ```text
        ['1:orbit', '2:nova', '3:lumen']
        ```

        ### groupby

        `groupby` only looks at neighbours. To collect all equal items together, sort by the same key first.

        > **Watch out:** Each group is an iterator that is used up once groupby moves on. Convert or consume it immediately, for example with `len(list(group))` or `sum(...)`.

        ```python
        import itertools

        statuses = ["ok", "ok", "fail", "ok"]
        runs = []
        for status, group in itertools.groupby(statuses):
            runs.append((status, len(list(group))))
        print(runs)

        records = [{"model": "nova", "tokens": 5}, {"model": "orbit", "tokens": 2}, {"model": "nova", "tokens": 1}]
        ordered = sorted(records, key=lambda record: record["model"])
        totals = {}
        for model, group in itertools.groupby(ordered, key=lambda record: record["model"]):
            totals[model] = sum(record["tokens"] for record in group)
        print(totals)
        ```

        ```text
        [('ok', 2), ('fail', 1), ('ok', 1)]
        {'nova': 6, 'orbit': 2}
        ```

        - In the first result, the final ok is a separate run because fail interrupts it.
        - In the second result, sorting brought both nova records next to each other.

        ## Common mistakes and debugging

        - **Nothing happened.** Calling a generator function only creates a generator; printing it shows something like `<generator object trace at 0x…>`. Ask for values with `next`, a `for` loop, or `list`.
        - **The second loop is empty.** Iterators and generators are exhausted after one pass. Call the generator function again, or store the values in a list if you truly need them twice.
        - **Debugging consumes values.** `print(next(gen))` takes a value out; the rest of your code will no longer see it.
        - **The program timed out.** An infinite generator or `itertools.count()` was consumed without a limit, for example with `list(...)` or a loop without `break`. Bound it with `islice`, `break`, or `zip`.
        - **groupby repeats a key.** The input was not sorted by the grouping key, so equal values were not neighbours.
        - **Raising StopIteration inside a generator function.** Python turns that into a RuntimeError. In a generator, use `return` (or let the body finish). Only an iterator class's `__next__` raises StopIteration itself.
        """,
        exercises: [
            exercise("generators-countdown", "Count down to a training run", """
            Goal:
            Build an iterator class that counts down the seconds before an invented training run starts. The object itself remembers where it is and hands out one number per `next` call.

            Starting code:
            - `class Countdown` is supplied.
            - Its `__init__(self, start)` saves `start` in the attribute `self.current`. Keep it unchanged.
            - `__iter__` currently returns `iter([])`. This is a placeholder: replace its body.
            - `__next__` immediately raises `StopIteration`. This is a placeholder: replace its body.

            Your task:
            1. Keep the class name `Countdown`, the `__init__` method, and the attribute name `current`. `start` is an integer and may be zero or negative.
            2. Make `__iter__` return the object itself (`self`), so that `iter(timer) is timer` is `True`.
            3. Make `__next__` return the current number and lower `self.current` by 1 for the following call. The values come out as `start`, `start - 1`, …, down to `1`. Return integers.
            4. When `self.current` is `0` or less, make `__next__` raise `StopIteration`.
            5. Once finished it stays finished: every later `next` call raises `StopIteration` again, and a second loop over the same object produces nothing.

            Expected result:
            - `list(Countdown(3))` is `[3, 2, 1]`.
            - `list(Countdown(0))` and `list(Countdown(-2))` are both `[]`.
            - For `timer = Countdown(2)`: `next(timer)` returns `2`, the next call returns `1`, the next call raises `StopIteration`, and `list(timer)` afterwards is `[]`.
            - `next(Countdown(5))` returns `5`.

            Check:
            Choose Check solution. It loops over `Countdown` objects, calls `iter` and `next` directly, and confirms that `StopIteration` ends the countdown. Printing is optional.
            """, """
            class Countdown:
                def __init__(self, start):
                    self.current = start

                def __iter__(self):
                    return iter([])

                def __next__(self):
                    raise StopIteration

            """, """
            class Countdown:
                def __init__(self, start):
                    self.current = start

                def __iter__(self):
                    return self

                def __next__(self):
                    if self.current <= 0:
                        raise StopIteration
                    value = self.current
                    self.current = self.current - 1
                    return value

            """, """
            assert list(Countdown(3)) == [3, 2, 1]
            assert list(Countdown(0)) == []
            assert list(Countdown(-2)) == []
            timer = Countdown(2)
            assert iter(timer) is timer
            assert next(timer) == 2
            assert next(timer) == 1
            finished = False
            try:
                next(timer)
            except StopIteration:
                finished = True
            assert finished
            assert list(timer) == []
            assert next(Countdown(5)) == 5
            assert list(Countdown(1)) == [1]

            """, [
                "An iterator needs two methods: `__iter__` hands back the object that remembers the position, and `__next__` hands out one value per call.",
                "`Countdown` already remembers its position in `self.current`, so `__iter__` can return the object itself. `__next__` should first decide whether anything is left.",
                "In `__next__`: if `self.current` is 0 or less, `raise StopIteration`; otherwise keep `self.current` in a local variable, subtract 1 from `self.current`, and return the kept value."
            ], effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("generators-ids", "Generate endless request IDs", """
            Goal:
            Produce request IDs such as `'req-1'`, `'req-2'`, `'req-3'`, … from a generator that never runs out, and safely take a fixed number of them.

            Starting code:
            - `import itertools` is supplied. Keep it.
            - `def request_ids(prefix, start):` currently returns `iter([])`, an empty placeholder iterator. Replace its body.
            - `def first_ids(prefix, start, how_many):` currently returns `[]` as a placeholder. Replace its body.

            Your task:
            1. Keep the import, both function names, and their parameters. `prefix` is a string, `start` is an integer, and `how_many` is a nonnegative integer.
            2. Turn `request_ids` into a generator function: its body must use `yield` (the check confirms this) and must not build a list.
            3. Make `request_ids` yield the strings `f'{prefix}-{number}'` for `number` = `start`, `start + 1`, `start + 2`, and so on, forever. A `while True` loop with a counter, or a `for` loop over `itertools.count(start)`, both work.
            4. Make `first_ids` return a list of the first `how_many` IDs from `request_ids(prefix, start)`. Take a bounded slice with `itertools.islice` and convert it with `list`. A `how_many` of `0` returns `[]`.
            5. Never call `list(...)` directly on `request_ids(...)`: it never ends, and the runner stops a program after 8 seconds.

            Expected result:
            - `first_ids('req', 1, 3)` returns `['req-1', 'req-2', 'req-3']`.
            - `first_ids('run', 0, 0)` returns `[]`.
            - `first_ids('a', 5, 2500)` returns a list of 2500 IDs.
            - For `gen = request_ids('job', 7)`: `next(gen)` returns `'job-7'` and the following `next(gen)` returns `'job-8'`. After 1000 more values, the last one is `'job-1008'`.

            Check:
            Choose Check solution. It confirms `request_ids` is a generator function and reads from it only in bounded amounts. Return values, not printed text.
            """, """
            import itertools


            def request_ids(prefix, start):
                return iter([])


            def first_ids(prefix, start, how_many):
                return []

            """, """
            import itertools


            def request_ids(prefix, start):
                for number in itertools.count(start):
                    yield f'{prefix}-{number}'


            def first_ids(prefix, start, how_many):
                return list(itertools.islice(request_ids(prefix, start), how_many))

            """, """
            import inspect
            import itertools
            assert first_ids('req', 1, 3) == ['req-1', 'req-2', 'req-3']
            assert first_ids('run', 0, 0) == []
            assert first_ids('eval', 10, 1) == ['eval-10']
            assert inspect.isgeneratorfunction(request_ids)
            gen = request_ids('job', 7)
            assert next(gen) == 'job-7'
            assert next(gen) == 'job-8'
            assert list(itertools.islice(gen, 1000))[-1] == 'job-1008'
            many = first_ids('a', 5, 2500)
            assert len(many) == 2500 and many[0] == 'a-5' and many[-1] == 'a-2504'

            """, [
                "A generator function is a `def` whose body contains `yield`; calling it returns a generator that produces values only when asked.",
                "Put `yield` inside a loop that never ends on its own, such as `while True` with a counter or a `for` loop over `itertools.count(start)`, and build each ID with an f-string.",
                "In `first_ids`, give `request_ids(prefix, start)` to `itertools.islice` with `how_many` as the stop value, then pass that to `list` to collect exactly that many IDs."
            ], effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("generators-stream", "Stream evaluation results", """
            Goal:
            Work with streams of invented evaluation results without reading more than necessary. A score is a number from one model evaluation; a status is a string such as `'ok'` or `'fail'` recorded by a monitoring job.

            Starting code:
            - `import itertools` is supplied. Keep it.
            - `def first_passing(scores, threshold, n):` currently returns `[]` as a placeholder. Replace its body.
            - `def status_runs(morning, evening):` currently returns `[]` as a placeholder. Replace its body.

            Your task:
            1. Keep the import, both function names, and their parameters.
            2. In `first_passing`, `scores` is any iterable of numbers (a list or a generator). Return a list of the first `n` scores that are at least `threshold` (equal scores qualify), in their original order.
            3. If fewer than `n` scores qualify, return all qualifying scores. `n` is a nonnegative integer; an `n` of `0` returns `[]`.
            4. Make `first_passing` lazy: stop reading scores as soon as `n` qualifying scores have been found. A generator expression with an `if` condition, bounded by `itertools.islice`, does this. The check supplies a generator that records each score it hands out.
            5. In `status_runs`, `morning` and `evening` are lists of status strings. Treat them as one stream, `morning` first and then `evening`, using `itertools.chain`.
            6. Return a list of `(status, run_length)` tuples, one for each run of consecutive equal statuses, in stream order. `run_length` is an integer.
            7. A run that continues from the end of `morning` into the start of `evening` is one run. Equal statuses separated by a different status are separate runs. Two empty lists return `[]`.
            8. Do not change the input lists.

            Expected result:
            - `first_passing([0.2, 0.9, 0.95, 0.1, 0.99], 0.9, 2)` returns `[0.9, 0.95]`.
            - `first_passing([0.5], 0.9, 3)` returns `[]`.
            - For a stream `0.3, 0.92, 0.4, 0.97, 0.99, 0.91` with `threshold` `0.9` and `n` `2`, the result is `[0.92, 0.97]` and only the first four scores are read.
            - `status_runs(['ok', 'ok'], ['ok', 'fail'])` returns `[('ok', 3), ('fail', 1)]`.
            - `status_runs(['fail'], ['ok', 'fail'])` returns `[('fail', 1), ('ok', 1), ('fail', 1)]`.

            Check:
            Choose Check solution. It checks thresholds, short and empty inputs, how many scores were read, runs across the morning/evening boundary, and unchanged lists.
            """, """
            import itertools


            def first_passing(scores, threshold, n):
                return []


            def status_runs(morning, evening):
                return []

            """, """
            import itertools


            def first_passing(scores, threshold, n):
                passing = (score for score in scores if score >= threshold)
                return list(itertools.islice(passing, n))


            def status_runs(morning, evening):
                runs = []
                for status, group in itertools.groupby(itertools.chain(morning, evening)):
                    runs.append((status, len(list(group))))
                return runs

            """, """
            assert first_passing([0.2, 0.9, 0.95, 0.1, 0.99], 0.9, 2) == [0.9, 0.95]
            assert first_passing([0.5], 0.9, 3) == []
            assert first_passing([0.9, 1.0], 0.9, 5) == [0.9, 1.0]
            assert first_passing([0.95, 0.99], 0.9, 0) == []
            handed_out = []
            def score_stream():
                for score in [0.3, 0.92, 0.4, 0.97, 0.99, 0.91]:
                    handed_out.append(score)
                    yield score
            assert first_passing(score_stream(), 0.9, 2) == [0.92, 0.97]
            assert handed_out == [0.3, 0.92, 0.4, 0.97]
            assert status_runs([], []) == []
            assert status_runs(['ok', 'ok'], ['ok', 'fail']) == [('ok', 3), ('fail', 1)]
            assert status_runs(['fail'], ['ok', 'fail']) == [('fail', 1), ('ok', 1), ('fail', 1)]
            assert status_runs([], ['ok']) == [('ok', 1)]
            morning = ['ok']
            evening = ['ok']
            assert status_runs(morning, evening) == [('ok', 2)]
            assert morning == ['ok'] and evening == ['ok']

            """, [
                "Laziness means asking for one score at a time. A generator expression filters without building a list, and `islice` stops after a fixed number of values.",
                "For `first_passing`, write a generator expression with an `if` condition and bound it with `itertools.islice` before converting to a list. For `status_runs`, join the two lists with `itertools.chain` before grouping.",
                "`itertools.groupby` over the chained stream gives `(status, group)` pairs for consecutive runs; each group is an iterator, so measure it with `len(list(group))` and append a `(status, length)` tuple."
            ], effort: .init(difficulty: .harder, scopeUnits: 2))
        ],
        assessment: exercise("generators-assessment", "Total token batches lazily", """
        Goal:
        Split a stream of invented token counts into fixed-size batches and total the first few batches, reading no more of the stream than needed. A token count is how many text units one request used; a batch is a group of consecutive requests.

        Starting code:
        - `import itertools` is supplied. Keep it.
        - `def batched(items, size):` currently returns `iter([])` as a placeholder. Replace its body.
        - `def batch_totals(token_counts, size, how_many):` currently returns `[]` as a placeholder. Replace its body.

        Your task:
        1. Keep the import, both function names, and their parameters. `items` may be any iterable (list, string, or generator). `size` is a positive integer. `how_many` is a nonnegative integer.
        2. Make `batched` a generator function (it must use `yield`) that yields lists of consecutive items.
        3. Every list holds exactly `size` items, except possibly the last, which holds whatever remains. Never yield an empty list.
        4. Make `batched` lazy: yield each batch as soon as it is full, without reading any further items first.
        5. Make `batch_totals` return a list of the integer sums of the first `how_many` batches produced by `batched(token_counts, size)`. If there are fewer batches, return the sums of all of them. A `how_many` of `0` returns `[]`.
        6. Read only as many token counts as are needed to complete those batches.

        Expected result:
        - `list(batched([1, 2, 3, 4, 5], 2))` is `[[1, 2], [3, 4], [5]]`.
        - `list(batched([], 3))` is `[]`.
        - `list(batched('abc', 3))` is `[['a', 'b', 'c']]`.
        - `batch_totals([5, 5, 1], 2, 10)` returns `[10, 1]`.
        - `batch_totals([1, 2], 1, 0)` returns `[]`.
        - For a stream of counts `10, 20, 30, 40, 50, 60, 70` with `size` `3` and `how_many` `2`, the result is `[60, 150]` and only the first six counts are read.

        Check:
        Complete the theory questions and written explanation, then choose Submit assessment. It checks full and partial batches, empty input, laziness, and how many values were read. Work independently; hints and solutions are unavailable.
        """, """
        import itertools


        def batched(items, size):
            return iter([])


        def batch_totals(token_counts, size, how_many):
            return []

        """, """
        import itertools


        def batched(items, size):
            batch = []
            for item in items:
                batch.append(item)
                if len(batch) == size:
                    yield batch
                    batch = []
            if len(batch) > 0:
                yield batch


        def batch_totals(token_counts, size, how_many):
            totals = (sum(batch) for batch in batched(token_counts, size))
            return list(itertools.islice(totals, how_many))

        """, """
        import inspect
        assert list(batched([1, 2, 3, 4, 5], 2)) == [[1, 2], [3, 4], [5]]
        assert list(batched([], 3)) == []
        assert list(batched('abc', 3)) == [['a', 'b', 'c']]
        assert list(batched([7], 5)) == [[7]]
        assert inspect.isgeneratorfunction(batched)
        read = []
        def counts():
            for value in [10, 20, 30, 40, 50, 60, 70]:
                read.append(value)
                yield value
        first_batches = batched(counts(), 2)
        assert next(first_batches) == [10, 20]
        assert read == [10, 20]
        read = []
        assert batch_totals(counts(), 3, 2) == [60, 150]
        assert read == [10, 20, 30, 40, 50, 60]
        assert batch_totals([5, 5, 1], 2, 10) == [10, 1]
        assert batch_totals([1, 2], 1, 0) == []
        assert batch_totals([], 4, 3) == []

        """, [], effort: .init(difficulty: .similar, scopeUnits: 3)),
        quiz: [
            question("generators-q1", "What does calling a generator function such as checkpoints(10, 4) do immediately?", ["Runs the whole body and returns a list", "Returns a generator object without running the body yet", "Raises StopIteration straight away"], 1, "A function containing yield returns a generator. Its body only runs, up to the next yield, when next is called on that generator."),
            question("generators-q2", "Why must itertools.count() be combined with islice, break, or zip?", ["It produces values forever, so the consumer must decide when to stop", "It only works inside iterator classes", "It returns a list too large to print"], 0, "count is an infinite lazy iterator. Collecting it with list or looping without a stop would never finish."),
            question("generators-q3", "How many groups does itertools.groupby(['a', 'b', 'a']) produce?", ["Two, one per distinct letter", "One, because the list has a single type", "Three, because only consecutive equal items are grouped"], 2, "groupby only merges neighbours. Sort by the grouping key first when all equal items should share one group.")
        ],
        sectionRoles: ["Produce values one at a time": .overview, "Common mistakes and debugging": .troubleshooting],
        generationNotes: """
        Check generator behaviour with evidence, not printed output. To prove laziness, define in testCode a source generator that appends each value to a list as it yields it, pass it to the learner's function, and assert exactly which values were read. Confirm a required generator function with inspect.isgeneratorfunction. Read infinite or long generators only through itertools.islice or a fixed number of next calls; never call list on them. For iterator classes, assert iter(obj) is obj and that StopIteration is raised again after exhaustion, using a flag set in an except StopIteration block.
        """)

    static let typingDecorators = Chapter(
        id: "typing-decorators", title: "Type hints and decorators", subtitle: "Describe, pass around, and wrap functions",
        track: .softwareCraft, prerequisites: ["inheritance", "generators"],
        lesson: """
        # Describe and wrap functions

        Functions are the main building block of your programs. This chapter treats them as values in their own right.

        You will:

        - label their inputs and outputs with **type hints**,
        - pass functions to other functions,
        - build functions that remember settings,
        - accept any number of arguments,
        - and finally write **decorators**: functions that wrap other functions to add behaviour such as logging or caching.

        You have already used decorators written by others, such as `@dataclass`, `@property`, and `@abstractmethod`. Every code block runs on its own.

        ## Type hints describe intent

        A **type hint** (also called an annotation) records which type a parameter, result, or variable is meant to have.

        ### Where hints go

        - After a parameter name: a colon and a type, as in `tokens: int`.
        - For the result: `->` followed by a type, before the colon that ends the `def` line.
        - For a variable: between its name and `=`, as in `limit: int = 5`.

        You have already written hints such as `name: str` inside a `@dataclass`.

        ```python
        def tokens_per_second(tokens: int, seconds: float) -> float:
            return tokens / seconds

        limit: int = 5
        print(tokens_per_second(300, 1.5))
        print(tokens_per_second(3.0, 2))
        print(tokens_per_second.__annotations__)
        ```

        ```text
        200.0
        1.5
        {'tokens': <class 'int'>, 'seconds': <class 'float'>, 'return': <class 'float'>}
        ```

        The second call passed a float where the hint says int, and Python ran it anyway.

        > **Key idea:** Type hints are **not enforced at runtime**. They are documentation that people, editors, and separate checking tools read.

        - Python simply stores hints in a dictionary called `__annotations__` on the function.
        - The key `'return'` holds the result hint.
        - If you need a real check, you still write `isinstance` and `raise ValueError` as in earlier chapters.

        ### Hints for containers

        For containers, the standard-library module `typing` provides names you can fill in with square brackets. `from typing import Dict, List` imports those names directly, so you can write `List` instead of `typing.List`.

        - `List[str]`: a list whose items are strings.
        - `Dict[str, int]`: a dictionary with string keys and integer values.
        - `Optional[int]`: an int **or** None. Use it for a result that may be missing.
        - `Iterator[int]`: an iterator, such as a generator, that produces ints.
        - `Callable[[float], float]`: a function taking one float and returning a float (explained in the next section).

        ```python
        from typing import Dict, Iterator, List, Optional

        def best_model(scores: Dict[str, float]) -> Optional[str]:
            if len(scores) == 0:
                return None
            return max(scores, key=lambda name: scores[name])

        def evens(limit: int) -> Iterator[int]:
            number = 0
            while number < limit:
                yield number
                number = number + 2

        names: List[str] = ["orbit", "nova"]
        print(best_model({"orbit": 0.8, "nova": 0.9}))
        print(best_model({}))
        print(list(evens(5)))
        ```

        ```text
        nova
        None
        [0, 2, 4]
        ```

        Looping over a dictionary, as `max` does here, visits its keys.

        ### Built-in names with `from __future__ import annotations`

        A second style uses the built-in names `list` and `dict` with square brackets.

        Put `from __future__ import annotations` as the very first statement of the file. It tells Python to store hints as text without evaluating them.

        ```python
        from __future__ import annotations

        def label_counts(labels: list[str]) -> dict[str, int]:
            counts: dict[str, int] = {}
            for label in labels:
                counts[label] = counts.get(label, 0) + 1
            return counts

        print(label_counts(["chat", "chat", "embed"]))
        print(label_counts.__annotations__["labels"])
        ```

        ```text
        {'chat': 2, 'embed': 1}
        list[str]
        ```

        > **Watch out:** This course runs Python 3.9. Newer Python versions also allow `int | None` for "int or None", but on 3.9 that spelling fails when evaluated, so write `Optional[int]`.

        ## Functions are values

        A function name refers to a function object, just as `scores` refers to a list.

        - Without parentheses you **refer** to the function.
        - With parentheses you **call** it.

        So you can:

        - save a function under another name,
        - store it in a list or dictionary,
        - pass it as an argument (you did this with `sorted(..., key=...)`),
        - and return it from another function.

        A function that takes or returns functions is called a **higher-order function**.

        ```python
        from typing import Callable, Dict

        def double(value: float) -> float:
            return value * 2

        def negate(value: float) -> float:
            return -value

        def apply_twice(func: Callable[[float], float], value: float) -> float:
            return func(func(value))

        operations: Dict[str, Callable[[float], float]] = {"double": double, "negate": negate}
        print(apply_twice(double, 3))
        print(operations["negate"](4))
        alias = double
        print(alias(5), alias is double, double.__name__)
        ```

        ```text
        12
        -4
        10 True double
        ```

        ### Reading the example

        - In `Callable[[float], float]`, the inner square brackets list the parameter types and the last type is the result.
        - `Callable[..., int]` (with three dots) means "any parameters, returns int".
        - Every function stores its own name as text in `__name__`.

        > **Watch out:** A common slip is `apply_twice(double(), 3)`. That calls double immediately (and fails, since it needs a value) instead of passing the function.

        ## Closures remember their surroundings

        A `def` can appear inside another function. The inner function can read the outer function's parameters and variables.

        If the outer function returns the inner one, the returned function keeps remembering those variables even after the outer call has finished.

        - A function that remembers variables from where it was created is called a **closure**.
        - Each call of the outer function creates a separate closure with its own remembered values.

        ```python
        from typing import Callable

        def make_threshold(limit: float) -> Callable[[float], bool]:
            def passes(score: float) -> bool:
                return score >= limit
            return passes

        strict = make_threshold(0.9)
        lenient = make_threshold(0.5)
        print(strict(0.7), lenient(0.7))
        print(strict(0.95))
        ```

        ```text
        False True
        True
        ```

        `strict` remembers limit 0.9 and `lenient` remembers 0.5.

        ### Changing a remembered variable with nonlocal

        Reading a remembered variable just works. **Changing** it needs the keyword `nonlocal`, which says "this name belongs to the enclosing function, not to me".

        > **Remember:** Without `nonlocal`, the assignment `count = count + 1` would make a new local name and fail with UnboundLocalError.

        ```python
        def make_counter():
            count = 0
            def increment():
                nonlocal count
                count = count + 1
                return count
            return increment

        ticket = make_counter()
        print(ticket(), ticket(), ticket())
        other = make_counter()
        print(other())
        ```

        ```text
        1 2 3
        1
        ```

        The second counter has its own count.

        ## Flexible parameters: *args and **kwargs

        Some functions should accept any number of arguments. In a `def`:

        - A parameter written `*name` collects all extra **positional** arguments into a tuple.
        - A parameter written `**name` collects all extra **keyword** arguments (written `key=value` in the call) into a new dictionary whose keys are the argument names as strings.

        The names `args` and `kwargs` ("keyword arguments") are conventions; the stars do the work.

        ```python
        def describe(*args, **kwargs):
            return args, kwargs

        print(describe())
        print(describe(1, 2, model="nova"))
        ```

        ```text
        ((), {})
        ((1, 2), {'model': 'nova'})
        ```

        ### Hints on starred parameters

        A hint on a starred parameter describes each item: `*latencies: float` means every positional argument should be a float.

        ```python
        from typing import Dict

        def total_latency(*latencies: float) -> float:
            total = 0.0
            for ms in latencies:
                total = total + ms
            return total

        def settings(**options: float) -> Dict[str, float]:
            result = {"temperature": 0.7}
            for key in options:
                result[key] = options[key]
            return result

        print(total_latency(), total_latency(120, 80.5))
        print(settings(), settings(temperature=0.2, top_p=0.9))
        ```

        ```text
        0.0 200.5
        {'temperature': 0.7} {'temperature': 0.2, 'top_p': 0.9}
        ```

        - Looping over the kwargs dictionary visits its keys.
        - Each call builds a fresh result dictionary, so earlier calls never leak into later ones.
        - Ordinary parameters can come first: `def report(name, *args, **kwargs)`.

        ### Spreading arguments when calling

        The stars also work in the opposite direction, when **calling**:

        - `func(*values)` spreads a tuple or list into separate positional arguments.
        - `func(**options)` spreads a dictionary into keyword arguments.

        This lets one function forward whatever it received to another.

        ```python
        def cost(tokens, rate=0.002):
            return tokens / 1000 * rate

        args = (5000,)
        kwargs = {"rate": 0.01}
        print(cost(*args, **kwargs))
        print(cost(*[2000]))
        ```

        ```text
        0.05
        0.004
        ```

        `(5000,)` is a one-item tuple; the comma makes it a tuple.

        ## Decorators wrap behaviour

        A **decorator** is a function that takes a function and returns a replacement. The replacement is usually a **wrapper** function that does something extra and calls the original.

        - Writing `@logged` on the line above a `def` is shorthand for `add_tokens = logged(add_tokens)` right after the definition.
        - The wrapper uses `*args, **kwargs` so it can forward any arguments.
        - The wrapper must return the original's result.

        ```python
        calls = []

        def logged(func):
            def wrapper(*args, **kwargs):
                calls.append(func.__name__)
                return func(*args, **kwargs)
            return wrapper

        @logged
        def add_tokens(a, b=0):
            return a + b

        print(add_tokens(2, b=3))
        print(add_tokens(4))
        print(calls)
        print(add_tokens.__name__)
        ```

        ```text
        5
        4
        ['add_tokens', 'add_tokens']
        wrapper
        ```

        That last line is a problem: the decorated function has lost its own name.

        ### Keeping the original's details with functools.wraps

        The standard-library decorator `functools.wraps(func)`, placed on the wrapper, copies these onto the wrapper:

        - the original's `__name__`,
        - its **docstring** (a string written as the first statement of a function body, stored in `__doc__`),
        - and its hints.

        It also saves the original function in the wrapper's `__wrapped__` attribute.

        ```python
        import functools

        def logged(func):
            @functools.wraps(func)
            def wrapper(*args, **kwargs):
                result = func(*args, **kwargs)
                print("called", func.__name__, "->", result)
                return result
            return wrapper

        @logged
        def add_tokens(a: int, b: int = 0) -> int:
            \"""Return the combined token count.\"""
            return a + b

        add_tokens(2, 3)
        print(add_tokens.__name__)
        print(add_tokens.__doc__)
        print(add_tokens.__wrapped__(1, 1))
        ```

        ```text
        called add_tokens -> 5
        add_tokens
        Return the combined token count.
        2
        ```

        Calling the original directly through `__wrapped__` skips the logging.

        > **Note:** A wrapper is a closure, so it can also keep state between calls with `nonlocal`, exactly like `make_counter`.

        ### Decorators with settings

        A decorator that needs settings is written as a function that **returns** a decorator; this is sometimes called a decorator factory.

        `@repeat(3)` first calls `repeat(3)`, then applies the decorator it returns: `ping = repeat(3)(ping)`.

        ```python
        import functools

        def repeat(times: int):
            def decorator(func):
                @functools.wraps(func)
                def wrapper(*args, **kwargs):
                    results = []
                    for _ in range(times):
                        results.append(func(*args, **kwargs))
                    return results
                return wrapper
            return decorator

        @repeat(3)
        def ping(name):
            return f"ping {name}"

        print(ping("nova"))
        print(ping.__name__)
        ```

        ```text
        ['ping nova', 'ping nova', 'ping nova']
        ping
        ```

        The name `_` is a convention for a loop variable you do not use.

        ## Cache results with functools.lru_cache

        **Caching** (also called memoization) means remembering the result of a call. A repeated call with the same arguments then returns the saved result without running the body again.

        ### Adding a cache

        `@functools.lru_cache(maxsize=None)` adds a cache to a function.

        - `maxsize=None` keeps every result.
        - A number such as `maxsize=128` keeps only that many, discarding the least recently used one first (LRU stands for "least recently used").

        The decorated function gains two extra methods:

        - `cache_info()` reports `hits` (answers served from the cache) and `misses` (calls that ran the body).
        - `cache_clear()` empties the cache.

        ```python
        import functools

        evaluated = []

        @functools.lru_cache(maxsize=None)
        def prompt_score(prompt: str) -> int:
            evaluated.append(prompt)
            return len(prompt.strip())

        print(prompt_score(" hello "))
        print(prompt_score(" hello "))
        print(prompt_score("hi"))
        print(evaluated)
        info = prompt_score.cache_info()
        print(info.hits, info.misses)
        ```

        ```text
        5
        5
        2
        [' hello ', 'hi']
        1 2
        ```

        The body ran only twice: one hit and two misses.

        ### What can be cached

        > **Watch out:** Cache **pure** functions only. If the body has important side effects, or its result depends on something other than its arguments, a cached answer can be wrong.

        The arguments become dictionary-style keys, so they must be **hashable** (unchangeable values such as numbers, strings, and tuples). Lists and dictionaries are rejected with TypeError:

        ```python
        import functools

        @functools.lru_cache(maxsize=None)
        def total(values):
            return sum(values)

        print(total((1, 2, 3)))
        try:
            total([1, 2, 3])
        except TypeError:
            print("lists cannot be cache keys")
        ```

        ```text
        6
        lists cannot be cache keys
        ```

        ## Common mistakes and debugging

        - **TypeError: 'NoneType' object is not callable.** The decorator forgot `return wrapper`, so the decorated name now holds None.
        - **The decorated function returns None.** The wrapper called `func(*args, **kwargs)` but did not return its result.
        - **Wrong name in errors and reports.** Add `@functools.wraps(func)` to the wrapper.
        - **Factory confusion.** `@repeat(3)` needs a function that returns a decorator; `@logged` needs the decorator itself. Writing `@logged()` calls logged with no function.
        - **UnboundLocalError in a closure.** You assigned to a remembered variable without `nonlocal`.
        - **A hint seemed to do nothing.** Hints are never checked when the program runs; validate explicitly when correctness matters. On Python 3.9, use `Optional[...]` rather than `X | None`.
        - **Stale cached values.** `lru_cache` on a function with side effects or changing inputs; call `cache_clear()` or do not cache it.
        """,
        exercises: [
            exercise("typing-decorators-scalers", "Build and apply scoring functions", """
            Goal:
            Create adjustment functions from a setting and apply a list of them to one invented model score. This practises type hints, functions as values, and closures.

            Starting code:
            - `from typing import Callable, List` is supplied. Keep it.
            - `def make_scaler(factor):` currently returns `None` as a placeholder and has no type hints yet. Replace its body and add hints.
            - `def apply_all(funcs, value):` currently returns `[]` as a placeholder and has no type hints yet. Replace its body and add hints.

            Your task:
            1. Keep the import and both function names and parameter names.
            2. Add type hints to `make_scaler` exactly like this: `make_scaler(factor: float) -> Callable[[float], float]`.
            3. Add type hints to `apply_all` exactly like this: `apply_all(funcs: List[Callable[[float], float]], value: float) -> List[float]`. The check reads `__annotations__` to confirm every parameter and the result have a hint.
            4. Make `make_scaler` return a new inner function (a closure). That function takes one number and returns it multiplied by `factor`. Each `make_scaler` call creates an independent function with its own `factor`.
            5. Make `apply_all` return a new list containing the result of calling each function in `funcs` with `value`, in the same order as `funcs`. An empty `funcs` list returns `[]`. Do not change `funcs`.

            Expected result:
            - With `double = make_scaler(2)` and `half = make_scaler(0.5)`: `double(3)` returns `6`, `half(3)` returns `1.5`, and `double(-1.5)` returns `-3.0`.
            - `make_scaler(0)(99)` returns `0`.
            - `apply_all([double, half], 4)` returns `[8, 2.0]`.
            - `apply_all([], 4)` returns `[]`.

            Check:
            Choose Check solution. It checks the hints, separately created scalers, order, and empty input. Return functions and lists; printing is optional.
            """, """
            from typing import Callable, List


            def make_scaler(factor):
                return None


            def apply_all(funcs, value):
                return []

            """, """
            from typing import Callable, List


            def make_scaler(factor: float) -> Callable[[float], float]:
                def scale(value: float) -> float:
                    return value * factor
                return scale


            def apply_all(funcs: List[Callable[[float], float]], value: float) -> List[float]:
                results = []
                for func in funcs:
                    results.append(func(value))
                return results

            """, """
            assert set(make_scaler.__annotations__) == {'factor', 'return'}
            assert set(apply_all.__annotations__) == {'funcs', 'value', 'return'}
            double = make_scaler(2)
            half = make_scaler(0.5)
            assert callable(double) and callable(half)
            assert double(3) == 6
            assert half(3) == 1.5
            assert double(-1.5) == -3.0
            assert make_scaler(0)(99) == 0
            funcs = [double, half]
            assert apply_all(funcs, 4) == [8, 2.0]
            assert funcs == [double, half]
            assert apply_all([], 4) == []
            assert apply_all([half, half, make_scaler(10)], 1) == [0.5, 0.5, 10]

            """, [
                "Hints go after each parameter name with a colon, and the result hint goes after `->` before the final colon of the `def` line.",
                "Inside `make_scaler`, define a second function with its own `def` that uses `factor`, and return that inner function's name without calling it.",
                "In `apply_all`, loop over `funcs`, call each one with `value` using parentheses, append each result to a new list, and return the list after the loop."
            ], effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("typing-decorators-flexible", "Accept any number of arguments", """
            Goal:
            Write three small helpers for invented request statistics that accept a flexible number of arguments and forward arguments to another function.

            Starting code:
            - `from typing import Callable, Dict` is supplied. Keep it.
            - `total_tokens(*counts: int) -> int` already has its hinted signature. Its body returns `0` as a placeholder.
            - `merge_settings(**overrides: float) -> Dict[str, float]` already has its hinted signature. Its body returns `{}` as a placeholder.
            - `measure(func: Callable[..., int], *args: int, **kwargs: int)` already has its hinted signature. Its body returns `('', 0)` as a placeholder.
            - Replace the three bodies only.

            Your task:
            1. Keep the import and all three signatures unchanged.
            2. Make `total_tokens` return the integer sum of all positional arguments it receives. With no arguments it returns `0`.
            3. Make `merge_settings` return a new dictionary that starts from the defaults `{'temperature': 0.7, 'top_p': 1.0}`.
            4. Then apply every keyword argument to that dictionary: a keyword with the same name replaces the default, and a new name is added. With no arguments, `merge_settings` returns the defaults.
            5. Make sure every `merge_settings` call returns a fresh dictionary; earlier calls must not affect later ones.
            6. Make `measure` call `func` with exactly the positional and keyword arguments it received (forward them with `*` and `**`).
            7. Have `measure` return a tuple of `func`'s name (its `__name__` text) and the result.

            Expected result:
            - `total_tokens()` returns `0`, `total_tokens(5)` returns `5`, and `total_tokens(10, 20, 30)` returns `60`.
            - `merge_settings()` returns `{'temperature': 0.7, 'top_p': 1.0}`.
            - `merge_settings(temperature=0.2)` returns `{'temperature': 0.2, 'top_p': 1.0}`.
            - `merge_settings(seed=7.0)` returns `{'temperature': 0.7, 'top_p': 1.0, 'seed': 7.0}`. Key order is not important.
            - With `def batches(items, size=4): return (items + size - 1) // size`: `measure(batches, 10)` returns `('batches', 3)`, `measure(batches, 10, size=5)` returns `('batches', 2)`, and `measure(batches, items=0)` returns `('batches', 0)`.

            Check:
            Choose Check solution. It calls each helper with zero, one, and several arguments, including keyword-only calls. Return values; printing is optional.
            """, """
            from typing import Callable, Dict


            def total_tokens(*counts: int) -> int:
                return 0


            def merge_settings(**overrides: float) -> Dict[str, float]:
                return {}


            def measure(func: Callable[..., int], *args: int, **kwargs: int):
                return ('', 0)

            """, """
            from typing import Callable, Dict


            def total_tokens(*counts: int) -> int:
                total = 0
                for count in counts:
                    total = total + count
                return total


            def merge_settings(**overrides: float) -> Dict[str, float]:
                merged = {'temperature': 0.7, 'top_p': 1.0}
                for key in overrides:
                    merged[key] = overrides[key]
                return merged


            def measure(func: Callable[..., int], *args: int, **kwargs: int):
                return (func.__name__, func(*args, **kwargs))

            """, """
            assert total_tokens(5) == 5
            assert total_tokens() == 0
            assert total_tokens(10, 20, 30) == 60
            assert merge_settings() == {'temperature': 0.7, 'top_p': 1.0}
            assert merge_settings(temperature=0.2) == {'temperature': 0.2, 'top_p': 1.0}
            assert merge_settings(seed=7.0) == {'temperature': 0.7, 'top_p': 1.0, 'seed': 7.0}
            assert merge_settings() == {'temperature': 0.7, 'top_p': 1.0}
            def batches(items, size=4):
                return (items + size - 1) // size
            assert measure(batches, 10) == ('batches', 3)
            assert measure(batches, 10, size=5) == ('batches', 2)
            assert measure(batches, items=0) == ('batches', 0)
            def no_args():
                return 9
            assert measure(no_args) == ('no_args', 9)

            """, [
                "Inside the function, `counts` is a tuple of every positional argument and `overrides` is a dictionary of every keyword argument, keyed by name.",
                "Loop over `counts` with an accumulator; for `merge_settings`, create the defaults dictionary inside the function, then loop over the `overrides` keys and assign each value.",
                "In `measure`, spread the received values back out when calling: `func(*args, **kwargs)`. Pair that result with `func.__name__` in a tuple."
            ], effort: .init(difficulty: .similar, scopeUnits: 3)),
            exercise("typing-decorators-record", "Record calls and cache results", """
            Goal:
            Write a decorator that records which functions were called, and cache an invented batch calculation so repeated questions are answered without recomputing.

            Starting code:
            - `import functools` is supplied. Keep it.
            - Two empty lists, `calls` and `computed`, are supplied. Keep them.
            - `def record_calls(func):` currently returns `func` unchanged. This is a placeholder: replace its body.
            - `estimate_batches` is already decorated with `@record_calls` and has a docstring. Keep it unchanged.
            - `cached_batches` appends `(items, size)` to `computed` and returns the number of batches, but has no cache yet. Keep its body unchanged.

            Your task:
            1. Keep the import, both lists, `estimate_batches`, and the body of `cached_batches` unchanged.
            2. Make `record_calls` return a new wrapper function that accepts any positional and keyword arguments.
            3. Each time the wrapper is called, it appends the original function's name (`func.__name__`) to `calls`, then calls the original with exactly the same arguments, and returns the original's result.
            4. Decorate the wrapper with `@functools.wraps(func)` so the decorated function keeps its original `__name__` and `__doc__` and exposes the original as `__wrapped__`.
            5. Make sure `record_calls` works for any function, not just `estimate_batches`.
            6. Add `@functools.lru_cache(maxsize=None)` on the line above `def cached_batches`, so a repeated call with the same `items` and `size` returns the saved result without running the body again.

            Expected result:
            - `estimate_batches(10)` returns `3` and `calls` becomes `['estimate_batches']`.
            - `estimate_batches(10, size=5)` returns `2` and `estimate_batches(items=0)` returns `0`, each adding another `'estimate_batches'`.
            - `estimate_batches.__name__` is `'estimate_batches'` and its `__doc__` is `'Return how many batches are needed.'`.
            - `estimate_batches.__wrapped__(7)` returns `2` without recording a call.
            - Calling `cached_batches(10, 4)` twice and then `cached_batches(8, 4)` returns `3`, `3`, and `2`, leaves `computed` as `[(10, 4), (8, 4)]`, and `cached_batches.cache_info().hits` is `1`.

            Check:
            Choose Check solution. It checks recorded names, forwarded arguments and results, preserved metadata, a second decorated function, and the cache statistics.
            """, """
            import functools

            calls = []
            computed = []


            def record_calls(func):
                return func


            @record_calls
            def estimate_batches(items, size=4):
                \"""Return how many batches are needed.\"""
                return (items + size - 1) // size


            def cached_batches(items, size):
                computed.append((items, size))
                return (items + size - 1) // size

            """, """
            import functools

            calls = []
            computed = []


            def record_calls(func):
                @functools.wraps(func)
                def wrapper(*args, **kwargs):
                    calls.append(func.__name__)
                    return func(*args, **kwargs)
                return wrapper


            @record_calls
            def estimate_batches(items, size=4):
                \"""Return how many batches are needed.\"""
                return (items + size - 1) // size


            @functools.lru_cache(maxsize=None)
            def cached_batches(items, size):
                computed.append((items, size))
                return (items + size - 1) // size

            """, """
            assert estimate_batches(10) == 3
            assert calls == ['estimate_batches']
            assert estimate_batches(10, size=5) == 2
            assert estimate_batches(items=0) == 0
            assert calls == ['estimate_batches', 'estimate_batches', 'estimate_batches']
            assert estimate_batches.__name__ == 'estimate_batches'
            assert estimate_batches.__doc__ == 'Return how many batches are needed.'
            assert estimate_batches.__wrapped__(7) == 2
            assert len(calls) == 3
            def tokens_used(*counts):
                return sum(counts)
            wrapped = record_calls(tokens_used)
            assert wrapped(1, 2, 3) == 6
            assert calls[-1] == 'tokens_used' and wrapped.__name__ == 'tokens_used'
            assert cached_batches(10, 4) == 3
            assert cached_batches(10, 4) == 3
            assert cached_batches(8, 4) == 2
            assert computed == [(10, 4), (8, 4)]
            assert cached_batches.cache_info().hits == 1

            """, [
                "A decorator receives a function and returns a different function that calls the original; the cache is a ready-made decorator you only need to apply.",
                "Define `wrapper(*args, **kwargs)` inside `record_calls`, put `@functools.wraps(func)` directly above it, and return `wrapper` (not `wrapper()`) at the end of `record_calls`.",
                "Inside `wrapper`, append `func.__name__` to `calls` first, then `return func(*args, **kwargs)`. For the cache, write `@functools.lru_cache(maxsize=None)` immediately above `def cached_batches`."
            ], effort: .init(difficulty: .harder, scopeUnits: 3))
        ],
        assessment: exercise("typing-decorators-assessment", "Limit how often a function runs", """
        Goal:
        Write a configurable decorator that lets an invented scoring function run only a limited number of times, then refuses further calls with a custom exception.

        Starting code:
        - `import functools` and `from typing import Callable` are supplied. Keep them.
        - `class CallLimitError(Exception)` is a supplied custom exception. Keep it.
        - `def limit_calls(max_calls):` returns a decorator that currently returns `func` unchanged. This is a placeholder, and `limit_calls` has no type hints yet.
        - `request_score` is decorated with `@limit_calls(2)` and has a docstring. Keep it unchanged.

        Your task:
        1. Keep the imports, `CallLimitError`, and `request_score` unchanged.
        2. Give `limit_calls` the parameter hint `max_calls: int` and the result hint `Callable`. The check confirms `max_calls` and the result are annotated.
        3. Make `limit_calls(max_calls)` return a decorator. The decorator receives `func` and returns a wrapper made with `@functools.wraps(func)`, so `__name__`, `__doc__`, and `__wrapped__` come from the original.
        4. Give every decorated function its own count of completed calls, starting at `0`.
        5. When the wrapper is called and the count is still below `max_calls`, it adds 1 to the count, calls `func` with exactly the positional and keyword arguments it received, and returns `func`'s result.
        6. When the count has already reached `max_calls`, the wrapper raises `CallLimitError` with a nonempty message and does not call `func`. With a `max_calls` of `0`, every call raises `CallLimitError`.

        Expected result:
        - `request_score(' hi ')` returns `2` and `request_score('abc', bonus=1)` returns `4`; a third call raises `CallLimitError`.
        - `request_score.__name__` is `'request_score'`.
        - `request_score.__doc__` is `'Score a prompt by its trimmed length.'`.
        - Two different functions decorated with `@limit_calls(1)` can each be called once.

        Check:
        Complete the theory questions and written explanation, then choose Submit assessment. It checks the hints, forwarded arguments, the limit, independent counters, a zero limit, and preserved metadata. Work independently; hints and solutions are unavailable.
        """, """
        import functools
        from typing import Callable


        class CallLimitError(Exception):
            pass


        def limit_calls(max_calls):
            def decorator(func):
                return func
            return decorator


        @limit_calls(2)
        def request_score(prompt, bonus=0):
            \"""Score a prompt by its trimmed length.\"""
            return len(prompt.strip()) + bonus

        """, """
        import functools
        from typing import Callable


        class CallLimitError(Exception):
            pass


        def limit_calls(max_calls: int) -> Callable:
            def decorator(func):
                count = 0

                @functools.wraps(func)
                def wrapper(*args, **kwargs):
                    nonlocal count
                    if count >= max_calls:
                        raise CallLimitError(f'{func.__name__} may only run {max_calls} times')
                    count = count + 1
                    return func(*args, **kwargs)
                return wrapper
            return decorator


        @limit_calls(2)
        def request_score(prompt, bonus=0):
            \"""Score a prompt by its trimmed length.\"""
            return len(prompt.strip()) + bonus

        """, """
        assert set(limit_calls.__annotations__) == {'max_calls', 'return'}
        assert request_score(' hi ') == 2
        assert request_score('abc', bonus=1) == 4
        refused = None
        try:
            request_score('again')
        except CallLimitError as error:
            refused = str(error)
        assert refused is not None and len(refused) > 0
        assert request_score.__name__ == 'request_score'
        assert request_score.__doc__ == 'Score a prompt by its trimmed length.'
        assert request_score.__wrapped__('x') == 1
        ran = []
        @limit_calls(1)
        def first(x):
            ran.append('first')
            return x * 2
        @limit_calls(1)
        def second(x):
            return x + 1
        assert first(3) == 6
        assert second(3) == 4
        blocked = False
        try:
            first(5)
        except CallLimitError:
            blocked = True
        assert blocked and ran == ['first']
        @limit_calls(0)
        def never():
            return 'ran'
        stopped = False
        try:
            never()
        except CallLimitError:
            stopped = True
        assert stopped

        """, [], effort: .init(difficulty: .harder, scopeUnits: 3)),
        quiz: [
            question("typing-decorators-q1", "What happens at runtime when a function hinted as def half(count: int) -> float is called with a float?", ["Python raises TypeError because the hint says int", "The hint is not checked, so the function runs with the float", "Python converts the float to an int first"], 1, "Type hints are stored in __annotations__ for readers and tools; Python does not enforce them when the program runs."),
            question("typing-decorators-q2", "What does writing @logged on the line above def score(...) mean?", ["score = logged(score) right after the definition", "logged = score(logged)", "score is called immediately and its result printed"], 0, "The @ syntax passes the newly defined function to the decorator and saves the returned replacement under the same name."),
            question("typing-decorators-q3", "Why put @functools.wraps(func) on a decorator's wrapper?", ["It makes the wrapper run faster", "It copies the original function's name, docstring and hints onto the wrapper", "It caches every result the wrapper returns"], 1, "Without wraps, the decorated function reports the wrapper's name and docstring; wraps preserves the original's metadata and saves it in __wrapped__.")
        ],
        sectionRoles: ["Describe and wrap functions": .overview, "Common mistakes and debugging": .troubleshooting],
        generationNotes: """
        Hints are not enforced at runtime, so check them by reading __annotations__ keys (including 'return'), not by expecting errors; compare key sets rather than type objects, because from __future__ import annotations stores hints as text. Use Optional[...], not X | None (Python 3.9). Check decorators by behaviour: count how often the original body runs with a list it appends to, apply the learner's decorator to a second function defined in testCode, and check __name__, __doc__ and __wrapped__ when functools.wraps is required. For lru_cache, call cache_clear() before counting, or account for calls the reference already made, then assert body-run counts or cache_info().hits and misses.
        """)
}
