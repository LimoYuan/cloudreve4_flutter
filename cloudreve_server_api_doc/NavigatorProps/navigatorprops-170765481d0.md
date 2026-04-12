# NavigatorProps

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
    NavigatorProps:
      type: object
      properties:
        capability:
          type: string
          description: >-
            [Boolset](https://docs.cloudreve.org/api/boolset) encoded set of
            capabilities supported in this filesystem.

            Capability definition can be found at [File System
            Capabilities](https://docs.cloudreve.org/api/boolset#file-system-capability)
          examples:
            - 39/9
        max_page_size:
          type: integer
          description: Max supported page size.
          examples:
            - 2000
        order_by_options:
          type: array
          items:
            type: string
            examples:
              - name
              - size
              - updated_at
              - created_at
          description: List of supported `order by` fields.
        order_direction_options:
          type: array
          items:
            type: string
            examples:
              - asc
              - desc
          description: List of supported order direction.
      x-apifox-orders:
        - capability
        - max_page_size
        - order_by_options
        - order_direction_options
      required:
        - capability
        - max_page_size
        - order_by_options
        - order_direction_options
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
