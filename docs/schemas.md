# Schemas

## Purpose

Schemas define the expected structure of metadata and artifact files.

They help the framework become more robust by making repository rules explicit.

---

## Current and Planned Schemas

Recommended schema files:

    schemas/case-meta.schema.json
    schemas/mig-meta.schema.json
    schemas/suite.schema.json
    schemas/manifest.schema.json
    schemas/eval.schema.json
    schemas/baseline.schema.json

---

## case-meta.schema.json

Defines allowed structure for case metadata.

Suggested fields:

- title
- expectedFormat
- purpose
- tags
- priority
- oracleType
- stability
- relatedMigs

Purpose:

- make cases self-describing
- support filtering and targeted regression
- improve evaluation clarity

---

## mig-meta.schema.json

Defines allowed structure for migration metadata.

Suggested fields:

- id
- title
- type
- risk
- target
- expectedImpact
- relatedCases
- author
- createdAt
- status

Purpose:

- make change intent explicit
- support impact analysis
- improve reviewability

---

## manifest.schema.json

Defines structure for run artifacts.

Suggested fields:

- runId
- executedAt
- frameworkVersion
- model
- generationConfig
- caseId
- suiteId
- appliedMigs
- promptSources
- gitCommit
- promptSha256
- responseSha256

Purpose:

- support reproducibility
- support auditability
- support comparison across runs

---

## Validation Strategy

Validation should eventually be built into:

- new-case.ps1
- new-mig.ps1
- run-case.ps1
- validate-case.ps1
- validate-mig.ps1
- validate-suite.ps1
- validate-repo.ps1

The goal is to detect structural errors before expensive runs happen.
