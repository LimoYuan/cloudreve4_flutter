# ExchangeToken

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths: {}
components:
  schemas:
    ExchangeToken:
      type: object
      properties:
        access_token:
          type: string
          examples:
            - >-
              eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwic3ViIjoibHB1YSIsImV4cCI6MTc0NTY1NDMwOCwibmJmIjoxNzQ1NjUwNzA4fQ.n2z8AY-A9GC-CymOsLSA8ruV3vYgNJd27MXRcm4bVu8
          description: >-
            Short lived access token, can be directly used to authenticate for
            all API calls.
        token_type:
          type: string
          examples:
            - Bearer
          description: Fixed value `Bearer`.
        expires_in:
          type: integer
          examples:
            - 3600
          description: Seconds until the `access_token` expires.
        refresh_token_expires_in:
          type: integer
          examples:
            - 7776000
          description: Seconds until the `refresh_token` expires.
          nullable: true
        refresh_token:
          type: string
          description: >-
            Refresh token can be used to get new pair of `access_token` and
            `refresh_token`. This is only presented if `offline_access` scope is
            grantged. 
          examples:
            - >-
              eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsInN1YiI6ImxwdWEiLCJleHAiOjE3NjEyMDI3MDgsIm5iZiI6MTc0NTY1MDcwOCwic3RhdGVfaGFzaCI6Ikk1OCtSbmsrTHVpTkxBbjBqek9KNG45OUorV3hqL0pzbjJoRVYrUXBhelE9In0.KoechX6_A2NeVcfFAlHkRLk572hjPKepP0XWfbvBxZY
          nullable: true
        scope:
          type: string
          examples:
            - openid offline_access File.Read
          description: List of granted scopes, joined with blank spaces.
      x-apifox-orders:
        - access_token
        - token_type
        - expires_in
        - refresh_token_expires_in
        - refresh_token
        - scope
      description: >-
        Response content. In some error type, e.g. lock conflicting errors, this
        field wil present details of the error, e.g. who is locking the current
        file.
      required:
        - access_token
        - token_type
        - expires_in
        - scope
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
