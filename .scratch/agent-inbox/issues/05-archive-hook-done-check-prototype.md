# Archive-hook done check prototype

Type: prototype
Status: open
Blocked by: 02, 03

## Question

What should the done check feel like at worktree removal? Build a throwaway archive script in a scratch repo, against a stub store shaped like the ticket 03 model. It:

- lists open items addressed to you, or to both
- exits non-zero with a readable message
- tells the user how to resolve the items or override

Try it through the Orca UI and through `orca worktree rm --run-hooks`. React to it with Prateek: what should the message say, should items addressed only to agents block, and is the override flow tolerable?
