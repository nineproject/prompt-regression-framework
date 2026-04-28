# 📘 Prompt Regression Framework

> Local-first prompt regression framework with human-in-the-loop evaluation. Safe prompt evolution over blind optimization.

> Test prompts like code. Catch regressions before they reach production.

This framework supports both specification generation and implementation generation workflows.

---

## 🚀 Overview

A local framework for **safe prompt evolution** using:

- regression testing
- structured comparison
- human-in-the-loop evaluation

---

## 🎯 Goal

Enable continuous prompt improvement **without breaking existing behavior**.

- Prevent unintended regressions  
- Provide evidence-based comparison  
- Keep final decision with human  

---

## 🧠 Core Principles

- compare = evidence  
- eval = interpretation  
- human = decision  
- promote = action  

- backward compatibility preferred  
- minimal-change updates preferred  

---

## 🔄 Execution Flow

```mermaid
flowchart TD
    A[dev-loop] --> B[summary-evals]
    B --> C[compare-run]
    C --> D[eval-run]
    D --> E[human decision]
    E --> F[promote-baseline]
    F --> G[baseline updated]
```

---

## 🆕 First Run Behavior (Important)

On the first run, no baseline exists yet.

```
compareStatus = BASELINE_MISSING
recommendedVerdict = REVIEW
```

This is **expected behavior**.

👉 It means:

- Comparison is not yet available  
- The output is a **candidate for initial baseline**  

---

## 🔍 What does REVIEW mean?

REVIEW does NOT mean failure.

- Human confirmation is required  
- Changes may be acceptable  
- Baseline may be updated if intentional  

---

## Included sample prompts

This repository includes minimal sample prompts so that the default example suite can run immediately after clone.

## First run note

On the very first accepted run, create the initial baseline with:

```powershell
./scripts/promote-baseline.ps1 -RunId RUN_xxx
```

Comparison starts from the second approved run onward.

---

## ⚡ Daily Usage

### 1. Run dev-loop

```powershell
./scripts/dev-loop.ps1 -SuiteId TS-0001
```

---

### 2. Open summary

```
evals/YYYY-MM-DD/summary.txt
```

---

### 3. Review FAIL / REVIEW

Focus on:

- missing information
- format differences
- behavior changes

---

### 4. Run compare / eval

```powershell
./scripts/compare-run.ps1 -RunId RUN_xxx
./scripts/eval-run.ps1 -RunId RUN_xxx
```

---

### 5. Make decision (Human)

#### DECISION GUIDE

- FAIL → Not acceptable (fix prompt)
- REVIEW → Accept if intentional change
- PASS → Safe to promote

---

### 6. Promote (if accepted)

```powershell
./scripts/promote-baseline.ps1 -RunId RUN_xxx
```

---

## 📦 Baseline Management

### INITIAL_CREATE

- Establish the first baseline  
- Accept current output as reference  

### UPDATE

- Replace existing baseline  
- Requires intentional decision (`-Force`)  

---

## 🧭 Decision Flow

```mermaid
flowchart TD
    A[Open summary] --> B{FAIL / REVIEW / PASS}
    B -->|FAIL| C[Revise prompt]
    B -->|REVIEW| D{Intentional change?}
    B -->|PASS| E[Promote]

    D -->|No| C
    D -->|Yes| E

    E --> F[Update baseline]
```

---

## 🧠 Responsibility Separation

```mermaid
flowchart LR
    A[compare-run] -->|evidence| D[summary]
    B[eval-run] -->|interpretation| D
    D --> C[human decision]
    C --> E[promote]
```

---

## 🧩 Key Scripts

| Script | Role |
|------|------|
| dev-loop.ps1 | Entry point |
| summary-evals.ps1 | Navigation |
| compare-run.ps1 | Evidence |
| eval-run.ps1 | Interpretation |
| promote-baseline.ps1 | Approval |

---

## 🛡 Safety Design

- Human-in-the-loop decision  
- Strict responsibility separation  
- Baseline-based regression  
- Robust against partial artifacts  

