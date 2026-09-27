# Family Tree transition architecture

## Goals

- Person click reacts immediately.
- No document reload.
- No mandatory network request during reroot when topology is available.
- No stale ELK result can win a race.
- New navigation interrupts current motion rather than queueing.
- Vue Flow edges follow node positions every frame.

## Stable layers

1. Domain topology store.
2. Pure visible-subgraph selector.
3. Pure domain-to-layout graph transformer.
4. ELK Worker client.
5. Transition coordinator.
6. Vue Flow adapter.
7. Router synchronization controller.

## Generation algorithm

```text
select person B while A transition may be active
  -> sample current visual frame
  -> generation += 1
  -> set selected B immediately
  -> push /family/{B.slug}
  -> compute B visible subgraph synchronously
  -> cancel obsolete network work
  -> terminate/recreate ELK worker if previous layout is running
  -> request layout(generation B)
  -> if result generation != current: discard
  -> derive enter/retain/leave animation plan
  -> animate from sampled frame to B target with one RAF clock
  -> center viewport on B
  -> remove completed leaving nodes
```

## Entering nodes

For every entering node find the nearest retained node by BFS over domain adjacency. Its start position is the retained branch position with a small relationship-direction offset. Opacity starts at zero.

## Leaving nodes

For every leaving node find the nearest retained connected node. The leaving target trends toward that branch while opacity reaches zero. Removal happens only after the transition completes.

## Layout failure

Keep the last valid visual graph. Never clear the tree. Surface a small non-blocking layout error state and permit a new Person selection/retry.
