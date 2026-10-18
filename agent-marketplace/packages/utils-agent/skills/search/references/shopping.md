# Products and inventory

Resolve material buyer context: specification/compatibility, quantity, delivery
market and deadline, total budget, acceptable condition, warranty/returns, pickup
and import tolerance. Reuse explicit context; ask only when a missing fact would
change feasibility or source choice. Language does not establish delivery market.

| Purchase need | Starting channels | Branch condition |
| --- | --- | --- |
| One new item or urgent replacement | Manufacturer, authorized/local retailers, relevant price comparison | Prefer verifiable stock and delivery; avoid unsuitable lots and long lead times |
| Lower price with used acceptable | Manufacturer refurb, established refurb/ITAD sellers, eBay and local resale | Inspect condition, provenance and return terms |
| Several units or flexible procurement | Institutional surplus, government sales, commercial auctions | Only when lot quantity, eligibility, testing and collection terms fit |
| Cross-border or volume sourcing | AliExpress, Alibaba, 1688, Global Sources or specialist distributors | Compare quantity/MOQ, samples, quote basis and delivered usable cost |
| Local grocery, meals or delivery | Store-direct service, Instacart, Uber Eats, DoorDash or local equivalents | Evidence must match the authorized service address, store and time window |
| Collectibles or specialist equipment | Relevant auction houses, specialist dealers and classified communities | Check authenticity, grading, buyer premium and fulfillment |

These names are seeds. Find local retailers/marketplaces and national surplus
channels for the actual market; do not assume US sellers or shipping. Read
[source scopes](source-scopes.md#scopes-and-operations) when selecting or excluding
regional storefronts: the `amazon` alias covers only `amazon.com`. Read
[used goods and auctions](shopping/used-and-auctions.md) for condition/lot questions,
and [sourcing and delivery](shopping/sourcing-and-delivery.md) for quantity/import
or address-dependent services. [Regional guidance](regions/global-discovery.md)
helps discover alternatives when the catalogue does not fit.

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
