# DavAccount

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
    DavAccount:
      type: object
      properties:
        id:
          type: string
          examples:
            - WNuO
          description: ID of the WebDAV account.
        created_at:
          type: string
          format: date-time
          examples:
            - '2023-12-04T18:51:42+08:00'
          description: Datetime when the account is created.
        name:
          type: string
          examples:
            - My account
          description: Annotation of this account.
        uri:
          type: string
          examples:
            - cloudreve://my
          description: '[URI](https://docs.cloudreve.org/api/file-uri) of the root folder.'
        password:
          type: string
          examples:
            - f6zxgh7j4yo3vuvtdpcxd6na89efvmpo
          description: Generated password of this account.
        options:
          type: string
          description: >-
            [Boolset](https://docs.cloudreve.org/api/boolset) encoded account
            options.
      x-apifox-orders:
        - id
        - created_at
        - name
        - uri
        - password
        - options
      required:
        - id
        - created_at
        - name
        - uri
        - password
        - options
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
