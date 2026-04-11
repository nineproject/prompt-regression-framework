# Framework Design
Local Prompt Development & Regression Testing Framework

---

## 1. Overview

This repository provides a **local framework for prompt development and regression testing**.

The purpose of this framework is to support a safe development cycle for LLM prompts by enabling:

- prompt composition from structured sources
- repeatable test execution
- comparison against approved baselines
- evidence-based evaluation
- human-in-the-loop judgment for final decisions

This framework is intended to reduce accidental behavior drift when prompts are updated.

---

## 2. Goals

The primary goals of this framework are:

1. Enable safe prompt iteration
2. Detect unintended output changes
3. Separate raw comparison from evaluation judgment
4. Preserve approved behavior through baselines
5. Keep evaluation human-reviewable
6. Support local and incremental workflow

---

## 3. Non-Goals

This framework does **not** aim to:

- fully automate final quality judgment
- replace human review for important changes
- serve as a cloud-scale evaluation platform
- manage model hosting or inference infrastructure
- guarantee semantic correctness in all cases

---

## 4. Design Principles

### 4.1 Local-first
The framework is designed to run locally with simple scripts and repository-managed artifacts.

### 4.2 Artifact-driven
Each execution should leave inspectable artifacts such as:

- generated prompt
- model response
- compare result
- evaluation result
- manifest

### 4.3 Separation of concerns
Comparison and evaluation are intentionally separated.

- **compare** = evidence generation
- **eval** = interpretation of evidence

### 4.4 Human-in-the-loop
The framework may recommend a verdict, but final operational judgment is made by a human.

### 4.5 Backward-compatible evolution
Changes should be introduced incrementally without unnecessarily breaking existing workflow.

### 4.6 Testable prompt development
Prompt changes should be treated like code changes:
designed, executed, compared, evaluated, and reviewed.

---

## 5. Repository Structure

Typical repository structure:

```text
repo-root/
  prompts/
    base/
    spec/
    mig/
  tests/
    cases/
    suites/
    baselines/
  runs/
  evals/
  scripts/
  docs/
  tmp/
```

### 5.1 prompts/

Prompt source files.

base/ : stable prompt foundation
spec/ : specification-oriented prompt fragments
mig/ : incremental prompt changes managed like migrations

### 5.2 tests/

Test assets.

cases/ : per-case input and metadata
suites/ : grouped execution units
baselines/ : approved expected outputs for regression comparison

### 5.3 runs/

Execution artifacts for each run.

Typical run directory contents:

prompt.txt
response.txt
compare.json
eval.json
manifest.json

### 5.4 evals/

Human-readable evaluation summaries and verdict sheets.

### 5.5 scripts/

Operational scripts used to build, run, compare, evaluate, summarize, and promote.

### 5.6 docs/

Framework and policy documentation.

### 5.7 tmp/

Temporary generated files.

---

## 6. Core Workflow

The expected development flow is:

Update prompt sources or migration files
Build prompt for a test case
Run a case or suite
Capture response artifact
Compare candidate output to baseline
Evaluate the comparison result
Review recommended verdict
Approve and promote baseline if appropriate

---

## 7. Prompt Composition Model

Prompt assembly follows a layered structure.

Typical composition order:

BASE
SPEC_BASE
SPEC
MIGS
TEST_CASE

This ordering ensures that:

stable instructions remain centralized
product or task requirements stay explicit
incremental changes remain trackable
per-test customization is isolated

---

## 8. Test Model

### 8.1 Test Case

A test case represents a single expected behavior check.

A case typically includes:

case.md
meta.json

### 8.2 Test Suite

A suite is a group of case IDs executed together for regression checking.

### 8.3 Baseline

A baseline is an approved output snapshot used as the comparison target.

A baseline is not “truth” in an absolute sense.
It is the currently approved reference behavior.

---

## 9. Metadata Model

Each test case may define metadata that influences evaluation.

Typical metadata fields:

expectedFormat
assertionMode
priority
changePolicy
tags

Example intent of each field:

### 9.1 expectedFormat

Defines expected output form such as:

text
json

### 9.2 assertionMode

Defines how strictly differences should be interpreted.

Examples:

strict
loose

### 9.3 priority

Represents business or review importance.

Examples:

high
medium
low

### 9.4 changePolicy

Defines tolerance to behavior drift.

Examples:

low-drift
flexible

