# Get file info

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /file/info:
    get:
      summary: Get file info
      deprecated: false
      description: >-
        Get info of a given file by
        [URI](https://docs.cloudreve.org/api/file-uri) of file ID. Additional
        info is available if requested.
      tags:
        - File
        - 'Auth: JWT Optional'
      parameters:
        - name: uri
          in: query
          description: >-
            [URI](https://docs.cloudreve.org/api/file-uri) of the target file.
            If it's empty, `id` is required.
          required: false
          example: cloudreve://my/file.txt
          schema:
            type: string
        - name: id
          in: query
          description: >-
            ID of the file. If it's empty, `uri` is required. Getting file info
            by ID is only available to the owner of the file or administrators.
          required: false
          example: 98XDX8Sr
          schema:
            type: string
        - name: extended
          in: query
          description: Whether to get additional info about this file.
          required: false
          schema:
            type: boolean
        - name: folder_summary
          in: query
          description: >-
            For folders, whether to calculate the size of this folder. The
            result might be cached.
          required: false
          schema:
            type: boolean
        - name: X-Cr-Purchase-Ticket
          in: header
          description: >-
            Can be used to authenticate to paid share links with a anonymous
            identity. The ticket value can be obtained after an anonymous user
            purchase a paid share link.
          required: false
          example: 1f63aa26-edc0-40ce-950a-cb4d4323158e
          schema:
            type: string
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                x-apifox-refs:
                  01JXCAKJ4WGTK3J2XKGBGSCKQW: &ref_1
                    $ref: '#/components/schemas/Response'
                    x-apifox-overrides:
                      aggregated_error: null
                      data: &ref_0
                        type: object
                        properties: {}
                        x-apifox-orders: []
                        x-apifox-ignore-properties: []
                    required:
                      - data
                x-apifox-orders:
                  - 01JXCAKJ4WGTK3J2XKGBGSCKQW
                properties:
                  data: *ref_0
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
                  correlation_id:
                    type: string
                    description: >-
                      Correlation ID of the request. Only presented on failed
                      reqeust.
                    format: uuid
                    examples:
                      - b4351ecc-ee1a-4455-bc94-2c3dbcc58538
                    nullable: true
                required:
                  - data
                  - code
                x-apifox-ignore-properties:
                  - data
                  - code
                  - msg
                  - error
                  - correlation_id
              examples:
                '1':
                  summary: File with extended info
                  value:
                    code: 0
                    data:
                      type: 0
                      id: 98XDX8Sr
                      name: melk-abbey-library.jpg
                      permission: null
                      created_at: '2025-05-13T14:31:52+08:00'
                      updated_at: '2025-05-13T14:31:55+08:00'
                      size: 1682177
                      metadata:
                        exif:camera_make: NIKON
                        exif:camera_model: E5700
                        exif:des: ''
                        exif:exposure_bias: '0.000000'
                        exif:exposure_time: 1/7
                        exif:f: '2.800000'
                        exif:flash: '0'
                        exif:focal_length: '35'
                        exif:iso: '100'
                        exif:orientation: '1'
                        exif:software: E5700v1.1
                        exif:taken_at: '2003-09-22T14:13:44Z'
                        exif:x: '2560'
                        exif:y: '1920'
                      path: >-
                        cloudreve://my/Inspirations/test_folder/images/melk-abbey-library.jpg
                      capability: 39/9AQ==
                      owned: true
                      primary_entity: mxB6SM
                      extended_info:
                        storage_policy:
                          id: eVtl
                          name: OneDrive
                          type: onedrive
                          max_size: 0
                        storage_policy_inherited: false
                        storage_used: 1682177
                        entities:
                          - id: mxB6SM
                            size: 1682177
                            type: 0
                            created_at: '2025-05-13T14:31:52+08:00'
                            storage_policy:
                              id: eVtl
                              name: OneDrive
                              type: onedrive
                              max_size: 0
                            created_by:
                              id: bnUn
                              nickname: Luke Skywalker
                              avatar: file
                              created_at: '2023-08-06T19:21:59+08:00'
                        direct_links:
                          - id: xMxIa
                            url: >-
                              http://localhost:5173/f/xMxIa/melk-abbey-library.jpg
                            downloaded: 0
                            created_at: '2025-06-26T17:55:30+08:00'
                    msg: ''
                '2':
                  summary: Folder with summary
                  value:
                    code: 0
                    data:
                      type: 1
                      id: 98XDe8sr
                      name: Inspirations
                      permission: null
                      created_at: '2025-04-25T14:36:48+08:00'
                      updated_at: '2025-06-10T14:37:37+08:00'
                      size: 0
                      metadata: {}
                      path: cloudreve://my/Inspirations
                      capability: 39/9AQ==
                      owned: true
                      primary_entity: zOie
                      folder_summary:
                        size: 3231226838
                        files: 18
                        folders: 10
                        completed: true
                        calculated_at: '2025-06-10T15:07:46.796462+08:00'
                      extended_info:
                        storage_policy:
                          id: XDcb
                          name: Upyun
                          type: upyun
                          max_size: 0
                        storage_policy_inherited: false
                        storage_used: 0
                        shares:
                          - id: LJ6cM
                            name: Inspirations
                            visited: 2
                            unlocked: true
                            source_type: 1
                            owner:
                              id: bnUn
                              email: luke@skywalker.com
                              nickname: Luke Skywalker
                              avatar: file
                              created_at: '2023-08-06T19:21:59+08:00'
                              group:
                                id: z4u4
                                name: 管理员
                            created_at: '2025-04-25T14:36:52+08:00'
                            expired: false
                            url: http://localhost:5173/s/LJ6cM
                            permission_setting:
                              same_group: null
                              everyone: AQ==
                              other: null
                              anonymous: AQ==
                              group_explicit: {}
                              user_explicit: {}
                          - id: 6eEhd
                            name: Inspirations
                            visited: 4
                            price: 500
                            unlocked: true
                            source_type: 1
                            owner:
                              id: bnUn
                              email: luke@skywalker.com
                              nickname: Luke Skywalker
                              avatar: file
                              created_at: '2023-08-06T19:21:59+08:00'
                              group:
                                id: z4u4
                                name: 管理员
                            created_at: '2025-05-27T13:08:39+08:00'
                            expired: false
                            url: http://localhost:5173/s/6eEhd
                            permission_setting:
                              same_group: null
                              everyone: AQ==
                              other: null
                              anonymous: AQ==
                              group_explicit: {}
                              user_explicit: {}
                            share_view: true
                    msg: ''
          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: File
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-306769225-run
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
  securitySchemes: {}
servers: []
security: []

```
