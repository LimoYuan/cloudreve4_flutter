# Create remote download

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /workflow/download:
    post:
      summary: Create remote download
      deprecated: false
      description: Create a remote download task.
      tags:
        - Workflow/Remote Download
        - 'Auth: JWT Required'
      parameters: []
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                dst:
                  type: string
                  description: URI of the destination folder.
                src_file:
                  type: string
                  description: >-
                    URI of the source torrent file. If this field is empty,
                    `src` is required.
                src:
                  type: array
                  items:
                    type: string
                  description: >-
                    List of URL to be download. Can be HTTP or magnet link,
                    depending on the configured downloader. If this field is
                    empty, `src_file` is required.
                preferred_node_id:
                  type: string
                  description: ID of preferred node to process
              required:
                - dst
              x-apifox-orders:
                - dst
                - src_file
                - src
                - preferred_node_id
              x-apifox-ignore-properties: []
            examples:
              '1':
                value:
                  src_file: cloudreve://my/big-buck-bunny_202112_archive.torrent
                  dst: cloudreve://my
                  preferred_node_id: m9uO
                summary: Download from existing torrent file
              '2':
                value:
                  dst: cloudreve://my
                  src:
                    - >-
                      https://github.com/cloudreve/Cloudreve/releases/download/4.0.0-beta.11/cloudreve_4.0.0-beta.11_darwin_amd64.tar.gz
                    - >-
                      https://github.com/cloudreve/Cloudreve/releases/download/4.0.0-beta.11/cloudreve_4.0.0-beta.11_darwin_arm64.tar.gz
                  preferred_node_id: m9uO
                summary: Download from URL
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JVP5YXDK0RJ74J61J3JZX4QQ: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      correlation_id: null
                      aggregated_error: null
                      error: null
                      data: &ref_0
                        type: array
                        items:
                          type: object
                          properties: {}
                          x-apifox-orders: []
                          x-apifox-ignore-properties: []
                    required:
                      - data
                x-apifox-orders:
                  - 01JVP5YXDK0RJ74J61J3JZX4QQ
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
                  - created_at: '2025-05-20T13:27:36.003255+08:00'
                    updated_at: '2025-05-20T13:27:36.003255+08:00'
                    id: agr0hj
                    status: queued
                    type: remote_download
                    summary:
                      props:
                        download: null
                        dst: cloudreve://my
                        failed: 0
                        src: ''
                        src_str: >-
                          https://github.com/cloudreve/Cloudreve/releases/download/4.0.0-beta.11/cloudreve_4.0.0-beta.11_darwin_amd64.tar.gz
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: Workflow/Remote Download
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-298183492-run
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
