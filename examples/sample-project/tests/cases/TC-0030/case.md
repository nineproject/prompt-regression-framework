# TC-0030: 投稿作成API 実装コード生成

## 目的

TC-0020「投稿作成API仕様」に基づき、Next.js App Router + Prisma で POST /api/posts を実装するためのコードを生成する。

このケースでは、実装に必要なファイル単位のコードを出力することを目的とする。

---

## 前提

- Next.js App Router を使用する
- TypeScript を使用する
- Prisma を使用する
- API Route は src/app/api/posts/route.ts とする
- Prisma Client は src/lib/prisma.ts から import する
- 認証機能はまだ本実装しない
- 認証済みユーザーIDは仮実装で 1 とする
- 後で Auth.js に置き換えられるよう、仮実装であることを明示する

---

## 参照仕様

TC-0020 の仕様に従うこと。

対象API:
POST /posts

実装上のパス:
POST /api/posts

Request body:
- title: string
- content: string

Success response:
- id: number
- title: string
- content: string
- authorId: number
- createdAt: string

Error responses:
- 401: authentication required
- 400: validation error

---

## 出力要件

出力は Markdown とし、必ず以下の順番で記載すること。

### 1. Prisma Model

prisma/schema.prisma に追加・確認すべき User / Post model を提示する。

### 2. Prisma Client Helper

src/lib/prisma.ts の完成コードを提示する。

### 3. API Route

src/app/api/posts/route.ts の完成コードを提示する。

### 4. 動作確認コマンド

curl による動作確認コマンドを提示する。

---

## 実装制約

- UI は実装しない
- 投稿一覧APIは実装しない
- 投稿詳細APIは実装しない
- コメント機能は実装しない
- 認証機能全体は実装しない
- 余計なファイルを増やさない
- 既存ファイル全体の大規模書き換えをしない
- TC-0020 の仕様から外れない

---

## 品質要件

- TypeScript として読めるコードにする
- title は必須、最大100文字
- content は必須、最大5000文字
- 未認証時は 401 を返す
- バリデーションエラー時は 400 を返す
- 成功時は 201 を返す
- createdAt は ISO string で返す
- エラーレスポンスは TC-0020 と完全に一致させること
- 未認証時は必ず { "error": "authentication required" } を返すこと
- バリデーションエラー時は必ず { "error": "validation error" } を返すこと
- 不正JSONも validation error として扱うこと
- User model は username + password を使うこと
- email は使わないこと
