import Foundation

extension Curriculum {
    static let inheritance = Chapter(
        id: "inheritance", title: "Inheritance and class design", subtitle: "Reuse, specialise, and combine classes",
        track: .softwareCraft, prerequisites: ["classes"],
        lesson: """
        # Build new classes from existing ones

        In the classes chapter you wrote each class from scratch. Real programs often contain several classes that share most of their behaviour:

        - a chat model card and an image model card both have a name and a version;
        - a flat price plan and a metered price plan both have a monthly fee.

        Copying the same methods into every class makes code long, and a later fix must be repeated everywhere.

        > **Key idea:** **Inheritance** lets a new class start with everything another class already has, and then add or change only the parts that differ.

        ### Some vocabulary

        - The existing class is called the **parent class** (also *base class* or *superclass*).
        - The new class is the **child class** or **subclass**.

        You have already seen the syntax once: a custom exception such as `class BudgetError(Exception)` is a subclass of Python's `Exception`.

        This chapter explains what that parenthesised name really does and how to design your own families of classes.

        ## Make a subclass

        To make a subclass, write the parent's name in parentheses after the new class name.

        The child **inherits** the parent's methods: an instance of the child can call them as if they were written in the child.

        ```python
        class Device:
            def __init__(self, name):
                self.name = name

            def describe(self):
                return f"device {self.name}"


        class Speaker(Device):
            def speaker_label(self):
                return f"{self.name} speaker"


        box = Speaker("kitchen")
        print(box.describe())
        print(box.speaker_label())
        assert box.name == "kitchen"
        ```

        ```text
        device kitchen
        kitchen speaker
        ```

        Here is what happened:

        - `Speaker` defines no `__init__`, so `Speaker("kitchen")` uses the parent's `__init__`, which saves `self.name`.
        - When you call `box.describe()`, Python first looks for `describe` in `Speaker`. It is not there, so Python looks in the parent `Device` and uses that method.

        This search from child to parent is called **method lookup**.

        ### Inheritance only flows downward

        A plain `Device("plug")` has no `speaker_label` method; calling it raises `AttributeError`.

        > **Tip:** Read a subclass as an **is-a** relationship: every speaker *is a* device, but not every device is a speaker.

        ### A subclass that adds nothing yet

        Sometimes a subclass adds nothing yet. Python requires an indented body after the colon, so write `pass`, a statement that does nothing.

        For example, `class Lamp(Device):` followed by an indented `pass` line creates a subclass that behaves exactly like `Device`.

        ## Override methods and call the parent with super()

        A child **overrides** a method by defining a method with the same name.

        - Method lookup finds the child's version first, so it wins for child instances.
        - Parent instances keep using the parent's version.

        Often you do not want to replace the parent's work completely, only to extend it. `super()` gives you access to the parent's version of a method from inside the child: `super().describe()` runs `Device.describe` on the current object.

        ### Extending `__init__`

        The most common use is `__init__`. A child that needs extra attributes:

        1. defines its own `__init__`;
        2. calls `super().__init__(...)` with the arguments the parent expects;
        3. then saves its own attributes.

        ```python
        class Device:
            def __init__(self, name):
                self.name = name

            def describe(self):
                return f"device {self.name}"


        class Thermostat(Device):
            def __init__(self, name, target):
                super().__init__(name)
                self.target = target

            def describe(self):
                base = super().describe()
                return f"{base} set to {self.target}C"


        heater = Thermostat("hall", 21)
        print(heater.name)
        print(heater.describe())
        print(Device("plug").describe())
        ```

        ```text
        hall
        device hall set to 21C
        device plug
        ```

        - You do not pass `self` to `super().__init__(name)`. Python supplies it, just like an ordinary method call.
        - Because the child reuses the parent's text through `super().describe()`, a later change to the parent's format automatically appears in the child too.

        ### Overrides reach parent methods that use self

        Overriding also affects parent methods that call other methods through `self`.

        `self` is always the actual object, so a parent method that calls `self.title()` uses the child's `title` when the object is a child instance:

        ```python
        class Report:
            def title(self):
                return "report"

            def heading(self):
                return self.title().upper()


        class EvalReport(Report):
            def title(self):
                return "eval report"


        assert Report().heading() == "REPORT"
        assert EvalReport().heading() == "EVAL REPORT"
        ```

        `EvalReport` did not rewrite `heading`, yet its heading changed, because `heading` asked `self` for its title.

        ## isinstance with class hierarchies

        A **class hierarchy** is a family of classes connected by inheritance.

        You met `isinstance(value, str)` in the reliability chapter. With your own classes, three related checks are useful:

        - `isinstance(obj, SomeClass)` is `True` when `obj` was created from `SomeClass` *or from any subclass of it*.
        - `type(obj) is SomeClass` is stricter: it is `True` only for the exact class.
        - `issubclass(Child, Parent)` asks the same question about two classes rather than an object.

        ```python
        class Device:
            def __init__(self, name):
                self.name = name


        class Speaker(Device):
            pass


        class SmartSpeaker(Speaker):
            pass


        item = SmartSpeaker("den")
        assert isinstance(item, SmartSpeaker)
        assert isinstance(item, Speaker)
        assert isinstance(item, Device)
        assert type(item) is not Speaker
        assert issubclass(SmartSpeaker, Device)
        assert not isinstance(Device("plug"), Speaker)


        def kind(thing):
            if isinstance(thing, SmartSpeaker):
                return "smart speaker"
            elif isinstance(thing, Speaker):
                return "speaker"
            elif isinstance(thing, Device):
                return "device"
            raise TypeError("expected a Device")


        print(kind(item))
        print(kind(Speaker("hall")))
        print(kind(Device("plug")))
        ```

        ```text
        smart speaker
        speaker
        device
        ```

        > **Watch out:** Check the **most specific** class first. If `kind` tested `Device` first, every object would match it and the other branches would never run.

        ### Raising TypeError

        `TypeError` is Python's standard exception for "this value has the wrong type". You raise it exactly like `ValueError`: `raise TypeError("message")`.

        Use `isinstance` with a parent class when any member of the family is acceptable. For example, a function that needs *some* kind of device should accept speakers and thermostats too.

        ## Computed attributes with @property

        A line starting with `@` directly above a `def` is a **decorator**: it changes how the definition below it behaves. You may have seen `@dataclass` above a class.

        `@property` turns a method into a **property**:

        - you read it like an attribute, *without parentheses*;
        - Python runs the method each time, so the value is always computed from the current attributes.

        ```python
        class Rectangle:
            def __init__(self, width, height):
                self.width = width
                self.height = height

            @property
            def area(self):
                return self.width * self.height


        class Garden(Rectangle):
            def __init__(self, width, height, path_area):
                super().__init__(width, height)
                self.path_area = path_area

            @property
            def area(self):
                return super().area - self.path_area


        plot = Garden(4, 3, 2)
        print(plot.area)
        plot.width = 5
        print(plot.area)
        print(Rectangle(4, 3).area)
        try:
            plot.area = 99
        except AttributeError:
            print("area is read-only")
        ```

        ```text
        10
        13
        12
        area is read-only
        ```

        - After `plot.width` changed, `plot.area` updated by itself because it is recomputed on every read. A value saved once in `__init__` would have gone stale.
        - A subclass can override a property by defining a property with the same name.
        - `super().area` (again without parentheses) reads the parent's version.
        - A property defined this way cannot be assigned to: the assignment raises `AttributeError`.

        ### Two typical mistakes

        - Writing `plot.area()` calls the number that the property returned and fails with `TypeError: 'int' object is not callable`.
        - Forgetting the `@property` line makes `plot.area` give you the method itself (displayed as something like `<bound method ...>`) instead of a number.

        ## Abstract base classes with abc

        Sometimes a parent class is only a template: every scorer must have a `score` method, but there is no sensible "general" scorer.

        The standard library module `abc` (abstract base classes) expresses this.

        ### Importing the two names

        `from abc import ABC, abstractmethod` is a form of import that makes the two names `ABC` and `abstractmethod` available directly, so you can write `ABC` instead of `abc.ABC`.

        ### Abstract and concrete classes

        - A class that inherits from `ABC` and marks a method with `@abstractmethod` is **abstract**: Python refuses to create instances of it, raising `TypeError`.
        - A subclass becomes **concrete** (creatable) only after it overrides every abstract method.
        - The abstract method's body is usually just `pass`, because it is never meant to run.
        - Ordinary methods in the abstract class may call the abstract ones; they will use the subclass's implementation.

        ```python
        from abc import ABC, abstractmethod


        class Shape(ABC):
            @abstractmethod
            def area(self):
                pass

            def describe(self):
                return f"area {self.area()}"


        class Square(Shape):
            def __init__(self, side):
                self.side = side

            def area(self):
                return self.side * self.side


        class Unfinished(Shape):
            pass


        print(Square(3).describe())
        try:
            Shape()
        except TypeError:
            print("Shape is abstract")
        try:
            Unfinished()
        except TypeError:
            print("Unfinished still has an abstract method")
        assert isinstance(Square(2), Shape)
        ```

        ```text
        area 9
        Shape is abstract
        Unfinished still has an abstract method
        ```

        > **Key idea:** The error appears when you try to *create* the object, so a forgotten method is caught early instead of failing later in the middle of a calculation.

        ## Choose composition or inheritance

        Inheritance models **is-a**. Many relationships are really **has-a**: a car *has an* engine; an evaluator *has a* scorer.

        For these, use **composition**: store the other object in an attribute and call its methods. Passing a call on to a stored object like this is called **delegation**.

        ```python
        class Engine:
            def __init__(self, horsepower):
                self.horsepower = horsepower

            def start(self):
                return f"engine {self.horsepower}hp running"


        class ElectricMotor:
            def start(self):
                return "motor humming"


        class Car:
            def __init__(self, name, power_source):
                self.name = name
                self.power_source = power_source

            def start(self):
                return f"{self.name}: {self.power_source.start()}"


        print(Car("hatch", Engine(90)).start())
        print(Car("city", ElectricMotor()).start())
        ```

        ```text
        hatch: engine 90hp running
        city: motor humming
        ```

        `Car` does not inherit from `Engine`. It works with any part that has a `start` method, and you can swap the part without writing a new car class.

        > **Tip:** As a rule of thumb, use inheritance when the child truly is a special kind of the parent and should be usable anywhere the parent is. Use composition when one object merely uses another.

        Composition and abstract classes combine well: an object can store "any `Shape`" and check it with `isinstance(part, Shape)`.

        ### Common mistakes and debugging

        - **Missing attribute.** If a child instance is missing an attribute the parent should set (`AttributeError: ... has no attribute 'name'`), the child's `__init__` probably forgot `super().__init__(...)`.
        - **Override ignored.** If an override seems ignored, check that the method name is spelled exactly like the parent's.
        - **Endless recursion.** If your new method calls itself instead of the parent (`RecursionError`), you wrote `self.describe()` where you meant `super().describe()`.
        - **Unsure of the class.** To see which class an object really came from, display `type(obj).__name__`.
        """,
        exercises: [
            exercise("inheritance-chat-card", "Extend a model card with a subclass", """
            Goal:
            Create a specialised model card by inheriting from a general one, reusing the parent's setup and label with `super()`.

            Starting code:
            - `class ModelCard` is complete. Do not change it.
            - `ModelCard.__init__(self, name, version)` saves `name` and `version`.
            - `ModelCard.label()` returns text such as `'orbit v2'`.
            - `ModelCard.is_ready()` returns `True` when `version` is at least `1`.
            - `class ChatModelCard(ModelCard)` is the subclass you complete. Its `__init__` only saves the placeholder `self.context_window = 0`, and its `label()` returns the placeholder `''`. Replace both placeholders.

            Your task:
            1. In `ChatModelCard.__init__(self, name, version, context_window)`, first call `super().__init__(name, version)` so the parent saves `name` and `version`.
            2. Then save the `context_window` argument as `self.context_window` (replace the `0` placeholder).
            3. Override `label(self)` so it returns the parent's label, one space, and then the context window in parentheses followed by `' tokens'`, for example `'orbit v2 (4096 tokens)'`.
            4. Build that label by calling `super().label()`, not by rewriting the parent's format, so that a change to `ModelCard.label` also changes the child's label.
            5. Do not define `is_ready` in `ChatModelCard`: it must be inherited unchanged.

            Expected result:
            - `ChatModelCard('orbit', 2, 4096).label()` returns `'orbit v2 (4096 tokens)'`.
            - That same card has `name` `'orbit'`, `version` `2` and `context_window` `4096`, and its `is_ready()` returns `True`.
            - `isinstance(card, ModelCard)` is `True`.
            - `ChatModelCard('draft', 0, 512).label()` returns `'draft v0 (512 tokens)'`, and its `is_ready()` returns `False`.
            - `ModelCard('base', 3).label()` is still `'base v3'`.

            Check:
            Choose **Check solution**. The checks create cards, temporarily change `ModelCard`'s `label` and `__init__` to confirm your subclass calls them through `super()`, and confirm `is_ready` is inherited rather than redefined.
            """, """
            class ModelCard:
                def __init__(self, name, version):
                    self.name = name
                    self.version = version

                def label(self):
                    return f"{self.name} v{self.version}"

                def is_ready(self):
                    return self.version >= 1


            class ChatModelCard(ModelCard):
                def __init__(self, name, version, context_window):
                    self.context_window = 0

                def label(self):
                    return ""
            """, """
            class ModelCard:
                def __init__(self, name, version):
                    self.name = name
                    self.version = version

                def label(self):
                    return f"{self.name} v{self.version}"

                def is_ready(self):
                    return self.version >= 1


            class ChatModelCard(ModelCard):
                def __init__(self, name, version, context_window):
                    super().__init__(name, version)
                    self.context_window = context_window

                def label(self):
                    return f"{super().label()} ({self.context_window} tokens)"
            """, """
            card = ChatModelCard("orbit", 2, 4096)
            assert card.label() == "orbit v2 (4096 tokens)"
            assert card.name == "orbit" and card.version == 2
            assert card.context_window == 4096
            assert card.is_ready() is True
            assert ChatModelCard("draft", 0, 512).is_ready() is False
            assert ChatModelCard("draft", 0, 512).label() == "draft v0 (512 tokens)"
            assert ModelCard("base", 3).label() == "base v3"
            assert isinstance(card, ModelCard)
            assert "is_ready" not in ChatModelCard.__dict__
            original_label = ModelCard.label
            ModelCard.label = lambda self: "[" + self.name + "]"
            patched_label = ChatModelCard("nova", 1, 64).label()
            ModelCard.label = original_label
            assert patched_label == "[nova] (64 tokens)", "Build the label with super().label()."
            original_init = ModelCard.__init__
            def tracking_init(self, name, version):
                original_init(self, name, version)
                self.parent_setup_ran = True
            ModelCard.__init__ = tracking_init
            tracked = ChatModelCard("nova", 1, 64)
            ModelCard.__init__ = original_init
            assert getattr(tracked, "parent_setup_ran", False), "Call super().__init__(name, version)."
            """, [
                "A subclass already has every parent method. Your job is only to add the extra attribute and adjust the label; keep `is_ready` out of the child.",
                "Inside the child's `__init__`, the parent's setup runs when you call it through `super()` with the two arguments the parent expects; then save the third argument on `self`.",
                "In the overriding `label`, save the result of `super().label()` in a variable (or use it directly inside an f-string) and add a space, an opening parenthesis, the context window, `' tokens'` and a closing parenthesis."
            ], effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("inheritance-token-properties", "Computed token totals with properties", """
            Goal:
            Use `@property` for values that must always be computed from the current attributes, and override a property in a subclass.

            Starting code:
            - `class TokenBatch` has `__init__(self, prompt_tokens, output_tokens)`, which saves both counts. Keep it.
            - `TokenBatch.billable_tokens` is a plain method that returns the placeholder `0`. Replace it.
            - `class CachedTokenBatch(TokenBatch)` has a complete `__init__(self, prompt_tokens, output_tokens, cached_tokens)` that already calls `super().__init__` and saves `cached_tokens`. Keep it.
            - `CachedTokenBatch.billable_tokens` also returns the placeholder `0`. Replace it.

            **Cached tokens** are tokens a service reused from an earlier request and does not charge for.

            Your task:
            1. In `TokenBatch`, put `@property` on the line directly above `def billable_tokens(self)`.
            2. Make it return `prompt_tokens` plus `output_tokens`.
            3. In `CachedTokenBatch`, make `billable_tokens` a property too.
            4. Make it return the parent's billable total minus `cached_tokens`, reading the parent's total with `super().billable_tokens` (no parentheses).
            5. A bill can never be negative: if `cached_tokens` is larger than the parent's total, return `0`. `max(0, value)` gives this.
            6. Do not store the total in `__init__`: it must update when an attribute changes later.

            Expected result:
            - `TokenBatch(120, 30).billable_tokens` is `150` (no parentheses).
            - `TokenBatch(0, 0).billable_tokens` is `0`.
            - `CachedTokenBatch(120, 30, 100).billable_tokens` is `50`.
            - `CachedTokenBatch(10, 5, 15)` and `CachedTokenBatch(10, 5, 40)` give `0`.
            - `CachedTokenBatch(10, 5, 0)` gives `15`.
            - After `batch = TokenBatch(120, 30)` and `batch.output_tokens = 50`, `batch.billable_tokens` is `170`.

            Check:
            Choose **Check solution**. It reads both properties without parentheses, confirms they are defined with `@property` in each class, and checks zero, exact-cancel and over-cancel cases plus updates after attribute changes.
            """, """
            class TokenBatch:
                def __init__(self, prompt_tokens, output_tokens):
                    self.prompt_tokens = prompt_tokens
                    self.output_tokens = output_tokens

                def billable_tokens(self):
                    return 0


            class CachedTokenBatch(TokenBatch):
                def __init__(self, prompt_tokens, output_tokens, cached_tokens):
                    super().__init__(prompt_tokens, output_tokens)
                    self.cached_tokens = cached_tokens

                def billable_tokens(self):
                    return 0
            """, """
            class TokenBatch:
                def __init__(self, prompt_tokens, output_tokens):
                    self.prompt_tokens = prompt_tokens
                    self.output_tokens = output_tokens

                @property
                def billable_tokens(self):
                    return self.prompt_tokens + self.output_tokens


            class CachedTokenBatch(TokenBatch):
                def __init__(self, prompt_tokens, output_tokens, cached_tokens):
                    super().__init__(prompt_tokens, output_tokens)
                    self.cached_tokens = cached_tokens

                @property
                def billable_tokens(self):
                    return max(0, super().billable_tokens - self.cached_tokens)
            """, """
            batch = TokenBatch(120, 30)
            assert batch.billable_tokens == 150
            assert isinstance(TokenBatch.__dict__["billable_tokens"], property)
            assert TokenBatch(0, 0).billable_tokens == 0
            cached = CachedTokenBatch(120, 30, 100)
            assert cached.billable_tokens == 50
            assert isinstance(CachedTokenBatch.__dict__["billable_tokens"], property)
            assert CachedTokenBatch(10, 5, 15).billable_tokens == 0
            assert CachedTokenBatch(10, 5, 40).billable_tokens == 0
            assert CachedTokenBatch(10, 5, 0).billable_tokens == 15
            batch.output_tokens = 50
            assert batch.billable_tokens == 170
            cached.cached_tokens = 0
            assert cached.billable_tokens == 150
            assert isinstance(cached, TokenBatch)
            """, [
                "A property is still written with `def` and `self`; the decorator line above it is what lets callers leave out the parentheses.",
                "The parent's property adds two attributes. The child's property starts from the parent's value, which `super()` can read the same way any caller reads a property.",
                "In the child, subtract `self.cached_tokens` from `super().billable_tokens` and pass that difference to `max` together with `0` so the result never drops below zero."
            ], effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("inheritance-scorers", "Abstract scorers inside an evaluator", """
            Goal:
            Design a small family of answer scorers with an abstract base class, specialise one scorer by overriding, and compose an evaluator that works with any scorer.

            Starting code:
            - `from abc import ABC, abstractmethod` is supplied. Keep it.
            - `class Scorer` is a plain class whose `score` method returns the placeholder `0.0`.
            - `class ExactMatch(Scorer)` and `class LooseMatch(ExactMatch)` have `score` methods returning the placeholder `0.0`.
            - `class Evaluator` stores a scorer in `__init__`, and its `average` method returns the placeholder `0.0`.
            - All placeholders must be replaced.

            Your task:
            1. Make `Scorer` abstract: inherit from `ABC` and put `@abstractmethod` above `score(self, prediction, expected)`. Its body can be `pass`. `Scorer()` must then raise `TypeError`.
            2. `ExactMatch.score(prediction, expected)` returns `1.0` when the two strings are exactly equal and `0.0` otherwise.
            3. `LooseMatch` overrides `score` to ignore surrounding spaces and letter case: strip and lowercase both strings.
            4. `LooseMatch.score` then returns `super().score(...)` with the cleaned strings, reusing `ExactMatch`'s comparison.
            5. `Evaluator(scorer)` must raise `TypeError` if `scorer` is not an instance of `Scorer` (any subclass is fine). Otherwise it saves it as `self.scorer`.
            6. `Evaluator.average(pairs)` receives a list of `(prediction, expected)` tuples. Return the mean of `self.scorer.score` for every pair as a float, or `0.0` for an empty list. Do not change the list.

            Expected result:
            - `ExactMatch().score('Paris', 'Paris')` is `1.0`.
            - `ExactMatch().score('paris', 'Paris')` is `0.0`.
            - `LooseMatch().score('  paris ', 'Paris')` is `1.0`.
            - For `pairs = [('Paris', 'Paris'), (' paris', 'Paris'), ('Rome', 'Oslo'), ('OSLO', 'oslo')]`, `Evaluator(ExactMatch()).average(pairs)` is `0.25` and `Evaluator(LooseMatch()).average(pairs)` is `0.75`.
            - `Evaluator(LooseMatch()).average([])` is `0.0`.
            - `Evaluator('exact')` raises `TypeError`.

            Check:
            Choose **Check solution**. It also creates its own `Scorer` subclass to confirm the evaluator works with any scorer, and temporarily changes `ExactMatch.score` to confirm `LooseMatch` reuses it through `super()`.
            """, """
            from abc import ABC, abstractmethod


            class Scorer:
                def score(self, prediction, expected):
                    return 0.0


            class ExactMatch(Scorer):
                def score(self, prediction, expected):
                    return 0.0


            class LooseMatch(ExactMatch):
                def score(self, prediction, expected):
                    return 0.0


            class Evaluator:
                def __init__(self, scorer):
                    self.scorer = scorer

                def average(self, pairs):
                    return 0.0
            """, """
            from abc import ABC, abstractmethod


            class Scorer(ABC):
                @abstractmethod
                def score(self, prediction, expected):
                    pass


            class ExactMatch(Scorer):
                def score(self, prediction, expected):
                    if prediction == expected:
                        return 1.0
                    return 0.0


            class LooseMatch(ExactMatch):
                def score(self, prediction, expected):
                    return super().score(prediction.strip().lower(), expected.strip().lower())


            class Evaluator:
                def __init__(self, scorer):
                    if not isinstance(scorer, Scorer):
                        raise TypeError("scorer must be a Scorer")
                    self.scorer = scorer

                def average(self, pairs):
                    if len(pairs) == 0:
                        return 0.0
                    total = 0.0
                    for prediction, expected in pairs:
                        total = total + self.scorer.score(prediction, expected)
                    return total / len(pairs)
            """, """
            assert ExactMatch().score("Paris", "Paris") == 1.0
            assert ExactMatch().score("paris", "Paris") == 0.0
            assert LooseMatch().score("  paris ", "Paris") == 1.0
            assert LooseMatch().score("Lyon", "Paris") == 0.0
            pairs = [("Paris", "Paris"), (" paris", "Paris"), ("Rome", "Oslo"), ("OSLO", "oslo")]
            assert Evaluator(ExactMatch()).average(pairs) == 0.25
            assert Evaluator(LooseMatch()).average(pairs) == 0.75
            assert pairs == [("Paris", "Paris"), (" paris", "Paris"), ("Rome", "Oslo"), ("OSLO", "oslo")]
            assert Evaluator(LooseMatch()).average([]) == 0.0
            assert isinstance(LooseMatch(), Scorer) and isinstance(LooseMatch(), ExactMatch)
            try:
                Scorer()
                scorer_created = True
            except TypeError:
                scorer_created = False
            assert not scorer_created, "Scorer must be abstract."
            try:
                Evaluator("exact")
                evaluator_created = True
            except TypeError:
                evaluator_created = False
            assert not evaluator_created, "Evaluator must reject non-Scorer values with TypeError."
            class AlwaysHalf(Scorer):
                def score(self, prediction, expected):
                    return 0.5
            assert Evaluator(AlwaysHalf()).average([("a", "b"), ("c", "d")]) == 0.5
            original_score = ExactMatch.score
            ExactMatch.score = lambda self, prediction, expected: 0.5
            patched_score = LooseMatch().score("a", "a")
            ExactMatch.score = original_score
            assert patched_score == 0.5, "LooseMatch should return super().score(...)."
            """, [
                "There are four separate jobs: an abstract template, an exact comparison, a cleaned-up comparison that reuses the exact one, and an evaluator that holds a scorer and averages its results.",
                "Abstract means: inherit from `ABC` and decorate the method with `abstractmethod`. The evaluator checks its argument with `isinstance` against the parent class `Scorer`, so every subclass is accepted.",
                "For `average`, guard the empty list first, then loop with `for prediction, expected in pairs`, add `self.scorer.score(prediction, expected)` to a running total, and divide by `len(pairs)`."
            ], effort: .init(difficulty: .harder, scopeUnits: 3))
        ],
        assessment: exercise("inheritance-assessment", "Price plans and accounts", """
        Goal:
        Model subscription price plans as an abstract family of classes, and compose an account that bills through whichever plan it holds.

        Starting code:
        - `class Plan` saves `name` and `monthly_fee` in `__init__`. Its `annual_fee` and `charge` methods return the placeholder `0`.
        - `class FlatPlan(Plan)` contains only `pass`.
        - `class MeteredPlan(Plan)` has an `__init__(self, name, monthly_fee, included_units, unit_price)` that saves only the last two values.
        - `class Account` saves `owner` and `plan`. Its `bill` method returns the placeholder `0`.
        - You may add `from abc import ABC, abstractmethod` at the top.

        Your task:
        1. Make `Plan` an abstract base class whose `charge(self, units)` method is abstract. `Plan('x', 1)` and any subclass that does not define `charge` must raise `TypeError` when created.
        2. Make `annual_fee` a property of `Plan` returning `monthly_fee * 12`, always computed from the current `monthly_fee`.
        3. `FlatPlan.charge(units)` returns `monthly_fee` whatever the number of units.
        4. `MeteredPlan.__init__` must call `super().__init__(name, monthly_fee)` and save `included_units` and `unit_price`.
        5. `MeteredPlan.charge(units)` returns `monthly_fee` plus `unit_price` for every unit above `included_units`. Using `included_units` or fewer costs just `monthly_fee`.
        6. `Account(owner, plan)` raises `TypeError` when `plan` is not an instance of `Plan`.
        7. `Account.bill(units)` returns the charge of the plan currently stored in `self.plan`.

        Expected result:
        - `FlatPlan('basic', 10).charge(0)` and `.charge(5000)` are both `10`.
        - For `MeteredPlan('pro', 20, 1000, 2)`: `charge(0)`, `charge(999)` and `charge(1000)` are `20`, `charge(1003)` is `26`, and `annual_fee` is `240`.
        - `FlatPlan('basic', 10).annual_fee` is `120`.
        - `Account('mira', MeteredPlan('team', 5, 10, 3)).bill(12)` is `11`.
        - After setting that account's `plan` to `FlatPlan('basic', 7)`, `bill(12)` is `7`.
        - `Account('mira', 'basic')` raises `TypeError`.

        Check:
        Complete the theory questions and written explanation, then choose **Submit assessment**. It checks boundaries at the included units, the abstract base class, the property, inheritance with `isinstance` and delegation from `Account`. Work independently; hints and solutions are unavailable.
        """, """
        class Plan:
            def __init__(self, name, monthly_fee):
                self.name = name
                self.monthly_fee = monthly_fee

            def annual_fee(self):
                return 0

            def charge(self, units):
                return 0


        class FlatPlan(Plan):
            pass


        class MeteredPlan(Plan):
            def __init__(self, name, monthly_fee, included_units, unit_price):
                self.included_units = included_units
                self.unit_price = unit_price


        class Account:
            def __init__(self, owner, plan):
                self.owner = owner
                self.plan = plan

            def bill(self, units):
                return 0
        """, """
        from abc import ABC, abstractmethod


        class Plan(ABC):
            def __init__(self, name, monthly_fee):
                self.name = name
                self.monthly_fee = monthly_fee

            @property
            def annual_fee(self):
                return self.monthly_fee * 12

            @abstractmethod
            def charge(self, units):
                pass


        class FlatPlan(Plan):
            def charge(self, units):
                return self.monthly_fee


        class MeteredPlan(Plan):
            def __init__(self, name, monthly_fee, included_units, unit_price):
                super().__init__(name, monthly_fee)
                self.included_units = included_units
                self.unit_price = unit_price

            def charge(self, units):
                extra = max(0, units - self.included_units)
                return self.monthly_fee + extra * self.unit_price


        class Account:
            def __init__(self, owner, plan):
                if not isinstance(plan, Plan):
                    raise TypeError("plan must be a Plan")
                self.owner = owner
                self.plan = plan

            def bill(self, units):
                return self.plan.charge(units)
        """, """
        flat = FlatPlan("basic", 10)
        assert flat.charge(0) == 10 and flat.charge(5000) == 10
        metered = MeteredPlan("pro", 20, 1000, 2)
        assert metered.charge(0) == 20
        assert metered.charge(999) == 20
        assert metered.charge(1000) == 20
        assert metered.charge(1003) == 26
        assert metered.name == "pro" and metered.monthly_fee == 20
        assert flat.annual_fee == 120 and metered.annual_fee == 240
        assert isinstance(Plan.__dict__["annual_fee"], property)
        metered.monthly_fee = 25
        assert metered.annual_fee == 300
        assert isinstance(metered, Plan) and isinstance(flat, Plan)
        account = Account("mira", MeteredPlan("team", 5, 10, 3))
        assert account.bill(12) == 11
        assert account.bill(10) == 5
        account.plan = FlatPlan("basic", 7)
        assert account.bill(12) == 7
        try:
            Plan("x", 1)
            plan_created = True
        except TypeError:
            plan_created = False
        assert not plan_created
        class Incomplete(Plan):
            pass
        try:
            Incomplete("x", 1)
            incomplete_created = True
        except TypeError:
            incomplete_created = False
        assert not incomplete_created
        try:
            Account("mira", "basic")
            account_created = True
        except TypeError:
            account_created = False
        assert not account_created
        """, [], effort: .init(difficulty: .harder, scopeUnits: 4)),
        quiz: [
            question("inheritance-q1", "Speaker inherits from Device and defines describe, which Device also defines. What does Speaker('den').describe() run?", ["Speaker's describe, because method lookup checks the child class first", "Device's describe, because parents always win", "Both methods, one after the other"], 0, "A child's method with the same name overrides the parent's. The parent's version runs only if the child calls it, for example with super().describe()."),
            question("inheritance-q2", "Shape inherits from ABC and marks area with @abstractmethod. What happens when you call Shape()?", ["It creates a Shape whose area returns None", "Python raises TypeError because Shape is abstract", "Python silently creates a Square instead"], 1, "An abstract class cannot be instantiated while it has abstract methods; only subclasses that override all of them can be created."),
            question("inheritance-q3", "An Evaluator stores a scorer in self.scorer and calls self.scorer.score(...). Which design is this?", ["Inheritance: an Evaluator is a scorer", "A property", "Composition: an Evaluator has a scorer and delegates to it"], 2, "Storing another object and calling its methods is composition (a has-a relationship). It lets you swap the part without creating new subclasses.")
        ],
        sectionRoles: ["Build new classes from existing ones": .overview])

    static let testing = Chapter(
        id: "testing", title: "Testing with unittest", subtitle: "Write test suites that catch real bugs",
        track: .softwareCraft, prerequisites: ["classes", "files"],
        lesson: """
        # Tests are programs that check programs

        In the reliability chapter you used `assert` lines as evidence that a function works. That is already testing, but it has limits:

        - the first failing `assert` stops everything, so you never learn whether the other checks would pass;
        - nothing records which check failed or why.

        Python's standard library includes **unittest**, a testing framework: a set of tools for writing many named checks, running all of them, and reporting the results.

        ### Some vocabulary

        - A **test** is a small piece of code that calls the code under test with chosen inputs and checks the result.
        - The code under test is often called the **implementation**.
        - A group of tests is a **test suite**.

        > **Key idea:** A good suite does two jobs: it passes when the implementation is correct, and it *fails* when the implementation has a bug.

        This chapter teaches both halves. In the exercises the implementation is supplied and correct; your job is to write the tests, and the checks will try your tests against deliberately broken versions.

        ## Write a test case class

        With unittest, tests live in a class.

        ### The test class

        `import unittest` makes the module available.

        Writing `class TablesNeededTests(unittest.TestCase):` creates a class that builds on unittest's `TestCase` class and receives all of its helper methods. This works in the same way that a custom exception class built on `Exception` gets exception behaviour.

        Here you only need this pattern. A separate Software craft chapter on inheritance goes deeper into how one class builds on another, but this chapter does not assume you have read it.

        ### Test methods

        - Inside the class, every method whose name **starts with `test`** is one test.
        - Each test method takes `self`, calls the implementation and checks the result with an assertion method.
        - The most common is `self.assertEqual(actual, expected)`: it passes when the two values are equal, and otherwise fails with a message showing both values.

        ### Somewhere to put the report: io.StringIO

        The example below ends with a few lines that run the tests. One of them uses `io.StringIO()` from the standard `io` module (another standard-library module, imported with `import io` like the modules in the files chapter).

        `io.StringIO()` creates an in-memory text container that behaves like a file opened for writing, but no real file is created. Here it gives unittest somewhere to write its report so that nothing is printed.

        For example, `box = io.StringIO()` followed by `box.write("hi")` stores the text, and `box.getvalue()` returns `'hi'`.

        ```python
        import io
        import unittest


        def tables_needed(guests, seats_per_table):
            return (guests + seats_per_table - 1) // seats_per_table


        class TablesNeededTests(unittest.TestCase):
            def test_exact_fit(self):
                self.assertEqual(tables_needed(12, 4), 3)

            def test_one_extra_guest(self):
                self.assertEqual(tables_needed(13, 4), 4)

            def test_no_guests(self):
                self.assertEqual(tables_needed(0, 4), 0)


        suite = unittest.defaultTestLoader.loadTestsFromTestCase(TablesNeededTests)
        result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
        print(result.testsRun)
        print(result.wasSuccessful())
        assert result.wasSuccessful()
        ```

        ```text
        3
        True
        ```

        - You never call the test methods yourself.
        - The last lines (explained in the next section) ask unittest to find every `test...` method, create a fresh instance of the class for each one, run it, and collect the outcome.

        > **Watch out:** A method named `check_total` would silently **not** run, because its name does not start with `test`.

        ## Run a suite yourself

        There are two convenient ways to run your tests in the editor.

        ### Option 1: unittest.main

        `unittest.main(argv=[''], exit=False)` finds every TestCase class in your program, runs all their tests, and prints a report.

        - `argv=['']` tells it to ignore command-line options (there are none in the editor).
        - `exit=False` tells it not to stop the whole program afterwards.

        Here is a suite whose implementation has a bug: it forgets to round up.

        ```python
        import unittest


        def tables_needed(guests, seats_per_table):
            return guests // seats_per_table


        class TablesNeededTests(unittest.TestCase):
            def test_exact_fit(self):
                self.assertEqual(tables_needed(12, 4), 3)

            def test_one_extra_guest(self):
                self.assertEqual(tables_needed(13, 4), 4)


        unittest.main(argv=[''], exit=False)
        ```

        ### Reading the report

        The report starts with one character per test:

        - `.` for a pass;
        - `F` for a **failure** (an assertion did not hold);
        - `E` for an **error** (the test crashed with some other exception, such as a `TypeError`).

        For the suite above, the report looks roughly like this. The exact layout of the header line varies a little between Python versions.

        ```text
        .F
        ======================================================================
        FAIL: test_one_extra_guest (__main__.TablesNeededTests)
        ----------------------------------------------------------------------
        Traceback (most recent call last):
          ...
        AssertionError: 3 != 4

        ----------------------------------------------------------------------
        Ran 2 tests in 0.001s

        FAILED (failures=1)
        ```

        - It shows `.F`, then a block headed `FAIL: test_one_extra_guest`.
        - `AssertionError: 3 != 4` lists the actual value first and the expected value second.
        - The summary says `Ran 2 tests` and `FAILED (failures=1)`.
        - When everything passes, the last line is `OK`.

        ### Option 2: the runner approach

        The runner approach gives you the result as a value instead of only a printed report, which is useful when code needs to inspect it.

        1. `unittest.defaultTestLoader.loadTestsFromTestCase(TheClass)` collects the tests of one class into a suite.
        2. `unittest.TextTestRunner(stream=io.StringIO())` creates a runner whose report goes into the in-memory `io.StringIO()` container introduced above, so nothing is printed.
        3. `.run(suite)` runs the tests and returns a result object.

        The result object tells you what happened:

        - `result.wasSuccessful()` is `True` only if every test passed;
        - `result.testsRun` counts the tests;
        - `result.failures` and `result.errors` are lists of what went wrong.

        The first example in this lesson used this approach, and the app's checks use it too.

        > **Tip:** Your exercise code may keep a `unittest.main(argv=[''], exit=False)` line at the bottom while you work. It only prints a report and does not affect **Check solution**.

        ## Check errors and decimals: assertRaises and assertAlmostEqual

        ### Expecting an exception with assertRaises

        Some behaviour is an exception, not a return value. `with self.assertRaises(ValueError):` followed by an indented block checks that the block raises `ValueError`.

        This is the same `with` statement you used in the files chapter to open a file for an indented block and close it automatically afterwards. Here, instead of a file, `with` hands the block to `assertRaises`. It runs the indented block and then lets `assertRaises` inspect what happened:

        - the test fails if no exception was raised;
        - the test errors if a *different* exception type was raised.

        Put only the call that should fail inside the block.

        ### Comparing decimals with assertAlmostEqual

        Decimal numbers need a different comparison. Floats are stored in binary, so tiny rounding differences are normal: `0.1 + 0.2 == 0.3` is `False`.

        - `self.assertAlmostEqual(actual, expected)` rounds the difference to 7 decimal places and passes if that rounded difference is zero.
        - You can pass `places=3` to compare to 3 decimal places instead.
        - Use it for every float result that comes from division or multiplication by decimals.

        Two more simple helpers exist: `self.assertTrue(value)` and `self.assertFalse(value)`.

        ```python
        import io
        import unittest


        def average_rating(ratings):
            if len(ratings) == 0:
                raise ValueError("no ratings")
            return sum(ratings) / len(ratings)


        class AverageRatingTests(unittest.TestCase):
            def test_decimal_average(self):
                self.assertAlmostEqual(average_rating([0.1, 0.2]), 0.15)

            def test_empty_list_is_rejected(self):
                with self.assertRaises(ValueError):
                    average_rating([])

            def test_single_rating(self):
                self.assertTrue(average_rating([4]) == 4)


        suite = unittest.defaultTestLoader.loadTestsFromTestCase(AverageRatingTests)
        result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
        assert result.wasSuccessful()
        print(average_rating([0.1, 0.2]))
        print(0.1 + 0.2 == 0.3)
        ```

        ```text
        0.15000000000000002
        False
        ```

        So `assertEqual(average_rating([0.1, 0.2]), 0.15)` would have failed even though the implementation is correct.

        > **Watch out:** A test that fails on correct code is just as misleading as one that passes on broken code.

        ## Share preparation with setUp

        When several tests need the same starting object, define a method named exactly `setUp(self)` (capital U).

        - unittest calls it **before each test method**, on that test's own instance.
        - Save what you build on `self`, for example `self.counter = ClickCounter()`, and read it in the tests.

        > **Key idea:** Because `setUp` runs again for every test, each test starts with a fresh object; a change made in one test cannot leak into another. This **test isolation** means tests can run in any order.

        ```python
        import io
        import unittest


        class ClickCounter:
            def __init__(self):
                self.clicks = 0

            def add(self, amount):
                if amount <= 0:
                    raise ValueError("amount must be positive")
                self.clicks = self.clicks + amount


        class ClickCounterTests(unittest.TestCase):
            def setUp(self):
                self.counter = ClickCounter()

            def test_starts_at_zero(self):
                self.assertEqual(self.counter.clicks, 0)

            def test_add_increases(self):
                self.counter.add(3)
                self.assertEqual(self.counter.clicks, 3)

            def test_zero_rejected_and_count_unchanged(self):
                with self.assertRaises(ValueError):
                    self.counter.add(0)
                self.assertEqual(self.counter.clicks, 0)


        suite = unittest.defaultTestLoader.loadTestsFromTestCase(ClickCounterTests)
        result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
        print(result.testsRun)
        assert result.wasSuccessful()
        ```

        ```text
        3
        ```

        - `test_starts_at_zero` still sees 0 even if `test_add_increases` ran first, because each test got its own new counter.
        - The last test also checks that a *rejected* call left the object unchanged, a detail that is easy to forget and a common source of bugs.

        ## Design tests around boundaries

        You cannot test every possible input, so choose the inputs that are most likely to reveal mistakes.

        ### Groups and boundaries

        1. Group inputs into ranges that should behave the same way (for a pass mark of 50: failing scores and passing scores).
        2. Test **one ordinary value from each group**.
        3. Test the **boundaries** between groups.

        > **Key idea:** Bugs cluster at boundaries. Writing `>` instead of `>=` changes the result only for the exact boundary value.

        For a rule "score 50 or more passes", test 49, 50 and a typical value such as 80.

        ### Other inputs worth testing

        - the smallest possible input (zero, an empty list, an empty string);
        - the largest allowed value;
        - every documented error, including the value just outside the allowed range.

        ```python
        import io
        import unittest


        def is_passing(score):
            return score >= 50


        class IsPassingTests(unittest.TestCase):
            def test_typical_scores(self):
                self.assertTrue(is_passing(80))
                self.assertFalse(is_passing(20))

            def test_boundary(self):
                self.assertFalse(is_passing(49))
                self.assertTrue(is_passing(50))


        suite = unittest.defaultTestLoader.loadTestsFromTestCase(IsPassingTests)
        result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
        assert result.wasSuccessful()
        print(result.testsRun)
        ```

        ```text
        2
        ```

        - Give each test a descriptive name saying which behaviour it checks; when it fails, the name tells you where to look.
        - A test may contain several assertions about the same behaviour.

        ## Make sure your tests catch bugs

        How do you know whether a suite is good? Run it against implementations you *know* are wrong. If a broken version still passes, the suite has a blind spot.

        This idea is called **mutation testing**: make small deliberate changes (mutations) such as `>=` to `>`, and check that some test fails for each.

        Test methods look up the implementation's name each time they run, so you can temporarily point the name at a buggy version:

        ```python
        import io
        import unittest


        def clamp_percent(value):
            return max(0, min(100, value))


        class ClampTests(unittest.TestCase):
            def test_inside_range(self):
                self.assertEqual(clamp_percent(42), 42)

            def test_below_zero(self):
                self.assertEqual(clamp_percent(-5), 0)

            def test_above_hundred(self):
                self.assertEqual(clamp_percent(130), 100)


        def run_tests():
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(ClampTests)
            return unittest.TextTestRunner(stream=io.StringIO()).run(suite)


        def forgets_lower_limit(value):
            return min(100, value)


        assert run_tests().wasSuccessful()
        correct_version = clamp_percent
        clamp_percent = forgets_lower_limit
        caught = not run_tests().wasSuccessful()
        clamp_percent = correct_version
        print(caught)
        assert caught
        ```

        ```text
        True
        ```

        `test_below_zero` caught the mutation.

        ### How the app's checks use this

        The app's checks do exactly this with your test classes. They run your tests against:

        - a correct implementation (all must pass);
        - sometimes an *equivalent* implementation that rounds floats slightly differently (all must still pass);
        - several buggy implementations (each must make at least one of your tests fail).

        The check messages name any bug your tests missed.

        > **Remember:** Keep the supplied function or class under its original name, and call it by that name inside each test method (or in `setUp`).

        ### Common mistakes and debugging

        - A test method whose name does not start with `test` never runs, so check `result.testsRun`.
        - Writing `setup` instead of `setUp` means it is never called, and tests then error with `AttributeError` on `self.counter`.
        - Forgetting `self.` before `assertEqual` gives a `NameError`.
        - Calling the failing function *outside* the `with self.assertRaises(...)` block makes the test crash instead of pass.
        - Comparing floats with `assertEqual` makes tests fail on correct code.
        - A test with only `pass` in its body always passes and catches nothing.
        - Test returned values, not printed text.
        - Keep each test independent by building fresh objects in `setUp`.
        """,
        exercises: [
            exercise("testing-latency-bands", "Test latency bands at their boundaries", """
            Goal:
            Write a unittest test case whose tests pass for a correct latency classifier and fail for buggy versions, especially at the band boundaries (the exact values where one label changes to the next).

            Starting code:
            - `import unittest` is supplied.
            - `latency_band(ms)` is a correct, complete implementation. Do not change it. Below 200 milliseconds it returns `'fast'`, from 200 up to but not including 1000 it returns `'ok'`, and 1000 or more returns `'slow'`.
            - `class LatencyBandTests(unittest.TestCase)` has three test methods.
            - `test_fast` already contains one example assertion.
            - `test_ok` and `test_slow` contain only the placeholder `pass`, which tests nothing.

            Your task:
            1. Keep the class name `LatencyBandTests` and the three method names.
            2. Keep the supplied `latency_band` function with its exact name, and call it by that name, `latency_band(...)`, inside each test method, as the example does. The check temporarily swaps buggy versions in under the name `latency_band`, so a test that calls a renamed copy instead cannot catch them.
            3. In `test_fast`, keep the example and add `self.assertEqual(latency_band(199), 'fast')` for the value just below the boundary.
            4. Replace `pass` in `test_ok` with `assertEqual` checks that `latency_band(200)` and `latency_band(999)` both return `'ok'`.
            5. Replace `pass` in `test_slow` with `assertEqual` checks that `latency_band(1000)` and `latency_band(5000)` both return `'slow'`.
            6. Optionally add `unittest.main(argv=[''], exit=False)` at the bottom and choose **Run** to see the report.

            Expected result:
            - All three tests pass for the supplied `latency_band`.
            - Your tests fail for a version that reports 200 ms as `'fast'`.
            - They fail for a version whose fast limit is lowered so that 199 ms is `'ok'`.
            - They fail for a version that reports 1000 ms as `'ok'`.
            - They fail for a version that uses the label `'okay'` instead of `'ok'`.
            - They fail for a version that never returns `'slow'`.

            Check:
            Choose **Check solution**. It runs your `LatencyBandTests` against its own correct `latency_band` (every test must pass) and then against five buggy versions (each must cause at least one failure). A message names any bug your tests missed.
            """, """
            import unittest


            def latency_band(ms):
                if ms < 200:
                    return "fast"
                if ms < 1000:
                    return "ok"
                return "slow"


            class LatencyBandTests(unittest.TestCase):
                def test_fast(self):
                    self.assertEqual(latency_band(0), "fast")

                def test_ok(self):
                    pass

                def test_slow(self):
                    pass
            """, """
            import unittest


            def latency_band(ms):
                if ms < 200:
                    return "fast"
                if ms < 1000:
                    return "ok"
                return "slow"


            class LatencyBandTests(unittest.TestCase):
                def test_fast(self):
                    self.assertEqual(latency_band(0), "fast")
                    self.assertEqual(latency_band(199), "fast")

                def test_ok(self):
                    self.assertEqual(latency_band(200), "ok")
                    self.assertEqual(latency_band(999), "ok")

                def test_slow(self):
                    self.assertEqual(latency_band(1000), "slow")
                    self.assertEqual(latency_band(5000), "slow")
            """, """
            import io
            import unittest
            assert isinstance(globals().get("LatencyBandTests"), type), "Keep the test class named LatencyBandTests."
            assert hasattr(globals().get("latency_band"), "__globals__"), "Keep the supplied latency_band function with its original name. The check swaps buggy versions in under that name, so call latency_band(...) inside each test method."
            learner_globals = latency_band.__globals__
            supplied_band = learner_globals["latency_band"]
            def run_learner_tests(implementation):
                learner_globals["latency_band"] = implementation
                suite = unittest.defaultTestLoader.loadTestsFromTestCase(LatencyBandTests)
                result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
                learner_globals["latency_band"] = supplied_band
                return result
            def reference_band(ms):
                if ms < 200:
                    return "fast"
                if ms < 1000:
                    return "ok"
                return "slow"
            def bug_200_is_fast(ms):
                if ms <= 200:
                    return "fast"
                if ms < 1000:
                    return "ok"
                return "slow"
            def bug_fast_limit_too_low(ms):
                if ms < 100:
                    return "fast"
                if ms < 1000:
                    return "ok"
                return "slow"
            def bug_1000_is_ok(ms):
                if ms < 200:
                    return "fast"
                if ms <= 1000:
                    return "ok"
                return "slow"
            def bug_wrong_label(ms):
                if ms < 200:
                    return "fast"
                if ms < 1000:
                    return "okay"
                return "slow"
            def bug_never_slow(ms):
                if ms < 200:
                    return "fast"
                return "ok"
            assert issubclass(LatencyBandTests, unittest.TestCase)
            assert hasattr(LatencyBandTests, "test_fast") and hasattr(LatencyBandTests, "test_ok") and hasattr(LatencyBandTests, "test_slow")
            passing = run_learner_tests(reference_band)
            assert passing.testsRun >= 3
            assert passing.wasSuccessful(), "Your tests must pass for the correct latency_band."
            assert not run_learner_tests(bug_200_is_fast).wasSuccessful(), "Missed bug: 200 ms reported as 'fast'."
            assert not run_learner_tests(bug_fast_limit_too_low).wasSuccessful(), "Missed bug: 199 ms reported as 'ok'."
            assert not run_learner_tests(bug_1000_is_ok).wasSuccessful(), "Missed bug: 1000 ms reported as 'ok'."
            assert not run_learner_tests(bug_wrong_label).wasSuccessful(), "Missed bug: label 'okay' instead of 'ok'."
            assert not run_learner_tests(bug_never_slow).wasSuccessful(), "Missed bug: 'slow' is never returned."
            assert latency_band is supplied_band
            """, [
                "Bugs hide at the edges of each band. For every boundary, test the last value of one band and the first value of the next.",
                "Each new check has the same shape as the supplied example: `self.assertEqual(call, expected_text)`. A test method can hold several of them.",
                "`test_ok` needs the two edge values `200` and `999` compared with `'ok'`; `test_slow` needs `1000` and one large value compared with `'slow'`. Remove the `pass` lines once a method has real checks."
            ], effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("testing-cost-errors", "Test a cost estimator with floats and errors", """
            Goal:
            Write tests that compare decimal results safely with `assertAlmostEqual` and check a documented error with `assertRaises`.

            Starting code:
            - `import unittest` is supplied.
            - `estimate_cost(tokens, rate_per_1000)` is a correct implementation. Do not change it. It raises `ValueError` when `tokens` is negative, and otherwise returns `tokens / 1000 * rate_per_1000` (charged proportionally, so 250 tokens cost a quarter of the rate).
            - `class EstimateCostTests(unittest.TestCase)` has four test methods whose bodies are only the placeholder `pass`.

            Your task:
            1. Keep the class name and the four method names.
            2. Keep the supplied `estimate_cost` function with its exact name, and call it by that name, `estimate_cost(...)`, inside each test method. The check temporarily swaps other versions in under the name `estimate_cost`, so a test that calls a renamed copy instead cannot catch the bugs.
            3. In `test_typical_cost`, check with `assertAlmostEqual` that `estimate_cost(1500, 0.002)` is `0.003`.
            4. In `test_partial_thousand`, check with `assertAlmostEqual` that `estimate_cost(250, 4.0)` is `1.0`.
            5. In `test_zero_tokens`, check with `assertAlmostEqual` that `estimate_cost(0, 4.0)` is `0.0` (zero tokens are allowed and cost nothing).
            6. In `test_negative_tokens_rejected`, use `with self.assertRaises(ValueError):` and call `estimate_cost(-1, 0.002)` inside the block.
            7. Compare every cost with `assertAlmostEqual`, never `assertEqual`: the checks also run an equivalent implementation whose results differ by less than `0.000000001`.

            Expected result:
            - All four tests pass for the supplied `estimate_cost` and for the equivalent version.
            - Your tests fail for a version that counts only whole thousands of tokens.
            - They fail for a version that charges the rate per token instead of per 1,000.
            - They fail for a version that accepts negative tokens.
            - They fail for a version that rejects zero tokens.
            - They fail for a version that raises `TypeError` instead of `ValueError` for negative tokens.

            Check:
            Choose **Check solution**. It runs `EstimateCostTests` against a correct implementation, an equivalent one with tiny float differences (both must pass) and five buggy ones (each must cause a failure or error).
            """, """
            import unittest


            def estimate_cost(tokens, rate_per_1000):
                if tokens < 0:
                    raise ValueError("tokens must not be negative")
                return tokens / 1000 * rate_per_1000


            class EstimateCostTests(unittest.TestCase):
                def test_typical_cost(self):
                    pass

                def test_partial_thousand(self):
                    pass

                def test_zero_tokens(self):
                    pass

                def test_negative_tokens_rejected(self):
                    pass
            """, """
            import unittest


            def estimate_cost(tokens, rate_per_1000):
                if tokens < 0:
                    raise ValueError("tokens must not be negative")
                return tokens / 1000 * rate_per_1000


            class EstimateCostTests(unittest.TestCase):
                def test_typical_cost(self):
                    self.assertAlmostEqual(estimate_cost(1500, 0.002), 0.003)

                def test_partial_thousand(self):
                    self.assertAlmostEqual(estimate_cost(250, 4.0), 1.0)

                def test_zero_tokens(self):
                    self.assertAlmostEqual(estimate_cost(0, 4.0), 0.0)

                def test_negative_tokens_rejected(self):
                    with self.assertRaises(ValueError):
                        estimate_cost(-1, 0.002)
            """, """
            import io
            import unittest
            assert isinstance(globals().get("EstimateCostTests"), type), "Keep the test class named EstimateCostTests."
            assert hasattr(globals().get("estimate_cost"), "__globals__"), "Keep the supplied estimate_cost function with its original name. The check swaps other versions in under that name, so call estimate_cost(...) inside each test method."
            learner_globals = estimate_cost.__globals__
            supplied_cost = learner_globals["estimate_cost"]
            def run_learner_tests(implementation):
                learner_globals["estimate_cost"] = implementation
                suite = unittest.defaultTestLoader.loadTestsFromTestCase(EstimateCostTests)
                result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
                learner_globals["estimate_cost"] = supplied_cost
                return result
            def reference_cost(tokens, rate_per_1000):
                if tokens < 0:
                    raise ValueError("tokens must not be negative")
                return tokens / 1000 * rate_per_1000
            def equivalent_cost(tokens, rate_per_1000):
                if tokens < 0:
                    raise ValueError("negative")
                return rate_per_1000 * tokens / 1000 + 0.000000000001
            def bug_whole_thousands(tokens, rate_per_1000):
                if tokens < 0:
                    raise ValueError("tokens must not be negative")
                return tokens // 1000 * rate_per_1000
            def bug_per_token(tokens, rate_per_1000):
                if tokens < 0:
                    raise ValueError("tokens must not be negative")
                return tokens * rate_per_1000
            def bug_accepts_negative(tokens, rate_per_1000):
                return tokens / 1000 * rate_per_1000
            def bug_rejects_zero(tokens, rate_per_1000):
                if tokens <= 0:
                    raise ValueError("tokens must be positive")
                return tokens / 1000 * rate_per_1000
            def bug_wrong_exception(tokens, rate_per_1000):
                if tokens < 0:
                    raise TypeError("tokens must not be negative")
                return tokens / 1000 * rate_per_1000
            assert issubclass(EstimateCostTests, unittest.TestCase)
            passing = run_learner_tests(reference_cost)
            assert passing.testsRun >= 4
            assert passing.wasSuccessful(), "Your tests must pass for the correct estimate_cost."
            assert run_learner_tests(equivalent_cost).wasSuccessful(), "Your tests are too strict for tiny float differences; use assertAlmostEqual."
            assert not run_learner_tests(bug_whole_thousands).wasSuccessful(), "Missed bug: only whole thousands of tokens are charged."
            assert not run_learner_tests(bug_per_token).wasSuccessful(), "Missed bug: the rate is charged per token."
            assert not run_learner_tests(bug_accepts_negative).wasSuccessful(), "Missed bug: negative tokens are accepted."
            assert not run_learner_tests(bug_rejects_zero).wasSuccessful(), "Missed bug: zero tokens are rejected."
            assert not run_learner_tests(bug_wrong_exception).wasSuccessful(), "Missed bug: TypeError raised instead of ValueError."
            assert estimate_cost is supplied_cost
            """, [
                "Three tests compare a returned float with an expected value; one test checks that a call raises. Use a different assertion method for each kind.",
                "`self.assertAlmostEqual(actual, expected)` has the same argument order as `assertEqual` but tolerates tiny rounding differences. For the error, the risky call goes inside an indented `with` block.",
                "The error test body is two lines: `with self.assertRaises(ValueError):` and, indented below it, the `estimate_cost` call with `-1` tokens. Do not wrap that call in `assertEqual`."
            ], effort: .init(difficulty: .similar, scopeUnits: 3)),
            exercise("testing-budget-setup", "Test a token budget with setUp", """
            Goal:
            Test a class: build a fresh object for every test with `setUp`, and check both successful calls and rejected calls, including that a rejected call leaves the object unchanged.

            Starting code:
            - `import unittest` is supplied.
            - `class TokenBudget` is a correct implementation. Do not change it.
            - `TokenBudget(limit)` starts with `used = 0`.
            - `spend(tokens)` raises `ValueError` when `tokens` is `0` or negative, and raises `ValueError` when `used + tokens` would exceed `limit` (spending exactly up to the limit is allowed). Otherwise it adds `tokens` to `used`.
            - `remaining()` returns `limit - used`.
            - `class TokenBudgetTests(unittest.TestCase)` has a `setUp` method and five test methods, all with the placeholder `pass`.

            Your task:
            1. Keep the supplied `TokenBudget` class with its exact name, and keep the class name `TokenBudgetTests` and its method names.
            2. In `setUp`, save a new budget with a limit of 100 as `self.budget = TokenBudget(100)`, calling the class by the name `TokenBudget`. Use `self.budget` in every test. The check temporarily swaps buggy classes in under the name `TokenBudget`; because `setUp` runs before each test method, every test then receives a fresh object of the swapped class. Do not build budgets from a renamed copy or outside the test class.
            3. In `test_starts_full`, check that `remaining()` is `100`.
            4. In `test_spend_reduces_remaining`, check that after `spend(30)`, `remaining()` is `70`.
            5. In `test_spending_exact_limit_is_allowed`, check that after `spend(100)`, `remaining()` is `0`.
            6. In `test_overspend_rejected_and_unchanged`, check that `spend(101)` raises `ValueError`, and that afterwards `remaining()` is still `100`.
            7. In `test_non_positive_rejected`, check that `spend(0)` raises `ValueError` and `spend(-5)` raises `ValueError` (use a separate `with` block for each call).

            Expected result:
            - All five tests pass for the supplied `TokenBudget`.
            - They fail for a class that rejects spending exactly the limit.
            - They fail for a class where a rejected overspend still changes `used`.
            - They fail for a class that accepts zero tokens.
            - They fail for a class that accepts negative tokens.
            - They fail for a class whose `remaining()` ignores spending.

            Check:
            Choose **Check solution**. It confirms `setUp` creates `self.budget` with limit 100, then runs your tests against a correct budget class (all must pass) and five buggy classes (each must cause a failure).
            """, """
            import unittest


            class TokenBudget:
                def __init__(self, limit):
                    self.limit = limit
                    self.used = 0

                def spend(self, tokens):
                    if tokens <= 0:
                        raise ValueError("tokens must be positive")
                    if self.used + tokens > self.limit:
                        raise ValueError("budget exceeded")
                    self.used = self.used + tokens

                def remaining(self):
                    return self.limit - self.used


            class TokenBudgetTests(unittest.TestCase):
                def setUp(self):
                    pass

                def test_starts_full(self):
                    pass

                def test_spend_reduces_remaining(self):
                    pass

                def test_spending_exact_limit_is_allowed(self):
                    pass

                def test_overspend_rejected_and_unchanged(self):
                    pass

                def test_non_positive_rejected(self):
                    pass
            """, """
            import unittest


            class TokenBudget:
                def __init__(self, limit):
                    self.limit = limit
                    self.used = 0

                def spend(self, tokens):
                    if tokens <= 0:
                        raise ValueError("tokens must be positive")
                    if self.used + tokens > self.limit:
                        raise ValueError("budget exceeded")
                    self.used = self.used + tokens

                def remaining(self):
                    return self.limit - self.used


            class TokenBudgetTests(unittest.TestCase):
                def setUp(self):
                    self.budget = TokenBudget(100)

                def test_starts_full(self):
                    self.assertEqual(self.budget.remaining(), 100)

                def test_spend_reduces_remaining(self):
                    self.budget.spend(30)
                    self.assertEqual(self.budget.remaining(), 70)

                def test_spending_exact_limit_is_allowed(self):
                    self.budget.spend(100)
                    self.assertEqual(self.budget.remaining(), 0)

                def test_overspend_rejected_and_unchanged(self):
                    with self.assertRaises(ValueError):
                        self.budget.spend(101)
                    self.assertEqual(self.budget.remaining(), 100)

                def test_non_positive_rejected(self):
                    with self.assertRaises(ValueError):
                        self.budget.spend(0)
                    with self.assertRaises(ValueError):
                        self.budget.spend(-5)
            """, """
            import io
            import unittest
            assert isinstance(globals().get("TokenBudgetTests"), type), "Keep the test class named TokenBudgetTests."
            assert "setUp" in TokenBudgetTests.__dict__, "Keep the setUp method in TokenBudgetTests."
            assert isinstance(globals().get("TokenBudget"), type), "Keep the supplied TokenBudget class with its original name. The check swaps buggy classes in under that name, so setUp must create the budget with TokenBudget(100)."
            learner_globals = TokenBudgetTests.setUp.__globals__
            supplied_budget = learner_globals["TokenBudget"]
            def run_learner_tests(budget_class):
                learner_globals["TokenBudget"] = budget_class
                suite = unittest.defaultTestLoader.loadTestsFromTestCase(TokenBudgetTests)
                result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
                learner_globals["TokenBudget"] = supplied_budget
                return result
            class ReferenceBudget:
                def __init__(self, limit):
                    self.limit = limit
                    self.used = 0
                def spend(self, tokens):
                    if tokens <= 0:
                        raise ValueError("tokens must be positive")
                    if self.used + tokens > self.limit:
                        raise ValueError("budget exceeded")
                    self.used = self.used + tokens
                def remaining(self):
                    return self.limit - self.used
            class ExactLimitRejected(ReferenceBudget):
                def spend(self, tokens):
                    if tokens <= 0:
                        raise ValueError("tokens must be positive")
                    if self.used + tokens >= self.limit:
                        raise ValueError("budget exceeded")
                    self.used = self.used + tokens
            class ChargesBeforeChecking(ReferenceBudget):
                def spend(self, tokens):
                    if tokens <= 0:
                        raise ValueError("tokens must be positive")
                    self.used = self.used + tokens
                    if self.used > self.limit:
                        raise ValueError("budget exceeded")
            class ZeroAccepted(ReferenceBudget):
                def spend(self, tokens):
                    if tokens < 0:
                        raise ValueError("tokens must not be negative")
                    if self.used + tokens > self.limit:
                        raise ValueError("budget exceeded")
                    self.used = self.used + tokens
            class NegativeAccepted(ReferenceBudget):
                def spend(self, tokens):
                    if tokens == 0:
                        raise ValueError("tokens must not be zero")
                    if self.used + tokens > self.limit:
                        raise ValueError("budget exceeded")
                    self.used = self.used + tokens
            class RemainingIgnoresSpending(ReferenceBudget):
                def remaining(self):
                    return self.limit
            assert issubclass(TokenBudgetTests, unittest.TestCase)
            assert "setUp" in TokenBudgetTests.__dict__
            probe = TokenBudgetTests("test_starts_full")
            probe.setUp()
            assert isinstance(getattr(probe, "budget", None), TokenBudget), "setUp must save self.budget = TokenBudget(100)."
            assert probe.budget.limit == 100 and probe.budget.used == 0
            passing = run_learner_tests(ReferenceBudget)
            assert passing.testsRun >= 5
            assert passing.wasSuccessful(), "Your tests must pass for the correct TokenBudget."
            assert not run_learner_tests(ExactLimitRejected).wasSuccessful(), "Missed bug: spending exactly the limit is rejected."
            assert not run_learner_tests(ChargesBeforeChecking).wasSuccessful(), "Missed bug: a rejected overspend still changes the budget."
            assert not run_learner_tests(ZeroAccepted).wasSuccessful(), "Missed bug: zero tokens are accepted."
            assert not run_learner_tests(NegativeAccepted).wasSuccessful(), "Missed bug: negative tokens are accepted."
            assert not run_learner_tests(RemainingIgnoresSpending).wasSuccessful(), "Missed bug: remaining() ignores spending."
            assert TokenBudget is supplied_budget
            """, [
                "`setUp` runs before every test, so each test can rely on a brand-new budget with nothing spent. Save it on `self` so the test methods can reach it.",
                "Success tests call `spend` and then compare `remaining()` with `assertEqual`. Rejection tests put the `spend` call inside `with self.assertRaises(ValueError):` and make any follow-up check after the `with` block, not inside it.",
                "For the overspend test, the `with` block holds `self.budget.spend(101)`; after it, at the method's indentation level, assert that `self.budget.remaining()` still equals `100`. For non-positive amounts write two separate `with` blocks."
            ], effort: .init(difficulty: .harder, scopeUnits: 3))
        ],
        assessment: exercise("testing-assessment", "Test a latency tracker", """
        Goal:
        Write a complete unittest test case for a latency tracker so that it passes for correct implementations and catches typical bugs.

        Starting code:
        - `import unittest` is supplied.
        - `class LatencyTracker` is a correct implementation. Do not change it.
        - `LatencyTracker(slow_threshold)` starts with an empty `readings` list.
        - `record(ms)` raises `ValueError` when `ms` is negative (`0` is allowed) and otherwise appends `ms`.
        - `average()` raises `ValueError` when there are no readings, and otherwise returns the mean of the readings.
        - `slow_count()` returns how many readings are greater than or equal to `slow_threshold`.
        - `class LatencyTrackerTests(unittest.TestCase)` has a `setUp` method and four test methods containing the placeholder `pass`.

        Your task:
        1. Keep the supplied `LatencyTracker` class with its exact name, and keep the class name `LatencyTrackerTests` and its method names.
        2. In `setUp`, save `self.tracker = LatencyTracker(500)`, calling the class by the name `LatencyTracker`, and use `self.tracker` in every test. The check temporarily swaps buggy classes in under the name `LatencyTracker`; because `setUp` runs before each test method, every test then receives a fresh object of the swapped class. Do not build trackers from a renamed copy or outside the test class.
        3. In `test_average_of_readings`, record `100`, `200` and `400`, then check with `assertAlmostEqual` that `average()` is `700 / 3`.
        4. In `test_empty_average_rejected`, check with `assertRaises` that `average()` raises `ValueError` when nothing was recorded.
        5. In `test_negative_rejected_zero_allowed`, check that `record(-1)` raises `ValueError`; then `record(0)` and check with `assertAlmostEqual` that `average()` is `0.0`.
        6. In `test_slow_count_boundary`, record `499`, `500` and `501`, then check with `assertEqual` that `slow_count()` is `2`.
        7. Compare averages only with `assertAlmostEqual`: an equivalent implementation whose averages differ by less than `0.000000001` must also pass.

        Expected result:
        - All four tests pass for the supplied tracker and for the equivalent version.
        - They fail for a tracker that uses whole-number division in `average()`.
        - They fail for a tracker whose `average()` returns `0.0` instead of raising when there are no readings.
        - They fail for a tracker that accepts negative readings.
        - They fail for a tracker that rejects a reading of `0`.
        - They fail for a tracker that counts slow readings only when they are strictly greater than the threshold.

        Check:
        Complete the theory questions and written explanation, then choose **Submit assessment**. It confirms `setUp` creates the tracker, then runs your tests against correct, equivalent and five buggy trackers. Work independently; hints and solutions are unavailable.
        """, """
        import unittest


        class LatencyTracker:
            def __init__(self, slow_threshold):
                self.slow_threshold = slow_threshold
                self.readings = []

            def record(self, ms):
                if ms < 0:
                    raise ValueError("latency cannot be negative")
                self.readings.append(ms)

            def average(self):
                if len(self.readings) == 0:
                    raise ValueError("no readings")
                return sum(self.readings) / len(self.readings)

            def slow_count(self):
                count = 0
                for ms in self.readings:
                    if ms >= self.slow_threshold:
                        count = count + 1
                return count


        class LatencyTrackerTests(unittest.TestCase):
            def setUp(self):
                pass

            def test_average_of_readings(self):
                pass

            def test_empty_average_rejected(self):
                pass

            def test_negative_rejected_zero_allowed(self):
                pass

            def test_slow_count_boundary(self):
                pass
        """, """
        import unittest


        class LatencyTracker:
            def __init__(self, slow_threshold):
                self.slow_threshold = slow_threshold
                self.readings = []

            def record(self, ms):
                if ms < 0:
                    raise ValueError("latency cannot be negative")
                self.readings.append(ms)

            def average(self):
                if len(self.readings) == 0:
                    raise ValueError("no readings")
                return sum(self.readings) / len(self.readings)

            def slow_count(self):
                count = 0
                for ms in self.readings:
                    if ms >= self.slow_threshold:
                        count = count + 1
                return count


        class LatencyTrackerTests(unittest.TestCase):
            def setUp(self):
                self.tracker = LatencyTracker(500)

            def test_average_of_readings(self):
                self.tracker.record(100)
                self.tracker.record(200)
                self.tracker.record(400)
                self.assertAlmostEqual(self.tracker.average(), 700 / 3)

            def test_empty_average_rejected(self):
                with self.assertRaises(ValueError):
                    self.tracker.average()

            def test_negative_rejected_zero_allowed(self):
                with self.assertRaises(ValueError):
                    self.tracker.record(-1)
                self.tracker.record(0)
                self.assertAlmostEqual(self.tracker.average(), 0.0)

            def test_slow_count_boundary(self):
                self.tracker.record(499)
                self.tracker.record(500)
                self.tracker.record(501)
                self.assertEqual(self.tracker.slow_count(), 2)
        """, """
        import io
        import unittest
        assert isinstance(globals().get("LatencyTrackerTests"), type), "Keep the test class named LatencyTrackerTests."
        assert "setUp" in LatencyTrackerTests.__dict__, "Keep the setUp method in LatencyTrackerTests."
        assert isinstance(globals().get("LatencyTracker"), type), "Keep the supplied LatencyTracker class with its original name. The check swaps buggy classes in under that name, so setUp must create the tracker with LatencyTracker(500)."
        learner_globals = LatencyTrackerTests.setUp.__globals__
        supplied_tracker = learner_globals["LatencyTracker"]
        def run_learner_tests(tracker_class):
            learner_globals["LatencyTracker"] = tracker_class
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(LatencyTrackerTests)
            result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
            learner_globals["LatencyTracker"] = supplied_tracker
            return result
        class ReferenceTracker:
            def __init__(self, slow_threshold):
                self.slow_threshold = slow_threshold
                self.readings = []
            def record(self, ms):
                if ms < 0:
                    raise ValueError("latency cannot be negative")
                self.readings.append(ms)
            def average(self):
                if len(self.readings) == 0:
                    raise ValueError("no readings")
                return sum(self.readings) / len(self.readings)
            def slow_count(self):
                count = 0
                for ms in self.readings:
                    if ms >= self.slow_threshold:
                        count = count + 1
                return count
        class EquivalentTracker(ReferenceTracker):
            def average(self):
                if len(self.readings) == 0:
                    raise ValueError("empty")
                total = 0.0
                for ms in self.readings:
                    total = total + ms / len(self.readings)
                return total + 0.0000000001
        class FloorAverage(ReferenceTracker):
            def average(self):
                if len(self.readings) == 0:
                    raise ValueError("no readings")
                return sum(self.readings) // len(self.readings)
        class EmptyAverageIsZero(ReferenceTracker):
            def average(self):
                if len(self.readings) == 0:
                    return 0.0
                return sum(self.readings) / len(self.readings)
        class NegativeAccepted(ReferenceTracker):
            def record(self, ms):
                self.readings.append(ms)
        class ZeroRejected(ReferenceTracker):
            def record(self, ms):
                if ms <= 0:
                    raise ValueError("latency must be positive")
                self.readings.append(ms)
        class StrictSlowCount(ReferenceTracker):
            def slow_count(self):
                count = 0
                for ms in self.readings:
                    if ms > self.slow_threshold:
                        count = count + 1
                return count
        assert issubclass(LatencyTrackerTests, unittest.TestCase)
        probe = LatencyTrackerTests("test_slow_count_boundary")
        probe.setUp()
        assert isinstance(getattr(probe, "tracker", None), LatencyTracker)
        assert probe.tracker.slow_threshold == 500 and probe.tracker.readings == []
        passing = run_learner_tests(ReferenceTracker)
        assert passing.testsRun >= 4
        assert passing.wasSuccessful(), "Your tests must pass for the correct LatencyTracker."
        assert run_learner_tests(EquivalentTracker).wasSuccessful(), "Your tests are too strict for tiny float differences."
        assert not run_learner_tests(FloorAverage).wasSuccessful(), "Missed bug: whole-number division in average()."
        assert not run_learner_tests(EmptyAverageIsZero).wasSuccessful(), "Missed bug: average() returns 0.0 with no readings."
        assert not run_learner_tests(NegativeAccepted).wasSuccessful(), "Missed bug: negative readings are accepted."
        assert not run_learner_tests(ZeroRejected).wasSuccessful(), "Missed bug: a reading of 0 is rejected."
        assert not run_learner_tests(StrictSlowCount).wasSuccessful(), "Missed bug: readings equal to the threshold are not counted as slow."
        assert LatencyTracker is supplied_tracker
        """, [], effort: .init(difficulty: .harder, scopeUnits: 4)),
        quiz: [
            question("testing-q1", "Inside class PriceTests(unittest.TestCase), which method will the test runner execute as a test?", ["def check_discount(self):", "def test_discount(self):", "def Discount(self):"], 1, "unittest runs only methods whose names start with test. Other methods are ignored unless a test calls them."),
            question("testing-q2", "Why compare average_rating([0.1, 0.2]) with assertAlmostEqual rather than assertEqual?", ["assertEqual cannot compare numbers", "assertAlmostEqual also checks for exceptions", "Float arithmetic has tiny rounding differences, so an exact comparison can fail on correct code"], 2, "The result is 0.15000000000000002. assertAlmostEqual rounds the difference to 7 decimal places, so correct code passes."),
            question("testing-q3", "Which evidence best shows that a test suite is strong?", ["It passes for the correct implementation and fails for deliberately buggy versions", "It contains many lines of code", "It never fails, whatever implementation it runs against"], 0, "A suite that still passes against a broken implementation has a blind spot. Mutation-style checks reveal which bugs it would miss.")
        ],
        sectionRoles: ["Tests are programs that check programs": .overview],
        generationNotes: """
        Exercises here assess test writing. Supply a small correct implementation, identical in starterCode and referenceSolution; the learner must not change it or its name. The learner completes one unittest.TestCase subclass with exact class and test_ method names (and setUp if required); the starter has it with pass placeholders, the referenceSolution a complete passing version. Tell the learner to call the implementation by its original name in each test or setUp. Keep unittest.main out of referenceSolution and testCode; instructions may offer unittest.main(argv=[''], exit=False) as an optional Run aid. Never use test discovery.
        In testCode, import io and unittest, assert the class exists and subclasses unittest.TestCase, and get the namespace from the implementation's __globals__ (or TestClass.setUp.__globals__). Write a helper that assigns a given implementation to the original name there, runs unittest.defaultTestLoader.loadTestsFromTestCase(TestClass) with unittest.TextTestRunner(stream=io.StringIO()).run(suite), restores the supplied object, and returns the result. Define a correct copy and at least two named buggy versions (one plausible mutation each). Assert the correct run wasSuccessful() and testsRun reaches the required method count; for floats, an equivalent version with tiny differences must also pass. Assert each buggy run fails, with a message naming the missed bug, then that the original name holds the supplied object. The pass-only starter must fail Check.
        """)
}
