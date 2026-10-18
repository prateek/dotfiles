# Social and forum evidence

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
