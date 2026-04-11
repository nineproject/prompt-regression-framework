# Phase 7B Minimal Extension: Omission-like Signal

## Summary

A minimal omission-like signal has been introduced to improve evaluation explainability.

This change does NOT alter the core recommendation logic.
It enhances the ability to distinguish between general differences and potential information loss.

---

## Changes

### compare-run

- Added:
  - `possibleOmissionDetected: boolean`

- Scope:
  - Only applied when:
    - expectedFormat = "json"
    - formatMatch = true
    - normalizedDiffDetected = true
    - summary field is present in both baseline and candidate

- Heuristic:
  - Detects missing keywords from baseline summary in candidate summary
  - Marks omission if multiple keywords are missing

---

### eval-run

- Added reasoning:
  - `"possible omission detected"`

- Added review focus:
  - `"check whether critical information was dropped"`
  - `"check whether required key information is missing"` (for high-priority cases)

- Important:
  - No change to PASS / REVIEW / FAIL decision logic

---

## Motivation

Previously, all differences were treated uniformly as "normalized diff".

This made it difficult to distinguish:

- minor wording changes
- meaningful content shifts
- critical information loss

This extension introduces a lightweight signal to highlight potential omission cases.

---

## Validation

- TC-0006 (omission case):
  - `possibleOmissionDetected: true`
  - evaluation includes omission-related reasoning

- Existing cases (TC-0005, TC-0007):
  - no unintended side effects observed (expected behavior preserved)

---

## Design Notes

- compare-run remains evidence-only
- eval-run remains interpretation-only
- heuristic-based (non-semantic) detection
- safe incremental step toward Phase 7B

---

## Next Steps (Phase 7B)

- refine omission detection accuracy
- distinguish diff types (minor / semantic / omission)
- introduce semantic importance weighting