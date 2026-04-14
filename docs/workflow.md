# Development Workflow

This document defines the **standard development workflow** for improving prompts using the prompt regression framework.

The framework is designed to support **safe prompt evolution** by combining:

- prompt migrations
- regression testing
- output comparison
- human evaluation
- baseline management

The workflow ensures that prompt improvements **do not introduce unintended regressions**.

---

# Core Development Cycle

The standard workflow follows this sequence:

Prompt Change
↓
Run Test Case
↓
Compare with Baseline
↓
Evaluate Output
↓
Record Verdict
↓
Promote Baseline (optional)

This cycle is repeated for each prompt improvement.

---

# Typical Prompt Improvement Flow

## Step 1 — Create a Prompt Migration

Create a migration describing the prompt change.

Example:

scripts/new-mig.ps1

This generates a new migration file under:

prompts/mig/

Migrations represent **incremental prompt changes**, similar to database migrations.

---

## Step 2 — Update Prompt Logic

Edit the migration to modify the prompt behavior.

Prompts are assembled in the following order:

BASE  
SPEC_BASE  
SPEC  
MIGS  
TEST_CASE  

This ensures migrations can modify prompt behavior incrementally.

---

## Step 3 — Run Target Test Case

Execute a test case to observe the prompt behavior.

Example:

./scripts/run-case.ps1 -CaseId TC-0001

Artifacts will be generated in:

runs/RUN_xxx/

Generated files include:

prompt.txt  
response.txt  
case.md  
meta.json  
manifest.json  

---

## Step 4 — Compare With Baseline

Run baseline comparison.

Example:

./scripts/run-case.ps1 -CaseId TC-0001 -CompareToBaseline

This automatically runs:

compare-run.ps1

Comparison results are stored in:

compare.json

The comparison detects:

- format differences
- response differences
- potential regressions

### First Run

If no baseline exists:

- compareStatus = BASELINE_MISSING
- recommendedVerdict = REVIEW

This is expected.

The output should be reviewed and may be promoted as the initial baseline.

---

## Step 5 — Evaluate Output

Run evaluation for the new run.

Example:

eval-run.ps1

Evaluation is based on the rules defined in:

docs/evaluation-policy.md

Evaluation considers:

- format compliance
- instruction compliance
- semantic correctness
- style drift
- safety

---

## Step 6 — Record Verdict

Record the evaluation decision.

Example:

set-verdict.ps1

Possible verdicts:

PASS  
FAIL  
REVIEW  

Verdicts are used to determine whether the prompt change is acceptable.

---

## Step 7 — Promote Baseline

If the prompt improvement is accepted, promote the run as the new baseline.

Example:

promote-baseline.ps1

This updates the baseline used for future comparisons.

Baseline promotion should only occur after evaluation is complete.

---

# Regression Workflow

Regression testing ensures that prompt changes do not break existing behavior.

Run a regression suite using:

./scripts/run-regression.ps1 -SuiteId TS-0001

Example result:

===== REGRESSION SUMMARY =====

TS-0001 : PASS

Total : 1  
PASS : 1  
FAIL : 0  

Regression should be executed:

- before promoting a baseline
- after major prompt migrations
- before repository release

---

## Current limitation

When authoring a case, updating `meta.json` alone does **not** change the generated prompt format.

The current workflow supports:

- metadata-aware comparison
- metadata-aware evaluation
- metadata-aware summary
- metadata lite validation

However, it does **not yet support**:

- metadata-driven prompt format switching during build

If a case requires a different output format at the prompt level, that requirement must currently be expressed in:

- BASE / SPEC prompt assets
- or explicit case content

not by metadata alone.

---

# Test Case Authoring Workflow

New test cases can be created using:

scripts/new-case.ps1

A test case directory contains:

tests/cases/TC-xxxx/

Files:

case.md  
meta.json  

Example meta.json:

{
  "title": "minimal summary case",
  "expectedFormat": "json"
}

Test cases define the **expected prompt behavior**.

---

# Migration Workflow

Prompt migrations are used to introduce controlled prompt changes.

Create migrations using:

scripts/new-mig.ps1

Migration files are stored in:

prompts/mig/

Each migration should document:

- purpose
- intended behavior change
- affected test cases
- non-goals

Migrations allow prompt behavior to evolve incrementally.

---

# Suite Workflow

Test suites group multiple cases.

Suites are stored in:

tests/suites/

Suites allow running regression tests across multiple cases.

Common suite types include:

core suite  
format suite  
full regression suite  

---

# Repository Validation

The repository structure can be validated using:

validate-repo.ps1

This checks:

- required directories exist
- case files are valid
- metadata structure is correct
- baseline structure is consistent

Validation should be run before committing major changes.

---

# Recommended Daily Workflow

A typical development session follows this pattern:

1. Create or modify a prompt migration
2. Run a target test case
3. Compare against baseline
4. Evaluate the result
5. Record a verdict
6. Run regression tests
7. Promote baseline if the change is accepted

---

# Design Principles

This framework follows several principles:

Safe Prompt Evolution  
Prompt behavior should evolve without breaking existing behavior.

Regression Protection  
Existing capabilities must remain stable.

Human-in-the-loop Evaluation  
Automated comparison assists but does not replace human review.

Incremental Prompt Changes  
Prompt migrations allow controlled evolution.

Traceable Prompt History  
All changes should be reproducible and reviewable.

---

# Future Extensions

Possible future enhancements include:

- automated semantic similarity checks
- evaluation dashboards
- diff visualization tools
- CI integration
- automated regression pipelines

---

# End of Document
