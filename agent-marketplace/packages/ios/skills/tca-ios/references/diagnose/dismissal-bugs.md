# Applies to: TCA 1.25+, iOS 16+

# Dismissal Bugs

## Use When

Use this when sheets dismiss incorrectly, child actions arrive after state is nil, or save/cancel flows lose data.

## Diagnosis

- Identify who owns presentation state.
- Check child delegate actions and parent handling order.
- Check if the parent clears state before reading child data.
- Check long-lived child effects.
- Check view presentation binding against reducer state.

## Common Causes

- Parent sets destination nil too early.
- Child uses dismissal as data transfer.
- View has local presentation state separate from TCA state.
- Effect cancellation is missing.

## Fix

Use delegate actions for data, parent-controlled state for presentation, and cancellation for child-owned work.
