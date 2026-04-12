# CustomNavItem

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
    CustomNavItem:
      type: object
      properties:
        icon:
          type: string
          description: Iconify icon name.
          examples:
            - fluent:comment-multiple-24-regular
        name:
          type: string
          description: Display name.
          examples:
            - Get help
        url:
          type: string
          description: URL to reidrect to after user clicked this item.
      x-apifox-orders:
        - icon
        - name
        - url
      required:
        - icon
        - url
        - name
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
