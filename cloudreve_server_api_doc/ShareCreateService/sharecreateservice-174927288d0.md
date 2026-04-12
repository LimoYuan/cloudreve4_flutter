# ShareCreateService

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
    ShareCreateService:
      type: object
      properties:
        permissions:
          $ref: '#/components/schemas/PermissionSetting'
          description: Required in Pro edition. Permission setting of the share link.
        uri:
          type: string
          description: >-
            [URI](https://docs.cloudreve.org/api/file-uri) of the shared file or
            folder.
        is_private:
          type: boolean
          description: >-
            Whether this share link is protected with addition password and
            hidden in user's profile.
          nullable: true
        share_view:
          type: boolean
          description: >-
            Whether view settings within the shared folder is exposed to other
            user. If `uri` points to a file, this field is appliable.
          nullable: true
        expire:
          type: integer
          description: >-
            Number of seconds after which the link will be expired. Empty value
            means permanent link.
          examples:
            - 864000
          nullable: true
        price:
          type: integer
          examples:
            - 20
          description: Only in Pro edition. Set the price (in points) to pay for this link.
          nullable: true
        password:
          type: string
          maxLength: 32
          pattern: ^[a-zA-Z0-9]+
          examples:
            - '123123'
          description: Set custom share link password if `is_private` is `true`.
          nullable: true
        show_readme:
          type: boolean
          description: >-
            Whether client UI should automatically render and shoe `README.md`
            file. Only for share folder.
          nullable: true
      required:
        - permissions
        - uri
      x-apifox-orders:
        - permissions
        - uri
        - is_private
        - share_view
        - expire
        - price
        - password
        - show_readme
      x-apifox-folder: ''
    PermissionSetting:
      type: object
      properties:
        same_group:
          type: string
          description: Permission for users under the same group as the file owner.
        everyone:
          type: string
          description: Permission for everyone else.
          examples:
            - AQ==
        other:
          type: string
          description: Permission for users under the different groups as the file owner.
        anonymous:
          type: string
          description: Permission for anonymous users.
          examples:
            - AQ==
        group_explicit:
          type: object
          properties: {}
          x-apifox-orders: []
          description: Map of explicit permission setting from group ID to boolset.
          additionalProperties:
            type: string
            examples:
              - AQ==
        user_explicit:
          type: object
          properties: {}
          x-apifox-orders: []
          additionalProperties:
            type: string
            examples:
              - AQ==
          description: Map of explicit permission setting from user ID to boolset.
      x-apifox-orders:
        - user_explicit
        - group_explicit
        - same_group
        - other
        - anonymous
        - everyone
      description: >-
        Permission setting for different groups/users. Encoded as
        [boolset](https://docs.cloudreve.org/api/boolset).
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
