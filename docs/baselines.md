# Baselines

## Purpose

A baseline is an approved reference output for a test case.

In traditional software testing, expected values are often exact.

In LLM systems, outputs can vary while still being acceptable, so a baseline
acts as a reviewed reference point rather than a strict golden output.

---

## Why Baselines Matter

Baselines help answer:

- what changed
- whether the change was intended
- whether important structure or constraints were preserved

They are especially useful when exact string matching is too brittle.

---

## Suggested Baseline Record

Example structure:

    tests/baselines/TC-0001.json

Suggested fields:

- caseId
- baselineRunId
- approvedAt
- approvedBy
- notes

Example:

    {
      "caseId": "TC-0001",
      "baselineRunId": "RUN_20260313_220501_TC-0001",
      "approvedAt": "2026-03-13T22:30:00+09:00",
      "approvedBy": "sari",
      "notes": "Accepted after MIG-0007"
    }

---

## Recommended Workflow

1. Run case or regression
2. Evaluate output
3. Record PASS verdict
4. Promote the run to baseline if it should become the new reference

---

## Baseline Comparison

Future comparison tooling should evaluate differences such as:

- output format consistency
- JSON validity
- required key presence
- approximate length change
- notable semantic shifts

The goal is not exact equality but meaningful change detection.
