# ADR-0002: First-Run Handling without Baseline

## Status

Accepted

---

## Context

The framework relies on baseline comparison to detect regressions.

However, during initial setup:

- no baseline exists yet
- compare cannot perform a comparison
- the system must still produce meaningful output

Previously, this situation could lead to:

- errors or early termination
- unclear user experience
- manual and implicit baseline creation

This created friction during onboarding and first use.

---

## Decision

The framework explicitly supports "no baseline" as a valid state.

### compare-run

When no baseline exists:

- do not throw an error
- produce a compare artifact with:

    compareStatus = BASELINE_MISSING  
    comparable = false  

- treat this as structured evidence

---

### eval-run

Non-comparable results are interpreted as:

- recommendedVerdict = REVIEW  
- reasons include:
  - comparison not available: BASELINE_MISSING  

---

### summary-evals

First-run results are displayed as:

- "Initial baseline review candidate"

The system provides clear guidance for next actions:

- review output
- promote as baseline if acceptable

---

### promote-baseline

Baseline promotion distinguishes two modes:

#### INITIAL_CREATE

- first-time baseline establishment
- no previous baseline exists

#### UPDATE

- replaces an existing baseline
- requires intentional decision (e.g., -Force)

---

## Alternatives Considered

### 1. Treat missing baseline as error

Rejected because:

- breaks first-run experience
- requires manual setup before usage
- violates usability goals

---

### 2. Automatically accept first run as baseline

Rejected because:

- removes human control
- risks accepting incorrect output
- violates human-in-the-loop principle

---

### 3. Skip evaluation when baseline is missing

Rejected because:

- loses visibility into system state
- breaks consistency of pipeline
- removes opportunity for guided review

---

## Consequences

### Positive

- smooth onboarding experience
- no special-case handling required by users
- consistent execution pipeline
- preserves responsibility separation:
  - compare = evidence
  - eval = interpretation
  - human = decision

---

### Negative

- introduces non-comparable states
- requires users to understand REVIEW semantics
- slightly more complex logic in compare/eval

---

## Notes

This decision formalizes the first-run experience as part of the system design.

It ensures that:

- absence of baseline is not treated as an error
- the system remains usable from the first run
- human decision remains central to baseline establishment
