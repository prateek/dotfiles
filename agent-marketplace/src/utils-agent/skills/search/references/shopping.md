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

## Shopping indexes and price comparison

For retailer discovery or price comparison, consider shopping indexes alongside
direct retailers. Choose a complementary set for the buyer's market, product and
budget; record selected and deferred sources in `source_decisions`.

| Source seeds | Web entry points | Selection checks |
| --- | --- | --- |
| Google Shopping | [Google Shopping](https://www.google.com/shopping) and Google's Shopping search surface | Set the relevant market; distinguish sponsored placements from other results |
| Bing / Microsoft Shopping | [Microsoft Shopping](https://www.bing.com/shop/) | Check market and whether results expose relevant retailers |
| Idealo | [Idealo UK](https://www.idealo.co.uk/) or the appropriate national site | Select the country site matching delivery and currency |
| PriceRunner | [PriceRunner](https://www.pricerunner.com/) or its relevant regional site | Verify current regional coverage and readable product/retailer results |
| PriceSpy | [PriceSpy UK](https://pricespy.co.uk/) or its relevant regional site | Verify current regional coverage and readable product/retailer results |
| Shopzilla, PriceGrabber | [Shopzilla](https://www.shopzilla.com/), [PriceGrabber](https://www.pricegrabber.com/) | Confirm the site still supplies useful comparison results for this market before allocating more calls |

These are seeds, not an exhaustive list or a requirement to query every index.
Discover local comparison services when these do not fit. Use public web search
to find indexed product/comparison pages with `site:hostname[/path]` scopes and
`area=shopping`, `operation=product.discover`. To search a site's own interface,
use the browser skill through `native-page` inspection (`page.inspect`) of an
explicit entry or results URL, returning parsed results and observed limits.
Declare a host binding supporting the operation and scope. Scope Google
web discovery to the actual Shopping host/path; the `google-shopping` alias alone
has no domain filter. A scoped web search finds indexed pages; it does not execute
the site's native search or prove complete catalogue coverage.

SearchAPI's Amazon and Google Shopping discovery is an optional API route.
Missing API credentials leave web search and browser routes eligible when their
capabilities and access permit. Declare the actual host bindings and respect
explicit route pins. Stop a route on challenge, login or 429 and report the gap;
use another eligible route or source within the original budget.

Follow index results to the retailer's offer for variant, seller, condition,
delivered price, stock, returns and delivery checks. Preserve index and retailer
provenance; repeated retailer feeds across indexes are not independent evidence.
An index's lowest price or sponsored ranking does not establish the best usable
offer.

## Marketplace and delivery access

General web routes can find Alibaba, Marketplace, Uber Eats and Instacart pages.
Native page inspections require an explicit URL and a real browser binding.
Capabilities show the actual available operations; there is no mandatory account
or every-marketplace fan-out.

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
