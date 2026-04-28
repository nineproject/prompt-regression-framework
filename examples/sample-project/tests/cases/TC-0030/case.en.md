# TC-0030: Post Creation API — Implementation Code Generation

## Purpose

Based on TC-0020 "Post Creation API Specification", generate the code required to implement `POST /api/posts` using Next.js App Router + Prisma.

The goal of this case is to output code organized by the files needed for implementation.

---

## Prerequisites

- Use Next.js App Router
- Use TypeScript
- Use Prisma
- API Route path: `src/app/api/posts/route.ts`
- Import Prisma Client from `src/lib/prisma.ts`
- Authentication is not yet fully implemented
- The authenticated user ID is stubbed as `1` for now
- Clearly indicate that this is a stub implementation, to be replaced with Auth.js later

---

## Reference Specification

Follow the specification from TC-0020.

Target API:
`POST /posts`

Implementation path:
`POST /api/posts`

Request body:
- `title`: string
- `content`: string

Success response:
- `id`: number
- `title`: string
- `content`: string
- `authorId`: number
- `createdAt`: string

Error responses:
- `401`: authentication required
- `400`: validation error

---

## Output Requirements

Output must be in Markdown, presented in the following order:

### 1. Prisma Model

Present the `User` / `Post` models to be added to or confirmed in `prisma/schema.prisma`.

### 2. Prisma Client Helper

Present the complete code for `src/lib/prisma.ts`.

### 3. API Route

Present the complete code for `src/app/api/posts/route.ts`.

### 4. Verification Commands

Present `curl` commands for verifying the API behavior.

---

## Implementation Constraints

- Do not implement any UI
- Do not implement a post listing API
- Do not implement a post detail API
- Do not implement comment functionality
- Do not implement authentication as a whole
- Do not create unnecessary files
- Do not perform large-scale rewrites of existing files
- Do not deviate from the TC-0020 specification

---

## Quality Requirements

- Code must be valid, readable TypeScript
- `title` is required, maximum 100 characters
- `content` is required, maximum 5000 characters
- Return `401` when unauthenticated
- Return `400` on validation errors
- Return `201` on success
- Return `createdAt` as an ISO string
- Error responses must exactly match TC-0020
- When unauthenticated, always return `{ "error": "authentication required" }`
- On validation error, always return `{ "error": "validation error" }`
- Treat malformed JSON as a validation error
- The `User` model must use `username` + `password`
- Do not use `email`
