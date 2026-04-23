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
