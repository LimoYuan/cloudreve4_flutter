# Relocate storage policy

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /workflow/reloacte:
    post:
      summary: Relocate storage policy
      deprecated: false
      description: Create a task to relocate storage policy for given files.
      tags:
        - Workflow
        - Pro
        - 'Auth: JWT Required'
      parameters: []
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                src:
                  type: array
                  items:
                    type: string
                  minItems: 1
                  description: URI of files or folders to be relocated.
                dst_policy_id:
                  type: string
              required:
                - src
                - dst_policy_id
              x-apifox-orders:
                - src
                - dst_policy_id
              x-apifox-ignore-properties: []
            example:
              src:
                - cloudreve://my/1/test_folder
                - cloudreve://my/1/cloudreve.exe
              dst_policy_id: J7uV
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JVP19P09Z3DETKW5K5H9EKZA: &ref_1
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
                  - 01JVP19P09Z3DETKW5K5H9EKZA
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
                  created_at: '2025-05-20T13:03:32.006656+08:00'
                  updated_at: '2025-05-20T13:03:32.006657+08:00'
                  id: pE6BU2
                  status: queued
                  type: relocate
                  summary:
                    props:
                      dst_policy_id: J7uV
                      failed: 0
                      src_multiple:
                        - cloudreve://my/1/test_folder
                        - cloudreve://my/1/cloudreve.exe
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: Workflow
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-298116563-run
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
