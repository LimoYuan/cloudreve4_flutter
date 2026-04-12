# List user's share links

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /user/shares/{user-id}:
    get:
      summary: List user's share links
      deprecated: false
      description: List public share links created by the given user.
      tags:
        - User
        - 'Auth: None'
      parameters:
        - name: user-id
          in: path
          description: ID of the user.
          required: true
          example: lpua
          schema:
            type: string
        - name: page_size
          in: query
          description: Page size.
          required: true
          example: 10
          schema:
            type: integer
            minimum: 10
            maximum: 100
        - name: order_by
          in: query
          description: Field name for ordering.
          required: false
          schema:
            type: string
            enum:
              - views
              - downloads
              - price
              - remain_downloads
              - id
            x-apifox-enum:
              - value: views
                name: ''
                description: View count.
              - value: downloads
                name: ''
                description: Download counts.
              - value: price
                name: ''
                description: Price in points.
              - value: remain_downloads
                name: ''
                description: Remain download count for auto-expired shares.
              - value: id
                name: ''
                description: Date of creation.
            default: id
        - name: order_direction
          in: query
          description: ''
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
                description: Ascending (a-z).
              - value: desc
                name: ''
                description: Descending (z-a).
            default: asc
        - name: next_page_token
          in: query
          description: >-
            Token for requesting next page. Empty value means requesting the
            first page.
          required: false
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
                  01JSV74XDS0B9CPHC23K69574V: &ref_1
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
                  - 01JSV74XDS0B9CPHC23K69574V
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
                  shares:
                    - id: VoMFL
                      name: BrNJdjbgi1mvqBf7zycSCskw6ky8nle0
                      visited: 1
                      unlocked: true
                      source_type: 1
                      owner:
                        id: lpua
                        email: admin@cloudreve.org
                        nickname: Aaron Liu2
                        avatar: file
                        created_at: '2023-08-06T19:21:59+08:00'
                      created_at: '2025-04-27T16:12:13+08:00'
                      expired: false
                      url: http://localhost:5173/s/VoMFL/2rje2bdj
                      permission_setting:
                        same_group: null
                        everyone: AQ==
                        other: null
                        anonymous: AQ==
                        group_explicit: {}
                        user_explicit: {}
                      is_private: true
                      password: 2rje2bdj
                    - id: KDVIn
                      name: 使用协议.txt
                      visited: 6
                      downloaded: 2
                      price: 1000
                      unlocked: true
                      source_type: 0
                      owner:
                        id: lpua
                        email: admin@cloudreve.org
                        nickname: Aaron Liu2
                        avatar: file
                        created_at: '2023-08-06T19:21:59+08:00'
                      created_at: '2025-04-22T17:12:52+08:00'
                      expired: false
                      url: http://localhost:5173/s/KDVIn
                      permission_setting:
                        same_group: null
                        everyone: AQ==
                        other: null
                        anonymous: AQ==
                        group_explicit: {}
                        user_explicit: {}
                  pagination:
                    page: 0
                    page_size: 50
                    is_cursor: true
                    next_token: eyJpZCI6Im1LTmxTRCJ9
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: User
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-289873723-run
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
