# Import external files

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /workflow/import:
    post:
      summary: Import external files
      deprecated: false
      description: >-
        Create a task to import external physical files to given path of a given
        user. **This method is restricted to users with admin permission only.**
      tags:
        - Workflow
        - 'Auth: JWT Required'
      parameters: []
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                src:
                  type: string
                  description: >-
                    Path of the folder to be imported in external storage
                    provider.
                dst:
                  type: string
                  description: >-
                    Path of the folder to store imported files in user's `my`
                    filesystem.
                  examples:
                    - /imported
                extract_media_meta:
                  type: boolean
                  description: >-
                    Whether to extract media metadata right after a file is
                    imported.
                user_id:
                  type: string
                  description: ID of the user that files are imported to.
                recursive:
                  type: boolean
                  description: Whether to recursively import child folders.
                policy_id:
                  type: integer
                  description: ID of the storage policy which have to be imported files.
              required:
                - src
                - dst
                - user_id
                - policy_id
              x-apifox-orders:
                - src
                - dst
                - extract_media_meta
                - user_id
                - recursive
                - policy_id
              x-apifox-ignore-properties: []
            example:
              src: /path/to/existing
              dst: /
              extract_media_meta: false
              user_id: lpua
              recursive: true
              policy_id: 1
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JVP1QJRM4NP82CEAQGB86X0W: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      correlation_id: null
                      aggregated_error: null
                      error: null
                      data: &ref_0
                        type: object
                        properties: {}
                        x-apifox-orders: []
                        x-apifox-ignore-properties: []
                    required:
                      - data
                x-apifox-orders:
                  - 01JVP1QJRM4NP82CEAQGB86X0W
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
                required:
                  - data
                  - code
                x-apifox-ignore-properties:
                  - data
                  - code
                  - msg
              example:
                code: 0
                data:
                  created_at: '2025-05-20T13:07:23.952911+08:00'
                  updated_at: '2025-05-20T13:07:23.952911+08:00'
                  id: D8wbcA
                  status: queued
                  type: import
                  summary:
                    props:
                      dst: cloudreve://lpua@my/%2F
                      dst_policy_id: J7uV
                      failed: 0
                      src_str: /not/exist
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: Workflow
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-298117803-run
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
