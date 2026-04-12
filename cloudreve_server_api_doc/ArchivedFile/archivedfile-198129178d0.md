# ArchivedFile

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
    ArchivedFile:
      type: object
      properties:
        name:
          type: string
          description: Path of the file in the archive.
          examples:
            - web/cmaps/Adobe-CNS1-UCS2.bcmap
        size:
          type: integer
          description: Size of the file uncompressed.
          examples:
            - 41193
        updated_at:
          type: string
          format: date-time
          examples:
            - '2024-12-31T16:26:12Z'
          description: Datetime when the file is modified.
        is_directory:
          type: boolean
          description: Whether this is a directory instead of a file.
          nullable: true
      required:
        - name
        - size
        - updated_at
      x-apifox-orders:
        - name
        - size
        - updated_at
        - is_directory
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