---

## 🔁 Loop

```mermaid
flowchart TD
    A[dev-loop] --> B[summary]
    B --> C[compare]
    C --> D[eval]
    D --> E[decision]
    E --> F[promote]
    F --> A
```

---

## ✨ Philosophy

> Safe evolution over blind optimization

- Keep prompts evolvable  
- Keep behavior stable  
- Keep humans in control  

---

## 💡 Concept

This framework separates:

- BASE (global behavior)
- SPEC_BASE (detailed design)
- SPEC_SUMMARY (LLM-optimized spec)
- MIG (intentional changes)
- CASE (task-level instruction)

This allows safe evolution of prompts without breaking existing behavior.

---

## 🚀 Quick Start (First 5 Minutes)

Follow this path if you are new:

---

## 🧭 0. Choose how to start

### Option A: Try the sample project (recommended for first-time users)

A complete working example is available under:

```
examples/sample-project/
```

This includes:

* BASE (prompt rules)
* SPEC_BASE (detailed specification)
* SPEC_SUMMARY (LLM-optimized specification)
* Test cases and suite

👉 Copy it to a working directory:

```powershell
cp -r examples/sample-project my-project
cd my-project
```

---

### Option B: Start your own project

If you want to use this framework for your own idea:

1. Edit base prompt:

```
prompts/base/base.md
```

2. Define your project:

```
prompts/spec/spec_base.md
prompts/spec/spec_summary.md
```

3. Create a test case:

```
tests/cases/TC-0001/case.md
```

⚠️ If you leave sample content in BASE or SPEC,
it will be merged into your prompt and may produce confusing outputs.

---

## 1. Run a test case

```powershell
./scripts/run-case.ps1 -CaseId TC-0001
```

---

## 2. Open the generated prompt and response

```
runs/RUN_xxx/response.txt
```

Fill in the response (or use an LLM).

---

## 3. Compare and evaluate

```powershell
./scripts/compare-run.ps1 -RunId RUN_xxx
./scripts/eval-run.ps1 -RunId RUN_xxx
```

---

## 4. Review summary

```powershell
./scripts/summary-evals.ps1 -RunDate YYYY-MM-DD
```

You will see:

```
REVIEW | Initial baseline review candidate
```

---

## 5. Promote baseline (first time)

```powershell
./scripts/promote-baseline.ps1 -RunId RUN_xxx
```

---

## 6. Make a change using MIG

```powershell
./scripts/new-mig.ps1 -Title xxx
```

Edit the MIG to change behavior.

---

## 7. Run again and observe differences

Repeat steps 1–4.

---

## 8. Decide

* If change is correct → promote
* If not → revise MIG

---

## ⚠️ First-Time Setup (PowerShell Execution Policy)

When running the scripts for the first time, you may encounter an error due to PowerShell's execution policy restrictions.

To allow script execution for the current session, run the following command:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

After that, try running the script again.

> Note: This setting applies only to the current PowerShell session and will be reset when you close the terminal.

---

## About sample project

A complete working example is available under:

examples/sample-project/

This includes:

* BASE (prompt rules)
* SPEC_BASE (detailed specification)
* SPEC_SUMMARY (LLM-optimized specification)
* Test cases and suites

If you want to quickly understand how the framework works,
start from the sample project.

If you want to use it for your own project,
create your own BASE and SPEC instead of modifying the sample.

---

### Example Flow

1. Generate system design (TC-0011)
2. Define API specification (TC-0020)
3. Generate implementation (TC-0030)

---

### How to run

Start with the smoke test, then follow the full flow:

```bash
./scripts/run-suite.ps1 -SuiteId TS-0001   # smoke
./scripts/run-suite.ps1 -SuiteId TS-0010   # spec generation
./scripts/run-suite.ps1 -SuiteId TS-0020   # implementation generation
```

Sample cases are provided in English for public use, while local development can use any language.

---

## Multi-language support

Cases can be written in any language locally.

For public sharing, English versions can be generated using the translation workflow.