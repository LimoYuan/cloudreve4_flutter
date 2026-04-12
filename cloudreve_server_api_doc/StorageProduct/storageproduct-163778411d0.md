# StorageProduct

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
    StorageProduct:
      type: object
      properties:
        id:
          type: string
          description: UUID of the storage SKU.
          title: ''
          examples:
            - ea602ab6-bd1e-40c3-b674-bef18fda7fa9
        name:
          type: string
          description: Display name of the storage SKU.
          examples:
            - Prenimum Storage
        size:
          type: integer
          description: Contained storage in bytes.
        time:
          type: integer
          description: Valid duration in seconds.
          examples:
            - 2592000
        price:
          type: integer
          description: Price in minimum currency unit.
          examples:
            - 1000
        chip:
          type: string
          description: Chip text.
          examples:
            - Recomended
          nullable: true
        points:
          type: integer
          description: >-
            Price in points. Empty value indicate paying with points is
            disabled.
          examples:
            - 10000
          nullable: true
      required:
        - id
        - name
        - size
        - time
        - price
      x-apifox-orders:
        - id
        - name
        - size
        - time
        - price
        - chip
        - points
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
