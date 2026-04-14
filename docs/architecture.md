# Architecture

## Purpose

This framework exists to support safe and iterative prompt development for LLM systems.

Prompt behavior is treated as something that evolves over time and must be
managed carefully, not as a single static artifact.

---

## Architectural Principles

### 1. Prompt changes are managed changes

Prompt edits should not be made as ad hoc rewrites.

Meaningful prompt changes may be introduced through MIGs so that:

- the reason for the change is explicit
- the impact can be tested
- the history remains traceable

### 2. Compare, evaluation, and decision are separate

Generating an output, comparing it to baseline, interpreting the result,
and deciding whether to accept it are different tasks.

This framework separates:

- run generation
- compare (evidence)
- eval (interpretation)
- human decision
- promote (action)

This supports both automation and human review while preserving clear
responsibility boundaries.

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

Contains execution artifacts for each run, including prompt, response, compare result, eval result, and manifest.

### evals/

Contains human-readable summaries and review-oriented outputs.

### schemas/

Contains JSON schemas used to validate metadata and artifact structures.

### scripts/

Contains operational scripts for building, running, comparing, evaluating, summarizing, promoting, and validating.

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

1. Create or update prompt behavior
2. Build prompt from layered sources
3. Execute test cases or suites
4. Persist run artifacts
5. Compare candidate output against baseline
6. Evaluate compare evidence
7. Review as human
8. Promote baseline if appropriate

---

## First-Run Handling

The framework supports first-run scenarios where no approved baseline exists yet.

In such cases:

- compare records `BASELINE_MISSING` as evidence
- eval interprets the state as `REVIEW`
- human decides whether the run should become the initial baseline

This avoids treating baseline absence as an operational error.

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
