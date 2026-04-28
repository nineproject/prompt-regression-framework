# TC-0020: Post Creation API Specification

## Objective

Define the API specification for creating a post in the bulletin board MVP.

---

## API

POST /posts

---

## Output Requirements

Output must be **JSON only**.

Do not include explanations, markdown, or code blocks.

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

- Do not include comments or additional APIs
- Focus only on this endpoint
- Keep the structure exactly as defined
