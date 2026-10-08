import Foundation

extension Curriculum {
    static let basics = Chapter(
        id: "basics", title: "1. Your first Python steps", subtitle: "Start with names, numbers, and text",
        lesson: """
        # Code is a sequence of instructions

        You do not need to know Python yet. This chapter starts from the very beginning.

        A **program** is text that tells the computer what to do. The editor is where you write that text.

        Python reads the instructions from top to bottom, one line at a time. Spelling, punctuation, and the order of lines all matter.

        > **Note:** All the data in this course is invented. You do not need an account, an API key, or personal information to complete an exercise.

        ## Save a value with a name

        A **value** is a piece of information, such as a number or some text. A **variable** is a name you give a value so you can use it later.

        ### Assignment

        An **assignment** has the form `name = value`.

        > **Key idea:** Read the equals sign as “save the value on the right under the name on the left,” not as a question about whether two things are equal.

        ```python
        learner = "Mira"
        apples = 3
        print(learner)
        print(apples)
        ```

        ```text
        Mira
        3
        ```

        - `learner` holds text; `apples` holds a whole number.
        - Each `print(...)` line displays one value on a new line. You will learn more about `print` later in this chapter.

        ### Text and numbers

        The quotes mark where the text starts and ends; they are not part of the text itself.

        - Python calls text a **string**.
        - A whole number is called an **integer**.
        - A decimal number such as `1.5` is called a **float**.

        ### Using quotes correctly

        - Single quotes such as `'Mira'` also work. Use the same kind at both ends.
        - Use straight quotes, not curly quotation marks.
        - Numbers used for arithmetic have no quotes: `"3"` is text, while `3` is a number.

        ### Choosing names

        - Names are case-sensitive: `apples` and `Apples` are different.
        - Use letters and underscores, with no spaces.
        - A name cannot start with a digit.
        - Descriptive names help: `apple_count` is a useful name.

        > **Remember:** In exercises, use exactly the requested names, because the checker looks for them.

        ## Calculate with saved numbers

        Python first calculates the right side of an assignment, then saves the result under the name on the left.

        The arithmetic operators are:

        - `+` adds
        - `-` subtracts
        - `*` multiplies
        - `/` divides

        Multiplication and division happen before addition and subtraction. Parentheses group a calculation to do first.

        ```python
        boxes = 3
        apples_per_box = 4
        total_apples = boxes * apples_per_box
        remaining = total_apples - 2
        shared = remaining / 2
        print(total_apples)
        print(shared)
        ```

        ```text
        12
        5.0
        ```

        - `total_apples` is `3 * 4`, which is `12`.
        - `remaining` is `12 - 2`, which is `10`.
        - `shared` is `10 / 2`. Division with `/` gives a decimal result, so it displays `5.0`.

        > **Watch out:** The earlier lines must run before the lines that use their names.

        You can assign a new value to an existing variable; the new value replaces the old one. No special declaration is needed.

        ## Join text

        With two strings, `+` joins the text instead of adding numbers.

        - Python does not automatically insert spaces. Include a space inside quotes when you want one.
        - An empty string, `""`, contains no characters.

        ```python
        greeting = "Hello"
        learner = "Mira"
        message = greeting + " " + learner
        print(message)
        ```

        ```text
        Hello Mira
        ```

        The middle piece, `" "`, is a string containing a single space. It sits between the two words.

        > **Watch out:** Do not join a string and a number with `+` yet: these are different types of value. This chapter's text exercises use strings only.

        ## Work in the editor

        ### Display a value with print

        `print(message)` displays a value. The word `print` names a built-in operation; the parentheses contain the value to display.

        Printing does not save a result under a name. Our exercises check saved variables, so `answer = 5` and `print(5)` are not interchangeable.

        ### Display several values at once

        `print` can display several values at once: separate them with commas inside the parentheses.

        - They appear on one line, in order, with one space between each pair.
        - The values may be different types, such as a string and a number, because `print` is only displaying them, not joining them into one saved value.

        ```python
        learner = "Mira"
        apples = 3
        print(learner, apples)
        print("Apples:", apples)
        ```

        ```text
        Mira 3
        Apples: 3
        ```

        The commas are not part of the output; `print` adds the single space itself.

        ### Work through a practice exercise

        1. Open a practice exercise and read its Goal and Starting code sections.
        2. Keep the given input lines.
        3. Replace the starter's placeholder values, such as `0` or `''`, on the requested result lines. Do not leave a later placeholder that overwrites your work.
        4. Write Python in the editor without the lesson's triple-backtick fence markers.
        5. You may add `print` lines to inspect values, but still save every required result.
        6. Choose **Check solution** to run the checks.

        ### When a check fails

        A failed check is feedback, not a penalty. Compare the exact names, values, spaces, and types with Expected result, edit, and check again.

        - `NameError`: look for a misspelling or a name used before its assignment.
        - `SyntaxError`: this often means missing quotes or punctuation.

        > **Note:** Practice hints explain the next idea. The chapter assessment is independent work without hints or solutions.

        ### Understanding errors: three kinds of failure

        - A **syntax error** means Python cannot read the program's grammar. A missing closing quote can cause `SyntaxError`; the program does not begin running.
        - A **runtime error** happens while readable code runs. For example, using an unsaved name causes `NameError` and stops that run.
        - A **wrong result** means the code runs but does not meet its goal. A failed exercise check may report `AssertionError`: a checked requirement was not met. This does not necessarily mean Python could not run your code.

        This intentionally broken line is shown as text, not as a runnable example:

        ```text
        message = "Welcome
        ```

        Quotes must mark both ends of a string. An error's wording can differ between Python versions, so use the category, location, and your source together.

        ### Understanding errors: read the traceback

        A **traceback** describes where a runtime error surfaced. Consider this intentionally broken two-line program:

        ```text
        apples = 3
        total = apples + pears
        ```

        A shortened error report might look like this:

        ```text
        Traceback (most recent call last):
          File "learner.py", line 2, in <module>
            total = apples + pears
        NameError: name 'pears' is not defined
        ```

        1. Read the last line first: `NameError` is the category; the message names `pears`.
        2. `line 2` identifies where the missing name was used. `<module>` here means the program's top-level instructions.
        3. Inspect that line and the earlier assignments. The line number marks where the symptom surfaced, not necessarily where the mistake began: perhaps an earlier name was misspelled or never saved.

        Syntax errors instead point to a source line, sometimes with a caret (`^`) near where reading failed. Look nearby too. A location in the app's checks is not a line to edit in your program; compare your saved results with the exercise contract.

        ### Understanding errors: investigate one change at a time

        1. State the **expected** value or behavior from the task.
        2. Reproduce the **observed** behavior with a small run and unchanged inputs.
        3. Read the error category and location, or print saved values if the result is wrong.
        4. Make one **hypothesis**: a specific explanation you can test.
        5. Change one thing that would test that explanation.
        6. Run again, then check the solution. Recheck any earlier working example so the repair has not broken it.

        Printing between assignments helps locate when a value changes:

        ```python
        tickets = 4
        total = tickets + 2
        print("After calculation:", total)
        total = 0
        print("At the end:", total)
        ```

        ```text
        After calculation: 6
        At the end: 0
        ```

        Both lines run successfully, but the last assignment replaces the earlier total. Compare the first point where observed values differ from your expectation rather than guessing at the final line.

        > **Key idea:** Errors are evidence, not punishment. A failed practice check does not undo what you have learned. Inspect, revise, and try again.
        """,
        exercises: [
            exercise("basics-name", "Save a learner name", """
                     Goal:
                     Save a name as text in a variable.

                     Starting code:
                     - `learner_name = ''` is an empty-text placeholder. Replace it.
                     - There are no input lines to keep.

                     Your task:
                     1. Replace the placeholder so `learner_name` holds the string `'Mira'`.
                     2. Keep the exact variable name `learner_name` and the capital `M`.

                     Expected result:
                     - `learner_name` is `'Mira'` (a string; the quote characters are not part of the value).

                     Check:
                     Choose **Check solution**. The check reads `learner_name`; printing alone does not count.
                     """,
                     "learner_name = ''\n",
                     "learner_name = 'Mira'\n",
                     "assert type(learner_name) is str\nassert learner_name == 'Mira'\n",
                     ["An assignment saves the right-hand value under the name on the left.", "Text needs matching quotes; replace the empty text between the starter's quotes in `learner_name = ''`.", "Names and text are case-sensitive: keep `learner_name` and the capital `M`."]),
            exercise("basics-total", "Add two fruit counts", """
                     Goal:
                     Find how many pieces of fruit you have altogether.

                     Starting code:
                     - `apples = 3` is an input. Keep it unchanged.
                     - `pears = 2` is an input. Keep it unchanged.
                     - `total_fruit = 0` is a placeholder, not the answer. Replace it.

                     Your task:
                     1. Keep `apples` and `pears` unchanged.
                     2. Replace the `total_fruit` placeholder with an addition that uses the two input names.
                     3. Make sure the result is saved as an integer, not quoted text.

                     Expected result:
                     - `total_fruit` is `5`.

                     Check:
                     Choose **Check solution**. It checks the inputs and the saved `total_fruit` value; `print` is optional.
                     """,
                     "apples = 3\npears = 2\ntotal_fruit = 0\n",
                     "apples = 3\npears = 2\ntotal_fruit = apples + pears\n",
                     "assert apples == 3 and pears == 2\nassert type(total_fruit) is int\nassert total_fruit == 5\n",
                     ["Use the input names `apples` and `pears` to read the numbers already saved above.", "The `+` operator adds two numbers. Numbers for arithmetic do not need quotes.", "Replace the existing `total_fruit` line rather than keeping a later assignment to zero."]),
            exercise("basics-message", "Join a greeting and a name", """
                     Goal:
                     Make a greeting by joining pieces of text together.

                     Starting code:
                     - `greeting = 'Hello'` is an input. Keep it unchanged.
                     - `learner = 'Mira'` is an input. Keep it unchanged.
                     - `message = ''` is the result placeholder. Replace it.

                     Your task:
                     1. Keep `greeting` and `learner` unchanged.
                     2. Save a string in `message` by joining `greeting`, one space, and `learner`, in that order.
                     3. Do not add punctuation or extra spaces.

                     Expected result:
                     - `message` is exactly `'Hello Mira'`.

                     Check:
                     Choose **Check solution**. It checks the inputs and `message`; displayed output is not the saved result.
                     """,
                     "greeting = 'Hello'\nlearner = 'Mira'\nmessage = ''\n",
                     "greeting = 'Hello'\nlearner = 'Mira'\nmessage = greeting + ' ' + learner\n",
                     "assert greeting == 'Hello' and learner == 'Mira'\nassert type(message) is str\nassert message == 'Hello Mira'\n",
                     ["The `+` operator joins strings without adding any spaces of its own.", "A single space inside matching quotes, `' '`, is a string you can join between the inputs.", "Save the joined text in `message`; a `print` call only displays it."]),
            exercise("basics-debug-quote", "Debug: a greeting will not run", """
                     Goal:
                     Repair a greeting program that stops with `SyntaxError` before it can display a message.

                     Starting code:
                     - `learner = 'Mira'` is an input. Keep it unchanged.
                     - The remaining lines are an attempted greeting, not placeholders. They currently cannot run.

                     Your task:
                     1. Run the starter and read the error category and source location.
                     2. Repair the program so `greeting` saves the text `'Hello'` and `message` joins it with one space and `learner`.
                     3. Keep the result names and display `message` with the existing print line.

                     Expected result:
                     - `greeting` is `'Hello'` and `message` is exactly `'Hello Mira'`.
                     - The program displays `Hello Mira` without an error.

                     Check:
                     Choose **Check solution** after repairing the source. It checks the unchanged input and saved text, not just the displayed output.
                     """,
                     "learner = 'Mira'\ngreeting = 'Hello\nmessage = greeting + ' ' + learner\nprint(message)\n",
                     "learner = 'Mira'\ngreeting = 'Hello'\nmessage = greeting + ' ' + learner\nprint(message)\n",
                     "assert learner == 'Mira'\nassert greeting == 'Hello'\nassert message == 'Hello Mira'\n",
                     ["A syntax error happens before the program runs. Start at the indicated source line rather than changing the desired message.", "Compare the punctuation on the two text assignments. Each string needs a clear beginning and end.", "The `greeting` string starts with a single quote. Add the matching closing quote after `Hello`, keeping the text and the joining expression unchanged."],
                     effort: .init(difficulty: .easier, scopeUnits: 1), expectedStarterError: "SyntaxError"),
            exercise("basics-debug-saved-total", "Debug: the total disappears", """
                     Goal:
                     Repair a program that runs but displays `0` instead of the number of seats available.

                     Starting code:
                     - `front_seats = 4` and `back_seats = 3` are inputs. Keep them unchanged.
                     - The program attempts to save and display `total_seats`.

                     Your task:
                     1. Trace the saved value of `total_seats` from top to bottom. You may add print lines between assignments.
                     2. Repair the code so the final `total_seats` is calculated from both seat counts.
                     3. Keep the final print line. Do not replace the calculation with a fixed answer.

                     Expected result:
                     - `total_seats` is the integer `7`, and the final line displays `7`.

                     Check:
                     Choose **Check solution**. It checks the inputs and the final saved total for this example. A printed intermediate answer alone is not enough.
                     """,
                     "front_seats = 4\nback_seats = 3\ntotal_seats = front_seats + back_seats\ntotal_seats = 0\nprint(total_seats)\n",
                     "front_seats = 4\nback_seats = 3\ntotal_seats = front_seats + back_seats\nprint(total_seats)\n",
                     "assert front_seats == 4 and back_seats == 3\nassert type(total_seats) is int and total_seats == 7\n",
                     ["Successful execution does not guarantee the right result. Compare the saved total after each assignment with your expected total.", "An assignment replaces the value already held by that name. Which assignment runs last for `total_seats`?", "Keep the calculation using both inputs, and remove the later assignment that saves zero before the final print."],
                     effort: .init(difficulty: .easier, scopeUnits: 1))
        ],
        assessment: exercise("basics-assessment", "Prepare a simple picnic note", """
                             Goal:
                             Save a fruit total and a short picnic note.

                             Starting code:
                             - `apples = 4` and `pears = 3` are inputs. Keep them unchanged.
                             - `place = 'Park'` and `activity = 'picnic'` are inputs. Keep them unchanged.
                             - `total_fruit = 0` is a placeholder. Replace it.
                             - `note = ''` is a placeholder. Replace it.

                             Your task:
                             1. Keep all four inputs unchanged and keep the exact result names `total_fruit` and `note`.
                             2. Set `total_fruit` to the integer number of fruit pieces altogether.
                             3. Set `note` to a string containing the place, one space, and the activity, with no extra characters.

                             Expected result:
                             - `total_fruit` is `7`.
                             - `note` is exactly `'Park picnic'`.

                             Check:
                             Complete the theory questions and written explanation, then choose **Submit assessment** to check the saved values. Printing is not required.
                             Complete this assessment independently; hints and solutions are unavailable.
                             """,
                             "apples = 4\npears = 3\nplace = 'Park'\nactivity = 'picnic'\ntotal_fruit = 0\nnote = ''\n",
                             "apples = 4\npears = 3\nplace = 'Park'\nactivity = 'picnic'\ntotal_fruit = apples + pears\nnote = place + ' ' + activity\n",
                             "assert apples == 4 and pears == 3\nassert place == 'Park' and activity == 'picnic'\nassert type(total_fruit) is int and total_fruit == 7\nassert type(note) is str and note == 'Park picnic'\n",
                             []),
        quiz: [
            question("basics-q1", "What does learner = 'Mira' do?", ["Saves text under the name learner", "Displays Mira automatically", "Asks whether two values are equal"], 0, "An assignment saves the right-hand value under the variable name on the left. Displaying it requires print."),
            question("basics-q2", "What is saved by total = 3 + 2?", ["The string '32'", "The integer 5", "Nothing until it is printed"], 1, "Unquoted numbers are numeric values, so + adds them. Assignment saves the result without needing print."),
            question("basics-q3", "What does 'Good' + 'day' produce?", ["'Good day'", "'Good+day'", "'Goodday'"], 2, "Joining strings does not insert a space. A desired space must be included in the text.")
        ],
        sectionRoles: ["Code is a sequence of instructions": .overview])
}
