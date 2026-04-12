# PinFileService

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
    PinFileService:
      type: object
      properties:
        uri:
          type: string
          description: >-
            [URI](https://docs.cloudreve.org/api/file-uri) of the target folder
            or search view.
          examples:
            - cloudreve://my/Inspirations?name=jpg&case_folding=
        name:
          type: string
          description: >-
            Option display name of the sidebar item. Default name will be used
            if this value is null.
          examples:
            - My images
          nullable: true
      x-apifox-orders:
        - uri
        - name
      required:
        - uri
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
