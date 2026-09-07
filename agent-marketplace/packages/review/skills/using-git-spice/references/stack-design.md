# Designing a stack

Plan the dependency graph before writing code. Use this reference when the
requested work should become multiple reviewable change requests.

## Plan layers

Each layer owns one concern. Code may depend on the same layer or one below it,
never on an unlanded sibling or descendant. Write the intended review order
first:

```text
master
└── prateek/billing-schema
    └── prateek/billing-api
        └── prateek/billing-ui
```

The names are illustrative. Infer concerns from the task and repository.

Prefer a lower layer for shared types, schemas, or mechanical groundwork.
Place behavior above the interfaces it consumes, then integration coverage
above the behavior. A reviewer should be able to understand each layer from
its base plus that layer's diff.

Git-spice stacks may branch. Use siblings when independent changes share a
base but do not depend on each other:

```text
master
└── prateek/billing-schema
    ├── prateek/billing-api
    └── prateek/billing-importer
```

Do not force siblings into a linear order that creates a false dependency.

## Name by topic and concern

Follow repository naming rules first. For this machine, managed config adds
`prateek/` during `branch create`, so pass bare names such as
`billing-schema`, `billing-api`, and `billing-ui`.

Use a shared topic plus the layer's concern. Avoid sequence-only names such as
`part-1` and `part-2`; names should survive insertion or reordering.

## Add a layer when it changes review

Create another layer when at least one is true:

- The next work has a different concern or reviewer audience.
- It introduces a dependency on the completed layer.
- The current diff is independently useful or already large enough to review.
- The next change can land or be reverted separately.

Keep work together when splitting would create two changes that cannot be
reviewed or tested meaningfully on their own. A layer that needs more than one
sentence to describe its purpose is a candidate for another split.

## Recover an after-the-fact stack

Planning is cheaper, but existing work can still be reshaped. Use
`git-spice branch split` at verified commit boundaries when one branch already
contains separable layers. Use `branch onto`, `upstack onto`, or fixup
operations from [stack-surgery.md](stack-surgery.md) when dependencies or
commit placement need repair.

The design is ready when every layer has one concern, every dependency points
downstack, branch names describe durable concerns, and the bottom-to-top review
order tells one coherent story.
