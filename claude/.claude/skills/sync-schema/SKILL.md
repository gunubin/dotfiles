---
name: sync-schema
description: |
  ltp-backendのschema.gqlをBFF・Frontendにコピーし、BFFでは型再生成を実行する。
  スキーマ変更後に使用。
allowed-tools: Bash, Read
disable-model-invocation: false
---

# sync-schema

ltp-backendの`src/schema.gql`をBFFとFrontendにコピーし、BFFではGraphQL型を再生成する。

## 手順

1. `src/schema.gql` を以下にコピー:
   - BFF: `/Users/koki.kato.a/works/ltp-person-bff/src/infrastructure/graphql/ltpBackend/schema.gql`
   - Frontend: `/Users/koki.kato.a/works/ltp-frontend/apps/to-person/src/graphql/schema.gql`

2. BFFで型再生成を実行:
   ```bash
   cd /Users/koki.kato.a/works/ltp-person-bff && yarn genGql:ltpBackend
   ```

3. 完了後、コピー結果をユーザーに報告する
