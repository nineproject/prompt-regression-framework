# TC-0020: Post Creation API Specification

## Purpose

Define the specification for the "Post Creation API" in a bulletin board MVP with user accounts.

The goal of this case is to output the API's inputs/outputs, authentication requirements, validations, and error responses in a fixed format, so there is no ambiguity during implementation.

---

## Target API

POST /posts

---

## Assumptions

- Only authenticated users can create posts
- A post has a `title` and `content`
- The author is treated as the currently logged-in user
- `createdAt` is generated server-side
- Keep it simple as an MVP

---

## Output Requirements

Output must be in the following JSON format only.

Do not include explanatory text, Markdown, or code fences.

```json
{
  "endpoint": {
    "method": "POST",
    "path": "/posts",
    "authRequired": true,
    "description": ""
  },
  "request": {
    "body": {
      "title": {
        "type": "string",
        "required": true,
        "maxLength": 100
      },
      "content": {
        "type": "string",
        "required": true,
        "maxLength": 5000
      }
    }
  },
  "response": {
    "successStatus": 201,
    "body": {
      "id": "number",
      "title": "string",
      "content": "string",
      "authorId": "number",
      "createdAt": "string"
    }
  },
  "errors": [
    {
      "status": 401,
      "reason": "authentication required"
    },
    {
      "status": 400,
      "reason": "validation error"
    }
  ]
}
```

---

## Constraints

- Do not include comment functionality
- Do not include post editing or deletion
- Do not write the full DB schema
- Focus on the API specification
- Output must be JSON only
