# Evaluation Architecture

This framework follows a structured evaluation architecture designed to make prompt evolution safe, auditable, and regression-resistant.

The system intentionally separates four concerns:

- execution
- evidence generation
- evaluation
- human verdict

This separation ensures that prompt changes can evolve without silently breaking existing behavior.

# High Level Flow

The overall flow of the framework is:

Prompt Build
↓
Execution
↓
Evidence Generation (compare-run)
↓
Evaluation (eval-run)
↓
Human Verdict (set-verdict)

Each stage has a clearly defined responsibility.

# Layer 1 — Execution Layer

The execution layer produces raw artifacts from prompt execution.

Scripts involved:

- build-prompt.ps1
- run-case.ps1
- run-suite.ps1
- run-regression.ps1

Artifacts generated:

- prompt.txt
- response.txt
- manifest.json
- case.md
- meta.json

Purpose:

- run prompts
- capture outputs
- store reproducible execution artifacts

This layer does not perform evaluation.

# Layer 2 — Evidence Layer

The evidence layer analyzes execution artifacts and produces comparison evidence.

Script:

compare-run.ps1

Primary artifact:

compare.json

Example structure:

{
  "caseId": "TC-0001",
  "baselineRunId": "RUN_20260312_222754_TC-0001",
  "candidateRunId": "RUN_20260314_231947_TC-0001",
  "formatMatch": false,
  "rawDiffDetected": true,
  "normalizedDiffDetected": true,
  "severityHint": "HIGH",
  "casePolicy": {
    "expectedFormat": "json",
    "assertionMode": "normal",
    "priority": "normal",
    "changePolicy": "normal",
    "tags": []
  }
}

Important properties of the evidence layer:

- deterministic
- reproducible
- policy-aware
- verdict-free

The evidence layer never decides PASS or FAIL.

It only produces facts and signals.

# Layer 3 — Evaluation Layer

The evaluation layer interprets evidence and produces evaluation guidance.

Script:

eval-run.ps1

Inputs:

- compare.json
- meta.json
- evaluation-policy.md

Outputs:

- evaluation artifacts
- recommendedVerdict

Example interpretation:

severityHint = HIGH
expectedFormat = json
formatMatch = false

Possible result:

recommendedVerdict = FAIL

However, this recommendation does not finalize the decision.

# Layer 4 — Human Verdict Layer

The final decision is recorded by a human evaluator.

Script:

set-verdict.ps1

Possible verdicts:

- PASS
- FAIL
- REVIEW

Purpose:

- confirm regression status
- approve prompt changes
- allow baseline promotion

Human judgment remains the final authority.

# Why This Architecture Matters

Separating the layers provides several benefits.

Reproducibility

All execution artifacts are preserved, allowing evaluation to be replayed.

Auditability

Every change is supported by evidence artifacts stored in the repository.

Examples:

runs/
compare.json
evaluation artifacts
verdict logs

This creates a transparent evaluation history.

Safe Prompt Evolution

Prompts can evolve without silently breaking existing behavior.

Regression risk is controlled through:

- baseline comparison
- policy-aware evaluation
- human verification

Extensibility

New evaluation techniques can be added without modifying execution logic.

Possible future extensions:

- structural JSON comparison
- schema validation
- semantic similarity scoring
- LLM-based evaluation

Because evidence artifacts are stable, evaluation logic can evolve independently.

# Design Principle

Execution produces artifacts.
Evidence produces facts.
Evaluation produces guidance.
Humans produce verdicts.

Automation supports decision making but does not replace human judgment.

# Summary

The evaluation architecture consists of four conceptual layers:

Execution
Evidence
Evaluation
Human Verdict

This structure enables safe prompt development with regression protection while maintaining transparency and human control.
