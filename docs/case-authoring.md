# Test Case Authoring Guide

This document defines how to create high-quality test cases for the prompt regression framework.

Test cases define the **expected behavior of prompts** and are the foundation of regression testing.

Well-designed cases ensure that prompt improvements do not introduce unintended regressions.

---

# Test Case Structure

Each test case is stored under:

tests/cases/TC-xxxx/

Example:

tests/cases/TC-0001/

Files:

case.md  
meta.json  

---

# case.md

`case.md` defines the **test input context**.

It contains the instructions and data used when building the final prompt.

Example:

User request:

Summarize the following article in JSON format.

Article:

<article text here>

Expected structure:

{
  "summary": ""
}

The content of `case.md` is appended during prompt build.

Prompt assembly order:

BASE  
SPEC_BASE  
SPEC  
MIGS  
TEST_CASE  

---

# meta.json

`meta.json` describes the **evaluation expectations** for the case.

Example:

{
  "title": "minimal summary case",
  "expectedFormat": "json"
}

This metadata is used during evaluation and regression analysis.

---

## Note on First Run (No Baseline)

In initial runs, a baseline may not exist yet.

In such cases:

- compareStatus = BASELINE_MISSING
- recommendedVerdict = REVIEW

This is expected behavior.

The output of the first run should be reviewed manually and may be promoted
as the initial baseline if acceptable.

---

# Recommended Metadata Fields

The following metadata fields are recommended.

Example:

{
  "title": "minimal summary case",
  "expectedFormat": "json",
  "assertionMode": "strict",
  "priority": "high",
  "changePolicy": "low-drift",
  "tags": ["summary", "format"]
}

---

## title

Human-readable description of the case.

Example:

"title": "extract entities from paragraph"

---

## expectedFormat

Expected output format.

Examples:

json  
markdown  
text  

Format violations typically result in failure.

---

## assertionMode

Defines how strict the evaluation should be.

Options:

strict  
normal  
loose  

### strict

Minimal output change allowed.

Used for:

- structured outputs
- extraction tasks
- safety behavior

### normal

Small wording differences allowed.

Used for:

- summarization
- explanation tasks

### loose

Only semantic correctness matters.

Used for:

- creative generation
- open-ended tasks

---

## Note on Evaluation Behavior

Metadata does not directly determine the final verdict.

Evaluation is based on:

- compare evidence (differences, omissions, format)
- metadata (assertionMode, changePolicy, priority)
- human review

In other words:

compare = evidence  
eval = interpretation  

Final decisions are always made by a human.

---

## priority

Defines the importance of the test case.

Options:

critical  
high  
normal  
low  

Critical cases represent **core prompt guarantees**.

Failures in critical cases may fail the entire regression suite.

---

## changePolicy

Defines how much output drift is allowed.

Options:

frozen  
low-drift  
allowed-improvement  

### frozen

Output should not change.

Used for:

- schema guarantees
- safety responses

### low-drift

Small wording differences allowed.

Meaning must remain identical.

### allowed-improvement

Changes allowed if output quality improves.

Human evaluation required.

---

## tags

Tags help categorize test cases.

Examples:

summary  
extraction  
format  
reasoning  
safety  
refusal  
classification  

Tags help build targeted regression suites.

---

## Note on expectedFormat

`expectedFormat` is currently used as **evaluation metadata**.

At this phase, it is used by:

- comparison (compare-run)
- evaluation (eval-run)
- summary (summary-evals)
- repository validation (validate-repo)

It does **not** automatically switch the prompt build output format.

In other words, updating `expectedFormat` in `meta.json` does not rewrite the assembled prompt or override BASE/SPEC instructions.

Until prompt-assembly support is introduced, `expectedFormat` should be treated as an **evaluation-side contract**, not a prompt-generation control flag.

---

# Good Test Case Design Principles

Good test cases should follow these principles.

---

## Test One Behavior Per Case

Avoid testing multiple behaviors in one case.

Bad:

Summarize the article and extract keywords.

Good:

TC-0001 → summarization  
TC-0002 → keyword extraction  

---

## Keep Inputs Small and Focused

Large inputs make debugging difficult.

Prefer minimal examples that isolate behavior.

---

## Avoid Ambiguous Tasks

Bad case:

Summarize this text.

Better case:

Summarize this text in one sentence.

---

## Prefer Deterministic Outputs

Tasks with many valid answers are harder to evaluate.

Prefer tasks where correctness is clearly defined.

Examples:

good:

entity extraction  
classification  
format conversion  

harder:

creative writing  
story generation  

---

## Include Edge Cases

Important edge cases include:

empty input  
long input  
unusual characters  
contradictory instructions  

Edge cases prevent prompt fragility.

---

# Example Test Case

Directory:

tests/cases/TC-0007/

case.md

User request:

Extract all company names from the following paragraph.

Text:

Apple announced a partnership with Microsoft while Amazon launched a new service.

Output format:

{
  "companies": []
}

meta.json

{
  "title": "company entity extraction",
  "expectedFormat": "json",
  "assertionMode": "strict",
  "priority": "high",
  "changePolicy": "frozen",
  "tags": ["extraction", "entities"]
}

---

# When to Add a New Test Case

Add a test case when:

- a new prompt capability is introduced
- a bug is fixed
- a regression is discovered
- a migration changes expected behavior

Every bug fix should ideally introduce a new regression test.

---

## Relationship to Baseline

Test cases define expected behavior, but actual regression comparison depends on baseline.

- baseline defines the current accepted behavior
- compare measures difference from baseline
- eval interprets the difference
- human decides whether to update baseline

Without a baseline, the first run becomes the reference candidate.

---

# Regression Philosophy

The purpose of test cases is not only verification but also documentation.

Test cases collectively define the **expected behavior of the prompt system**.

As the prompt evolves, the test suite becomes the **behavior specification**.

---

# Future Improvements

Possible future improvements include:

- schema validation
- semantic similarity scoring
- auto-generated evaluation hints
- case coverage metrics

---

# End of Document
