# Products and inventory

Discovery finds candidates. A supported shopping answer requires the requested
product/variant, seller, condition, price/currency, location and observation time;
include MOQ and shipping when applicable. `product.discover` never establishes
orderability. Use `offer.inspect` through the browser skill for current offers.

SearchAPI supports Amazon and Google Shopping discovery. General web routes can
find Alibaba, Marketplace, Uber Eats and Instacart pages. Native page inspections
require an explicit URL and a real browser binding. Capabilities show the actual
available operations; there is no mandatory account or every-marketplace fan-out.

For Marketplace, check listing location and seller as well as price. For Alibaba,
check variant/MOQ and the quote/shipping basis. For delivery/grocery sites, confirm
store, service address, stock, fees and time window in the authorized session.
Keep private delivery addresses in that session, not in saved search defaults,
public requests or eval artifacts. A grid for the wrong city fails the task even
when it contains the right product. Login/security gates remain explicit gaps.

Preserve separate offers for different sellers, variants, conditions and times.
Never deduplicate by title or take a maximum/minimum price as ground truth.
Research authorization does not authorize adding to carts, contacting sellers,
reserving, ordering or paying.
