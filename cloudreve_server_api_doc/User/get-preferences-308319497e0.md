# Get preferences

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /user/setting:
    get:
      summary: Get preferences
      deprecated: false
      description: ''
      tags:
        - User/Setting
        - 'Auth: JWT Required'
      parameters: []
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JXKKR699A0KTQH17K5Z0TR9D: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      data: &ref_0
                        type: object
                        properties:
                          group_expires:
                            type: string
                            format: date-time
                            description: >-
                              Datetime when the cuurent membership expired.
                              Empty value means no active membership. Only
                              presented in Pro edition.
                            nullable: true
                          open_id:
                            type: array
                            items:
                              type: object
                              properties:
                                provider:
                                  type: integer
                                  description: Provider type.
                                  enum:
                                    - 0
                                    - 1
                                    - 2
                                  x-apifox-enum:
                                    - value: 0
                                      name: ''
                                      description: Logto
                                    - value: 1
                                      name: ''
                                      description: Tencent QQ
                                    - value: 2
                                      name: ''
                                      description: OIDC
                                  examples:
                                    - 1
                                linked_at:
                                  type: string
                                  description: Datetime when the provider is linked.
                                  examples:
                                    - '2025-04-10T20:04:19+08:00'
                              x-apifox-orders:
                                - provider
                                - linked_at
                              required:
                                - provider
                                - linked_at
                              x-apifox-ignore-properties: []
                            description: >-
                              List of linked external identity providers. Only
                              presented in Pro edition.
                            nullable: true
                          version_retention_enabled:
                            type: boolean
                            description: Whether file version retention is enabled.
                          version_retention_ext:
                            type: array
                            items:
                              type: string
                            description: >-
                              List of file extensions enabling file version
                              retention. For null or empty list, all extensions
                              are enabled.
                            nullable: true
                          version_retention_max:
                            type: integer
                            description: >-
                              Max preserved version. For `0` or null, all
                              version will be preserved.
                            nullable: true
                          passwordless:
                            type: boolean
                            description: >-
                              Whether this account is passwordless (sign in via
                              3rd party identity provider).
                          two_fa_enabled:
                            type: boolean
                            description: Whether 2FA is enabled.
                          passkeys:
                            type: array
                            items:
                              $ref: '#/components/schemas/Passkey'
                            description: List of registered passkeys.
                            nullable: true
                          login_activity:
                            type: array
                            items:
                              type: object
                              properties:
                                created_at:
                                  type: string
                                  format: date-time
                                  examples:
                                    - '2025-06-12T09:24:19+08:00'
                                  description: When the login activity initiated.
                                ip:
                                  type: string
                                  examples:
                                    - '::1'
                                  description: IP address of the client.
                                browser:
                                  type: string
                                  examples:
                                    - Safari
                                  description: Name of the browser, parsed from user agent.
                                device:
                                  type: string
                                  examples:
                                    - Mac
                                  description: Name of the device, parsed from user agent.
                                os:
                                  type: string
                                  examples:
                                    - Mac OS X
                                  description: >-
                                    Name of the operating system, parsed from
                                    user agent.
                                login_with:
                                  type: string
                                  enum:
                                    - passkey
                                    - openid
                                  x-apifox-enum:
                                    - value: passkey
                                      name: ''
                                      description: ''
                                    - value: openid
                                      name: ''
                                      description: ''
                                  description: >-
                                    Method for sign in. Empty string means sign
                                    in using password.
                                open_id_provider:
                                  type: integer
                                  description: >-
                                    Type of the 3rd party identity provider.
                                    Only valid if `login_with` is `openid`.
                                success:
                                  type: boolean
                                  description: Whether this sign in succeed.
                                webdav:
                                  type: boolean
                                  description: >-
                                    Whether this request is from WebDAV client.
                                    Currently we only record failed sign in
                                    activities for WebDAV requests.
                              x-apifox-orders:
                                - created_at
                                - ip
                                - browser
                                - device
                                - os
                                - login_with
                                - open_id_provider
                                - success
                                - webdav
                              required:
                                - created_at
                                - ip
                                - browser
                                - device
                                - os
                                - login_with
                                - open_id_provider
                                - success
                                - webdav
                              x-apifox-ignore-properties: []
                            description: >-
                              List of recent login activities. Only presented in
                              Pro edition.
                            nullable: true
                          storage_packs:
                            type: array
                            items:
                              type: object
                              properties:
                                name:
                                  type: string
                                  examples:
                                    - Unlimited Storage
                                  description: Name of the storage pack.
                                active_since:
                                  type: string
                                  description: When the storage pack is activated.
                                  format: date-time
                                  examples:
                                    - '2025-03-20T17:52:20+08:00'
                                expire_at:
                                  type: string
                                  format: date-time
                                  examples:
                                    - '2026-03-20T17:52:20+08:00'
                                  description: When the storage pack will be expired.
                                size:
                                  type: integer
                                  examples:
                                    - 214748364800
                                  description: >-
                                    Extra capacity included in this pack, in
                                    bytes.
                              x-apifox-orders:
                                - name
                                - active_since
                                - expire_at
                                - size
                              required:
                                - name
                                - active_since
                                - expire_at
                                - size
                              x-apifox-ignore-properties: []
                            description: List of available extra storage packs
                          credit:
                            type: integer
                            examples:
                              - 24600
                            description: Available points balance.
                          disable_view_sync:
                            type: boolean
                            description: Whether explorer view setting sync is disabled.
                          share_links_in_profile:
                            type: string
                            enum:
                              - '[Empty string]'
                              - all_share
                              - hide_share
                            x-apifox-enum:
                              - value: '[Empty string]'
                                name: ''
                                description: Only public share links are visable.
                              - value: all_share
                                name: ''
                                description: All share links are visable.
                              - value: hide_share
                                name: ''
                                description: No share links are visable.
                            description: >-
                              What type of share link is visable in user's
                              profile.
                            nullable: true
                          oauth_grants:
                            type: array
                            items:
                              type: object
                              properties:
                                client_id:
                                  type: string
                                  format: uuid
                                  examples:
                                    - 393a1839-f52e-498e-9972-e77cc2241eee
                                  description: Client ID of the OAuth app.
                                client_name:
                                  type: string
                                  description: >-
                                    Display name of the OAuth app, can be
                                    i18next keys.
                                  examples:
                                    - application:oauth.desktop
                                client_logo:
                                  type: string
                                  description: Logo URL of the OAuth app.
                                  examples:
                                    - /static/img/cloudreve.svg
                                scopes:
                                  type: array
                                  items:
                                    type: string
                                    examples:
                                      - openid
                                      - offline_access
                                      - File.Read
                                  description: List of granted scopes.
                                last_used_at:
                                  type: string
                                  description: Datetime of when this grant is last used.
                                  examples:
                                    - '2026-01-28T20:37:02+08:00'
                                  nullable: true
                              x-apifox-orders:
                                - client_id
                                - client_name
                                - client_logo
                                - scopes
                                - last_used_at
                              required:
                                - client_id
                                - client_name
                                - client_logo
                                - scopes
                              x-apifox-ignore-properties: []
                            description: List of current authorized OAuth apps.
                            nullable: true
                        x-apifox-orders:
                          - group_expires
                          - open_id
                          - version_retention_enabled
                          - version_retention_ext
                          - version_retention_max
                          - passwordless
                          - two_fa_enabled
                          - passkeys
                          - login_activity
                          - storage_packs
                          - credit
                          - disable_view_sync
                          - share_links_in_profile
                          - oauth_grants
                        description: >-
                          Response content. In some error type, e.g. lock
                          conflicting errors, this field wil present details of
                          the error, e.g. who is locking the current file.
                        required:
                          - version_retention_enabled
                          - passwordless
                          - two_fa_enabled
                          - storage_packs
                          - credit
                          - disable_view_sync
                        x-apifox-ignore-properties: []
                        nullable: true
                      aggregated_error: null
                      code: null
                x-apifox-orders:
                  - 01JXKKR699A0KTQH17K5Z0TR9D
                properties:
                  data: *ref_0
                  msg:
                    type: string
                    description: Human readable error message (if any).
                  error:
                    type: string
                    description: Internal error message, only visable in debug mode.
                    nullable: true
                  correlation_id:
                    type: string
                    description: >-
                      Correlation ID of the request. Only presented on failed
                      reqeust.
                    format: uuid
                    examples:
                      - b4351ecc-ee1a-4455-bc94-2c3dbcc58538
                    nullable: true
                x-apifox-ignore-properties:
                  - data
                  - msg
                  - error
                  - correlation_id
              example:
                code: 0
                data:
                  open_id:
                    - provider: 0
                      linked_at: '2025-04-10T20:04:19+08:00'
                  version_retention_enabled: true
                  version_retention_max: 5
                  passwordless: false
                  two_fa_enabled: false
                  passkeys:
                    - id: oQK4yEBXSeONnJJLN+GMkA==
                      name: Chrome on Mac OS X
                      used_at: '2025-05-23T16:43:29+08:00'
                      created_at: '2025-05-23T16:43:10+08:00'
                  login_activity:
                    - created_at: '2025-06-12T09:24:19+08:00'
                      ip: '::1'
                      browser: Safari
                      device: Mac
                      os: Mac OS X
                      login_with: ''
                      open_id_provider: 0
                      success: true
                      webdav: false
                    - created_at: '2025-04-01T16:46:16+08:00'
                      ip: '::1'
                      browser: Chrome
                      device: Mac
                      os: Mac OS X
                      login_with: ''
                      open_id_provider: 0
                      success: false
                      webdav: false
                  storage_packs:
                    - name: Unlimited Storage
                      active_since: '2025-03-20T17:52:20+08:00'
                      expire_at: '2026-03-20T17:52:20+08:00'
                      size: 214748364800
                  credit: 24600
                  disable_view_sync: false
                msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: User/Setting
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-308319497-run
components:
  schemas:
    Response:
      type: object
      properties:
        data:
          type: string
        code:
          type: integer
          description: |-
            Response code.
            `0` - Success.
          default: 0
          examples:
            - 0
        msg:
          type: string
          description: Human readable error message (if any).
        error:
          type: string
          description: Internal error message, only visable in debug mode.
          nullable: true
        aggregated_error:
          type: object
          properties: {}
          x-apifox-orders:
            - 01JSRF01R97ZK0FE2NPYS810YS
          description: >-
            Map of multiple error in batch request. The key is the failed
            resource ID, it could be a file URI or a resource ID, the value is a
            `Response`.
          additionalProperties: *ref_1
          x-apifox-ignore-properties: []
          nullable: true
        correlation_id:
          type: string
          description: Correlation ID of the request. Only presented on failed reqeust.
          format: uuid
          examples:
            - b4351ecc-ee1a-4455-bc94-2c3dbcc58538
          nullable: true
      x-apifox-orders:
        - data
        - code
        - msg
        - error
        - aggregated_error
        - correlation_id
      required:
        - data
        - code
      x-apifox-ignore-properties: []
      x-apifox-folder: ''
    Passkey:
      type: object
      properties:
        id:
          type: string
          description: ID of the passkey.
          examples:
            - 7urNE/WTQSGqA06D0w+1Xw==
        name:
          type: string
          examples:
            - Chrome on Mac OS X
          description: Name of the passkey platform.
        used_at:
          type: string
          description: Datetime when the passkey is lastly used.
          format: date-time
          examples:
            - '2025-06-13T10:43:09.929001+08:00'
          nullable: true
        created_at:
          type: string
          format: date-time
          examples:
            - '2025-06-13T10:43:09.929001+08:00'
          description: Datetime when the passkey is created.
      x-apifox-orders:
        - id
        - name
        - used_at
        - created_at
      required:
        - id
        - name
        - created_at
      x-apifox-ignore-properties: []
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
