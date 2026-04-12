# Events stream

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /file/events:
    get:
      summary: Events stream
      deprecated: false
      description: >-
        This is a SSE (Server-side events) endpoint to get notified when file
        modification happens.
      tags:
        - File
        - 'Auth: JWT Required'
      parameters:
        - name: uri
          in: query
          description: URI of the folder to watch.
          required: false
          example: cloudreve://my
          schema:
            type: string
        - name: X-Cr-Client-Id
          in: header
          description: >-
            Unique ID of the client. Can be used to resume subscription or omit
            self-generated events.
          required: false
          example: a220d681-6146-4c46-baed-c934e9deb8bc
          schema:
            type: string
      responses:
        '200':
          description: ''
          content:
            text/event-stream:
              schema:
                type: object
                properties: {}
              example: >+
                data: 

                event: resumed


                data:
                [{"type":"modify","file_id":"lpR3d","from":"/folder/myfile.txt","to":""}]

                event: event


                ...


                data: 

                event: reconnect-required

          headers: {}
          x-apifox-name: Success
      security: []
      x-apifox-folder: File
      x-apifox-status: released
      x-run-in-apifox: https://app.apifox.com/web/project/6271409/apis/api-413501323-run
components:
  schemas: {}
  securitySchemes: {}
servers: []
security: []

```
