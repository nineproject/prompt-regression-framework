# Evaluation Policy

This document defines how prompt outputs are evaluated in the prompt regression framework.

The goal of evaluation is to determine whether a prompt change introduces:

- regression
- acceptable variation
- improvement

Evaluation is human-in-the-loop, supported by automated comparison artifacts.

---

# Evaluation Flow

The evaluation process follows this sequence:

prompt build  
↓  
execution  
↓  
baseline comparison  
↓  
evaluation  
↓  
verdict recording  
↓  
baseline promotion (optional)

Evaluation uses the artifacts generated in:

runs/RUN_xxx/

Key files:

- prompt.txt
- response.txt
- compare.json

---

# Evaluation Dimensions

Evaluation is performed across multiple dimensions.

A single test case should be reviewed using the following criteria.

---

## 1. Format Compliance

Does the output follow the required format?

Examples:

- valid JSON
- required fields exist
- markdown structure preserved
- schema compliance

Possible results:

PASS  
FAIL  

Format failures are typically hard failures.

---

## 2. Instruction Compliance

Does the response follow the instructions defined in the prompt?

Examples:

- requested task completed
- constraints respected
- no hallucinated instructions
- no ignored requirements

Possible results:

PASS  
MINOR_DRIFT  
FAIL  

---

## 3. Semantic Regression

Has the meaning or correctness of the output degraded compared to the baseline?

Examples of regression:

- missing key information
- incorrect summary
- incorrect extraction
- wrong reasoning outcome

Possible results:

PASS  
FAIL  

Semantic regressions are considered critical failures.

---

## 4. Style Drift

Has the wording or structure changed but meaning remains correct?

Examples:

- rephrased sentences
- additional explanation
- improved clarity

Possible results:

NONE  
MINOR  
MAJOR  

Style drift alone should not cause a failure unless it violates a case policy.

---

## 5. Safety Compliance

Check for violations of safety rules.

Examples:

- unsafe instructions
- policy violations
- unexpected harmful output

Possible results:

PASS  
FAIL  

Safety failures must always be treated as critical failures.

---

# Case Policies

Each test case may define its change tolerance using meta.json.

Example:

{
  "title": "minimal summary case",
  "expectedFormat": "json",
  "assertionMode": "strict",
  "priority": "high",
  "changePolicy": "low-drift"
}

---

## assertionMode

Defines how strict the comparison should be.

strict  
→ minimal output drift allowed

normal  
→ minor changes allowed

loose  
→ semantic correctness only

---

## priority

Defines the importance of the case.

critical  
high  
normal  
low  

Critical cases may fail the entire regression suite.

---

## changePolicy

Defines how much change is acceptable.

frozen  
low-drift  
allowed-improvement  

### frozen

No output changes expected.  
Any diff should trigger investigation.

### low-drift

Small wording differences allowed.  
Semantic meaning must remain unchanged.

### allowed-improvement

Changes are allowed if they improve output quality.  
Human evaluation required.

---

## Current role of metadata fields

Metadata fields such as:

- `expectedFormat`
- `assertionMode`
- `priority`
- `changePolicy`
- `tags`

are currently interpreted on the **evaluation side**.

In particular:

- `expectedFormat` is used to guide comparison and evaluation behavior
- it is **not yet used for prompt assembly control**

This means the framework currently supports:

> metadata-driven evaluation foundation

but does not yet implement:

> metadata-driven prompt assembly

---

# Verdict Types

After evaluation, a final verdict must be recorded.

Possible values:

PASS  
FAIL  
REVIEW  

### PASS

The candidate output is acceptable and does not introduce regression.

### FAIL

The candidate output introduces regression or policy violation.

### REVIEW

The change is acceptable but requires human confirmation before promotion.

---

# Baseline Promotion Rules

A run may be promoted to baseline when:

1. All critical cases PASS
2. No semantic regression detected
3. Format compliance maintained
4. Evaluation completed
5. Reviewer approves change

Promotion command:

promote-baseline.ps1

Baseline updates should be performed only after evaluation is complete.

---

# Migration Evaluation

When evaluating a prompt migration (MIG):

The reviewer should verify:

1. Intended behavior change occurred
2. No unintended regression introduced
3. Affected cases behave as expected

Migration documentation should include:

- purpose
- expected behavior change
- affected cases
- non-goals

---

# Regression Policy

Regression suites should be run:

- before baseline promotion
- after major prompt migrations
- before repository release

Recommended suites:

- core suite
- format suite
- full regression suite

---

# Human Review Principles

Evaluation should prioritize:

1. semantic correctness
2. instruction compliance
3. format stability
4. safety

Minor style variations should not block prompt evolution.

---

# Summary

Evaluation decisions should follow this priority order:

Safety  
→ Semantic correctness  
→ Instruction compliance  
→ Format  
→ Style  

A prompt improvement should not be rejected solely due to harmless wording changes.

---

# Future Extensions

Possible future improvements:

- automatic semantic similarity scoring
- structured evaluation JSON
- evaluator UI
- diff visualization
- automated drift detection
