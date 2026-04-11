You are given a short support ticket.

Return exactly one JSON object.
Do not use markdown.
Do not use code fences.
Do not add any explanation before or after the JSON.

Support ticket:
---
Login fails after password reset.
User can access email but cannot sign in to the app.
---

Required JSON schema:
{
  "category": string,
  "urgency": string,
  "summary": string
}

Constraints:
- category must be one of: "auth", "billing", "ui", "other"
- urgency must be one of: "low", "medium", "high"
- summary must be a single sentence
