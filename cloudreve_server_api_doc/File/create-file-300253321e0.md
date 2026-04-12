# Create file

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /file/create:
    post:
      summary: Create file
      deprecated: false
      description: >-
        Create a new file with given URI and props. If ancestor folders does not
        existed for given `uri`, they will be created automatically.
      tags:
        - File
        - 'Auth: JWT Optional'
      parameters:
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
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                uri:
                  type: string
                  description: >-
                    [URI](https://docs.cloudreve.org/api/file-uri) of the file
                    to be created.
                  examples:
                    - cloudreve://my/Inspirations/new.txt
                type:
                  type: string
                  enum:
                    - file
                    - folder
                  x-apifox-enum:
                    - value: file
                      name: ''
                      description: ''
                    - value: folder
                      name: ''
                      description: ''
                  description: Type of the new file.
                metadata:
                  type: object
                  properties: {}
                  x-apifox-orders: []
                  additionalProperties:
                    type: string
                  description: Key-value map of metadata for the new file.
                  x-apifox-ignore-properties: []
                  nullable: true
                err_on_conflict:
                  type: string
                  description: >-
                    Define the behavior when there's conflict (object already
                    existed) for given `uri`:


                    * If `true`, an error will be returned;

                    * If `false`, no mutation is performed, the existing file in
                    `uri` will be returned.
              x-apifox-orders:
                - uri
                - type
                - metadata
                - err_on_conflict
              required:
                - uri
                - type
              x-apifox-ignore-properties: []
            examples:
              '1':
                value:
                  type: file
                  uri: cloudreve://my/Inspirations/new.txt
                  err_on_conflict: true
                summary: Create new empty file
              '2':
                value:
                  type: folder
                  uri: cloudreve://my/Inspirations/Q3
                  metadata:
                    sys:shared_redirect: cloudreve://EBuq:745@share
                    sys:shared_owner: lpua
                  err_on_conflict: true
                summary: Save share link to a shortcut
              '3':
                value:
                  type: folder
                  uri: cloudreve://EBuq:745@share/New%20folder
                  err_on_conflict: true
                summary: Create a new folder
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JW0FG7XGR77VYK05VZ9CSZCV: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      aggregated_error: null
                      data: &ref_0
                        type: object
                        x-apifox-refs:
                          01KG90B8H9MG3FVJVXDJ5121F3:
                            type: object
                            properties: {}
                        x-apifox-orders:
                          - 01KG90B8H9MG3FVJVXDJ5121F3
                        properties: {}
                        x-apifox-ignore-properties: []
                    required:
                      - data
                x-apifox-orders:
                  - 01JW0FG7XGR77VYK05VZ9CSZCV
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
                  type: 1
                  id: d08Wy1Hx
                  name: Q3
                  permission: null
                  created_at: '2025-05-24T14:24:27+08:00'
                  updated_at: '2025-05-24T14:24:27+08:00'
                  size: 0
                  metadata: null
                  path: cloudreve://my/Inspirations/Q3
                  capability: 39/9
                  owned: true
                  primary_entity: zOie
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: File
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-300253321-run
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
