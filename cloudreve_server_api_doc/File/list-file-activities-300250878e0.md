# List file activities

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /file/activities:
    get:
      summary: List file activities
      deprecated: false
      description: ''
      tags:
        - File
        - 'Auth: JWT Optional'
        - Pro
      parameters:
        - name: uri
          in: query
          description: '[URI](https://docs.cloudreve.org/api/file-uri) of the file.'
          required: true
          example: cloudreve://my/Luke's%20AMA
          schema:
            type: string
        - name: page_size
          in: query
          description: Page size.
          required: true
          example: 50
          schema:
            type: integer
            minimum: 10
        - name: order_direction
          in: query
          description: Order direction.
          required: false
          example: asc
          schema:
            type: string
            enum:
              - asc
              - desc
            x-apifox-enum:
              - value: asc
                name: ''
                description: ''
              - value: desc
                name: ''
                description: ''
            default: asc
        - name: next_page_token
          in: query
          description: >-
            Token for requesting next page. Empty value means requesting the
            first page.
          required: false
          example: eyJpZCI6IjFibFdJTyJ9
          schema:
            type: string
        - name: filter
          in: query
          description: Filter name. Use empty value to list all activities.
          required: false
          schema:
            type: string
            enum:
              - my
              - updates
              - reads
            x-apifox-enum:
              - value: my
                name: ''
                description: All activities triggered by current authenticated user.
              - value: updates
                name: ''
                description: All activities related to update operation.
              - value: reads
                name: ''
                description: All read-only related activities.
        - name: X-Cr-Purchase-Ticket
          in: header
          description: >-
            Can be used to authenticate to paid share links with a anonymous
            identity. The ticket value can be obtained after an anonymous user
            purchase a paid share link.
          required: false
          example: 1f63aa26-edc0-40ce-950a-cb4d4323158e
          schema:
            type: string
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JW0EEXD7ARE397A92RY7SKBQ: &ref_1
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
                  - 01JW0EEXD7ARE397A92RY7SKBQ
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
                code: 0
                data:
                  activities:
                    - id: VrAoFX
                      content:
                        category: 8
                        original_name: 202206供水检测报告s.docx
                        new_name: 202206供水s检测报告s.docx
                        from: >-
                          cloudreve://ALNU6@share/202206%E4%BE%9B%E6%B0%B4%E6%A3%80%E6%B5%8B%E6%8A%A5%E5%91%8As.docx
                      created_at: '2024-05-29T14:03:49+08:00'
                      user:
                        id: bnUn
                        email: luke@skywalker.com
                        nickname: Luke Skywalker
                        avatar: file
                        created_at: '2023-08-06T19:21:59+08:00'
                    - id: 3JYYTr
                      content:
                        category: 11
                        from: >-
                          cloudreve://ALNU6@share/202206%E4%BE%9B%E6%B0%B4%E6%A3%80%E6%B5%8B%E6%8A%A5%E5%91%8As.docx
                      created_at: '2024-05-29T14:03:44+08:00'
                      user:
                        id: bnUn
                        email: luke@skywalker.com
                        nickname: Luke Skywalker
                        avatar: file
                        created_at: '2023-08-06T19:21:59+08:00'
                  pagination:
                    page: 0
                    page_size: 20
                    next_token: eyJpZCI6IjFibFdJTyJ9
                    is_cursor: true
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: File
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-300250878-run
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
