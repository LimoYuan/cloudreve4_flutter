# Search user

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /user/search:
    get:
      summary: Search user
      deprecated: false
      description: Search other users by display name of email.
      tags:
        - User
        - 'Auth: JWT Required'
      parameters:
        - name: keyword
          in: query
          description: Search keyword, can be part of display name or email.
          required: true
          example: Aaron
          schema:
            type: string
            minLength: 2
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JXHDGGBB3VHHZNP41BP1MAQC: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      aggregated_error: null
                      data: &ref_0
                        type: array
                        items:
                          type: object
                          x-apifox-refs:
                            01KG902PCCG27EPQHJWF024YV0:
                              type: object
                              properties: {}
                          x-apifox-orders:
                            - 01KG902PCCG27EPQHJWF024YV0
                          properties: {}
                          x-apifox-ignore-properties: []
                        description: >-
                          Response content. In some error type, e.g. lock
                          conflicting errors, this field wil present details of
                          the error, e.g. who is locking the current file.
                        nullable: true
                x-apifox-orders:
                  - 01JXHDGGBB3VHHZNP41BP1MAQC
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
                  - code
                x-apifox-ignore-properties:
                  - data
                  - code
                  - msg
                  - error
                  - correlation_id
              example:
                code: 0
                data:
                  - id: lpua
                    email: admin@cloudreve.org
                    nickname: Aaron Liu
                    avatar: file
                    created_at: '2023-08-06T19:21:59+08:00'
                    group:
                      id: z4u4
                      name: 管理员
                  - id: gymfz
                    email: a1e4b09e-8332-44a2-8c2e-de95b1ead741@openid.unmanaged
                    nickname: Aaron Liu
                    created_at: '2025-02-08T13:57:26+08:00'
                    group:
                      id: 1AI8
                      name: User
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: User
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-307905893-run
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
