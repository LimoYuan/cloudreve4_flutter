# CustomHTML

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
    CustomHTML:
      type: object
      properties:
        headless_footer:
          type: string
          description: Custom HTML to inject at the footer of landing page.
          nullable: true
        headless_bottom:
          type: string
          description: >-
            Custom HTML to inject at the bottom of landing page, stil within the
            white border.
          nullable: true
        sidebar_bottom:
          type: string
          description: Custom HTML to inject at the footer of the sidebar navigation.
          nullable: true
      x-apifox-orders:
        - headless_footer
        - headless_bottom
        - sidebar_bottom
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
