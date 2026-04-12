# ArchiveWorkflowService

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths: {}
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
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
