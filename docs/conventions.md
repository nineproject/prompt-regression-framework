# Conventions

## Naming Rules

### Case IDs

Test cases use:

    TC-0001
    TC-0002

### Suite IDs

Suites use:

    TS-0001
    TS-SMOKE
    TS-CRITICAL

A descriptive naming style is acceptable for suites if consistently applied.

### Migration IDs

Migrations use:

    MIG-0001
    MIG-0002

### Run IDs

Runs should use a timestamp-based format such as:

    RUN_20260313_220501_TC-0001

### Evaluation IDs

Evaluations may use a format such as:

    EV_20260313_223000_RUN_20260313_220501_TC-0001

---

## File Layout Rules

### Case

Each case should contain at minimum:

    case.md
    meta.json

Optional:

    oracle/
      expected.json
      notes.md

### MIG

Recommended structure:

    prompts/mig/MIG-0001/
      prompt.md
      meta.json

For compatibility, legacy single-file MIGs may remain temporarily supported.

### Suite

Recommended structure:

    tests/suites/TS-SMOKE/
      suite.json

### Baseline

Recommended structure:

    tests/baselines/TC-0001.json

---

## Metadata Guidelines

### case meta

Recommended fields include:

- title
- expectedFormat
- purpose
- tags
- priority
- oracleType
- stability
- relatedMigs

### MIG meta

Recommended fields include:

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

### run manifest

Recommended fields include:

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

---

## Suite Design Guidance

Suites should reflect intent, not only grouping convenience.

Recommended suite categories:

- smoke
- critical
- capability-based
- migration impact

Examples:

- TS-SMOKE
- TS-CRITICAL
- TS-SUMMARY
- TS-JSON
- TS-MIG-0007-IMPACT

---

## Documentation Guidance

Keep README short.

Put detailed design and operational guidance into the docs directory.

Recommended reading order:

1. README.md
2. docs/architecture.md
3. docs/workflow.md
4. docs/conventions.md
5. scripts and schemas
