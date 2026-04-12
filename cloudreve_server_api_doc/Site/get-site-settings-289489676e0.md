# Get site settings

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /site/config/{section}:
    get:
      summary: Get site settings
      deprecated: false
      description: >-
        Get global site settings paritioned by sections. Only settings in your
        requested section will be included in your response.
      tags:
        - Site
        - 'Auth: JWT Optional'
      parameters:
        - name: section
          in: path
          description: Setting section name.
          required: true
          example: basic
          schema:
            type: string
            enum:
              - basic
              - login
              - explorer
              - emojis
              - vas
              - app
              - thumb
            x-apifox-enum:
              - value: basic
                name: ''
                description: ''
              - value: login
                name: ''
                description: ''
              - value: explorer
                name: ''
                description: ''
              - value: emojis
                name: ''
                description: ''
              - value: vas
                name: ''
                description: ''
              - value: app
                name: ''
                description: ''
              - value: thumb
                name: ''
                description: ''
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JSRES3WX6QRET3CZN19JDB79: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      data: &ref_0
                        type: object
                        properties: {}
                        x-apifox-orders: []
                        x-apifox-ignore-properties: []
                      aggregated_error: null
                    required:
                      - data
                x-apifox-orders:
                  - 01JSRES3WX6QRET3CZN19JDB79
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
                  instance_id: ac748bd0-7a04-48e7-a12b-8b3b9184b908
                  title: Cloudreve
                  themes: >-
                    {"#3f51b5":{"light":{"palette":{"primary":{"main":"#3f51b5"},"secondary":{"main":"#f50057"}}},"dark":{"palette":{"primary":{"main":"#9fa8da"},"secondary":{"main":"#ff4081"}}}},"#722946":{"light":{"palette":{"primary":{"main":"#722946"},"secondary":{"main":"#f50057"}}},"dark":{"palette":{"primary":{"main":"#e17fa5"},"secondary":{"main":"#f50057"}}}},"#1976d2":{"light":{"palette":{"primary":{"main":"#1976d2","light":"#42a5f5","dark":"#1565c0"},"secondary":{"main":"#9c27b0","light":"#ba68c8","dark":"#7b1fa2"}}},"dark":{"palette":{"primary":{"main":"#90caf9","light":"#e3f2fd","dark":"#42a5f5"},"secondary":{"main":"#ce93d8","light":"#f3e5f5","dark":"#ab47bc"}}}}}
                  default_theme: '#1976d2'
                  site_notice: This is a test site
                  user:
                    id: 6JIo
                    email: johnny.z@cloudreve.org
                    nickname: Johnny Zhang
                    status: active
                    avatar: file
                    created_at: '2023-08-06T19:21:59+08:00'
                    credit: 2000
                    group:
                      id: 1AI8
                      name: User
                      permission: /GY=
                      direct_link_batch_size: 10
                      trash_retention: 14400
                    pined:
                      - uri: cloudreve://my/videos
                  logo: /static/img/logo.svg
                  logo_light: /static/img/logo_light.svg
                  shop_nav_enabled: true
                  captcha_ReCaptchaKey: 6Lel1OgUAAAAABCVuOIduv0dKsrAZnsQeemPZayd
                  captcha_type: turnstile
                  turnstile_site_id: 0x4AAAAAAA9Te1sevTpZkzvy
                  app_promotion: true
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: Site
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-289489676-run
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
