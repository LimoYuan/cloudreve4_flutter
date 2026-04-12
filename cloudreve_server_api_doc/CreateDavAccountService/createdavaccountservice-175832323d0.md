# CreateDavAccountService

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
    CreateDavAccountService:
      type: object
      properties:
        uri:
          type: string
          description: >-
            [URI](https://docs.cloudreve.org/api/file-uri) of the relative root
            folder.
        name:
          type: string
          minLength: 1
          maxLength: 255
          description: Annotation of the account.
        readonly:
          type: boolean
          description: Whether this account is readonly.
          nullable: true
        proxy:
          type: boolean
          description: Whether reverse proxy is enabled for this account.
          nullable: true
        disable_sys_files:
          type: boolean
          description: >-
            Whehter system file with leading `.` should be blocked from being
            uploaded.
          nullable: true
      x-apifox-orders:
        - uri
        - name
        - readonly
        - proxy
        - disable_sys_files
      required:
        - uri
        - name
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
