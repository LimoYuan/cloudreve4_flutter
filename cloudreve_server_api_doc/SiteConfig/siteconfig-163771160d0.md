# SiteConfig

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
    CustomHTML:
      type: object
      properties:
        headless_footer:
          type: string
          description: Custom HTML to inject at the footer of landing page.
          nullable: true
        headless_bottom:
          type: string
          description: >-
            Custom HTML to inject at the bottom of landing page, stil within the
            white border.
          nullable: true
        sidebar_bottom:
          type: string
          description: Custom HTML to inject at the footer of the sidebar navigation.
          nullable: true
      x-apifox-orders:
        - headless_footer
        - headless_bottom
        - sidebar_bottom
      x-apifox-folder: ''
    CustomNavItem:
      type: object
      properties:
        icon:
          type: string
          description: Iconify icon name.
          examples:
            - fluent:comment-multiple-24-regular
        name:
          type: string
          description: Display name.
          examples:
            - Get help
        url:
          type: string
          description: URL to reidrect to after user clicked this item.
      x-apifox-orders:
        - icon
        - name
        - url
      required:
        - icon
        - url
        - name
      x-apifox-folder: ''
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
    GroupSKU:
      type: object
      properties:
        id:
          type: string
          description: UUID of the membership SKU.
        name:
          type: string
          description: Name of the membership SKU.
        time:
          type: integer
          description: Valid duration of the membership SKU.
        price:
          type: integer
          description: Price in minimum currency unit.
        chip:
          type: string
          description: Chip text.
          nullable: true
        points:
          type: integer
          description: >-
            Price in points. Empty value indicate paying with points is
            disabled.
          nullable: true
        des:
          type: array
          items:
            type: string
          description: Description texts.
      required:
        - id
        - name
        - time
        - price
        - des
      x-apifox-orders:
        - id
        - name
        - time
        - price
        - chip
        - points
        - des
      x-apifox-folder: ''
    StorageProduct:
      type: object
      properties:
        id:
          type: string
          description: UUID of the storage SKU.
          title: ''
          examples:
            - ea602ab6-bd1e-40c3-b674-bef18fda7fa9
        name:
          type: string
          description: Display name of the storage SKU.
          examples:
            - Prenimum Storage
        size:
          type: integer
          description: Contained storage in bytes.
        time:
          type: integer
          description: Valid duration in seconds.
          examples:
            - 2592000
        price:
          type: integer
          description: Price in minimum currency unit.
          examples:
            - 1000
        chip:
          type: string
          description: Chip text.
          examples:
            - Recomended
          nullable: true
        points:
          type: integer
          description: >-
            Price in points. Empty value indicate paying with points is
            disabled.
          examples:
            - 10000
          nullable: true
      required:
        - id
        - name
        - size
        - time
        - price
      x-apifox-orders:
        - id
        - name
        - size
        - time
        - price
        - chip
        - points
      x-apifox-folder: ''
    PaymentSetting:
      type: object
      properties:
        currency_code:
          type: string
          description: Currency code.
          examples:
            - USD
        currency_mark:
          type: string
          examples:
            - $
          description: Currency symbol.
        currency_unit:
          type: integer
          description: Minimum currency unit (e.g., 100 for dollars/cents)
          examples:
            - 100
        providers:
          type: array
          items:
            $ref: '#/components/schemas/PaymentProvider'
          description: List of available payment method.
      required:
        - currency_code
        - currency_mark
        - currency_unit
        - providers
      x-apifox-orders:
        - currency_code
        - currency_mark
        - currency_unit
        - providers
      x-apifox-folder: ''
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
    FileViewer:
      type: object
      properties:
        viewers:
          type: array
          items:
            type: object
            properties:
              id:
                type: string
                description: ID of the file app.
              type:
                type: string
                description: Type of the file app.
              display_name:
                type: string
                examples:
                  - builtin
                enum:
                  - builtin
                  - wopi
                  - custom
                x-apifox-enum:
                  - value: builtin
                    name: ''
                    description: Cloudreve builtin app.
                  - value: wopi
                    name: ''
                    description: WOPI app.
                  - value: custom
                    name: ''
                    description: Custom iframe app.
                description: Display name of the app, can be i18next key.
              exts:
                type: array
                items:
                  type: string
                  examples:
                    - jpg
                    - jpeg
                description: Supported extensions.
              icon:
                type: string
                description: Icon URL.
              max_size:
                type: integer
                description: Max supported size in bytes of the source file.
              url:
                type: string
                description: URL of embed iframe apps.
                nullable: true
            required:
              - id
              - type
              - display_name
              - exts
              - icon
              - max_size
              - url
            x-apifox-orders:
              - id
              - type
              - display_name
              - exts
              - icon
              - max_size
              - url
      required:
        - viewers
      x-apifox-orders:
        - viewers
      x-apifox-folder: ''
    Group:
      type: object
      properties:
        id:
          type: string
          examples:
            - 1AI8
          description: ID of the group.
        name:
          type: string
          description: Name of the group.
          examples:
            - Admin
        permission:
          type: string
          description: >-
            Permission boolset of the group. Refer to
            [Boolset](https://docs.cloudreve.org/api/boolset) for how to read
            it.
          examples:
            - /f8B
        direct_link_batch_size:
          type: integer
          examples:
            - 10
          description: >-
            The maximum number of files allowed for users to obtain direct links
            in a single batch, fill in 0 means no batch generation of direct
            links is allowed.
        trash_retention:
          type: integer
          description: >-
            The retention time in seconds of files in the trash bin, files will
            be permanently deleted after the expiration time. Changing this
            setting will not affect files already in the trash bin.
          examples:
            - 864000
      required:
        - id
        - name
        - permission
        - direct_link_batch_size
        - trash_retention
      x-apifox-orders:
        - id
        - name
        - permission
        - direct_link_batch_size
        - trash_retention
      x-apifox-folder: ''
    User:
      type: object
      properties:
        id:
          type: string
          description: ID of the user.
          examples:
            - 6JIo
        nickname:
          type: string
          description: Display name of the user.
          examples:
            - Johnny Zhang
          nullable: true
        created_at:
          type: string
          description: >-
            Time at which the user is created. For anonymous session, this value
            is invalid.
          format: date-time
          examples:
            - '2023-08-06T19:21:59+08:00'
        anonymous:
          type: boolean
          description: Indicating whether the session is anonymous.
          nullable: true
        group:
          $ref: '#/components/schemas/Group'
        email:
          type: string
          description: Email of the user. For anonymous session, it is empty.
          nullable: true
        status:
          type: string
          enum:
            - active
            - inactive
            - manual_banned
            - sys_banned
          x-apifox-enum:
            - value: active
              name: ''
              description: ''
            - value: inactive
              name: ''
              description: ''
            - value: manual_banned
              name: ''
              description: ''
            - value: sys_banned
              name: ''
              description: ''
          nullable: true
        avatar:
          type: string
          description: >-
            Source type of the profile picture. Empty value indicates no profile
            picture.
          enum:
            - file
            - gravatar
          x-apifox-enum:
            - value: file
              name: ''
              description: Uploaded avatar
            - value: gravatar
              name: ''
              description: Use Gravatar.
          examples:
            - file
          nullable: true
        preferred_theme:
          type: string
          description: Primary color of preferred theme.
          examples:
            - '#131313'
          nullable: true
        credit:
          type: integer
          description: Credit balance.
          nullable: true
        language:
          type: string
          examples:
            - en-US
          description: Primary language.
        disable_view_sync:
          type: string
          description: Whether syncing view setting to server is enabled.
          nullable: true
        share_links_in_profile:
          type: string
          description: What type of share link is visable in user's profile.
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
          nullable: true
      required:
        - id
        - nickname
        - created_at
        - anonymous
        - group
        - avatar
        - preferred_theme
        - credit
        - language
      x-apifox-orders:
        - id
        - email
        - nickname
        - created_at
        - anonymous
        - group
        - status
        - avatar
        - preferred_theme
        - credit
        - language
        - disable_view_sync
        - share_links_in_profile
      x-apifox-folder: ''
    SiteConfig:
      type: object
      properties:
        instance_id:
          type: string
          description: Unique UUID of the Cloudreve instance.
          nullable: true
        title:
          type: string
          description: Name of the site.
          nullable: true
        login_captcha:
          type: boolean
          description: Whether CPATCHA is required for sign in request.
          nullable: true
        reg_captcha:
          type: boolean
          description: Whether CPATCHA is required for sign up request.
          nullable: true
        forget_captcha:
          type: boolean
          description: Whether CPATCHA is required for resettinig password request.
          nullable: true
        themes:
          type: string
          description: JSON encoded theme options.
          examples:
            - >-
              {"#3f51b5":{"light":{"palette":{"primary":{"main":"#3f51b5"},"secondary":{"main":"#f50057"}}},"dark":{"palette":{"primary":{"main":"#9fa8da"},"secondary":{"main":"#ff4081"}}}},"#722946":{"light":{"palette":{"primary":{"main":"#722946"},"secondary":{"main":"#f50057"}}},"dark":{"palette":{"primary":{"main":"#e17fa5"},"secondary":{"main":"#f50057"}}}},"#1976d2":{"light":{"palette":{"primary":{"main":"#1976d2","light":"#42a5f5","dark":"#1565c0"},"secondary":{"main":"#9c27b0","light":"#ba68c8","dark":"#7b1fa2"}}},"dark":{"palette":{"primary":{"main":"#90caf9","light":"#e3f2fd","dark":"#42a5f5"},"secondary":{"main":"#ce93d8","light":"#f3e5f5","dark":"#ab47bc"}}}}}
          nullable: true
        default_theme:
          type: string
          description: Primary color of the global default theme.
          nullable: true
        authn:
          type: boolean
          description: Whether Passkey is enabled.
          nullable: true
        user:
          anyOf:
            - $ref: '#/components/schemas/User'
            - type: 'null'
          description: Current logined user.
        captcha_ReCaptchaKey:
          type: string
          description: Site key of Google reCaptcha (if configured).
          nullable: true
        site_notice:
          type: string
          description: Global site announcement (if configured).
          nullable: true
        captcha_type:
          type: string
          description: Provider type of the captcha.
          enum:
            - normal
            - recaptcha
            - turnstile
          x-apifox-enum:
            - value: normal
              name: ''
              description: ''
            - value: recaptcha
              name: ''
              description: ''
            - value: turnstile
              name: ''
              description: ''
          nullable: true
        turnstile_site_id:
          type: string
          description: Cloudflare Turnstile Site ID (if configured).
          nullable: true
        register_enabled:
          type: boolean
          description: Whether this site allowing new user sign up.
          nullable: true
        qq_enabled:
          type: boolean
          description: Whether sign in via Tencent QQ is enabled.
          nullable: true
        sso_enabled:
          type: boolean
          description: Whether sign in via Logto is enabled.
          nullable: true
        sso_display_name:
          type: string
          description: Display name of the Logto sign method, may be i18next key.
          examples:
            - vas.sso
          nullable: true
        logo:
          type: string
          description: URL of the logo image for light mode.
          examples:
            - /static/img/logo.svg
          nullable: true
        logo_light:
          type: string
          description: URL of the logo image for dark mode.
          examples:
            - /static/img/logo_light.svg
          nullable: true
        tos_url:
          type: string
          description: URL of the document for term of serivce.
          nullable: true
        privacy_policy_url:
          type: string
          description: URL of the document for privacy policy.
          nullable: true
        icons:
          type: string
          examples:
            - >-
              [{"exts":["mp3","flac","ape","wav","acc","ogg","m4a"],"icon":"audio","color":"#651fff"},{"exts":["mp4","flv","avi","wmv","mkv","rm","rmvb","mov","ogv","m3u8"],"icon":"video","color":"#d50000"},{"exts":["bmp","iff","png","gif","jpg","jpeg","psd","svg","webp","heif","heic","tiff","avif"],"icon":"image","color":"#d32f2f"},{"exts":["3fr","ari","arw","bay","braw","crw","cr2","cr3","cap","dcs","dcr","dng","drf","eip","erf","fff","gpr","iiq","k25","kdc","mdc","mef","mos","mrw","nef","nrw","obm","orf","pef","ptx","pxn","r3d","raf","raw","rwl","rw2","rwz","sr2","srf","srw","tif","x3f"],"icon":"raw","color":"#d32f2f"},{"exts":["pdf"],"color":"#f44336","icon":"pdf"},{"exts":["doc","docx"],"color":"#538ce5","icon":"word"},{"exts":["ppt","pptx"],"color":"#EF633F","icon":"ppt"},{"exts":["xls","xlsx","csv"],"color":"#4caf50","icon":"excel"},{"exts":["txt","html"],"color":"#607d8b","icon":"text"},{"exts":["torrent"],"color":"#5c6bc0","icon":"torrent"},{"exts":["zip","gz","xz","tar","rar","7z","bz2","z"],"color":"#f9a825","icon":"zip"},{"exts":["exe","msi"],"color":"#1a237e","icon":"exe"},{"exts":["apk"],"color":"#8bc34a","icon":"android"},{"exts":["go"],"color":"#16b3da","icon":"go"},{"exts":["py"],"color":"#3776ab","icon":"python"},{"exts":["c"],"color":"#a4c639","icon":"c"},{"exts":["cpp"],"color":"#f34b7d","icon":"cpp"},{"exts":["js","jsx"],"color":"#f4d003","icon":"js"},{"exts":["epub"],"color":"#81b315","icon":"book"},{"exts":["rs"],"color":"#000","color_dark":"#fff","icon":"rust"},{"exts":["drawio"],"color":"#F08705","icon":"flowchart"},{"exts":["dwb"],"color":"#F08705","icon":"whiteboard"},{"exts":["md"],"color":"#383838","color_dark":"#cbcbcb","icon":"markdown"},{"exts":["so"],"img":"https://cdn.sstatic.net/Img/teams/teams-illo-free-sidebar-promo.svg"},{"img":"https://dscache.tencent-cloud.cn/upload//%E5%AE%98%E7%BD%91%E4%BE%A7%E8%BE%B9_%E9%99%90%E6%97%B6%E7%A7%92%E6%9D%80-de2107c547c0ee4e372a829c800caaa540abcda8.png","exts":["123"]},{"img":"https://www.nekodrive.net/images/client_icons/filetypes_icons/asp.svg","exts":["asp"]},{"img":"https://cdn.sstatic.net/Img/teams/teams-promo.svg?v=e507948b81bf","exts":["aspx"]}]
          description: JSON encoded file icons map.
          nullable: true
        emoji_preset:
          type: string
          description: JSON encoded emoji preset for customizing file icons.
          examples:
            - '{"😀":["😀"]}'
          nullable: true
        point_enabled:
          type: boolean
          description: Whether credit(points) feature is enabled.
          nullable: true
        share_point_gain_rate:
          type: number
          examples:
            - 80
          minimum: 1
          multipleOf: 1
          maximum: 100
          description: Percentage of share owner's commission rate.
          nullable: true
        map_provider:
          type: string
          description: Map provider.
          enum:
            - google
            - openstreetmap
            - mapbox
          x-apifox-enum:
            - value: google
              name: ''
              description: ''
            - value: openstreetmap
              name: ''
              description: ''
            - value: mapbox
              name: ''
              description: ''
          nullable: true
        google_map_tile_type:
          type: string
          enum:
            - terrain
            - satellite
            - normal
          x-apifox-enum:
            - value: terrain
              name: ''
              description: ''
            - value: satellite
              name: ''
              description: ''
            - value: normal
              name: ''
              description: ''
          description: Google map tile type.
          nullable: true
        file_viewers:
          type: array
          items:
            anyOf:
              - $ref: '#/components/schemas/FileViewer'
              - type: 'null'
          description: List of file app groups.
          nullable: true
        max_batch_size:
          type: number
          description: The maximum number of files in a batch operation.
          nullable: true
        app_promotion:
          type: boolean
          description: Whether to show promotion page for iOS app.
          nullable: true
        app_feedback:
          type: string
          description: Feedback URL for mobile APP.
          nullable: true
        app_forum:
          type: string
          description: Forum URL for mobile APP.
          nullable: true
        payment:
          anyOf:
            - $ref: '#/components/schemas/PaymentSetting'
            - type: 'null'
          description: Payment settings.
        anonymous_purchase:
          type: boolean
          description: >-
            Whether to allow non-logged-in users to purchase share links
            directly.
          nullable: true
        point_price:
          type: number
          description: >-
            Price for recharging credit points with money (in minimum currency
            unit). Fill 0 to disable credit recharge.
          examples:
            - 10
          nullable: true
        shop_nav_enabled:
          type: boolean
          description: Whether to display 'Shop' items in the sidebar navigation.
          nullable: true
        storage_products:
          type: array
          items:
            anyOf:
              - $ref: '#/components/schemas/StorageProduct'
              - type: 'null'
          description: Available storage product SKUs.
          nullable: true
        group_skus:
          type: array
          items:
            anyOf:
              - $ref: '#/components/schemas/GroupSKU'
              - type: 'null'
          description: Available membership SKUs.
          nullable: true
        thumbnail_width:
          type: number
          description: Max width of file thumbnails.
          nullable: true
        thumbnail_height:
          type: number
          description: Max height of file thumbnails.
          nullable: true
        oidc_enabled:
          type: boolean
          description: Whether sign in via OIDC is enabled.
          nullable: true
        oidc_display_name:
          type: string
          description: Display name of the OIDC sign method, may be i18next key.
          nullable: true
        captcha_cap_instance_url:
          type: string
          description: Instance URL for Cap V2.
        captcha_cap_site_key:
          type: string
          description: Site key for Cap V2.
        custom_props:
          type: array
          items:
            $ref: '#/components/schemas/CustomProps'
          description: Available custom file propertity options.
          nullable: true
        custom_nav_items:
          type: array
          items:
            description: Custom items for the sidebar navigation.
            type: object
            x-apifox-refs:
              01K06VAKAQ46KNQ8E46KCVE736:
                $ref: '#/components/schemas/CustomNavItem'
                x-apifox-overrides: {}
            properties:
              '':
                type: string
            required:
              - ''
            x-apifox-orders:
              - 01K06VAKAQ46KNQ8E46KCVE736
              - ''
          nullable: true
        custom_html:
          anyOf:
            - $ref: '#/components/schemas/CustomHTML'
            - type: 'null'
          description: Custom HTML contents injected at predefined locations.
        abuse_report_captcha:
          type: boolean
          description: >-
            Whether CPATCHA is required for submiting abuse report. Only
            available in Pro.
          nullable: true
        sso_icon:
          type: string
          description: Iconify icon name or image URL of custom icon for Logto.
          nullable: true
        oidc_icon:
          type: string
          description: Iconify icon name or image URL of custom icon for OIDC.
          nullable: true
        mapbox_ak:
          type: string
          description: Access token for Mapbox to display embeded maps.
          nullable: true
        thumb_exts:
          type: array
          items:
            type: string
          description: List of file extensions supported for thumbnails.
          nullable: true
        desktop_app_promotion:
          type: boolean
          description: Whether to show promotion page for desktop app.
          nullable: true
        show_encryption_status:
          type: boolean
          description: Show file encryption status in file details panel.
          nullable: true
      additionalProperties: false
      definitions:
        User:
          $ref: ./user.ts#/definitions/User
        ViewerGroup:
          $ref: ./explorer.ts#/definitions/ViewerGroup
        PaymentSetting:
          $ref: ./vas.ts#/definitions/PaymentSetting
        StorageProduct:
          $ref: ./vas.ts#/definitions/StorageProduct
        GroupSku:
          $ref: ./vas.ts#/definitions/GroupSku
      x-apifox-orders:
        - instance_id
        - title
        - login_captcha
        - reg_captcha
        - forget_captcha
        - abuse_report_captcha
        - themes
        - default_theme
        - authn
        - user
        - captcha_ReCaptchaKey
        - captcha_cap_instance_url
        - captcha_cap_site_key
        - site_notice
        - captcha_type
        - turnstile_site_id
        - register_enabled
        - qq_enabled
        - sso_enabled
        - sso_display_name
        - sso_icon
        - oidc_enabled
        - oidc_display_name
        - oidc_icon
        - logo
        - logo_light
        - tos_url
        - privacy_policy_url
        - icons
        - emoji_preset
        - point_enabled
        - share_point_gain_rate
        - map_provider
        - google_map_tile_type
        - file_viewers
        - max_batch_size
        - app_promotion
        - app_feedback
        - app_forum
        - desktop_app_promotion
        - payment
        - anonymous_purchase
        - point_price
        - shop_nav_enabled
        - storage_products
        - group_skus
        - thumbnail_width
        - thumbnail_height
        - custom_props
        - show_encryption_status
        - custom_nav_items
        - custom_html
        - mapbox_ak
        - thumb_exts
      required:
        - captcha_cap_site_key
        - captcha_cap_instance_url
      x-apifox-folder: ''
  securitySchemes: {}
servers: []
security: []

```
