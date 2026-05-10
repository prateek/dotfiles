# Storage And Backup Options

Use this when the user has not chosen the long-term home yet.

## Decision Rule

Pick one primary source of truth. Then add backup and sharing rules around it.

Do not recommend an always-active multi-cloud sprawl unless the user has a very specific reason.

## iCloud Drive

Best when:

- The user lives in the Apple ecosystem
- iPhone and Mac access matter most
- Family sharing is useful

Watch for:

- Mixed experience on non-Apple devices
- Shared family access that may be too broad for sensitive categories

## Google Drive

Best when:

- Web access and search matter
- Cross-platform access matters
- The user already lives in Gmail and Google Workspace

Watch for:

- Shared-drive sprawl
- Users treating Gmail and Drive as separate sources of truth forever

## Dropbox

Best when:

- The user already keeps a stable Dropbox archive
- Sync behavior and cross-platform use matter
- Shared folders are already part of family workflow

Watch for:

- Legacy folders that were never cleaned up
- Sensitive records mixed into broad shared folders

## Local-First

Best when:

- Privacy requirements are strict
- The user already has a disciplined backup setup

Watch for:

- No offsite backup
- Single-device failure risk

## Recommended Backup Shapes

### Simple default

- One primary cloud home
- One local machine copy
- One separate backup system such as Time Machine or exported archive

### Higher privacy split

- Primary cloud home for most categories
- Separate encrypted or local-only location for especially sensitive categories

### Family handoff aware

- Primary personal source of truth
- Clearly scoped shared folder for documents others need
- Written emergency-access notes outside the folder tree

## Questions To Resolve

- Who needs access now?
- Who needs access if the owner is unavailable?
- Which categories should stay private even from family?
- Which originals must remain physical?
- What happens if the same file exists in email, Downloads, and cloud storage?
