# PaymentProvider

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
    PaymentProvider:
      type: object
      properties:
        id:
          type: string
          description: UUID of the payment provider.
          examples:
            - 8ff2cceb-b4e6-4fa8-a934-04900a2e8699
        type:
          type: string
          examples:
            - stripe
          enum:
            - stripe
            - alipay
            - weixin
            - points
            - custom
          x-apifox-enum:
            - value: stripe
              name: ''
              description: ''
            - value: alipay
              name: ''
              description: ''
            - value: weixin
              name: ''
              description: Wechat pay.
            - value: points
              name: ''
              description: Pay with credit.
            - value: custom
              name: ''
              description: Custom payment.
          description: Type of the payment provider.
        name:
          type: string
          title: Stripe
          description: Display name of the payment method.
      x-apifox-orders:
        - id
        - type
        - name
      required:
        - id
        - name
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
