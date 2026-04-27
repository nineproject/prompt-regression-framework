# Workflow

## 🧭 Getting Started (Recommended Path)

If you are new to this framework, follow this sequence:

1. Run an existing test case  
2. Create initial baseline  
3. Introduce changes via MIG  
4. Compare and evaluate  
5. Promote if acceptable  

---

## 🚀 First Run

### Step 1 — Run a test case

```powershell
./scripts/run-case.ps1 -CaseId TC-0001
```

---

### Step 2 — Provide response

Open:

```
runs/RUN_xxx/response.txt
```

Fill in the response manually or using an LLM.

---

### Step 3 — Compare and evaluate

```powershell
./scripts/compare-run.ps1 -RunId RUN_xxx
./scripts/eval-run.ps1 -RunId RUN_xxx
```

---

### Step 4 — Review summary

```powershell
./scripts/summary-evals.ps1 -RunDate YYYY-MM-DD
```

Expected result:

```
REVIEW | Initial baseline review candidate
```

---

### Step 5 — Promote baseline

```powershell
./scripts/promote-baseline.ps1 -RunId RUN_xxx
```

---

## 🔄 Iteration (After Baseline Exists)

### Step 1 — Create a MIG

```powershell
./scripts/new-mig.ps1 -Title xxx
```

---

### Step 2 — Modify behavior

Edit the MIG file to introduce changes.

---

### Step 3 — Run again

```powershell
./scripts/run-case.ps1 -CaseId TC-0001
```

---

### Step 4 — Compare and evaluate

```powershell
./scripts/compare-run.ps1 -RunId RUN_xxx
./scripts/eval-run.ps1 -RunId RUN_xxx
```

---

### Step 5 — Review differences

Check:

- missing information  
- format differences  
- behavior changes  

---

### Step 6 — Decision

- FAIL → fix prompt  
- REVIEW → accept if intentional  
- PASS → safe to promote  

---

### Step 7 — Promote (if accepted)

```powershell
./scripts/promote-baseline.ps1 -RunId RUN_xxx -Force
```

---

## Evaluation Model (Phase 13)

Evaluation is divided into three clear responsibilities:

- compare = evidence generation
- eval = interpretation of evidence
- human = final decision

### Evidence (compare)

compare produces raw signals only:

- formatMatch
- rawDiffDetected
- normalizedDiffDetected
- possibleOmissionDetected
- omissionStrength (none / weak / strong)
- diffSignals / summarySignals

compare does NOT make judgments.

---

### Interpretation (eval)

eval interprets evidence and produces:

- recommendedVerdict (PASS / REVIEW / FAIL)
- reasons (categorized)
- reviewFocus
- evidence (copied + enriched)

#### Reason Categories

Reasons are categorized for readability:

- [OMISSION]
- [DIFF]
- [FORMAT]
- [POLICY]
- [MIG]

Example:

[OMISSION] strong omission risk detected  
[POLICY] low-drift policy escalated omission risk  
[MIG] add-only kept REVIEW because omission risk was detected

---

### Omission Handling

Omission is treated in graded levels:

- none → no impact
- weak → REVIEW
- strong → FAIL (unless adjusted)

eval uses omissionStrength, not just boolean flags.

---

### MIG-aware Adjustment

MIG type affects final interpretation:

- add-only:
  - FAIL → downgraded to REVIEW
  - reason added: [MIG] add-only kept REVIEW ...

This ensures intended feature additions are not rejected.

---

### Final Decision

Human always makes the final decision:

- PASS → safe to promote
- REVIEW → promote if intended
- FAIL → fix unless intentional change

---

## Human-in-the-loop Model

All decisions are ultimately made by a human.

The system provides:

- evidence (compare)
- interpretation (eval)
- visibility (summary)

Human decides:

- accept (promote baseline)
- reject (revise prompt)

---

## Baseline Strategy (Phase 13)

Baseline is not just a comparison target.

It is:

→ a record of human-approved expected output

---

### Baseline Metadata

Each baseline includes:

- baselineRunId
- previousBaselineRunId
- approvedAt
- approvedReason
- approvedBy
- baselineContext (MIG info)

Example:

{
  "baselineRunId": "...",
  "approvedReason": "Accepted add-only MIG behavior after human review",
  "baselineContext": {
    "migName": "0001-add-comment",
    "migType": "add-only"
  }
}

---

### Promote Flow

run → compare → eval → human review → promote

Promote requires human intent:

./scripts/promote-baseline.ps1 \
  -RunId RUN_... \
  -Reason "..."

---

### Key Principle

Baseline represents:

→ "what we intentionally accept as correct"

NOT:

→ "what happened last time"

---

## 🧠 Development Model

Prompt changes should be introduced via MIG (prompt migrations).

Do NOT start by modifying spec directly.

Instead:

1. Create MIG  
2. Apply incremental change  
3. Validate via regression  
4. Promote if acceptable  
5. Periodically consolidate into spec  

---

## 🔍 Key Concepts

- compare = evidence  
- eval = interpretation  
- human = decision  
- promote = action  

---

## 🆕 First-Run Behavior

When no baseline exists:

- compareStatus = BASELINE_MISSING  
- recommendedVerdict = REVIEW  

This is expected behavior.

The first run acts as a **baseline candidate**.

---

## ⚠️ Common Mistakes

❌ Editing spec directly at the start  
❌ Promoting without review  
❌ Treating REVIEW as failure  

---

## 🎯 Summary

- Start with existing case  
- Establish baseline  
- Evolve via MIG  
- Validate with compare/eval  
- Decide as human  
