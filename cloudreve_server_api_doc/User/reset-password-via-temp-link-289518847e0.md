# Reset password via temp link

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /user/reset/{user_id}:
    patch:
      summary: Reset password via temp link
      deprecated: false
      description: >-
        Reset account password using the `secret` included in the temp URl from
        the Email sent by [Send reset password
        email](https://cloudrevev4.apifox.cn/send-reset-password-email-289518969e0.md).
      tags:
        - User
        - 'Auth: None'
      parameters:
        - name: user_id
          in: path
          description: ''
          required: true
          example: lpua
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                password:
                  type: string
                  minLength: 6
                  maxLength: 64
                  examples:
                    - P@ssw0rd
                  description: New password.
                secret:
                  type: string
                  examples:
                    - XR3EdrZXoi5jDAXJUt9yLn85WWMYmmhK
                  description: Value can be retrieved from the temp url in the email.
              x-apifox-orders:
                - password
                - secret
              required:
                - password
                - secret
              x-apifox-ignore-properties: []
            examples: {}
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JSRMR6JAWCENPHYE2K29YQ4C: &ref_1
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
                  - 01JSRMR6JAWCENPHYE2K29YQ4C
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
                  id: 6JIo
                  email: Randall63@gmail.com
                  nickname: Johnny Zhang
                  created_at: '2023-08-06T19:21:59+08:00'
                  anonymous: null
                  group:
                    id: 1AI8
                    name: Admin
                    permission: /f8B
                    direct_link_batch_size: 10
                    trash_retention: 864000
                  status: manual_banned
                  avatar: file
                  preferred_theme: '#131313'
                  credit: 69
                  language: en-US
                code: 0
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: User
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-289518847-run
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
