# Metadata Schema

This document defines the **metadata schema used by the prompt regression framework**.

Metadata allows the framework to become **metadata-driven**, where case behavior,
evaluation policy, and regression sensitivity are controlled by structured data
rather than hardcoded logic.

The primary metadata source is:

tests/cases/TC-xxxx/meta.json

---

# Design Goals

The metadata system aims to provide:

- configurable evaluation strictness
- regression prioritization
- controlled prompt evolution
- structured case categorization
- improved automation potential

Metadata should remain **simple, human-readable, and stable**.

---

# Example meta.json

Example:

{
  "title": "minimal summary case",
  "expectedFormat": "json",
  "assertionMode": "strict",
  "priority": "high",
  "changePolicy": "low-drift",
  "tags": ["summary", "format"],
  "owner": "core",
  "notes": "Structured JSON output must remain stable."
}

---

# Field Definitions

## title

Human-readable name of the test case.

Example:

"title": "entity extraction from paragraph"

Used only for documentation and reporting.

---

## expectedFormat

Defines the expected output format.

Examples:

json  
markdown  
text  

Future extensions may support schema validation.

Format mismatches are typically treated as **hard failures**.

---

## assertionMode

Defines how strict evaluation should be.

Options:

strict  
normal  
loose  

### strict

Minimal output drift allowed.

Used for:

- structured outputs
- extraction tasks
- classification
- safety responses

### normal

Small wording changes allowed.

Used for:

- summaries
- explanations
- reasoning outputs

### loose

Only semantic correctness matters.

Used for:

- creative generation
- open-ended tasks

---

## priority

Defines the importance of the test case in regression analysis.

Options:

critical  
high  
normal  
low  

### critical

Core guarantees of the prompt system.

Any failure may fail the entire regression suite.

### high

Important behavior but not system-breaking.

### normal

Standard regression coverage.

### low

Informational or exploratory cases.

---

## changePolicy

Defines how much output drift is acceptable.

Options:

frozen  
low-drift  
allowed-improvement  

### frozen

Output should remain unchanged.

Any difference requires investigation.

Used for:

- schema outputs
- safety responses
- deterministic transformations

### low-drift

Minor wording differences allowed.

Meaning must remain identical.

### allowed-improvement

Changes are acceptable if output quality improves.

Human evaluation required.

---

## tags

Tags allow cases to be categorized.

Examples:

summary  
extraction  
format  
reasoning  
safety  
refusal  
classification  
edge-case  

Tags support:

- targeted regression suites
- case discovery
- coverage analysis

Example:

"tags": ["extraction", "entities"]

---

## owner (optional)

Identifies which logical component or area owns the case.

Examples:

core  
format  
safety  
reasoning  

This helps organize large test suites.

---

## notes (optional)

Additional evaluation guidance for reviewers.

Example:

"notes": "Model must not hallucinate entities."

Notes help reviewers interpret evaluation results.

---

# How Metadata Is Used

Metadata influences several framework components.

---

## compare-run.ps1

Metadata may be used to generate **severity hints**.

Example logic:

strict + frozen  
→ diff severity = HIGH

normal + low-drift  
→ diff severity = MEDIUM

loose + allowed-improvement  
→ diff severity = LOW

compare.json may include:

{
  "severityHint": "LOW",
  "casePolicy": {
    "assertionMode": "normal",
    "priority": "high",
    "changePolicy": "low-drift"
  }
}

---

## eval-run.ps1

Metadata informs the **recommended evaluation verdict**.

Example:

strict + frozen + diff detected  
→ recommendedVerdict = FAIL

normal + low-drift + wording drift  
→ recommendedVerdict = REVIEW

loose + allowed-improvement  
→ recommendedVerdict = PASS

Human reviewers make the final decision.

---

## run-regression.ps1

Metadata influences regression reporting.

Example regression summary:

===== REGRESSION SUMMARY =====

Critical FAIL : 0  
High FAIL : 1  
Normal FAIL : 2  
Low FAIL : 3  

Overall Verdict : REVIEW

Priority allows important failures to be highlighted.

---

# Metadata Design Principles

The schema follows several principles.

---

## Keep Metadata Minimal

Only add fields that directly influence evaluation or organization.

Avoid excessive complexity.

---

## Prefer Stable Fields

Metadata structure should remain stable to avoid breaking historical cases.

Fields should rarely be renamed.

---

## Support Incremental Evolution

New metadata fields should be **optional** whenever possible.

Existing cases should remain valid.

---

## Separate Policy from Implementation

Metadata defines policy.

Scripts implement behavior.

This separation allows the framework to evolve safely.

---

# Future Extensions

Possible metadata extensions include:

- schema validation definitions
- semantic similarity thresholds
- automated evaluation hints
- case coverage tracking
- suite auto-generation

---

# Summary

Metadata enables the framework to evolve from:

Script-driven behavior  
→ Metadata-driven behavior

This makes the system easier to extend, analyze, and maintain.

---

# End of Document
