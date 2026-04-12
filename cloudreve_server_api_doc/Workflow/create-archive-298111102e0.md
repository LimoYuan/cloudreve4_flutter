# Create archive

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /workflow/archive:
    post:
      summary: Create archive
      deprecated: false
      description: Create a tasks to create a new archive file from existing files.
      tags:
        - Workflow
        - 'Auth: JWT Required'
      parameters: []
      requestBody:
        content:
          application/json:
            schema:
              type: object
              x-apifox-refs:
                01JVNZFX64CJ01T19KYMZM0X71:
                  $ref: '#/components/schemas/ArchiveWorkflowService'
                  x-apifox-overrides:
                    encoding: null
                    dst: &ref_0
                      type: string
                      description: URI of destination archive file.
                      examples:
                        - cloudreve://my/dst
                  required:
                    - src
                    - dst
              x-apifox-orders:
                - 01JVNZFX64CJ01T19KYMZM0X71
              properties:
                src:
                  type: array
                  items:
                    type: string
                    examples:
                      - cloudreve://my/1.zip
                  description: Source file URIs.
                dst: *ref_0
                preferred_node_id:
                  type: string
                  description: >-
                    Select preferred node to handle this task. Only available in
                    pro edition. Option of nodes can be get from [List available
                    nodes](./list-available-nodes-308315715e0).
                  examples:
                    - aO9z
                password:
                  type: string
                  description: Optional paassword for `zip` or `7z` archive files.
                  nullable: true
                file_mask:
                  type: array
                  items:
                    type: string
                  description: >-
                    List of files to select. If presented, only files in this
                    list, or contains any of it as prefix will be extracted.
                  nullable: true
              required:
                - src
                - dst
              x-apifox-ignore-properties:
                - src
                - dst
                - preferred_node_id
                - password
                - file_mask
            example:
              src:
                - cloudreve://my/1/marker-shadow%20(2).png
                - cloudreve://my/1/cloudreve_4.0.0-beta.7_windows_amd64.zip
              dst: cloudreve://my/1/archive.zip
              preferred_node_id: m9uO
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JVNZNEVPZZ71QB7SDQ3F3HTJ: &ref_2
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      correlation_id: null
                      aggregated_error: null
                      error: null
                      data: &ref_1
                        type: object
                        properties: {}
                        x-apifox-orders: []
                        x-apifox-ignore-properties: []
                    required:
                      - data
                x-apifox-orders:
                  - 01JVNZNEVPZZ71QB7SDQ3F3HTJ
                properties:
                  data: *ref_1
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
                  created_at: '2025-05-20T12:37:54.772918+08:00'
                  updated_at: '2025-05-20T12:37:54.772919+08:00'
                  id: qlboH4
                  status: queued
                  type: create_archive
                  summary:
                    props:
                      dst: cloudreve://my/1/archive.zip
                      failed: 0
                      src_multiple:
                        - cloudreve://my/1/marker-shadow%20(2).png
                        - >-
                          cloudreve://my/1/cloudreve_4.0.0-beta.7_windows_amd64.zip
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: Workflow
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-298111102-run
components:
  schemas:
    ArchiveWorkflowService:
      type: object
      properties:
        src:
          type: array
          items:
            type: string
            examples:
              - cloudreve://my/1.zip
          description: Source file URIs.
        dst:
          type: string
          description: URI of destination folder to store output files.
          examples:
            - cloudreve://my/dst
        preferred_node_id:
          type: string
          description: >-
            Select preferred node to handle this task. Only available in pro
            edition. Option of nodes can be get from [List available
            nodes](./list-available-nodes-308315715e0).
          examples:
            - aO9z
        encoding:
          type: string
          description: Encoding charset of the source archive file. By default it's `utf8`.
          examples:
            - gb18030
        password:
          type: string
          description: Optional paassword for `zip` or `7z` archive files.
          nullable: true
        file_mask:
          type: array
          items:
            type: string
          description: >-
            List of files to select. If presented, only files in this list, or
            contains any of it as prefix will be extracted.
          nullable: true
      x-apifox-orders:
        - src
        - dst
        - preferred_node_id
        - encoding
        - password
        - file_mask
      required:
        - src
        - dst
      x-apifox-ignore-properties: []
      x-apifox-folder: ''
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
          additionalProperties: *ref_2
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
