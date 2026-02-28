# Sim D: Sybil Splitting Attack

**Status:** Planned -- see THESIS_GUIDE.md for infrastructure status and required code changes

---

## Research Question

Does splitting stake into many wallets game the sqrt curve? Is an honest whale
strategy better than sybil splitting under budget constraints and lock duration requirements?

---

## Experiment Design

Compare an honest whale (1 wallet with S tokens) against a sybil attacker
(N wallets with S/N tokens each), holding total budget and lock duration constant.
Test across curve types to identify which curves are sybil-resistant.

---

## Infrastructure Status

New code required: custom sybil scenario builder, comparison harness, and
`compute_sybil_advantage()` metric. Factory cannot model adversarial splitting.
See [../../THESIS_GUIDE.md](../../THESIS_GUIDE.md) for specific required changes.

**Priority:** 2 (depends on Sim C output for curve_type selection)
