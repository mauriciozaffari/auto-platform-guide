<!--
Generated: 2026-10-23 02:16:30 UTC
-->

<h1 id="documenting-specs">Documenting specs</h1>

A file enters the guide when it matches `specs_glob` and contains a `# =`
heading at column 0.


<h2 id="anatomy">Anatomy</h2>


```ruby
# spec/system/orders_spec.rb
require 'rails_helper'

# @category Orders
# @order 200
#
# = Orders
# Create and track customer orders.
#
# == Creating an order
# Pick a customer, add line items and save.

RSpec.describe 'Orders', type: :system do
  it 'creates an order' do
    visit new_admin_order_path
    click_button 'Save'

    doc_screenshot('orders/created')
  end
end
```


<h2 id="headings">Headings</h2>


| Comment | Rendered |
| --- | --- |
| `# = Orders` | `h1` |
| `# == Creating an order` | `h2` |
| `# === Line items` | `h3` |

A comment block runs until the next heading or the first non-comment line, so
a section can sit directly above the examples it describes. An indented
heading is parsed as content but never marks the file as documented; the file
is skipped.


<h2 id="directives">Directives</h2>


`@category` and `@order` place the guide in the generated README. They are
stripped from the body and default to `Other` / `999_999` when missing.

| Directive | Effect |
| --- | --- |
| `@category Orders` | TOC group |
| `@order 200` | Position within the guide |

> [!TIP]
> Categories sort by their smallest order and guides by their own, so leave
> gaps between orders to insert a guide later.


<h2 id="screenshots">Screenshots</h2>


`doc_screenshot('orders/created')` writes
`docs/screenshots/orders/created.png` when `SCREENSHOTS=true`; otherwise it is
a no-op. The image is embedded after the heading block that precedes the call,
and only if the PNG already exists.
