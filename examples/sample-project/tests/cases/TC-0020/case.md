# TC-0020: 投稿作成API仕様

## 目的

ユーザーアカウント付き掲示板MVPにおける「投稿作成API」の仕様を定義する。

このケースでは、実装時に迷わないよう、APIの入出力・認証要件・バリデーション・エラー応答を固定フォーマットで出力することを目的とする。

---

## 対象API

POST /posts

---

## 前提

- 認証済みユーザーのみ投稿を作成できる
- 投稿は title と content を持つ
- 投稿者はログイン中ユーザーとして扱う
- createdAt はサーバー側で生成する
- MVPとしてシンプルに保つ

---

## 出力要件

出力は必ず以下の JSON 形式のみとする。

説明文、Markdown、コードフェンスは含めないこと。

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

---

## 制約

- コメント機能は含めない
- 投稿編集・削除は含めない
- DBスキーマ全体は書かない
- API仕様に集中する
- 出力は JSON のみ