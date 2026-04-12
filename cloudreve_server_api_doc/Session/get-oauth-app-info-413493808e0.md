# Get OAuth app info

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /session/oauth/app/{app_id}:
    get:
      summary: Get OAuth app info
      deprecated: false
      description: ''
      tags:
        - Session/OAuth
        - 'Auth: JWT Optional'
      parameters:
        - name: app_id
          in: path
          description: ID of the OAuth client app.
          required: true
          example: 393a1839-f52e-498e-9972-e77cc2241eee
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
                  01KG90RMVAE584FHNX1840DM34: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      aggregated_error: null
                      data: &ref_0
                        type: object
                        properties:
                          id:
                            type: string
                            examples:
                              - 393a1839-f52e-498e-9972-e77cc2241eee
                            format: uuid
                            description: ID of the OAuth client app.
                          name:
                            type: string
                            description: >-
                              Display name of the OAuth client app, can be
                              i18next keys.
                            examples:
                              - application:oauth.desktop
                          icon:
                            type: string
                            examples:
                              - /static/img/cloudreve.svg
                            description: URL of the icon image.
                            nullable: true
                          consented_scopes:
                            type: array
                            items:
                              type: string
                            description: >-
                              List of scopes current user already granted to
                              this app. Only presented when requested as a
                              authenticated user.
                            nullable: true
                        x-apifox-orders:
                          - id
                          - name
                          - icon
                          - consented_scopes
                          - 01KG90SFNPG69RQG77XWC1V5G9
                          - 01KG90SFG0TAJ2SPAMVDQAHPZ5
                          - 01KG90SF3GPP8R36MEJ40AME4D
                        description: >-
                          Response content. In some error type, e.g. lock
                          conflicting errors, this field wil present details of
                          the error, e.g. who is locking the current file.
                        required:
                          - id
                          - name
                        x-apifox-ignore-properties: []
                    required:
                      - data
                x-apifox-orders:
                  - 01KG90RMVAE584FHNX1840DM34
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
                  id: 393a1839-f52e-498e-9972-e77cc2241eee
                  name: application:oauth.desktop
                  icon: /static/img/cloudreve.svg
                  consented_scopes:
                    - profile
                    - email
                    - openid
                    - offline_access
                    - UserInfo.Write
                    - Workflow.Write
                    - Files.Write
                    - Shares.Write
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: Session/OAuth
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-413493808-run
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
