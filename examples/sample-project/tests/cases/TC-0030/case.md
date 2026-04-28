
# TC-0030: Generate Implementation for Post Creation API

## Objective

Generate implementation code for POST /api/posts using Next.js App Router and Prisma.

This implementation must follow TC-0020 exactly.

---

## Requirements

- Use Next.js App Router
- Use TypeScript
- Use Prisma
- API route: src/app/api/posts/route.ts
- Prisma client: src/lib/prisma.ts
- Authentication is not fully implemented
- Use a mock user ID (1) for now

---

## Output Structure

Provide the following sections:

1. Prisma Model (schema.prisma)
2. Prisma Client Helper (src/lib/prisma.ts)
3. API Route (src/app/api/posts/route.ts)
4. Test commands (curl)

---

## Constraints

- Do not implement UI
- Do not add extra APIs
- Do not implement full authentication
- Do not deviate from TC-0020 specification

---

## Quality Requirements

- Must be valid TypeScript
- title: required, max 100 characters
- content: required, max 5000 characters
- Return 401 for unauthenticated requests
- Return 400 for validation errors
- Return 201 for success
- createdAt must be ISO string
- Error responses must strictly follow:

```json
{ "error": "authentication required" }
{ "error": "validation error" }
```
