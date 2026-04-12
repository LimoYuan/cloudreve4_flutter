# FolderSummary

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
    FolderSummary:
      type: object
      properties:
        size:
          type: integer
          description: Total size of this folder.
          examples:
            - 8001
        files:
          type: integer
          description: Count of files under this folder (recursive).
          examples:
            - 3
        folders:
          type: integer
          description: Count of folders under this folder (recursive).
          examples:
            - 1
        completed:
          type: boolean
          description: >-
            Whether the size calculation is completed. If there're too many
            children under this folder, it may exceed the limit, in this case
            only subset of files are counted.
        calculated_at:
          type: string
          examples:
            - '2025-05-24T11:02:43.086056909+08:00'
          description: When the summary is calculated. It may be a cached result.
      required:
        - size
        - files
        - folders
        - completed
        - calculated_at
      x-apifox-orders:
        - size
        - files
        - folders
        - completed
        - calculated_at
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
