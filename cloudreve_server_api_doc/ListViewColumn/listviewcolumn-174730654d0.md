# ListViewColumn

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
    ListViewColumn:
      type: object
      properties:
        type:
          type: integer
          minimum: 0
          description: >-
            Column type ID, predefined in
            [Column.tsx](https://github.com/cloudreve/frontend/blob/master/src/component/FileManager/Explorer/ListView/Column.tsx).
        width:
          type: integer
          description: >-
            Width of the column in px. Default width will be used for null
            value.
          nullable: true
        props:
          type: object
          properties:
            metadata_key:
              type: string
              description: Metadata key for metadata column (`type` equals `3`).
              nullable: true
          x-apifox-orders:
            - metadata_key
          nullable: true
      x-apifox-orders:
        - type
        - width
        - props
      required:
        - type
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
