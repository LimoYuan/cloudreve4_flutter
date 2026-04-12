# CustomProps

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
    CustomProps:
      type: object
      properties:
        id:
          type: string
          examples:
            - department
          description: >-
            ID of the custom props. You can get the corresponding metadata key
            by appending `props:` prefix.
        name:
          type: string
          examples:
            - Department
          description: Display name of the propertity.
        type:
          type: string
          enum:
            - text
            - number
            - boolean
            - select
            - multi_select
            - link
            - rating
          x-apifox-enum:
            - value: text
              name: ''
              description: ''
            - value: number
              name: ''
              description: ''
            - value: boolean
              name: ''
              description: ''
            - value: select
              name: ''
              description: ''
            - value: multi_select
              name: ''
              description: ''
            - value: link
              name: ''
              description: ''
            - value: rating
              name: ''
              description: ''
          examples:
            - rating
          description: Type of the input component.
        max:
          type: string
          description: >-
            Maximum length for text fields, maximum value for number/rating
            field.
          nullable: true
        min:
          type: string
          description: Minimum length for text fields, minimum value for number field.
          nullable: true
        default:
          type: string
          description: Default value in string.
          nullable: true
        options:
          type: array
          items:
            type: string
          description: Options for selection component.
          nullable: true
        icon:
          type: string
          description: Optional icon name from Iconify.
          examples:
            - fluent:organization-24-filled
      x-apifox-orders:
        - id
        - name
        - type
        - max
        - min
        - default
        - options
        - icon
      required:
        - id
        - type
        - name
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