### 9.5 tags

Free-form classification for reporting and review guidance.

---

## 10. Compare / Eval Separation

This is one of the central design decisions.

### 10.1 compare

compare produces structured evidence about differences between baseline and candidate.

Typical outputs include:

format match
raw difference detection
normalized difference detection
omission-related signals
severity hint
policy context

### 10.2 eval

eval interprets compare evidence and metadata to produce a recommended judgment.

Typical outputs include:

recommended verdict
reasons
review focus

### 10.3 Why separation matters

This separation allows:

evidence to remain stable and inspectable
interpretation rules to evolve independently
human reviewers to see both raw signals and suggested judgment

---

## 11. Run Artifacts

Each run should be traceable through artifacts.

Typical artifact expectations:

### 11.1 prompt.txt

The fully assembled prompt used for the run.

### 11.2 response.txt

The actual model output or manually inserted candidate output.

### 11.3 compare.json

Structured evidence comparing baseline and candidate.

### 11.4 eval.json

Recommended evaluation result based on compare evidence and metadata.

### 11.5 manifest.json

Execution metadata such as:

run ID
case ID
timestamps
file paths
execution options

---

## 12. Script Responsibilities

This section defines intended responsibilities, not implementation detail.

### 12.1 build-prompt.ps1

Builds a final prompt from prompt layers and test case context.

### 12.2 run-case.ps1

Executes one case workflow and stores run artifacts.

### 12.3 run-suite.ps1

Executes a defined set of cases.

### 12.4 run-regression.ps1

Runs one or more suites for regression verification.

### 12.5 compare-run.ps1

Compares a candidate run against its approved baseline.

### 12.6 eval-run.ps1

Interprets compare evidence and produces evaluation output.

### 12.7 set-verdict.ps1

Records a human-reviewed final verdict.

### 12.8 summary-evals.ps1

Aggregates evaluation outcomes for reporting.

### 12.9 promote-baseline.ps1

Promotes an approved run to become the new baseline.

### 12.10 validate-repo.ps1

Checks repository consistency and metadata quality.

---

## 13. Evaluation Model

### 13.1 Recommended verdicts

Typical recommended verdicts:

PASS
REVIEW
FAIL

### 13.2 Meaning

PASS: change appears acceptable within policy
REVIEW: human inspection is needed
FAIL: change likely violates expected behavior or policy

### 13.3 Final authority

Recommended verdicts are advisory.
Final operational judgment belongs to a human reviewer.

---

## 14. Human Review Policy

Human review should focus on:

whether required information was lost
whether behavior changed materially
whether formatting rules were broken
whether drift exceeds policy tolerance
whether baseline promotion is justified

This framework intentionally avoids automatic baseline replacement without human approval.

---

## 15. Baseline Promotion Policy

A run may be promoted to baseline only when:

the output has been reviewed
the change is intentional
the result is acceptable for future regression comparison
reviewer identity and notes are recorded if needed

Promoting a baseline means:
the new behavior becomes the approved reference point for future comparisons.

---

## 16. Expected Operating Style

This framework is expected to be used in an iterative cycle:

make a prompt change
run targeted cases
inspect diffs
evaluate drift
review intentionally
promote only when justified

This supports gradual prompt evolution with explicit review checkpoints.

---

## 17. Known Limitations

Current or inherent limitations may include:

semantic correctness is only partially inferable from diffs
some good changes may still appear as regressions
some harmful changes may require careful human interpretation
response capture may be manual depending on workflow
evaluation quality depends on metadata quality

---

## 18. Future Extensions

Possible future extensions:

smarter omission detection
richer diff signals
artifact fingerprinting
CI integration
automated report generation
stronger spec linkage between product requirements and test cases

---

## 19. Relationship to Product Specifications

This framework is the development and verification engine.

It should be used together with separate product-level specifications that define:

what the target behavior should be
what outputs are acceptable
what edge cases matter
what must never regress

In other words:

this document explains how the framework works
product spec documents explain what the target prompt/system should do

---

## 20. Summary

This framework provides a local, artifact-driven, human-review-centered method for prompt development and regression testing.

Its key characteristics are:

structured prompt composition
reproducible runs
baseline comparison
compare/eval separation
metadata-guided interpretation
human-controlled approval flow

The framework is designed not to eliminate judgment, but to make judgment safer, clearer, and more repeatable.