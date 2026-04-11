# ADR: Format Semantics for expectedFormat = "text"

## Context

In the current framework, metadata includes:

- expectedFormat

This value is used in compare-run to determine formatMatch.

During testing (TC-0004), the following behavior was observed:

- A JSON object response was considered valid when expectedFormat = "text"
- formatMatch was reported as true

## Current Behavior

expectedFormat: "text" is interpreted as:

→ "response is non-empty text"

This means:

- JSON
- structured text
- loosely formatted content

are all treated as valid "text"

## Problem

This behavior does not fully align with case-level instructions such as:

- "Output plain text only"
- "Do not use structured formats"

As a result:

- formatMatch may be true even when output violates prompt constraints
- evaluation may miss format-level issues

## Decision (Current Phase)

Do NOT change behavior yet.

Rationale:

- The current system is in Trial & Expansion Phase
- Existing behavior is consistent and predictable
- Immediate tightening may break existing cases

## Future Direction (Phase 7B candidate)

Consider introducing stricter format semantics:

Option A:
- Introduce new format types
  - "plain_text"
  - "json"
  - "markdown"

Option B:
- Add secondary constraints
  - disallowJson: true
  - allowStructured: false

Option C:
- Enhance compare-run with lightweight structural detection

## Status

- Accepted as known limitation
- Deferred to Phase 7B (Smarter Evaluation)
