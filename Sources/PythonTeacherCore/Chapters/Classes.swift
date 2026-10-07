import Foundation

extension Curriculum {
    static let classes = Chapter(
        id: "classes", title: "Classes and objects", subtitle: "Bundle data with the behaviour that uses it", track: .corePython, prerequisites: ["iteration"],
        lesson: """
        # Bundle data with the behaviour that uses it

        Until now, a record has been a dictionary such as `{"owner": "mira", "limit": 100, "used": 0}`, and the operations on it have been separate functions such as `spend(budget, 30)`.

        That works, but it has two weaknesses:

        - Nothing connects the data to the functions that are allowed to change it.
        - A typing mistake in a key, such as `"usd"`, only shows up later.

        A **class** lets you design your own kind of value that carries both its data and its operations.

        ### Objects, types and instances

        You have already used such values. Every Python value is an **object**: a piece of data in memory together with the operations it supports.

        - A string is an object whose operations include `strip()` and `lower()`.
        - A list is an object with `append()`.

        The **type** of an object describes what kind of object it is (`str`, `list`, `dict`). A class is a type you define yourself.

        An **instance** is one particular object made from a class. `"mira"` is an instance of `str`, and in this chapter `TokenBudget("mira", 100)` will be an instance of a `TokenBudget` class.

        > **Key idea:** One class can produce many instances, each with its own data, in the same way one recipe can produce many cakes.

        ## Define a class and create instances

        ### The class statement

        The `class` keyword starts a class definition, followed by a name and a colon. The indented block underneath is the class body.

        By convention class names use CapitalizedWords (`TokenBudget`, `EvalResult`), which makes them easy to tell apart from function and variable names.

        A function written inside a class body is called a **method**.

        ### Setting up a new object

        One method has a special name: `__init__` (two underscores, init, two underscores; often read “dunder init”). Python calls it automatically every time you create an instance, to initialize (set up) the new object.

        You never call `__init__` by name. Instead you **call the class** like a function. `Model("orbit", 4096)` does three things:

        1. It makes a new empty object.
        2. It runs `__init__` on that object with the arguments you gave.
        3. It returns the finished object.

        `__init__` itself must not return a value.

        ### The self parameter and attributes

        The first parameter of every method is conventionally named `self`. It is the instance the method is working on.

        Python fills `self` in for you. So `Model("orbit", 4096)` supplies two arguments even though `__init__` lists three parameters: `self`, `name`, and `max_tokens`.

        Inside `__init__`, `self.name = name` creates an **attribute**: a named value stored on that particular object.

        - The left side, `self.name`, means “the attribute called `name` on this object”.
        - The right side, `name`, is the ordinary parameter.
        - They share a spelling but are different things.

        Outside the class, read an attribute with a dot: `orbit.name`.

        ```python
        class Model:
            def __init__(self, name, max_tokens):
                self.name = name
                self.max_tokens = max_tokens

        orbit = Model("orbit", 4096)
        nova = Model("nova", 1024)
        print(orbit.name, orbit.max_tokens)
        print(nova.name, nova.max_tokens)
        print(isinstance(orbit, Model))
        assert orbit is not nova
        ```

        ```text
        orbit 4096
        nova 1024
        True
        ```

        - The two instances were made from the same class but keep separate attributes.
        - `isinstance`, which you used with built-in types, also works with your own classes.
        - Assigning `orbit.max_tokens = 8192` later would replace that attribute on `orbit` only.
        - Reading an attribute that was never assigned, such as `orbit.speed`, raises `AttributeError`.

        > **Tip:** Create every attribute inside `__init__`, even if it starts as `0` or an empty list, so every instance always has the same set of attributes.

        ## Add methods that read and change attributes

        Any other function in the class body is an ordinary method. Call it with a dot on an instance: `tokens.add(30)`.

        Python turns that into a call where `self` is `tokens` and `amount` is `30`. Inside the method, `self.count` reads or changes the attribute of whichever instance the method was called on.

        A method can return a value like any function. If it has no `return`, it returns `None`.

        ```python
        class Counter:
            def __init__(self, label):
                self.label = label
                self.count = 0

            def add(self, amount):
                self.count = self.count + amount
                return self.count

            def is_empty(self):
                return self.count == 0

        tokens = Counter("tokens")
        print(tokens.is_empty())
        print(tokens.add(30))
        print(tokens.add(12))
        print(tokens.count, tokens.is_empty())
        ```

        ```text
        True
        30
        42
        42 False
        ```

        - `count` was not passed in: `__init__` gave every new counter a starting value of `0`.
        - Methods can call other methods of the same object through `self`, for example `self.is_empty()`.

        > **Key idea:** The object **remembers state** between calls. This is the main reason to use a class instead of separate functions: the data and the rules for changing it live together.

        ### Changing an object

        A method that changes attributes is said to **mutate** the object.

        When a method decides that a change is not allowed, it has two options:

        - Leave the attributes untouched and report that with its return value.
        - Raise an exception, as later sections show.

        ## Control how objects print and compare

        A plain object prints as something like `<__main__.Plain object at 0x100743fa0>`: the class name and a memory location, which is not useful when debugging.

        Also, without instructions Python treats two instances as equal only if they are the very same object, even when every attribute matches.

        ```python
        class Plain:
            def __init__(self, value):
                self.value = value

        print(Plain(1) == Plain(1))
        same = Plain(1)
        print(same == same)
        ```

        ```text
        False
        True
        ```

        Methods whose names start and end with two underscores are **special methods**: Python calls them for you in particular situations. Two are worth writing for almost every class.

        ### How an object is displayed

        `__repr__(self)` must return a string describing the object; the name is short for representation. Python uses it whenever it displays the object:

        - `print(obj)`
        - `repr(obj)`
        - when the object is inside a displayed list.

        A good repr looks like the code that would recreate the object.

        The built-in `repr(value)` returns that text for any value. For a string it includes the quotes, so `repr("orbit")` is `'orbit'` with the quote characters.

        Inside f-string braces, writing `!r` after the expression inserts its repr instead of its plain text: `f"{name!r}"` gives `'orbit'` with quotes when `name` is `"orbit"`.

        ### What == means

        `__eq__(self, other)` decides what `==` means. Python calls it with the left object as `self` and the right value as `other`, and uses its returned `True` or `False`. `!=` automatically gives the opposite.

        The other value might not be the same kind of object at all, so check first with `isinstance`. If it is a different kind, return the special built-in value `NotImplemented` (no quotes, no parentheses).

        `NotImplemented` means “this method does not know how to compare with that value”. Python then falls back to its default, and `==` produces `False` rather than crashing.

        ```python
        class Run:
            def __init__(self, model, seconds):
                self.model = model
                self.seconds = seconds

            def __repr__(self):
                return f"Run(model={self.model!r}, seconds={self.seconds})"

            def __eq__(self, other):
                if not isinstance(other, Run):
                    return NotImplemented
                return self.model == other.model and self.seconds == other.seconds

        first = Run("orbit", 1.5)
        print(first)
        print([first, Run("nova", 2)])
        print(first == Run("orbit", 1.5))
        print(first == Run("orbit", 2.0))
        print(first == "orbit")
        ```

        ```text
        Run(model='orbit', seconds=1.5)
        [Run(model='orbit', seconds=1.5), Run(model='nova', seconds=2)]
        True
        False
        False
        ```

        Equality now compares the attributes that matter.

        > **Note:** A class that defines `__eq__` can no longer be stored in a set or used as a dictionary key unless you also make it hashable, a topic for later chapters. Lists of such objects work normally.

        ## Class attributes, instance attributes, and aliasing

        ### Two kinds of attribute

        - An assignment written directly in the class body, outside any method, creates a **class attribute**: one value stored on the class itself and shared by every instance.
        - Attributes assigned through `self` are **instance attributes**, stored separately on each object.

        When you read `self.pass_mark`, Python looks on the instance first and, if it is not there, on the class.

        Class attributes suit settings and constants that should be the same for every instance unless deliberately changed.

        ```python
        class Grader:
            pass_mark = 0.8

            def __init__(self, name):
                self.name = name

            def passes(self, score):
                return score >= self.pass_mark

        strict = Grader("strict")
        relaxed = Grader("relaxed")
        relaxed.pass_mark = 0.5
        print(strict.passes(0.6), relaxed.passes(0.6))
        Grader.pass_mark = 0.6
        print(strict.passes(0.6), strict.pass_mark, relaxed.pass_mark)
        ```

        ```text
        False True
        True 0.6 0.5
        ```

        - Assigning `relaxed.pass_mark` created an instance attribute on `relaxed` only; it hides (shadows) the class value for that object.
        - Changing `Grader.pass_mark` through the class affected `strict`, which had no value of its own, but not `relaxed`.
        - Reading `self.pass_mark` inside methods, rather than retyping `0.8`, keeps both behaviours working.

        ### Aliasing

        Variables do not hold copies of objects; they are names that refer to objects. `b = a` makes a second name for the same object. This is called **aliasing**.

        - `is` checks whether two names refer to the same object.
        - `==` checks whether the values are equal.

        If an object is mutable, a change made through one name is visible through every alias, including attributes that store the object.

        ```python
        class Playlist:
            def __init__(self, songs):
                self.songs = songs

        mine = ["intro", "outro"]
        playlist = Playlist(mine)
        alias = playlist
        alias.songs.append("bonus")
        print(playlist.songs)
        print(mine)
        print(alias is playlist)

        safe = Playlist(list(mine))
        safe.songs.append("extra")
        print(len(mine), len(safe.songs))
        ```

        ```text
        ['intro', 'outro', 'bonus']
        ['intro', 'outro', 'bonus']
        True
        3 4
        ```

        - `alias` and `playlist` are one object, and its `songs` attribute is the caller's own list `mine`, so appending changed all three views.
        - `list(mine)` builds a new list with the same items, so `safe` can change its copy without touching `mine`.
        - When a method should leave the original alone, build and return a new instance instead of changing `self`: `return Playlist(self.songs + ["extra"])`.

        > **Watch out:** A class attribute that is a list, such as `members = []` in a class body, is one list shared by every instance, which is almost never what you want. Create mutable attributes in `__init__`.

        ## Let @dataclass write the boilerplate

        Many classes are mostly data. They need:

        - an `__init__` that copies parameters to attributes,
        - a `__repr__` listing them,
        - an `__eq__` comparing them.

        Python's standard library module `dataclasses` can write those three methods for you.

        ### Importing names from a module

        You know `import json` followed by `json.loads(...)`. The line `from dataclasses import dataclass, field` is a related form.

        It takes the two names `dataclass` and `field` out of the `dataclasses` module so you can use them directly, without the `dataclasses.` prefix.

        ### Decorating the class

        Writing `@dataclass` on the line directly above `class` is called **decorating** the class: after Python builds the class, `dataclass` adds the generated methods to it.

        How decorators work in general is taught later; here you only need to place the line correctly.

        In the class body, list each field as `name: type`. The part after the colon is a **type annotation**: a label documenting the expected kind of value. Python does not check or convert it.

        - A field can have a default value with `= value`.
        - Fields with defaults must come after fields without them.
        - The generated `__init__` takes the fields as parameters in the order written.

        ### Defaults that are lists

        A default must not be a mutable object such as `[]`, because every instance would share that one list; `dataclass` refuses with an error.

        `field(default_factory=list)` instead gives a function to call for each new instance. `list` called with no arguments returns a new empty list, so every instance gets its own.

        ```python
        from dataclasses import dataclass, field

        @dataclass
        class Sample:
            text: str
            tokens: int = 0
            labels: list = field(default_factory=list)

        a = Sample("hello")
        b = Sample("hello", 0, [])
        a.labels.append("greeting")
        print(a)
        print(b)
        print(a == Sample("hello", labels=["greeting"]))
        print(b.labels)
        ```

        ```text
        Sample(text='hello', tokens=0, labels=['greeting'])
        Sample(text='hello', tokens=0, labels=[])
        True
        []
        ```

        - The generated `__init__` accepts positional or keyword arguments.
        - `__repr__` shows every field.
        - `__eq__` compares all fields in order.
        - The list in `a` did not leak into `b`.

        > **Note:** You can still add your own methods to a dataclass body, written exactly like methods in an ordinary class.

        ## Custom exceptions and debugging

        Exception types such as `ValueError` are classes too. You can define your own, more specific error type by naming an existing exception in parentheses after the class name: `class BudgetError(ValueError):`.

        This makes `BudgetError` a specialized kind of `ValueError`. The full idea, called inheritance, is taught in a later chapter.

        The keyword `pass` is a statement that does nothing; it fills a block that must not be empty. The new class needs no body of its own, because it reuses everything from `ValueError`, including the message argument.

        ```python
        class BudgetError(ValueError):
            pass

        def charge(remaining, cost):
            if cost > remaining:
                raise BudgetError(f"cost {cost} exceeds remaining {remaining}")
            return remaining - cost

        print(charge(10, 4))
        try:
            charge(3, 5)
        except BudgetError as error:
            print("BudgetError:", error)
        try:
            charge(1, 2)
        except ValueError as error:
            print(isinstance(error, BudgetError), isinstance(error, ValueError))
        ```

        ```text
        6
        BudgetError: cost 5 exceeds remaining 3
        True True
        ```

        - A caller can catch the precise `BudgetError`, while code that already catches `ValueError` still works.
        - A specific name tells readers exactly what went wrong.

        ### Common mistakes and how to debug them

        - Forgetting `self` as the first method parameter gives `TypeError: ... takes 1 positional argument but 2 were given`.
        - Writing `name = name` instead of `self.name = name` in `__init__` only assigns a local variable; the object has no attribute and a later read raises `AttributeError`.
        - Misspelling `__init__` (for example with one underscore) means Python never calls it.
        - Forgetting the parentheses, as in `budget.remaining` instead of `budget.remaining()`, gives the method itself rather than its result.
        - A `__repr__` must return a string, not print one.
        - When two objects unexpectedly change together, check for aliasing with `is`.

        > **Tip:** Print an object to inspect it; a useful `__repr__` makes that output readable.
        """,
        exercises: [
            exercise("classes-budget", "Model a token budget", """
                     Goal:
                     Write a class that remembers how many tokens an invented project has used. A **token** is a counted unit of text; a **budget** is the maximum number of tokens the owner may use.

                     Starting code:
                     - `class TokenBudget:` is supplied with three methods. Keep the class name, method names and parameters; replace the placeholder bodies.
                     - `__init__(self, owner, limit)` currently stores the placeholders `''` and `0` instead of its arguments.
                     - `remaining(self)` returns the placeholder `0`.
                     - `spend(self, tokens)` returns the placeholder `False`.

                     Your task:
                     1. In `__init__`, save the `owner` argument (a string) as the attribute `self.owner`.
                     2. Save the `limit` argument (a nonnegative integer) as `self.limit`.
                     3. Create `self.used` with the starting value `0` for every new budget.
                     4. Make `remaining(self)` return the integer number of tokens still available: the limit minus the tokens used so far.
                     5. Make `spend(self, tokens)` accept a nonnegative integer. If `tokens` is at most the remaining amount, add it to `self.used` and return `True`. Spending exactly the remaining amount is allowed, and spending `0` is allowed.
                     6. If `tokens` is larger than the remaining amount, leave `self.used` unchanged and return `False`.
                     7. Make sure each instance keeps its own `owner`, `limit` and `used` values; creating or changing one budget must not affect another.

                     Expected result:
                     After `budget = TokenBudget('mira', 100)`:

                     - `budget.owner` is `'mira'`, `budget.limit` is `100`, `budget.used` is `0`, and `budget.remaining()` is `100`.
                     - `budget.spend(30)` returns `True`; then `budget.used` is `30` and `budget.remaining()` is `70`.
                     - `budget.spend(71)` then returns `False` and `budget.used` stays `30`.
                     - `budget.spend(70)` returns `True` and `budget.remaining()` becomes `0`.
                     - A separate `TokenBudget('leo', 5)` starts with `used` equal to `0` and `remaining()` returning `5`.

                     Check:
                     Choose **Check solution**. It creates several budgets and checks every attribute, exact-boundary and over-limit spending, zero spending, and that budgets stay independent.
                     """,
                     "class TokenBudget:\n    def __init__(self, owner, limit):\n        self.owner = ''\n        self.limit = 0\n        self.used = 0\n\n    def remaining(self):\n        return 0\n\n    def spend(self, tokens):\n        return False\n",
                     "class TokenBudget:\n    def __init__(self, owner, limit):\n        self.owner = owner\n        self.limit = limit\n        self.used = 0\n\n    def remaining(self):\n        return self.limit - self.used\n\n    def spend(self, tokens):\n        if tokens > self.remaining():\n            return False\n        self.used = self.used + tokens\n        return True\n",
                     "budget = TokenBudget('mira', 100)\nassert budget.owner == 'mira' and budget.limit == 100 and budget.used == 0\nassert budget.remaining() == 100\nassert budget.spend(30) is True\nassert budget.used == 30 and budget.remaining() == 70\nassert budget.spend(0) is True and budget.used == 30\nassert budget.spend(71) is False\nassert budget.used == 30\nassert budget.spend(70) is True\nassert budget.remaining() == 0\nassert budget.spend(1) is False and budget.used == 100\nother = TokenBudget('leo', 5)\nassert other.owner == 'leo' and other.used == 0 and other.remaining() == 5\nassert budget.used == 100 and budget.limit == 100\nempty = TokenBudget('zero', 0)\nassert empty.remaining() == 0 and empty.spend(0) is True and empty.spend(1) is False\n",
                     ["Inside a method, `self` is the particular budget being used. Attributes written as `self.something` belong to that one object, so separate budgets never share them.", "`__init__` should copy each argument onto `self` and start `used` at `0`. `remaining` can compute its answer from two attributes rather than storing a third number.", "In `spend`, compare `tokens` with the result of calling `self.remaining()`. Only when it fits, update `self.used` by adding `tokens`; return `True` or `False` to report which case happened."], effort: .init(difficulty: .similar, scopeUnits: 3)),
            exercise("classes-results", "Print and compare evaluation results", """
                     Goal:
                     Make an evaluation-result class that displays clearly, compares by value, and uses a shared pass mark. An **evaluation result** records one invented model's score on a test; it passes when the score reaches the pass mark.

                     Starting code:
                     - `class EvalResult:` is supplied. Keep every name and parameter.
                     - `__init__(self, model, score)` is already complete: it stores `self.model` (a string) and `self.score` (a number). Leave it unchanged.
                     - The class attribute `pass_mark = 0` is a placeholder.
                     - `passed` returns `False`, `with_score` returns `self`, `__repr__` returns `''`, and `__eq__` returns `False`. All four are placeholders to replace.

                     Your task:
                     1. Change the class attribute `pass_mark` to `0.8`. Keep it in the class body; do not assign it in `__init__`.
                     2. Make `passed(self)` return `True` when `self.score` is at least the pass mark (exactly `0.8` passes) and `False` otherwise.
                     3. Inside `passed`, read the pass mark through `self.pass_mark` rather than writing `0.8` again, so changing `EvalResult.pass_mark` changes the result.
                     4. Make `with_score(self, new_score)` return a new `EvalResult` with the same model and the new score. Do not change the original object.
                     5. Make `__repr__` return exactly `EvalResult(model='orbit', score=0.8)` for `EvalResult('orbit', 0.8)`: the model's repr (with quotes) and the score as Python normally displays it. The lesson's `!r` f-string marker produces the quoted model.
                     6. Make `__eq__` return `True` when `other` is also an `EvalResult` with an equal model and an equal score, and `False` when either differs.
                     7. Inside `__eq__`, if `other` is not an `EvalResult`, return `NotImplemented` so that comparing with a string gives `False`.

                     Expected result:
                     - `EvalResult('orbit', 0.8).passed()` is `True` and `EvalResult('nova', 0.79).passed()` is `False`.
                     - `repr(EvalResult('a b', 1))` is `"EvalResult(model='a b', score=1)"`.
                     - A list containing `EvalResult('nova', 0.79)` displays as `[EvalResult(model='nova', score=0.79)]`.
                     - `EvalResult('orbit', 0.8) == EvalResult('orbit', 0.8)` is `True`; changing the score or the model's case makes them unequal.
                     - `EvalResult('orbit', 0.8) == 'orbit'` is `False`.
                     - For `low = EvalResult('nova', 0.79)`, `low.with_score(0.95)` returns a different object with model `'nova'` and score `0.95`, while `low.score` stays `0.79`.

                     Check:
                     Choose **Check solution**. It checks the class attribute, boundary scores, a changed class pass mark, exact repr text, equality and inequality, comparison with a string, and that `with_score` leaves the original unchanged.
                     """,
                     "class EvalResult:\n    pass_mark = 0\n\n    def __init__(self, model, score):\n        self.model = model\n        self.score = score\n\n    def passed(self):\n        return False\n\n    def with_score(self, new_score):\n        return self\n\n    def __repr__(self):\n        return ''\n\n    def __eq__(self, other):\n        return False\n",
                     "class EvalResult:\n    pass_mark = 0.8\n\n    def __init__(self, model, score):\n        self.model = model\n        self.score = score\n\n    def passed(self):\n        return self.score >= self.pass_mark\n\n    def with_score(self, new_score):\n        return EvalResult(self.model, new_score)\n\n    def __repr__(self):\n        return f'EvalResult(model={self.model!r}, score={self.score})'\n\n    def __eq__(self, other):\n        if not isinstance(other, EvalResult):\n            return NotImplemented\n        return self.model == other.model and self.score == other.score\n",
                     "assert EvalResult.pass_mark == 0.8\nlow = EvalResult('nova', 0.79)\nedge = EvalResult('orbit', 0.8)\nassert low.passed() is False and edge.passed() is True\nEvalResult.pass_mark = 0.9\nchanged = edge.passed()\nEvalResult.pass_mark = 0.8\nassert changed is False, 'passed must read the shared pass_mark'\nassert repr(edge) == \"EvalResult(model='orbit', score=0.8)\"\nassert repr(EvalResult('a b', 1)) == \"EvalResult(model='a b', score=1)\"\nassert str([low]) == \"[EvalResult(model='nova', score=0.79)]\"\nassert EvalResult('orbit', 0.8) == edge\nassert edge != EvalResult('orbit', 0.9)\nassert edge != EvalResult('Orbit', 0.8)\nassert (edge == 'orbit') is False\nbetter = low.with_score(0.95)\nassert isinstance(better, EvalResult) and better is not low\nassert better.model == 'nova' and better.score == 0.95 and better.passed()\nassert low.score == 0.79 and low.passed() is False\n",
                     ["A class attribute lives in the class body and is shared; methods reach it through `self` just like an instance attribute. Special methods are called by Python itself: `print` and `repr` use `__repr__`, and `==` uses `__eq__`.", "`__repr__` must return a string built from `self.model` and `self.score`; an f-string with `!r` after the model adds its quotes. `with_score` should call the class to build a fresh object instead of assigning to `self.score`.", "In `__eq__`, first test `isinstance(other, EvalResult)` and return `NotImplemented` when it fails; otherwise combine two `==` comparisons of model and score with `and`."], effort: .init(difficulty: .similar, scopeUnits: 4)),
            exercise("classes-dataset", "Describe datasets with a dataclass", """
                     Goal:
                     Describe invented training datasets with a dataclass and reject bad tags with your own exception type. A **dataset** here is a named collection of rows; **tags** are short text labels describing it.

                     Starting code:
                     - `from dataclasses import dataclass, field` is supplied. Keep it.
                     - `class DatasetError(Exception): pass` is a placeholder exception whose parent type must change.
                     - The `@dataclass` class `Dataset` declares `name: str`, `rows: int = -1` and `tags: list = None`. Both defaults are placeholders.
                     - `add_tag(self, tag)` returns the placeholder `0`.
                     - Keep all names and the field order `name`, `rows`, `tags`.

                     Your task:
                     1. Change `DatasetError` so it is a specialized `ValueError`: write `ValueError` inside its parentheses. Keep `pass` as its body.
                     2. Give `rows` the default `0`.
                     3. Give `tags` a default that creates a new empty list for every instance, using `field(default_factory=list)`. Two datasets created without tags must not share one list.
                     4. Keep `@dataclass` so Python generates `__init__`, `__repr__` and `__eq__`; do not write those methods yourself.
                     5. Make `add_tag(self, tag)` take a string and remove surrounding whitespace from it.
                     6. If the cleaned tag is empty, or is already in `self.tags`, raise `DatasetError` with any nonempty message and leave `self.tags` unchanged.
                     7. Otherwise, append the cleaned tag to `self.tags` and return the new number of tags as an integer.

                     Expected result:
                     - `Dataset('faq')` has `rows` equal to `0` and `tags` equal to `[]`.
                     - `repr(Dataset('chat', 12))` is `"Dataset(name='chat', rows=12, tags=[])"`.
                     - For `first = Dataset('faq')`: `first.add_tag(' support ')` returns `1` and `first.add_tag('english')` returns `2`.
                     - `first.tags` is then `['support', 'english']`, while another new `Dataset('reviews')` still has `tags` equal to `[]`.
                     - `first == Dataset('faq', 0, ['support', 'english'])` is `True`.
                     - Adding `'support'`, `' english'`, `''` or `'   '` again raises `DatasetError`, which an `except ValueError` block also catches.

                     Check:
                     Choose **Check solution**. It checks the defaults, separate tag lists, generated repr and equality, cleaned tags and returned counts, and that duplicate or blank tags raise `DatasetError` (a `ValueError`) without changing the list.
                     """,
                     "from dataclasses import dataclass, field\n\n\nclass DatasetError(Exception):\n    pass\n\n\n@dataclass\nclass Dataset:\n    name: str\n    rows: int = -1\n    tags: list = None\n\n    def add_tag(self, tag):\n        return 0\n",
                     "from dataclasses import dataclass, field\n\n\nclass DatasetError(ValueError):\n    pass\n\n\n@dataclass\nclass Dataset:\n    name: str\n    rows: int = 0\n    tags: list = field(default_factory=list)\n\n    def add_tag(self, tag):\n        cleaned = tag.strip()\n        if cleaned == '' or cleaned in self.tags:\n            raise DatasetError(f'cannot add tag {tag!r}')\n        self.tags.append(cleaned)\n        return len(self.tags)\n",
                     "first = Dataset('faq')\nassert first.rows == 0 and first.tags == []\nsecond = Dataset('reviews')\nassert first.tags is not second.tags\nassert first.add_tag(' support ') == 1\nassert first.add_tag('english') == 2\nassert first.tags == ['support', 'english'] and second.tags == []\nassert first == Dataset('faq', 0, ['support', 'english'])\nassert repr(Dataset('chat', 12)) == \"Dataset(name='chat', rows=12, tags=[])\"\nassert Dataset('chat', 12) != Dataset('chat', 13)\nfor bad in ['support', ' english', '', '   ']:\n    raised = False\n    try:\n        first.add_tag(bad)\n    except DatasetError as error:\n        raised = isinstance(error, ValueError) and bool(str(error))\n    assert raised, 'duplicate or blank tags must raise DatasetError with a message'\nassert first.tags == ['support', 'english']\ncaught = False\ntry:\n    raise DatasetError('demo')\nexcept ValueError:\n    caught = True\nassert caught\n",
                     ["The name in parentheses after a class name decides what kind of exception it is. `@dataclass` already writes `__init__`, `__repr__` and `__eq__` from the field lines, so most of the work is choosing correct defaults.", "A list default must come from `field(default_factory=list)` so each instance calls `list()` for its own new list. In `add_tag`, clean the text with `strip` before checking it.", "Check the two failure cases (empty after cleaning, or already in `self.tags`) and raise `DatasetError` before appending anything. Only then append the cleaned tag and return `len(self.tags)`."], effort: .init(difficulty: .similar, scopeUnits: 4))
        ],
        assessment: exercise("classes-assessment", "Build a capacity-limited job queue", """
                             Goal:
                             Model a small queue of invented processing jobs. A job has a name and a token count; a **queue** holds jobs in the order they were added, up to a **capacity** (the maximum number of jobs).

                             Starting code:
                             - `from dataclasses import dataclass` is supplied. Keep it.
                             - `class QueueFullError(Exception): pass` has the wrong parent type.
                             - The `@dataclass` class `Job` declares `name: str` and `tokens: int = -1` (a placeholder default).
                             - `class JobQueue` has the class attribute `capacity = 0` (a placeholder).
                             - `JobQueue.__init__(self, name)` stores the placeholders `''` and `None`.
                             - The methods `add`, `total_tokens`, `__repr__` and `__eq__` return placeholders.
                             - Keep all class names, method names, parameters and the field order of `Job`.

                             Your task:
                             1. Make `QueueFullError` a specialized `ValueError`.
                             2. Give the `tokens` field of `Job` the default `0`. Keep `Job` a dataclass so it compares and displays by its fields.
                             3. Set the `JobQueue` class attribute `capacity` to `3`.
                             4. In `__init__`, store the `name` argument as `self.name` and give every queue its own new empty list in `self.jobs`.
                             5. Make `add(self, job)` append `job` to `self.jobs` and return the new number of jobs.
                             6. If the queue already holds `self.capacity` jobs, make `add` raise `QueueFullError` with a nonempty message instead, and leave the list unchanged. Read the limit through `self.capacity` so one queue can be given its own `capacity` attribute.
                             7. Make `total_tokens(self)` return the integer sum of the tokens of all jobs in the queue (`0` when empty).
                             8. Make `__repr__` return exactly `JobQueue('night', jobs=2)` for a queue named `'night'` holding two jobs: the name's repr, then `jobs=` and the job count.
                             9. Make `__eq__` return `True` when `other` is a `JobQueue` with an equal name and equal jobs in the same order, `False` when either differs, and `NotImplemented` when `other` is not a `JobQueue`.

                             Expected result:
                             - `Job('warmup').tokens` is `0` and `repr(Job('embed', 40))` is `"Job(name='embed', tokens=40)"`.
                             - `night = JobQueue('night')` starts with `jobs` equal to `[]` and `total_tokens()` returning `0`.
                             - Adding `Job('embed', 40)`, `Job('warmup')` and `Job('chat', 15)` returns `1`, `2`, `3`, and `total_tokens()` becomes `55`, while a separate `JobQueue('day')` still has no jobs.
                             - A fourth `add` raises `QueueFullError`, which `except ValueError` also catches, and the queue keeps 3 jobs.
                             - The repr of that queue is `JobQueue('night', jobs=3)`.
                             - A different `JobQueue('night')` given the same three jobs is equal to it.
                             - `JobQueue('day') != JobQueue('Day')`, and comparing a queue with the string `'night'` gives `False`.

                             Check:
                             Complete the theory questions and written explanation, then choose **Submit assessment**. It checks the dataclass defaults, the class and instance attributes, separate job lists, adding up to and beyond capacity, a per-queue capacity, token totals, exact repr text and equality. Work independently without hints or solutions.
                             """,
                             "from dataclasses import dataclass\n\n\nclass QueueFullError(Exception):\n    pass\n\n\n@dataclass\nclass Job:\n    name: str\n    tokens: int = -1\n\n\nclass JobQueue:\n    capacity = 0\n\n    def __init__(self, name):\n        self.name = ''\n        self.jobs = None\n\n    def add(self, job):\n        return 0\n\n    def total_tokens(self):\n        return 0\n\n    def __repr__(self):\n        return ''\n\n    def __eq__(self, other):\n        return False\n",
                             "from dataclasses import dataclass\n\n\nclass QueueFullError(ValueError):\n    pass\n\n\n@dataclass\nclass Job:\n    name: str\n    tokens: int = 0\n\n\nclass JobQueue:\n    capacity = 3\n\n    def __init__(self, name):\n        self.name = name\n        self.jobs = []\n\n    def add(self, job):\n        if len(self.jobs) >= self.capacity:\n            raise QueueFullError(f'{self.name} is full')\n        self.jobs.append(job)\n        return len(self.jobs)\n\n    def total_tokens(self):\n        return sum([job.tokens for job in self.jobs])\n\n    def __repr__(self):\n        return f'JobQueue({self.name!r}, jobs={len(self.jobs)})'\n\n    def __eq__(self, other):\n        if not isinstance(other, JobQueue):\n            return NotImplemented\n        return self.name == other.name and self.jobs == other.jobs\n",
                             "assert Job('warmup').tokens == 0\nassert Job('embed', 40) == Job('embed', 40) and Job('embed', 40) != Job('embed', 41)\nassert repr(Job('embed', 40)) == \"Job(name='embed', tokens=40)\"\nassert JobQueue.capacity == 3\nnight = JobQueue('night')\nday = JobQueue('day')\nassert night.name == 'night' and night.jobs == [] and night.total_tokens() == 0\nassert night.jobs is not day.jobs\nassert repr(night) == \"JobQueue('night', jobs=0)\"\nassert night.add(Job('embed', 40)) == 1\nassert night.add(Job('warmup')) == 2\nassert night.add(Job('chat', 15)) == 3\nassert day.jobs == [] and night.total_tokens() == 55\nassert repr(night) == \"JobQueue('night', jobs=3)\"\nraised = False\ntry:\n    night.add(Job('late', 5))\nexcept QueueFullError as error:\n    raised = isinstance(error, ValueError) and bool(str(error))\nassert raised, 'a full queue must raise QueueFullError with a message'\nassert len(night.jobs) == 3 and night.total_tokens() == 55\ntwin = JobQueue('night')\nassert twin != night\nfor job in [Job('embed', 40), Job('warmup'), Job('chat', 15)]:\n    twin.add(job)\nassert twin == night and twin is not night\nassert JobQueue('day') != JobQueue('Day')\nassert (night == 'night') is False\nsmall = JobQueue('tiny')\nsmall.capacity = 1\nassert small.add(Job('one', 1)) == 1\ncaught = False\ntry:\n    small.add(Job('two', 2))\nexcept ValueError:\n    caught = True\nassert caught and JobQueue.capacity == 3\n",
                             [], effort: .init(difficulty: .similar, scopeUnits: 5)),
        quiz: [
            question("classes-q1", "After first = TokenBudget('mira', 100), then second = first, then second.spend(30), what is first.used?", ["0, because second is a separate copy", "30, because both names refer to the same object", "An AttributeError, because first was never changed"], 1, "Assignment creates an alias, not a copy. first and second are one object, so a change made through either name is visible through both."),
            question("classes-q2", "In def add(self, amount): called as counter.add(5), what is self?", ["The number 5", "The class Counter itself", "The instance counter that the method was called on"], 2, "Python passes the instance before the dot as the first argument, self. The explicit argument 5 becomes amount."),
            question("classes-q3", "Why write tags: list = field(default_factory=list) in a dataclass instead of tags: list = []?", ["So every instance gets its own new empty list rather than sharing one", "Because annotations force Python to convert values into lists", "Because field makes the attribute read-only"], 0, "A single [] default would be shared by every instance, so dataclass rejects it. default_factory calls list() once per new instance. Annotations are labels and are not enforced.")
        ],
        sectionRoles: ["Bundle data with the behaviour that uses it": .overview])
}
