# Social and forum evidence

Choose communities by audience and evidence form, not platform popularity. These
are selection seeds, not a requirement to query every site or a promise of access:

| Need | Source families and useful seeds | Verify or limit |
| --- | --- | --- |
| Owner experience or troubleshooting | Specialist forums, Reddit, public community Q&A | Original account, concrete setup and replies; a subreddit is not representative of all owners |
| Developer or startup discussion | HN, project issues/discussions, specialist engineering communities | Trace the linked original; distinguish release claims from user evidence |
| Public current conversation | X, Threads, Bluesky, relevant Mastodon instances | Dates, original/repost and audience; instance search is not a global federated index |
| Professional experience | LinkedIn, professional associations, practitioner blogs | Role and firsthand detail; promotional content and guest access can limit evidence |
| Demonstration or walkthrough | YouTube, TikTok, Instagram, regional video communities | Actual audio/video and relevant segment; captions, views or thumbnails alone do not prove behavior |
| Local or language-specific experience | Native-language forums and regional communities | Content language, community location and purchase market are separate |

For multilingual or regional requests, read [multilingual discovery](multilingual.md)
and its relevant regional reference. Discover an unfamiliar specialist community
when the seeded sites do not fit. Public Discord/Telegram pages, newsletters and
podcasts may supply leads; private groups and app-only content remain unavailable
without an authorized access route. Do not require new accounts for ordinary search.

Distinguish `post.discover` / `video.discover` from `comments.read`,
`transcript.read` and `item.read`. A web provider can discover Reddit/X threads
without native API access; that does not grant comments, full threads or deleted
content. A SearchAPI video record does not prove the channel or spoken content.

Use native HN Algolia discovery and budgeted HN item reads when relevant. Item
reads return child IDs; reading each child is a separate operation. For Reddit,
X and YouTube, inspect candidate destinations through available host/browser
access. Native Reddit/X credentials are optional and currently have no dedicated
adapter. Do not invent a key or account requirement for ordinary web discovery.

Check author/channel, publication date, community, original versus repost, and
whether replies or a transcript actually support the requested claim. Preserve
engagement metrics with their observation time and native meaning. Votes, views
and comments are different signals; never aggregate them as one popularity score.
Wrong-channel videos and title-only matches fail identity/content requirements.

State the evidence window and coverage: thread discovery, full post, replies or
transcript. Search sources selectively. A mixed owner-experience and current-price
request uses social plus shopping facets with one shared budget.
