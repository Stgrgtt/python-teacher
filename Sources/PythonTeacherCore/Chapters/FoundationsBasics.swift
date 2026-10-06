import Foundation

extension Curriculum {
    static let basics = Chapter(
        id: "basics", title: "1. Your first Python steps", subtitle: "Start with names, numbers, and text",
        lesson: """
        # Code is a sequence of instructions

        You do not need to know Python yet. A program is text that tells the computer what to do. The editor is where you write that text. Python reads the instructions from top to bottom, one line at a time. Spelling, punctuation, and the order of lines matter. All the data in this course is invented; you do not need an account, an API key, or personal information to complete an exercise.

        ## Save a value with a name

        A value is a piece of information, such as a number or some text. A variable is a name you give a value so you can use it later. An assignment has the form `name = value`. Read the equals sign as “save the value on the right under the name on the left,” not as a question about whether two things are equal.

        ```python
        learner = "Mira"
        apples = 3
        print(learner)
        print(apples)
        ```

        This displays Mira, then 3 on a new line. `learner` holds text; `apples` holds a whole number. The quotes mark where the text starts and ends; they are not part of the text itself. Python calls text a **string** and a whole number an **integer**. Single quotes such as `'Mira'` also work: use the same kind at both ends. Use straight quotes, not curly quotation marks. Numbers used for arithmetic have no quotes. `"3"` is text, while `3` is a number. A decimal number such as `1.5` is called a **float**.

        Names are case-sensitive: `apples` and `Apples` are different. Use letters and underscores, with no spaces; a name cannot start with a digit. `apple_count` is a useful descriptive name. In exercises, use exactly the requested names because the checker looks for them.

        ## Calculate with saved numbers

        Python first calculates the right side of an assignment. `+` adds, `-` subtracts, `*` multiplies, and `/` divides. Multiplication and division happen before addition and subtraction; parentheses group a calculation to do first.

        ```python
        boxes = 3
        apples_per_box = 4
        total_apples = boxes * apples_per_box
        remaining = total_apples - 2
        shared = remaining / 2
        print(total_apples)
        print(shared)
        ```

        The results displayed are 12 and 5.0. The earlier lines must run before the lines that use their names. You can assign a new value to an existing variable; the new value replaces the old one. No special declaration is needed.

        ## Join text

        With two strings, `+` joins the text instead of adding numbers. Python does not automatically insert spaces. Include a space inside quotes when you want one. An empty string, `""`, contains no characters.

        ```python
        greeting = "Hello"
        learner = "Mira"
        message = greeting + " " + learner
        print(message)
        ```

        This displays Hello Mira. Do not join a string and a number with `+` yet: these are different types of value. This chapter's text exercises use strings only.

        ## Work in the editor

        `print(message)` displays a value. The word `print` names a built-in operation; parentheses contain the value to display. Printing does not save a result under a name. Our exercises check saved variables, so `answer = 5` and `print(5)` are not interchangeable.

        `print` can display several values at once: separate them with commas inside the parentheses. They appear on one line, in order, with one space between each pair. The values may be different types, such as a string and a number, because `print` is only displaying them, not joining them into one saved value.

        ```python
        learner = "Mira"
        apples = 3
        print(learner, apples)
        print("Apples:", apples)
        ```

        This displays `Mira 3`, then `Apples: 3` on a new line. The commas are not part of the output; `print` adds the single space itself.

        Open a practice exercise and read its Goal and Starting code sections. Keep the given input lines. Replace the starter's placeholder values, such as `0` or `''`, on the requested result lines; do not leave a later placeholder that overwrites your work. Write Python in the editor without the lesson's triple-backtick fence markers. You may add `print` lines to inspect values, but still save every required result. Choose **Check solution** to run the checks. A failed check is feedback, not a penalty: compare the exact names, values, spaces, and types with Expected result, edit, and check again. If Python reports `NameError`, look for a misspelling or a name used before its assignment. `SyntaxError` often means missing quotes or punctuation. Practice hints explain the next idea; the chapter assessment is independent work without hints or solutions.
        """,
        exercises: [
            exercise("basics-name", "Save a learner name", "Goal:\nSave a name as text in a variable.\n\nStarting code:\nlearner_name = '' is an empty-text placeholder. There are no input lines to preserve.\n\nYour task:\n1. Replace the placeholder so learner_name holds the string 'Mira'. Keep the exact variable name and capital M.\n\nExpected result:\nlearner_name is 'Mira' (a string, without quote characters in the value).\n\nCheck:\nChoose Check solution. The check reads learner_name; printing alone does not count.",
                     "learner_name = ''\n",
                     "learner_name = 'Mira'\n",
                     "assert type(learner_name) is str\nassert learner_name == 'Mira'\n",
                     ["An assignment saves the right-hand value under the name on the left.", "Text needs matching quotes; replace the empty text between the starter's quotes.", "Names and text are case-sensitive: keep learner_name and the capital M."]),
            exercise("basics-total", "Add two fruit counts", "Goal:\nFind how many pieces of fruit you have altogether.\n\nStarting code:\napples = 3 and pears = 2 are inputs. total_fruit = 0 is a placeholder, not the answer.\n\nYour task:\n1. Keep apples and pears unchanged.\n2. Replace the total_fruit placeholder with an addition using the two input names. Save the result as an integer, not quoted text.\n\nExpected result:\ntotal_fruit is 5.\n\nCheck:\nChoose Check solution. It checks the inputs and the saved total_fruit value; print is optional.",
                     "apples = 3\npears = 2\ntotal_fruit = 0\n",
                     "apples = 3\npears = 2\ntotal_fruit = apples + pears\n",
                     "assert apples == 3 and pears == 2\nassert type(total_fruit) is int\nassert total_fruit == 5\n",
                     ["Use the input names to read the numbers already saved above.", "The + operator adds two numbers. Numbers for arithmetic do not need quotes.", "Replace the existing total_fruit line rather than keeping a later assignment to zero."]),
            exercise("basics-message", "Join a greeting and a name", "Goal:\nMake a greeting by joining text.\n\nStarting code:\ngreeting = 'Hello' and learner = 'Mira' are inputs. message = '' is the result placeholder.\n\nYour task:\n1. Keep greeting and learner unchanged.\n2. Save a string in message by joining greeting, one space, and learner in that order. Do not add punctuation or extra spaces.\n\nExpected result:\nmessage is exactly 'Hello Mira'.\n\nCheck:\nChoose Check solution. It checks the inputs and message; displayed output is not the saved result.",
                     "greeting = 'Hello'\nlearner = 'Mira'\nmessage = ''\n",
                     "greeting = 'Hello'\nlearner = 'Mira'\nmessage = greeting + ' ' + learner\n",
                     "assert greeting == 'Hello' and learner == 'Mira'\nassert type(message) is str\nassert message == 'Hello Mira'\n",
                     ["The + operator joins strings without adding any spaces of its own.", "A single space inside matching quotes is a string you can join between the inputs.", "Save the joined text in message; a print call only displays it."])
        ],
        assessment: exercise("basics-assessment", "Prepare a simple picnic note", "Goal:\nSave a fruit total and a short picnic note.\n\nStarting code:\napples = 4, pears = 3, place = 'Park', and activity = 'picnic' are inputs. total_fruit and note are placeholders.\n\nYour task:\n1. Keep all four inputs unchanged and keep the exact result names.\n2. Set total_fruit to the integer number of fruit pieces altogether.\n3. Set note to a string containing the place, one space, and the activity, with no extra characters.\n\nExpected result:\ntotal_fruit is 7 and note is exactly 'Park picnic'.\n\nCheck:\nComplete the theory questions and written explanation, then choose Submit assessment to check the saved values. Printing is not required. Complete this assessment independently; hints and solutions are unavailable.",
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
