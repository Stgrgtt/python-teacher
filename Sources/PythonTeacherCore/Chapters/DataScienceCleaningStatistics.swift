import Foundation

extension Curriculum {
    static let dsCleaning = Chapter(
        id: "ds-cleaning", title: "Cleaning tabular data", subtitle: "Turn messy CSV text into trustworthy rows",
        track: .dataScience, prerequisites: ["files"],
        lesson: #"""
        # Clean data before you analyze it

        Data science means answering questions with data: which model is fastest, how many survey answers are missing, whether a city is warmer than another. Real data almost never arrives ready to use. A file exported by a person or a program can contain extra spaces, numbers stored as text, several spellings of the same thing, blanks, and repeated rows. **Data cleaning** is the work of turning that raw data into consistent values you can trust before calculating anything.

        This chapter uses only Python's standard library. Later chapters introduce pandas, a popular third-party library that does many of these steps with one function call each. Learning them by hand first means you will understand what pandas is doing for you: reading a table, choosing column types, marking missing values, normalizing text, dropping duplicates, and writing the result. All data here is invented.

        ## Tables as lists of dictionaries

        A **table** is data arranged in rows and columns. A **row** describes one item, such as one model run. A **column** is one kind of information that every row has, such as the token count. The **header** is the first line of a CSV file and names the columns. In plain Python, a convenient table shape is a list of dictionaries: the list holds the rows in order, and each dictionary maps column names (keys) to that row's values.

        ```python
        runs = [
            {"model": "orbit", "tokens": 120, "latency_ms": 340.5},
            {"model": "nova", "tokens": 80, "latency_ms": 210.0},
        ]
        first = runs[0]
        print(first["model"])
        tokens_column = [row["tokens"] for row in runs]
        print(tokens_column)
        print(len(runs))
        ```

        This prints orbit, then `[120, 80]`, then 2. Indexing the list picks a row; looking up a key in a row picks one cell; a comprehension over all rows collects a whole column. pandas calls this kind of table a DataFrame.

        The files chapter showed `csv.DictReader`, which reads CSV rows as dictionaries using the header as keys. It needs something that behaves like an open file. When the CSV is already in a string (for example, text received from another function or typed into a test), the `io` module helps: `io.StringIO(text)` creates an in-memory object that acts like a file opened for reading, whose contents are that text. No real file is created.

        ```python
        import csv
        import io

        text = "model,tokens,latency_ms\norbit,120,340.5\nnova,80,210\n"
        reader = csv.DictReader(io.StringIO(text))
        rows = list(reader)
        print(rows[0])
        print(reader.fieldnames)
        assert rows[0]["tokens"] == "120"
        assert len(rows) == 2
        ```

        The first print shows `{'model': 'orbit', 'tokens': '120', 'latency_ms': '340.5'}` and the second shows `['model', 'tokens', 'latency_ms']`. `list(reader)` collects every remaining row into a list; `reader.fieldnames` holds the header names. The header line itself is not a data row. Notice the quotes around `'120'`: **every value from a CSV file is a string**, even when it looks like a number. CSV has no idea what a number is. The same reader works with a real file opened with `encoding="utf-8"` and `newline=""`:

        ```python
        import csv

        with open("runs.csv", "w", encoding="utf-8", newline="") as handle:
            handle.write("model,tokens\norbit,120\nnova,80\n")
        with open("runs.csv", encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
        print(rows)
        ```

        This prints `[{'model': 'orbit', 'tokens': '120'}, {'model': 'nova', 'tokens': '80'}]`. Collect the rows inside the `with` block: once the block ends, the file is closed and the reader can no longer read from it.

        ## Convert text into the right types

        **Type conversion** changes a value from one type to another. `int(text)` converts whole-number text such as `"120"` to the integer 120; `float(text)` converts decimal text such as `"340.5"` to a float. Both ignore spaces at the edges, but stripping first with `.strip()` makes your intent clear and also cleans text columns. If the text is not a valid number, the conversion raises ValueError instead of guessing. `int("12.5")` fails because 12.5 is not a whole number, while `float("12.5")` works.

        ```python
        raw = " 120 "
        tokens = int(raw.strip())
        latency = float("340.5")
        print(tokens + 1)
        print(latency * 2)
        try:
            int("12.5")
        except ValueError:
            print("12.5 is not an integer")
        ```

        This prints 121, 681.0, and 12.5 is not an integer. Converting a row means building a **new** dictionary in which each column has its proper type. Leaving the original row unchanged lets you compare raw and cleaned data while debugging.

        ```python
        def convert_row(row):
            return {
                "model": row["model"].strip(),
                "tokens": int(row["tokens"]),
                "latency_ms": float(row["latency_ms"]),
            }

        raw_row = {"model": " orbit ", "tokens": "120", "latency_ms": "210"}
        clean_row = convert_row(raw_row)
        print(clean_row)
        assert type(clean_row["latency_ms"]) is float
        assert raw_row["tokens"] == "120"
        ```

        This prints `{'model': 'orbit', 'tokens': 120, 'latency_ms': 210.0}`. Note that `float("210")` gives 210.0: a float column should hold floats even when a value happens to be whole.

        Yes/no columns need care: `bool("False")` is True, because `bool` of any nonempty string is True. Compare the cleaned text against allowed spellings instead:

        ```python
        def to_bool(text):
            cleaned = text.strip().lower()
            if cleaned in ("yes", "true", "1"):
                return True
            if cleaned in ("no", "false", "0"):
                return False
            raise ValueError("not a yes/no value: " + text)

        print(bool("False"))
        print(to_bool(" Yes "))
        print(to_bool("false"))
        ```

        This prints True, True, False. pandas performs the same conversions when it infers a column's type (its "dtype") while reading a CSV file.

        ## Mark missing values

        A **missing value** is a cell where the information was not recorded. Files show it in many ways: an empty cell, `NA` ("not available"), `N/A`, `null`, or a dash. These spellings are called **missing markers**. A cleaning step should recognize them and replace them with one clear Python value: `None`, which means "no value". Never replace a missing number with 0: zero is a real measurement, and it would silently pull averages down.

        A common recipe: strip the text, lowercase it, and check whether it is in a set of known markers. Only if it is not missing, convert it. Anything else that fails conversion is not missing but **invalid**, and should raise ValueError so you notice it.

        ```python
        MISSING = {"", "na", "n/a", "null", "-"}

        def parse_number(text):
            cleaned = text.strip()
            if cleaned.lower() in MISSING:
                return None
            return float(cleaned)

        values = ["3.5", " ", "NA", "n/a", "7", "null"]
        parsed = [parse_number(value) for value in values]
        print(parsed)
        missing_count = len([value for value in parsed if value is None])
        print(missing_count)
        ```

        This prints `[3.5, None, None, None, 7.0, None]` and 4. Use `value is None` (identity) to test for None, as the reliability chapter explained. After marking, you choose a policy. **Dropping** removes missing values (or whole rows) before a calculation. **Filling** (also called imputation) replaces them with a chosen value. Each choice changes the results, so report it:

        ```python
        scores = [0.8, None, 0.6, None]
        present = [score for score in scores if score is not None]
        filled = []
        for score in scores:
            if score is None:
                filled.append(0.0)
            else:
                filled.append(score)
        print(sum(present) / len(present))
        print(sum(filled) / len(filled))
        ```

        The first average is 0.7; filling with zero gives 0.35, half as large, because two invented zeros were averaged in. In pandas, missing numbers become NaN, and `isna`, `dropna`, and `fillna` perform these steps.

        ## Normalize text and remove duplicates

        **Normalization** rewrites values that mean the same thing into one standard form, so that `"  Orbit   MINI "` and `"orbit mini"` are treated as equal. Two string tools help. `text.split()` with no argument splits text at any run of whitespace and drops whitespace at the edges, returning a list of words. `" ".join(words)` does the reverse: it joins a list of strings into one string with a single space between items. Together they collapse repeated spaces.

        ```python
        raw = "  Orbit   MINI  "
        words = raw.split()
        print(words)
        normalized = " ".join(words).lower()
        print(normalized)
        ```

        This prints `['Orbit', 'MINI']`, then orbit mini. A dictionary can map known alternative spellings to a standard one; `.get(cleaned, cleaned)` keeps any value that has no alternative:

        ```python
        CITY_NAMES = {"nyc": "new york", "new york city": "new york"}

        def normalize_city(text):
            cleaned = " ".join(text.split()).lower()
            return CITY_NAMES.get(cleaned, cleaned)

        print(normalize_city("  NYC "))
        print(normalize_city("New   York City"))
        print(normalize_city("Lima"))
        ```

        This prints new york, new york, lima.

        A **duplicate** is a row that repeats an earlier row. Deciding what counts as "the same" is part of the cleaning rules: it may be the whole row, or only an identifying column such as an ID. **De-duplication** keeps the first occurrence and skips later ones. Track the keys you have already seen in a set. Dictionaries cannot be stored in a set, but tuples of strings can, so build a tuple **key** from the normalized columns that define sameness:

        ```python
        rows = [
            {"prompt": "Hello  world", "label": "greeting"},
            {"prompt": "hello world", "label": "Greeting "},
            {"prompt": "Bye", "label": "farewell"},
        ]
        seen = set()
        unique = []
        duplicates = 0
        for row in rows:
            prompt = " ".join(row["prompt"].split()).lower()
            label = row["label"].strip().lower()
            key = (prompt, label)
            if key in seen:
                duplicates += 1
                continue
            seen.add(key)
            unique.append({"prompt": prompt, "label": label})
        print(unique)
        print(duplicates)
        ```

        This prints `[{'prompt': 'hello world', 'label': 'greeting'}, {'prompt': 'bye', 'label': 'farewell'}]` and 1. Normalize **before** comparing: without it, the first two rows would look different. The loop appends a **new** dictionary holding the normalized values rather than the original `row`, so the cleaned list contains tidy text and the input rows stay unchanged; appending `row` itself would keep the messy spelling `'Hello  world'`. Because rows are visited in order and only unseen keys are appended, the original order is preserved. pandas offers `str.strip`, `str.lower`, and `drop_duplicates` for this work.

        ## Report and write the cleaned table

        A **cleaning report** is a small summary of what cleaning did: how many rows came in, how many went out, how many values were missing, how many duplicates were removed. It lets someone else trust (or question) your results, and is easy to build as a dictionary of counts while you clean.

        To save the cleaned table, use `csv.DictWriter` from the files chapter. `fieldnames` gives the column order. `writeheader()` writes the header line, and `writerows(rows)` writes every dictionary in a list as one line each (`writerow(row)` writes a single one). Numbers are written as text using Python's normal spelling, so 20.0 is written as `20.0`, and `None` is written as an empty cell. Open the file with `"w"` mode, `encoding="utf-8"`, and `newline=""` so the csv module controls line endings.

        ```python
        import csv

        cleaned = [
            {"model": "orbit", "tokens": 120, "score": 0.8},
            {"model": "nova", "tokens": 80, "score": None},
        ]
        report = {"rows_in": 3, "rows_out": len(cleaned), "missing_scores": 1, "duplicates": 1}
        with open("cleaned.csv", "w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=["model", "tokens", "score"])
            writer.writeheader()
            writer.writerows(cleaned)
        with open("cleaned.csv", encoding="utf-8", newline="") as handle:
            back = list(csv.DictReader(handle))
        print(back)
        print(report)
        ```

        The first print shows `[{'model': 'orbit', 'tokens': '120', 'score': '0.8'}, {'model': 'nova', 'tokens': '80', 'score': ''}]`. Reading the file back is a good habit: it proves what was actually written, and it shows that the types are lost again, since every CSV value returns as text. pandas writes a table with `to_csv`.

        ## Common mistakes and debugging

        - Doing arithmetic on CSV values without converting: `"120" + "80"` is `"12080"`, not 200. Check `type(value)` when results look strange.
        - Treating missing values as zero, or checking markers before stripping and lowercasing, so `" NA "` slips through and causes a ValueError in `float`.
        - Normalizing after de-duplicating instead of before, so near-identical rows survive.
        - Changing the caller's rows in place. Build new dictionaries and lists instead.
        - Using `csv.DictReader` after its file was closed, or forgetting `newline=""` when writing.

        When a cleaning function fails, print the first raw row and the first cleaned row side by side, then test the smallest input that still fails: one header line plus one data row. Try an empty table (header only) too; it should produce an empty result and a report full of zeros, not an error.
        """#,
        exercises: [
            exercise("ds-cleaning-load", "Load typed rows from CSV text", #"""
                Goal:
                Read invented model-run data from CSV text into a table of typed rows. Each row describes one run: the model name, the number of tokens processed, and the latency (response time) in milliseconds.

                Starting code:
                import csv and import io are supplied. def load_runs(text): is the required function; return [] is a placeholder. text is a string holding a whole CSV file, not a file name.

                Your task:
                1. Keep both imports, the function name, and the parameter. The first line of text is always the header model,tokens,latency_ms.
                2. Read the rows with csv.DictReader over io.StringIO(text), as shown in the lesson.
                3. For each data row, build a new dictionary with three keys: 'model' as the string with edge spaces removed, 'tokens' as an int, and 'latency_ms' as a float (also when the text is whole, such as '210').
                4. Return a list of these dictionaries in the same order as the file. A header with no data rows returns []. You may assume every value is present and valid.

                Expected result:
                load_runs('model,tokens,latency_ms\norbit,120,340.5\n nova ,80,210\n') returns [{'model': 'orbit', 'tokens': 120, 'latency_ms': 340.5}, {'model': 'nova', 'tokens': 80, 'latency_ms': 210.0}].
                load_runs('model,tokens,latency_ms\n') returns [].

                Check:
                Choose Check solution. It checks the converted values, their exact types (int and float), row order, and the header-only case.
                """#,
                #"""
                import csv
                import io

                def load_runs(text):
                    return []
                """#,
                #"""
                import csv
                import io

                def load_runs(text):
                    rows = []
                    for row in csv.DictReader(io.StringIO(text)):
                        rows.append({
                            "model": row["model"].strip(),
                            "tokens": int(row["tokens"]),
                            "latency_ms": float(row["latency_ms"]),
                        })
                    return rows
                """#,
                #"""
                result = load_runs("model,tokens,latency_ms\norbit,120,340.5\n nova ,80,210\n")
                assert result == [{"model": "orbit", "tokens": 120, "latency_ms": 340.5}, {"model": "nova", "tokens": 80, "latency_ms": 210.0}]
                assert type(result[0]["tokens"]) is int
                assert type(result[1]["latency_ms"]) is float
                assert load_runs("model,tokens,latency_ms\n") == []
                single = load_runs("model,tokens,latency_ms\nx,7,0.5\n")
                assert single == [{"model": "x", "tokens": 7, "latency_ms": 0.5}]
                """#,
                ["DictReader needs a file-like object. io.StringIO turns the text string into one, and each row it produces is a dictionary of strings keyed by the header names.", "Loop over the reader and, for every row, create a fresh dictionary whose values are converted: strip the model text, convert tokens with int, and latency_ms with float.", "Append each converted dictionary to a list that starts empty before the loop, and return that list after the loop finishes."],
                effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("ds-cleaning-missing", "Mark missing scores", #"""
                Goal:
                Clean one column of evaluation scores read from a CSV file. Some cells are missing and use different missing markers; the rest are numbers stored as text.

                Starting code:
                def clean_scores(values): is the required function. return [], 0 is a placeholder that returns a tuple of an empty list and zero.

                Your task:
                1. Keep the function name and parameter. values is a list of strings. Do not change it.
                2. For each value, remove edge whitespace. If the stripped, lowercased text is one of the missing markers '', 'na', 'n/a', 'null', or '-', the cleaned value is None.
                3. Otherwise convert the stripped text with float. If it is not a number (for example 'high'), let float raise its ValueError; do not catch it or return a fallback.
                4. Return a tuple of two items: the list of cleaned values in the original order, and the integer number of missing values.

                Expected result:
                clean_scores(['0.8', ' NA ', '', '1', 'n/a', 'null', '-', ' 0.25 ']) returns ([0.8, None, None, 1.0, None, None, None, 0.25], 5).
                clean_scores([]) returns ([], 0).
                clean_scores(['0.5', 'high']) raises ValueError.

                Check:
                Choose Check solution. It checks every marker in mixed case and with spaces, float conversion, the missing count, empty input, unchanged input, and the ValueError for invalid text.
                """#,
                #"""
                def clean_scores(values):
                    return [], 0
                """#,
                #"""
                MISSING = {"", "na", "n/a", "null", "-"}

                def clean_scores(values):
                    cleaned = []
                    missing = 0
                    for value in values:
                        text = value.strip()
                        if text.lower() in MISSING:
                            cleaned.append(None)
                            missing += 1
                        else:
                            cleaned.append(float(text))
                    return cleaned, missing
                """#,
                #"""
                cleaned, missing = clean_scores(["0.8", " NA ", "", "1", "n/a", "null", "-", " 0.25 "])
                assert cleaned == [0.8, None, None, 1.0, None, None, None, 0.25]
                assert missing == 5
                assert type(cleaned[3]) is float
                assert clean_scores([]) == ([], 0)
                values = ["N/A", "2", "NULL"]
                assert clean_scores(values) == ([None, 2.0, None], 2)
                assert values == ["N/A", "2", "NULL"]
                raised = False
                try:
                    clean_scores(["0.5", "high"])
                except ValueError:
                    raised = True
                assert raised
                """#,
                ["Decide for each value whether it is missing before trying to convert it. Missing means one of the listed markers after cleaning, not any text that fails conversion.", "Strip the text, then compare its lowercase form against a set of the five markers. Append None for a marker and count it; otherwise append the float of the stripped text.", "Keep a list and an integer counter that start empty and zero before the loop, and return them together as cleaned, count after the loop. Do not wrap float in try/except."],
                effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("ds-cleaning-dedupe", "Normalize and de-duplicate labeled prompts", #"""
                Goal:
                Prepare an invented dataset of labeled prompts for training. A prompt is a piece of text sent to a model; its label is a category assigned by a person. People typed the data inconsistently, so the same example can appear several times with different spacing or capitalization.

                Starting code:
                def dedupe_prompts(rows): is the required function. return [], 0 is a placeholder tuple.

                Your task:
                1. Keep the function name and parameter. rows is a list of dictionaries, each with string 'prompt' and 'label' keys (other keys may exist and are ignored). Do not change rows or its dictionaries.
                2. Normalize each row: the prompt becomes lowercase with every run of whitespace collapsed to one space and no edge spaces (use split and join as in the lesson); the label becomes lowercase with edge spaces removed.
                3. Two rows are duplicates when both their normalized prompt and normalized label are equal. Keep only the first occurrence and skip later ones. Rows with the same prompt but a different label are not duplicates.
                4. Return a tuple: a new list of new dictionaries containing only the normalized 'prompt' and 'label', in original order, and the integer number of skipped duplicates.

                Expected result:
                For rows [{'prompt': '  What is   2+2? ', 'label': 'Math'}, {'prompt': 'what is 2+2?', 'label': ' math'}, {'prompt': 'Translate cat', 'label': 'language'}, {'prompt': 'What is 2+2?', 'label': 'trivia'}], return ([{'prompt': 'what is 2+2?', 'label': 'math'}, {'prompt': 'translate cat', 'label': 'language'}, {'prompt': 'what is 2+2?', 'label': 'trivia'}], 1).
                dedupe_prompts([]) returns ([], 0).

                Check:
                Choose Check solution. It checks normalization, first-occurrence order, same prompt with a different label, the duplicate count, empty input, extra keys, and unchanged input.
                """#,
                #"""
                def dedupe_prompts(rows):
                    return [], 0
                """#,
                #"""
                def dedupe_prompts(rows):
                    seen = set()
                    unique = []
                    duplicates = 0
                    for row in rows:
                        prompt = " ".join(row["prompt"].split()).lower()
                        label = row["label"].strip().lower()
                        key = (prompt, label)
                        if key in seen:
                            duplicates += 1
                            continue
                        seen.add(key)
                        unique.append({"prompt": prompt, "label": label})
                    return unique, duplicates
                """#,
                #"""
                rows = [
                    {"prompt": "  What is   2+2? ", "label": "Math"},
                    {"prompt": "what is 2+2?", "label": " math"},
                    {"prompt": "Translate cat", "label": "language"},
                    {"prompt": "What is 2+2?", "label": "trivia"},
                ]
                unique, duplicates = dedupe_prompts(rows)
                assert unique == [{"prompt": "what is 2+2?", "label": "math"}, {"prompt": "translate cat", "label": "language"}, {"prompt": "what is 2+2?", "label": "trivia"}]
                assert duplicates == 1
                assert rows[0] == {"prompt": "  What is   2+2? ", "label": "Math"}
                assert dedupe_prompts([]) == ([], 0)
                repeated = [{"prompt": "A", "label": "x", "id": 1}, {"prompt": "a", "label": "X", "id": 2}, {"prompt": " a ", "label": "x ", "id": 3}]
                assert dedupe_prompts(repeated) == ([{"prompt": "a", "label": "x"}], 2)
                assert repeated[2] == {"prompt": " a ", "label": "x ", "id": 3}
                """#,
                ["Normalize first, then compare. Two rows that differ only in spacing or capitals must produce exactly the same normalized prompt and label.", "Use a set to remember which (prompt, label) tuples you have already kept. A tuple of the two normalized strings works as a set element even though a dictionary would not.", "In one loop: build the normalized pair; if it is already in the set, add one to the duplicate counter and continue; otherwise add it to the set and append a new two-key dictionary. Return the list and the counter as a tuple."],
                effort: .init(difficulty: .similar, scopeUnits: 3))
        ],
        assessment: exercise("ds-cleaning-assessment", "Clean a sensor file and write a report", #"""
            Goal:
            Clean an invented CSV file of temperature readings from weather sensors, write the cleaned table to a new CSV file, and return a cleaning report.

            Starting code:
            import csv and def clean_readings(source_path, target_path): are supplied. return {} is a placeholder. Both arguments are relative file paths as strings.

            Your task:
            1. Keep the import, the function name, and the parameters. Read source_path as UTF-8 CSV with csv.DictReader. Its header is always sensor_id,city,temperature.
            2. Clean each row: sensor_id with edge spaces removed; city lowercase with whitespace runs collapsed to single spaces and no edge spaces; temperature as None if its stripped, lowercased text is '', 'na', 'n/a', 'null', or '-', otherwise as a float. All non-missing temperatures are valid numbers.
            3. Rows whose cleaned sensor_id was already seen are duplicates: keep the first and skip later ones, even when their other values differ.
            4. Write the kept rows, in original order, to target_path as UTF-8 CSV with csv.DictWriter, header sensor_id,city,temperature (open it with newline=''). DictWriter writes floats in Python's normal spelling (21.0 becomes 21.0) and None as an empty cell. A source with no data rows produces a file containing only the header.
            5. Return a dictionary with integer counts: 'rows_in' (data rows read), 'rows_out' (rows written), 'missing_temperature' (kept rows whose temperature is None), and 'duplicates' (rows skipped).

            Expected result:
            For a source containing the lines sensor_id,city,temperature / S1, Oslo ,4.5 / S2,  new   YORK,NA / S1,Oslo,5.0 / S3,Lima, / S4,Rome,21 the report is {'rows_in': 5, 'rows_out': 4, 'missing_temperature': 2, 'duplicates': 1}, and reading the target back gives rows S1/oslo/'4.5', S2/new york/'', S3/lima/'', S4/rome/'21.0'.

            Check:
            Complete the theory questions and written explanation, then choose Submit assessment. It writes source files in the working folder, checks the report, and reads your written file back, including a header-only source. Work independently without hints or solutions.
            """#,
            #"""
            import csv

            def clean_readings(source_path, target_path):
                return {}
            """#,
            #"""
            import csv

            MARKERS = ("", "na", "n/a", "null", "-")

            def clean_readings(source_path, target_path):
                with open(source_path, encoding="utf-8", newline="") as handle:
                    raw_rows = list(csv.DictReader(handle))
                kept = []
                seen_ids = set()
                missing = 0
                for raw in raw_rows:
                    sensor_id = raw["sensor_id"].strip()
                    if sensor_id in seen_ids:
                        continue
                    seen_ids.add(sensor_id)
                    text = raw["temperature"].strip()
                    if text.lower() in MARKERS:
                        temperature = None
                        missing += 1
                    else:
                        temperature = float(text)
                    kept.append({"sensor_id": sensor_id, "city": " ".join(raw["city"].split()).lower(), "temperature": temperature})
                with open(target_path, "w", encoding="utf-8", newline="") as handle:
                    writer = csv.DictWriter(handle, fieldnames=["sensor_id", "city", "temperature"])
                    writer.writeheader()
                    writer.writerows(kept)
                return {"rows_in": len(raw_rows), "rows_out": len(kept), "missing_temperature": missing, "duplicates": len(raw_rows) - len(kept)}
            """#,
            #"""
            import csv
            with open("readings.csv", "w", encoding="utf-8", newline="") as handle:
                handle.write("sensor_id,city,temperature\nS1, Oslo ,4.5\nS2,  new   YORK,NA\nS1,Oslo,5.0\nS3,Lima,\n S4 ,Rome,21\n")
            report = clean_readings("readings.csv", "clean.csv")
            assert report == {"rows_in": 5, "rows_out": 4, "missing_temperature": 2, "duplicates": 1}
            with open("clean.csv", encoding="utf-8", newline="") as handle:
                reader = csv.DictReader(handle)
                written = list(reader)
            assert reader.fieldnames == ["sensor_id", "city", "temperature"]
            assert written == [
                {"sensor_id": "S1", "city": "oslo", "temperature": "4.5"},
                {"sensor_id": "S2", "city": "new york", "temperature": ""},
                {"sensor_id": "S3", "city": "lima", "temperature": ""},
                {"sensor_id": "S4", "city": "rome", "temperature": "21.0"},
            ]
            with open("header_only.csv", "w", encoding="utf-8", newline="") as handle:
                handle.write("sensor_id,city,temperature\n")
            assert clean_readings("header_only.csv", "header_clean.csv") == {"rows_in": 0, "rows_out": 0, "missing_temperature": 0, "duplicates": 0}
            with open("header_clean.csv", encoding="utf-8", newline="") as handle:
                lines = handle.read().splitlines()
            assert lines == ["sensor_id,city,temperature"]
            """#,
            [],
            effort: .init(difficulty: .similar, scopeUnits: 4)),
        quiz: [
            question("ds-cleaning-q1", "csv.DictReader reads the cell 120 from a file. What is its value in the row dictionary?", ["The integer 120", "The string '120'", "The float 120.0"], 1, "CSV stores only text, so every value read is a string until you convert it with int or float."),
            question("ds-cleaning-q2", "Why mark a missing score as None instead of 0?", ["Zero is a real measurement and would distort averages", "None makes the file smaller", "float cannot represent zero"], 0, "Replacing missing values with zero invents data. None keeps the gap visible so you can choose to drop or fill it deliberately."),
            question("ds-cleaning-q3", "Why should text be normalized before removing duplicates?", ["Sets only store lowercase text", "Normalizing sorts the rows", "Rows that differ only in spacing or capitals would otherwise not be recognized as the same"], 2, "De-duplication compares exact keys. Normalizing first makes equivalent values compare equal.")
        ],
        sectionRoles: [
            "Clean data before you analyze it": .overview,
            "Common mistakes and debugging": .troubleshooting
        ])

    static let dsStatistics = Chapter(
        id: "ds-statistics", title: "Descriptive statistics and sampling", subtitle: "Summarize data, spot outliers, and split it fairly",
        track: .dataScience, prerequisites: ["ds-cleaning"],
        lesson: #"""
        # Summarize data with numbers

        Once data is clean, the next question is what it says. **Descriptive statistics** are numbers that summarize many values: where the middle is, how spread out the values are, and which values are unusual. Python's standard-library `statistics` module computes the common ones. This chapter also covers measuring how two columns move together, and using reproducible randomness to split data for testing a model. pandas and NumPy offer the same summaries later (`describe`, `mean`, `std`, `corr`, `sample`); here you will see exactly how they work. All data is invented.

        ## Center: mean, median, and mode

        A **statistic** is a number calculated from data. Three describe the "typical" value:

        - The **mean** (average) is the sum divided by the count.
        - The **median** is the middle value after sorting. With an even count it is the mean of the two middle values.
        - The **mode** is the most common value. It also works for text categories.

        ```python
        import statistics

        latencies = [120, 135, 128, 900, 131]
        print(statistics.mean(latencies))
        print(statistics.median(latencies))
        print(statistics.median([4, 1, 3, 2]))
        print(statistics.mode(["chat", "code", "chat", "search"]))
        ```

        This prints 282.8, 131, 2.5, and chat. The single slow request of 900 ms drags the mean far above every other value, while the median stays at a typical 131. A value far away from the rest is called an **outlier**. The median is **robust**: a few outliers barely move it. When several values tie for most common, `statistics.mode` returns the one that appears first in the data. `statistics.mean` of integers can return an integer when the division is exact: `statistics.mean([1, 2, 3])` is 2.

        These functions need data. An empty list raises `statistics.StatisticsError`, which is a kind of ValueError:

        ```python
        import statistics

        try:
            statistics.mean([])
        except statistics.StatisticsError:
            print("no data to summarize")
        ```

        This prints no data to summarize.

        ## Spread: standard deviation, quantiles, and floats

        Two datasets can share a mean but differ in spread. The **standard deviation** measures the typical distance of values from the mean: find each value's distance from the mean, square it, average those squares (that average is the **variance**), then take the square root.

        There are two versions. If your data is the complete group you care about, called the **population**, divide the squared distances by the count n: `statistics.pstdev`. If your data is a **sample**, a subset used to estimate a larger population, divide by n − 1 instead: `statistics.stdev`. Dividing by the slightly smaller number corrects the tendency of a sample to underestimate the spread. The sample version needs at least two values. When unsure, data scientists usually treat data as a sample; pandas' `std` uses n − 1 by default.

        ```python
        import statistics

        scores = [2, 4, 4, 4, 5, 5, 7, 9]
        print(statistics.pstdev(scores))
        print(round(statistics.stdev(scores), 4))
        ```

        This prints 2.0 and 2.1381. The mean is 5; the squared distances sum to 32; 32 / 8 = 4 and its square root is 2.0, while 32 / 7 ≈ 4.571 gives about 2.1381.

        `round(x, 4)` was used because floats are binary approximations of decimals, so calculations can produce tiny representation errors. Never compare computed floats with `==` directly. Either round both sides to a fixed number of decimals, or check that the difference is smaller than a tiny **tolerance**.

        Two new pieces of syntax make the tolerance check short. The built-in function `abs(x)` returns the **absolute value** of x: its distance from zero, which is never negative. So `abs(-3)` and `abs(3)` are both 3, and `abs(a - b)` is how far apart a and b are, whichever one is larger. The number `1e-9` is **scientific notation**: `e-9` means "times 10 to the power of −9", so `1e-9` is the float 0.000000001 (one billionth). Likewise `2.5e3` is 2500.0. Putting them together, `abs(a - b) < 1e-9` reads "a and b differ by less than one billionth".

        ```python
        print(abs(-3), abs(3))
        print(abs(2 - 5))
        print(1e-9 == 0.000000001)
        print(2.5e3)
        ```

        This prints `3 3`, 3, True and 2500.0. Now the tolerance check:

        ```python
        total = 0.1 + 0.2
        print(total)
        print(total == 0.3)
        print(abs(total - 0.3) < 1e-9)
        print(round(total, 4) == 0.3)
        ```

        This prints 0.30000000000000004, False, True, True. The exercises compare your floats this way, and you should test your own code the same way.

        **Quantiles** are cut points that divide sorted data into equal-sized groups. With `n=4` they are the **quartiles**: Q1 has about a quarter of the data below it, Q2 is the median, and Q3 has about three quarters below it. `statistics.quantiles(data, n=4)` returns a list of the three cut points and needs at least two values.

        ```python
        import statistics

        data = [1, 2, 3, 4, 5, 6, 7, 8]
        print(statistics.quantiles(data, n=4))
        ```

        This prints `[2.25, 4.5, 6.75]`. Cut points can fall between data values. There are several conventions for computing them; Python's default is called `"exclusive"`, and `statistics.quantiles(data, n=4, method="inclusive")` uses the convention pandas uses by default, giving `[2.75, 4.5, 6.25]` here. Results from different tools can therefore differ slightly; always use one method consistently.

        ## Find outliers with the IQR rule and z-scores

        The **interquartile range** (IQR) is Q3 − Q1: the width of the middle half of the data. The common **IQR rule** marks a value as an outlier when it is below the low fence Q1 − 1.5 × IQR or above the high fence Q3 + 1.5 × IQR. A value exactly on a fence is not an outlier. Because quartiles are robust, one extreme value does not hide itself by stretching the fences. A list of three numbers can be unpacked into three names, just like a tuple:

        ```python
        import statistics

        latencies = [2, 4, 4, 5, 7, 9, 10, 12, 40]
        q1, q2, q3 = statistics.quantiles(latencies, n=4)
        iqr = q3 - q1
        low = q1 - 1.5 * iqr
        high = q3 + 1.5 * iqr
        outliers = [value for value in latencies if value < low or value > high]
        print(q1, q3, iqr)
        print(low, high)
        print(outliers)
        ```

        This prints 4.0 11.0 7.0, then -6.5 21.5, then `[40]`.

        A **z-score** says how many standard deviations a value is from the mean: z = (value − mean) / standard deviation. A z-score of 0 is exactly average, 2 is two standard deviations above, and −1.5 is one and a half below. Rewriting values as z-scores is called **standardizing**: it puts columns measured in different units on the same scale. A common rule of thumb treats values with a z-score above 3 or below −3 as unusual.

        ```python
        import statistics

        scores = [2, 4, 4, 4, 5, 5, 7, 9]
        mean = statistics.mean(scores)
        spread = statistics.pstdev(scores)
        z_scores = [(value - mean) / spread for value in scores]
        print(z_scores)
        ```

        This prints `[-1.5, -0.5, -0.5, -0.5, 0.0, 0.0, 1.0, 2.0]`. If the standard deviation is 0 (all values equal), z-scores are undefined, because Python cannot divide by zero; check for that case first.

        ## Measure correlation by hand

        **Correlation** measures how strongly two numeric columns move together in a straight-line way. The **Pearson correlation coefficient**, written r, is between −1 and 1. Near 1 means both rise together; near −1 means one rises as the other falls; near 0 means no straight-line relationship. Correlation does not prove that one causes the other.

        Python 3.9 has no built-in correlation function, so compute r step by step from paired lists xs and ys of equal length:

        1. Compute the mean of xs and the mean of ys.
        2. For each pair, find the deviations dx = x − mean_x and dy = y − mean_y.
        3. Add up dx × dy over all pairs (the numerator).
        4. Add up dx × dx and, separately, dy × dy; take the square root of each.
        5. r = numerator / (square root of the dx sum × square root of the dy sum).

        `zip(xs, ys)` from the iteration chapter walks the two lists in pairs, and `math.sqrt` takes a square root.

        ```python
        import math

        hours = [1, 2, 3, 4, 5]
        scores = [52, 55, 61, 64, 70]
        mean_x = sum(hours) / len(hours)
        mean_y = sum(scores) / len(scores)
        dx = [x - mean_x for x in hours]
        dy = [y - mean_y for y in scores]
        numerator = sum([a * b for a, b in zip(dx, dy)])
        spread_x = math.sqrt(sum([a * a for a in dx]))
        spread_y = math.sqrt(sum([b * b for b in dy]))
        r = numerator / (spread_x * spread_y)
        print(round(r, 4))
        falling = [10, 8, 6, 4, 2]
        mean_f = sum(falling) / len(falling)
        df = [f - mean_f for f in falling]
        r_falling = sum([a * b for a, b in zip(dx, df)]) / (spread_x * math.sqrt(sum([b * b for b in df])))
        assert abs(r_falling - (-1.0)) < 1e-9
        ```

        This prints 0.9934: more study hours go with higher scores in this invented data. The second list falls perfectly as hours rise, so its r is −1 (checked with a tolerance). If either column has zero spread, the denominator is 0 and r is undefined.

        ## Seeded random sampling and train/test splits

        A **random sample** is a subset chosen by chance. Computers produce **pseudo-random** numbers: a deterministic sequence that looks random, started from a number called the **seed**. The same seed always gives the same sequence, which makes an analysis **reproducible**: anyone rerunning it gets identical results. `random.Random(seed)` creates your own generator object; always use one with an explicit seed in analysis code, rather than the shared, unseeded functions of the `random` module.

        The generator's methods: `rng.random()` returns a float from 0 up to (not including) 1; `rng.choice(items)` picks one item; `rng.sample(items, k)` returns a new list of k different items; `rng.shuffle(items)` reorders a list **in place** and returns None, so shuffle a copy made with `list(items)` when the original must stay unchanged.

        ```python
        import random

        rng = random.Random(7)
        print(rng.sample(["a", "b", "c", "d", "e"], 3))
        print(round(rng.random(), 6))
        values = list(range(1, 11))
        shuffled = list(values)
        random.Random(42).shuffle(shuffled)
        print(shuffled)
        print(values)
        again = list(values)
        random.Random(42).shuffle(again)
        assert again == shuffled
        ```

        This prints `['c', 'b', 'd']`, 0.650934, `[8, 4, 3, 9, 6, 7, 10, 5, 1, 2]`, and the unchanged `[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]`. Each call moves the generator forward, so the order of calls matters too.

        To judge a model fairly, you test it on data it never saw while learning. A **train/test split** divides shuffled rows into a **training set** (used to fit the model or compute statistics) and a **test set** (held back for evaluation). Shuffle first so that any ordering in the file, such as rows sorted by date, does not bias either set. Then slice:

        ```python
        import random

        rows = list(range(1, 11))
        shuffled = list(rows)
        random.Random(42).shuffle(shuffled)
        test_size = 3
        test = shuffled[:test_size]
        train = shuffled[test_size:]
        print(test)
        print(train)
        assert sorted(test + train) == rows
        ```

        This prints `[8, 4, 3]` and `[9, 6, 7, 10, 5, 1, 2]`. Every row lands in exactly one set. Any statistic used to transform data, such as the mean and standard deviation for z-scores, must be computed from the training set only and then applied to the test set. Using test data to compute them is called **data leakage**: information from the evaluation sneaks into preparation and makes results look better than they really are.

        ## Common mistakes and debugging

        - Comparing computed floats with `==`. Round both sides or use a tolerance such as `abs(a - b) < 1e-9`.
        - Mixing up `stdev` (sample, n − 1) and `pstdev` (population, n). Read which one a task requires.
        - Calling `rng.shuffle` on the caller's list, or expecting it to return the shuffled list. It returns None.
        - Using `random.shuffle` without a seed, so results change on every run.
        - Forgetting the empty, single-value, and zero-spread cases, where some statistics are undefined.

        To debug a statistic, compute it by hand for three or four small numbers first, then compare with your function's result. Print intermediate values such as the mean, Q1, Q3, or the deviation lists.
        """#,
        exercises: [
            exercise("ds-statistics-summary", "Summarize survey ratings", #"""
                Goal:
                Summarize invented survey ratings, where users rated an assistant from 1 to 5, with the statistics module.

                Starting code:
                import statistics is supplied. def summarize_ratings(ratings): is the required function; return {} is a placeholder.

                Your task:
                1. Keep the import, the function name, and the parameter. ratings is a list of integers. Do not change it.
                2. If ratings has fewer than 2 values, raise ValueError with a nonempty message (the sample standard deviation needs two values).
                3. Otherwise return a dictionary with six keys: 'count' (the number of ratings), 'mean', 'median', 'mode', 'stdev' (sample standard deviation), and 'pstdev' (population standard deviation).
                4. Round 'mean', 'stdev', and 'pstdev' with round(value, 3). Leave 'median' and 'mode' exactly as the statistics functions return them. For ties, use what statistics.mode returns (the first most common value).

                Expected result:
                summarize_ratings([4, 5, 3, 4, 2, 4, 5]) returns {'count': 7, 'mean': 3.857, 'median': 4, 'mode': 4, 'stdev': 1.069, 'pstdev': 0.99}.
                summarize_ratings([1, 2]) returns {'count': 2, 'mean': 1.5, 'median': 1.5, 'mode': 1, 'stdev': 0.707, 'pstdev': 0.5}.
                summarize_ratings([5]) and summarize_ratings([]) raise ValueError.

                Check:
                Choose Check solution. It compares the rounded values, checks a tie and the two-value case, the ValueError cases, and unchanged input.
                """#,
                #"""
                import statistics

                def summarize_ratings(ratings):
                    return {}
                """#,
                #"""
                import statistics

                def summarize_ratings(ratings):
                    if len(ratings) < 2:
                        raise ValueError("need at least two ratings")
                    return {
                        "count": len(ratings),
                        "mean": round(statistics.mean(ratings), 3),
                        "median": statistics.median(ratings),
                        "mode": statistics.mode(ratings),
                        "stdev": round(statistics.stdev(ratings), 3),
                        "pstdev": round(statistics.pstdev(ratings), 3),
                    }
                """#,
                #"""
                ratings = [4, 5, 3, 4, 2, 4, 5]
                summary = summarize_ratings(ratings)
                assert summary == {"count": 7, "mean": 3.857, "median": 4, "mode": 4, "stdev": 1.069, "pstdev": 0.99}
                assert ratings == [4, 5, 3, 4, 2, 4, 5]
                pair = summarize_ratings([1, 2])
                assert pair["mode"] == 1 and pair["median"] == 1.5 and pair["count"] == 2
                assert abs(pair["mean"] - 1.5) < 1e-9
                assert abs(pair["stdev"] - 0.707) < 1e-9 and abs(pair["pstdev"] - 0.5) < 1e-9
                same = summarize_ratings([3, 3, 3])
                assert same["stdev"] == 0 and same["pstdev"] == 0 and same["mean"] == 3
                errors = 0
                for bad in ([5], []):
                    try:
                        summarize_ratings(bad)
                    except ValueError as error:
                        if str(error):
                            errors += 1
                assert errors == 2
                """#,
                ["Each requested value has a matching function in the statistics module; you do not need to compute any formula yourself.", "Check the length first and raise before calling any statistics function. Then build the dictionary, calling stdev for the sample version and pstdev for the population version.", "Wrap only mean, stdev, and pstdev in round(..., 3); median and mode go into the dictionary unchanged, and count is len(ratings)."],
                effort: .init(difficulty: .similar, scopeUnits: 3)),
            exercise("ds-statistics-outliers", "Flag latency outliers with the IQR rule", #"""
                Goal:
                Find unusually fast or slow requests in invented latency measurements (response times in milliseconds) using quartiles and the IQR rule.

                Starting code:
                import statistics is supplied. def iqr_outliers(values): is the required function; its placeholder returns {'low': 0, 'high': 0, 'outliers': []}.

                Your task:
                1. Keep the import, the function name, and the parameter. values is a list of numbers. Do not change it.
                2. If values has fewer than 4 numbers, raise ValueError with a nonempty message.
                3. Compute Q1 and Q3 with statistics.quantiles(values, n=4) using its default method, then IQR = Q3 - Q1, low fence = Q1 - 1.5 * IQR, and high fence = Q3 + 1.5 * IQR.
                4. Return a dictionary: 'low' and 'high' are the two fences (unrounded), and 'outliers' is a list of the values strictly below the low fence or strictly above the high fence, in their original order (keep repeats). A value exactly equal to a fence is not an outlier.

                Expected result:
                iqr_outliers([2, 4, 4, 5, 7, 9, 10, 12, 40]) returns {'low': -6.5, 'high': 21.5, 'outliers': [40]}.
                iqr_outliers([300, 310, 305, 20, 298, 302, 900, 307]) has fences 282.375 and 325.375 and outliers [20, 900].
                iqr_outliers([16, 27, 12, 14, 12, 1, 18, 18]) has fences 3.0 and 27.0 and outliers [1]; 27 sits exactly on the high fence.

                Check:
                Choose Check solution. It compares fences with a small tolerance, checks low and high outliers, the exact-fence boundary, input order, unchanged input, and the ValueError for short lists.
                """#,
                #"""
                import statistics

                def iqr_outliers(values):
                    return {"low": 0, "high": 0, "outliers": []}
                """#,
                #"""
                import statistics

                def iqr_outliers(values):
                    if len(values) < 4:
                        raise ValueError("need at least four values")
                    q1, median, q3 = statistics.quantiles(values, n=4)
                    iqr = q3 - q1
                    low = q1 - 1.5 * iqr
                    high = q3 + 1.5 * iqr
                    outliers = [value for value in values if value < low or value > high]
                    return {"low": low, "high": high, "outliers": outliers}
                """#,
                #"""
                first = iqr_outliers([2, 4, 4, 5, 7, 9, 10, 12, 40])
                assert first["outliers"] == [40]
                assert abs(first["low"] - (-6.5)) < 1e-9 and abs(first["high"] - 21.5) < 1e-9
                latencies = [300, 310, 305, 20, 298, 302, 900, 307]
                second = iqr_outliers(latencies)
                assert second["outliers"] == [20, 900]
                assert abs(second["low"] - 282.375) < 1e-9 and abs(second["high"] - 325.375) < 1e-9
                assert latencies == [300, 310, 305, 20, 298, 302, 900, 307]
                edge = iqr_outliers([16, 27, 12, 14, 12, 1, 18, 18])
                assert edge["outliers"] == [1]
                assert abs(edge["high"] - 27.0) < 1e-9
                assert iqr_outliers([5, 5, 5, 5])["outliers"] == []
                raised = False
                try:
                    iqr_outliers([1, 2, 3])
                except ValueError as error:
                    raised = bool(str(error))
                assert raised
                """#,
                ["statistics.quantiles with n=4 gives three cut points: Q1, the median, and Q3. The fences are built from Q1, Q3, and their difference.", "Unpack the three quartiles into names, compute the IQR and both fences, then collect the values outside them while keeping the original order.", "Use strict comparisons (< low, > high) so values on a fence stay in. Raise ValueError for lists shorter than four before calling quantiles."],
                effort: .init(difficulty: .similar, scopeUnits: 2)),
            exercise("ds-statistics-correlation", "Compute Pearson correlation by hand", #"""
                Goal:
                Measure how strongly two invented columns move together, such as study hours and quiz scores, by computing the Pearson correlation coefficient r yourself.

                Starting code:
                import math is supplied. def pearson(xs, ys): is the required function; return 0.0 is a placeholder.

                Your task:
                1. Keep the import, the function name, and the parameters. xs and ys are lists of numbers where xs[i] and ys[i] belong together. Do not change them.
                2. Raise ValueError with a nonempty message if the lists have different lengths or fewer than 2 pairs.
                3. Follow the lesson's five steps: the means, the deviations, the sum of products of deviations, and the square roots of the two sums of squared deviations.
                4. If either square-root sum is 0 (a column with no spread), raise ValueError instead of dividing by zero.
                5. Otherwise return r as an unrounded float. Do not use any correlation function from a library.

                Expected result:
                pearson([1, 2, 3, 4, 5], [52, 55, 61, 64, 70]) is approximately 0.9934.
                pearson([1, 2, 3], [10, 20, 30]) is approximately 1.0 and pearson([1, 2, 3], [6, 4, 2]) is approximately -1.0.
                pearson([1, 2, 3], [1, 3, 1]) is approximately 0.0.
                pearson([1, 2], [1]), pearson([1], [2]), and pearson([1, 2, 3], [4, 4, 4]) raise ValueError.

                Check:
                Choose Check solution. It compares results with round(r, 4) or a tolerance, and checks perfect positive, perfect negative, zero correlation, the three error cases, and unchanged input.
                """#,
                #"""
                import math

                def pearson(xs, ys):
                    return 0.0
                """#,
                #"""
                import math

                def pearson(xs, ys):
                    if len(xs) != len(ys) or len(xs) < 2:
                        raise ValueError("need two equal-length lists with at least two pairs")
                    mean_x = sum(xs) / len(xs)
                    mean_y = sum(ys) / len(ys)
                    numerator = 0.0
                    sum_xx = 0.0
                    sum_yy = 0.0
                    for x, y in zip(xs, ys):
                        dx = x - mean_x
                        dy = y - mean_y
                        numerator += dx * dy
                        sum_xx += dx * dx
                        sum_yy += dy * dy
                    denominator = math.sqrt(sum_xx) * math.sqrt(sum_yy)
                    if denominator == 0:
                        raise ValueError("a column has no spread")
                    return numerator / denominator
                """#,
                #"""
                hours = [1, 2, 3, 4, 5]
                scores = [52, 55, 61, 64, 70]
                assert round(pearson(hours, scores), 4) == 0.9934
                assert hours == [1, 2, 3, 4, 5] and scores == [52, 55, 61, 64, 70]
                assert abs(pearson([1, 2, 3], [10, 20, 30]) - 1.0) < 1e-9
                assert abs(pearson([1, 2, 3], [6, 4, 2]) - (-1.0)) < 1e-9
                assert abs(pearson([1, 2, 3], [1, 3, 1])) < 1e-9
                assert abs(pearson([0.5, 1.5], [3, 1]) - (-1.0)) < 1e-9
                errors = 0
                for xs, ys in (([1, 2], [1]), ([1], [2]), ([1, 2, 3], [4, 4, 4]), ([7, 7], [1, 2])):
                    try:
                        pearson(xs, ys)
                    except ValueError as error:
                        if str(error):
                            errors += 1
                assert errors == 4
                """#,
                ["Correlation compares deviations from each column's own mean. Validate the lengths first, because zip silently stops at the shorter list.", "Walk both lists together with zip, compute dx and dy for each pair, and keep three running sums: dx*dy, dx*dx, and dy*dy.", "The denominator is math.sqrt of the dx*dx sum multiplied by math.sqrt of the dy*dy sum. If it equals 0 raise ValueError; otherwise return the dx*dy sum divided by it."],
                effort: .init(difficulty: .harder, scopeUnits: 3))
        ],
        assessment: exercise("ds-statistics-assessment", "Split data and standardize with training statistics", #"""
            Goal:
            Prepare invented response-time measurements for a model evaluation: make a reproducible train/test split, then standardize the test values as z-scores using statistics from the training set only (to avoid data leakage).

            Starting code:
            import random and import statistics are supplied. def split_and_standardize(values, test_size, seed): is the required function; its placeholder returns {'train': [], 'test': [], 'test_z': []}.

            Your task:
            1. Keep the imports, the function name, and the parameters. values is a list of numbers, test_size is an integer, and seed is an integer. Do not change values.
            2. Raise ValueError with a nonempty message if test_size is less than 1 or if fewer than 2 values would remain for training (len(values) - test_size < 2).
            3. Make a copy of values and shuffle the copy with random.Random(seed).shuffle. The test list is the first test_size items of the shuffled copy; the train list is the rest, both in shuffled order.
            4. Compute the training mean with statistics.mean and the training sample standard deviation with statistics.stdev. If that standard deviation is 0, raise ValueError.
            5. Compute each test value's z-score, (value - training mean) / training standard deviation, rounded with round(z, 3), in test order.
            6. Return a dictionary with keys 'train', 'test', and 'test_z'.

            Expected result:
            For values [12.0, 15.5, 11.0, 14.0, 13.5, 30.0, 12.5, 16.0, 14.5, 13.0], test_size 3, and seed 3, the result is {'train': [12.0, 13.0, 13.5, 16.0, 11.0, 14.5, 14.0], 'test': [15.5, 30.0, 12.5], 'test_z': [1.26, 10.081, -0.565]}.
            With the same values, test_size 2, and seed 11, test is [11.0, 12.5] and test_z is [-0.876, -0.617].

            Check:
            Complete the theory questions and written explanation, then choose Submit assessment. It checks the seeded split, that every value lands in exactly one set, the rounded z-scores, repeatability with the same seed, unchanged input, and the ValueError cases. Work independently without hints or solutions.
            """#,
            #"""
            import random
            import statistics

            def split_and_standardize(values, test_size, seed):
                return {"train": [], "test": [], "test_z": []}
            """#,
            #"""
            import random
            import statistics

            def split_and_standardize(values, test_size, seed):
                if test_size < 1 or len(values) - test_size < 2:
                    raise ValueError("invalid test size for this many values")
                shuffled = list(values)
                random.Random(seed).shuffle(shuffled)
                test = shuffled[:test_size]
                train = shuffled[test_size:]
                center = statistics.mean(train)
                spread = statistics.stdev(train)
                if spread == 0:
                    raise ValueError("training values have no spread")
                test_z = [round((value - center) / spread, 3) for value in test]
                return {"train": train, "test": test, "test_z": test_z}
            """#,
            #"""
            values = [12.0, 15.5, 11.0, 14.0, 13.5, 30.0, 12.5, 16.0, 14.5, 13.0]
            result = split_and_standardize(values, 3, 3)
            assert result["test"] == [15.5, 30.0, 12.5]
            assert result["train"] == [12.0, 13.0, 13.5, 16.0, 11.0, 14.5, 14.0]
            assert result["test_z"] == [1.26, 10.081, -0.565]
            assert values == [12.0, 15.5, 11.0, 14.0, 13.5, 30.0, 12.5, 16.0, 14.5, 13.0]
            assert sorted(result["train"] + result["test"]) == sorted(values)
            assert split_and_standardize(values, 3, 3) == result
            other = split_and_standardize(values, 2, 11)
            assert other["test"] == [11.0, 12.5]
            assert other["test_z"] == [-0.876, -0.617]
            assert len(other["train"]) == 8
            errors = 0
            for size in (0, 9, 10):
                try:
                    split_and_standardize(values, size, 1)
                except ValueError as error:
                    if str(error):
                        errors += 1
            try:
                split_and_standardize([4.0, 4.0, 4.0, 9.0], 1, 1)
            except ValueError as error:
                if str(error):
                    errors += 1
            assert errors == 4
            """#,
            [],
            effort: .init(difficulty: .similar, scopeUnits: 3)),
        quiz: [
            question("ds-statistics-q1", "A list of latencies has one extremely slow request. Which summary of the typical value is least affected?", ["The mean", "The median", "The sum"], 1, "The median depends only on the middle of the sorted data, so a single outlier barely moves it, while the mean is pulled toward the outlier."),
            question("ds-statistics-q2", "What is the difference between statistics.stdev and statistics.pstdev?", ["stdev treats the data as a sample and divides by n - 1; pstdev treats it as the whole population and divides by n", "stdev rounds the result; pstdev does not", "pstdev works only on integers"], 0, "Dividing by n - 1 corrects a sample's tendency to underestimate the spread of the larger population."),
            question("ds-statistics-q3", "Why create random.Random(42) instead of calling random.shuffle without a seed?", ["Seeded generators are faster", "random.shuffle cannot shuffle lists", "The same seed reproduces the same shuffle, so the split and results can be repeated exactly"], 2, "A seeded generator produces the same pseudo-random sequence every run, making the analysis reproducible.")
        ],
        sectionRoles: [
            "Summarize data with numbers": .overview,
            "Common mistakes and debugging": .troubleshooting
        ],
        generationNotes: """
        For seeded random tasks, name the seed and the exact random.Random(seed) method calls and their order in the steps, \
        because different calls or call order give different results. In tests, compute expected seeded results by repeating \
        the same calls on a fresh random.Random(seed) instead of hard-coding shuffled or sampled values you have not run. \
        Also check seed-independent properties such as every item landing in exactly one set, repeatability with the same seed, \
        and unchanged input. State whether a task wants stdev or pstdev and which statistics.quantiles method, and give \
        exact rounding instructions for reported floats.
        """)
}
