# ExplorerView

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
    ListViewColumn:
      type: object
      properties:
        type:
          type: integer
          minimum: 0
          description: >-
            Column type ID, predefined in
            [Column.tsx](https://github.com/cloudreve/frontend/blob/master/src/component/FileManager/Explorer/ListView/Column.tsx).
        width:
          type: integer
          description: >-
            Width of the column in px. Default width will be used for null
            value.
          nullable: true
        props:
          type: object
          properties:
            metadata_key:
              type: string
              description: Metadata key for metadata column (`type` equals `3`).
              nullable: true
          x-apifox-orders:
            - metadata_key
          nullable: true
      x-apifox-orders:
        - type
        - width
        - props
      required:
        - type
      x-apifox-folder: ''
    ExplorerView:
      title: ExplorerView
      type: object
      properties:
        page_size:
          type: integer
          description: The number of items to display per page.
          minimum: 50
        order:
          type: string
          description: The field to order the results by.
          maxLength: 255
        order_direction:
          type: string
          description: The direction to order the results.
          enum:
            - asc
            - desc
        view:
          type: string
          description: The view mode for the explorer.
          enum:
            - list
            - grid
            - gallery
          x-apifox-enum:
            - value: list
              name: ''
              description: List view.
            - value: grid
              name: ''
              description: Grid view.
            - value: gallery
              name: ''
              description: Gallery view.
        thumbnail:
          type: boolean
          description: Whether to display thumbnails in grid view.
        gallery_width:
          type: integer
          description: The width of a single item in gallery view.
          minimum: 50
          maximum: 500
        columns:
          type: array
          description: The columns to display in the list view.
          maxItems: 1000
          items:
            $ref: '#/components/schemas/ListViewColumn'
      required:
        - page_size
      definitions:
        ListViewColumn:
          type: object
          description: >-
            Represents a column in the list view. The schema for this object
            would need to be defined based on the ListViewColumn Go struct.
          properties: {}
          additionalProperties: true
          x-apifox-orders: []
      x-apifox-orders:
        - page_size
        - order
        - order_direction
        - view
        - thumbnail
        - gallery_width
        - columns
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
