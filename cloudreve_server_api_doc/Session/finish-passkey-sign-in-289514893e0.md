# Finish Passkey sign-in

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /session/authn:
    post:
      summary: Finish Passkey sign-in
      deprecated: false
      description: ''
      tags:
        - Session/Passkey
        - 'Auth: None'
      parameters: []
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                response:
                  type: string
                  description: >-
                    JSON encoded `AuthenticatorAttestationResponse` with
                    additional fields, see example for details.
                session_id:
                  type: string
                  description: Passkey login session ID.
                  examples:
                    - 47c10dd3-7e10-4950-95d5-483dbc9508e6
                  format: uuid
              x-apifox-orders:
                - response
                - session_id
              required:
                - response
                - session_id
              x-apifox-ignore-properties: []
            example:
              session_id: 1d3fedd6-5542-4345-803c-0e7e757fd7b7
              response: >-
                {"id":"hA0kDB_WS1GKXC9-O9Y5yQ","type":"public-key","rawId":"hA0kDB_WS1GKXC9-O9Y5yQ","response":{"attestationObject":"","clientDataJSON":"eyJ0eXBlIjoid2ViYXV0aG4uZ2V0IiwiY2hhbGxlbmdlIjoiLWV5bWEwMlZRcnZxYkdYcXlxMUI3bV9tdlkzdmNweFpTMXJHNmk4RFlPdyIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6NTE3MyIsImNyb3NzT3JpZ2luIjpmYWxzZX0","signature":"MEUCIAFLyQQb-0ivVQvGroWhl8op0E19gAYq1QeYVw6_eRiKAiEA6r_sBQ3r4IutCTmuTLPd7GrjKBbC17avP5RW0gNeUMk","userHandle":"Z3hIZQ","authenticatorData":"SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MdAAAAAA"}}
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JSRKE0B0TGF062N2HG3QZHQM: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      aggregated_error: null
                      data: &ref_0
                        type: object
                        properties: {}
                        x-apifox-orders: []
                        x-apifox-ignore-properties: []
                    required:
                      - data
                x-apifox-orders:
                  - 01JSRKE0B0TGF062N2HG3QZHQM
                properties:
                  data: *ref_0
                  code:
                    type: integer
                    description: |-
                      Response code.
                      `0` - Success.
                    default: 0
                    examples:
                      - 0
                  msg:
                    type: string
                    description: Human readable error message (if any).
                  error:
                    type: string
                    description: Internal error message, only visable in debug mode.
                    nullable: true
                  correlation_id:
                    type: string
                    description: >-
                      Correlation ID of the request. Only presented on failed
                      reqeust.
                    format: uuid
                    examples:
                      - b4351ecc-ee1a-4455-bc94-2c3dbcc58538
                    nullable: true
                required:
                  - data
                  - code
                x-apifox-ignore-properties:
                  - data
                  - code
                  - msg
                  - error
                  - correlation_id
              example:
                data:
                  user:
                    id: 6JIo
                    email: Josh_Fay@yahoo.com
                    nickname: Johnny Zhang
                    created_at: '2023-08-06T19:21:59+08:00'
                    anonymous: false
                    group:
                      id: 1AI8
                      name: Admin
                      permission: /f8B
                      direct_link_batch_size: 10
                      trash_retention: 864000
                    status: manual_banned
                    avatar: file
                    preferred_theme: '#131313'
                    credit: 9
                    language: en-US
                  token:
                    access_token: >-
                      eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwic3ViIjoibHB1YSIsImV4cCI6MTc0NTY1NDMwOCwibmJmIjoxNzQ1NjUwNzA4fQ.n2z8AY-A9GC-CymOsLSA8ruV3vYgNJd27MXRcm4bVu8
                    access_expires: '2025-04-26T15:58:28.456762+08:00'
                    refresh_token: >-
                      eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsInN1YiI6ImxwdWEiLCJleHAiOjE3NjEyMDI3MDgsIm5iZiI6MTc0NTY1MDcwOCwic3RhdGVfaGFzaCI6Ikk1OCtSbmsrTHVpTkxBbjBqek9KNG45OUorV3hqL0pzbjJoRVYrUXBhelE9In0.KoechX6_A2NeVcfFAlHkRLk572hjPKepP0XWfbvBxZY
                    refresh_expires: '2025-10-23T14:58:28.456762+08:00'
                code: 0
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: Session/Passkey
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-289514893-run
components:
  schemas:
    Response:
      type: object
      properties:
        data:
          type: string
        code:
          type: integer
          description: |-
            Response code.
            `0` - Success.
          default: 0
          examples:
            - 0
        msg:
          type: string
          description: Human readable error message (if any).
        error:
          type: string
          description: Internal error message, only visable in debug mode.
          nullable: true
        aggregated_error:
          type: object
          properties: {}
          x-apifox-orders:
            - 01JSRF01R97ZK0FE2NPYS810YS
          description: >-
            Map of multiple error in batch request. The key is the failed
            resource ID, it could be a file URI or a resource ID, the value is a
            `Response`.
          additionalProperties: *ref_1
          x-apifox-ignore-properties: []
          nullable: true
        correlation_id:
          type: string
          description: Correlation ID of the request. Only presented on failed reqeust.
          format: uuid
          examples:
            - b4351ecc-ee1a-4455-bc94-2c3dbcc58538
          nullable: true
      x-apifox-orders:
        - data
        - code
        - msg
        - error
        - aggregated_error
        - correlation_id
      required:
        - data
        - code
      x-apifox-ignore-properties: []
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
