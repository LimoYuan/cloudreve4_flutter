# FileViewer

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
    FileViewer:
      type: object
      properties:
        viewers:
          type: array
          items:
            type: object
            properties:
              id:
                type: string
                description: ID of the file app.
              type:
                type: string
                description: Type of the file app.
              display_name:
                type: string
                examples:
                  - builtin
                enum:
                  - builtin
                  - wopi
                  - custom
                x-apifox-enum:
                  - value: builtin
                    name: ''
                    description: Cloudreve builtin app.
                  - value: wopi
                    name: ''
                    description: WOPI app.
                  - value: custom
                    name: ''
                    description: Custom iframe app.
                description: Display name of the app, can be i18next key.
              exts:
                type: array
                items:
                  type: string
                  examples:
                    - jpg
                    - jpeg
                description: Supported extensions.
              icon:
                type: string
                description: Icon URL.
              max_size:
                type: integer
                description: Max supported size in bytes of the source file.
              url:
                type: string
                description: URL of embed iframe apps.
                nullable: true
            required:
              - id
              - type
              - display_name
              - exts
              - icon
              - max_size
              - url
            x-apifox-orders:
              - id
              - type
              - display_name
              - exts
              - icon
              - max_size
              - url
      required:
        - viewers
      x-apifox-orders:
        - viewers
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
