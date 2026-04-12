# TaskListResponse

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
    TaskResponse:
      type: object
      properties:
        created_at:
          type: string
          format: date-time
          examples:
            - '2025-04-22T17:13:06+08:00'
        updated_at:
          type: string
          format: date-time
          examples:
            - '2025-04-22T17:13:06+08:00'
        id:
          type: string
          examples:
            - LO5GtW
          description: ID of the tasks.
        status:
          type: string
          description: Status of the task
          examples:
            - completed
          enum:
            - queued
            - processing
            - suspending
            - error
            - canceled
            - completed
          x-apifox-enum:
            - value: queued
              name: ''
              description: Tasks is queued and wait to be processed.
            - value: processing
              name: ''
              description: Task is being processed.
            - value: suspending
              name: ''
              description: >-
                Task is suspended for async operations, it will be resumed
                later.
            - value: error
              name: ''
              description: Task is failed with error.
            - value: canceled
              name: ''
              description: Task is canceled
            - value: completed
              name: ''
              description: Task is completed.
        type:
          type: string
          examples:
            - extract_archive
          enum:
            - media_meta
            - entity_recycle_routine
            - explicit_entity_recycle
            - upload_sentinel_check
            - create_archive
            - extract_archive
            - relocate
            - remote_download
            - import
          x-apifox-enum:
            - value: media_meta
              name: ''
              description: Extract media metadata.
            - value: entity_recycle_routine
              name: ''
              description: Stale entities recycle routine.
            - value: explicit_entity_recycle
              name: ''
              description: Explicitly entity recycle.
            - value: upload_sentinel_check
              name: ''
              description: Upload sentinel check.
            - value: create_archive
              name: ''
              description: Create archive file.
            - value: extract_archive
              name: ''
              description: Extract archive file
            - value: relocate
              name: ''
              description: Relocate file storage policy.
            - value: remote_download
              name: ''
              description: Remote download.
            - value: import
              name: ''
              description: Import files from external storage.
        summary:
          type: object
          properties:
            phase:
              type: string
              examples:
                - finish
              description: >-
                Current phase(sub-step) of the task. The possible value differs
                from different task types.
            props:
              type: object
              properties: {}
              x-apifox-orders: []
              additionalProperties:
                type: string
              description: Key-value map of task specific props.
          x-apifox-orders:
            - phase
            - props
          required:
            - phase
            - props
          nullable: true
        duration:
          type: integer
          description: Tasl executed duration in milliseconds.
          examples:
            - 1908
          nullable: true
        resume_time:
          type: integer
          description: Time stamp of the next expected resume time for suspended task.
          examples:
            - 1745313204
          nullable: true
        error:
          type: string
          description: Error message (if any).
          nullable: true
        error_history:
          type: array
          items:
            type: string
          description: List of error messages in previous retries (if any).
          nullable: true
        retry_count:
          type: integer
          description: Retry count.
          nullable: true
        node:
          $ref: '#/components/schemas/Node'
          description: Node of which this tasks is distributed onto.
      required:
        - created_at
        - updated_at
        - id
        - status
        - type
        - node
      x-apifox-orders:
        - created_at
        - updated_at
        - id
        - status
        - type
        - summary
        - duration
        - resume_time
        - error
        - error_history
        - retry_count
        - node
      x-apifox-folder: ''
    Node:
      type: object
      properties:
        id:
          type: string
          description: ID of the node.
          examples:
            - xmhb
        name:
          type: string
          examples:
            - Master
          description: Name of the node.
        type:
          type: string
          enum:
            - master
            - slave
          x-apifox-enum:
            - value: master
              name: ''
              description: Master node.
            - value: slave
              name: ''
              description: Slave node.
          description: Type of the node.
        capabilities:
          type: string
          description: >-
            [Boolset](https://docs.cloudreve.org/en/api/boolset) encoded node
            capabilities.
      required:
        - id
        - name
        - type
        - capabilities
      x-apifox-orders:
        - id
        - name
        - type
        - capabilities
      x-apifox-folder: ''
    TaskListResponse:
      type: object
      properties:
        pagination:
          type: object
          x-apifox-refs:
            01JV48MWWY7AGJC0VN9YN40MVY:
              $ref: '#/components/schemas/PaginationResults'
              x-apifox-overrides:
                page: null
                total_items: null
          x-apifox-orders:
            - 01JV48MWWY7AGJC0VN9YN40MVY
          properties: {}
        tasks:
          type: array
          items:
            $ref: '#/components/schemas/TaskResponse'
      x-apifox-orders:
        - pagination
        - tasks
      required:
        - pagination
        - tasks
      x-apifox-folder: ''
    PaginationResults:
      type: object
      properties:
        page:
          type: integer
          examples:
            - 1
          description: Current page starting from `0`, only applied to offset pagination.
        page_size:
          type: integer
          examples:
            - 50
          description: Maximum items included in one page.
        total_items:
          type: integer
          examples:
            - 5664
          description: Total count of items, only applied to offset pagination.
        next_token:
          type: string
          examples:
            - eyJpZCI6Inh4cUR1QSJ9
          description: Token used to request the next page in cursor pagination.
        is_cursor:
          type: boolean
          description: Whether the response is using cursor pagination.
      x-apifox-orders:
        - page
        - page_size
        - total_items
        - next_token
        - is_cursor
      required:
        - page
        - page_size
        - next_token
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
