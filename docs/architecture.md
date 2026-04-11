# Architecture

## Purpose

This framework exists to support safe and iterative prompt development for LLM systems.

Prompt behavior is treated as something that evolves over time and must be
managed carefully, not as a single static artifact.

---

## Architectural Principles

### 1. Prompt changes are managed changes

Prompt edits should not be made as ad hoc rewrites.

Each meaningful change should be introduced as a MIG so that:

- the reason for the change is explicit
- the impact can be tested
- the history remains traceable

### 2. Execution and evaluation are separate

Generating an output and deciding whether it is acceptable are different tasks.

This framework separates:

- run generation
- evaluation
- verdict recording

This supports both automation and human review.

### 3. Reproducibility matters

Each run should produce enough artifacts to reconstruct:

- what prompt was used
- what input was used
- what output was generated
- which migrations were applied

### 4. Regression is comparison, not exact matching

Because LLM outputs are variable, regression testing should focus on:

- preserved structure
- preserved constraints
- expected behavior boundaries
- meaningful differences from baseline

---

## Main Components

### prompts/

Contains the layered prompt sources.

- `base/` contains foundational prompt content
- `spec/` contains specifications and constraints
- `mig/` contains prompt migrations

### tests/

Contains the verification assets.

- `cases/` contains individual test cases
- `suites/` groups cases for execution
- `baselines/` stores approved reference outputs

### runs/

Contains execution artifacts for each run.

### evals/

Contains evaluation records and verdict-related data.

### reports/

Contains human-readable summaries and regression reports.

### schemas/

Contains JSON schemas used to validate metadata and artifact structures.

### scripts/

Contains operational scripts for building, running, evaluating, and validating.

---

## Prompt Assembly Order

Prompt build order is:

1. BASE
2. SPEC_BASE
3. SPEC
4. MIGS
5. TEST_CASE

This ordering ensures that:

- stable instruction layers are applied first
- migrations are incremental overlays
- the test case is always the final scenario-specific input

---

## Conceptual Flow

1. Create or update prompt behavior via MIG
2. Build prompt from layered sources
3. Execute test cases
4. Persist run artifacts
5. Evaluate outputs
6. Record verdict
7. Compare against baseline where needed

---

## Human-in-the-loop Evaluation

The framework intentionally keeps a human review step.

This is important because prompt quality often depends on:

- nuance
- trade-offs
- acceptable variation
- product intent

The framework should support automation, but not assume that all quality
judgments can be reduced to exact rules.
