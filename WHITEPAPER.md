# SIGNALS

An on-chain framework for aligning community intentions.\
**Created:** October 2, 2024\
**Author:** Arnold (1a35e1) [arnold@lighthouse.cx](mailto\:arnold@lighthouse.cx)\
**Contributors:** jkm.eth, x43n, n0mad\
**Discussion:** Discord Channel

## Problem

[Lighthouse](https://lighthouse.cx) is a governance aggregator that supports many EVM-based communities, providing real-time proposal and voting capabilities.

We define the governance stack as: **Ideation, Discourse, Voting, Allocation, Accountability**.

While voting is a core part of governance, many ideas are often lost in the noise, making it difficult for new and even returning participants to gauge the current sentiment and objectives of a community.

For our collabtech submission, we are exploring how **Ideation** can serve as a signal to both existing and new participants in an on-chain community.

Hence the project name: **SIGNALS**.

## Solution

In traditional product development, product owners gather feedback from stakeholders to shape priorities. However, on-chain organizations operate in networked environments where information is fragmented across multiple channels, making it challenging to collect and understand community priorities.

Aligning community priorities can help set both short- and long-term strategies, serving as a vital measure of collective intent.

### Objectives

**SIGNALS** enables:

- Crowdsourcing ideas from the community in a way that encourages thoughtful participation and reduces noise.
- Giving minority stakeholders an opportunity to coordinate and amplify their voice through collective action.
- Optionally rewarding meaningful contributions fairly, while avoiding incentives that could be counterproductive.

## Method

* **Idea Submission:** Members of the on-chain community can submit ideas if they hold tokens meeting the threshold required for submission.\
* **Commitment Mechanism:** Members can commit tokens to support an idea, signaling their backing for that proposal. Tokens are locked for a duration of the member's choosing.\
* **Commitment Weighting:** The longer tokens are locked, the greater the initial commitment weight. Commitment weight decays over time based on the duration.\
* **Dynamic Ranking:** The decay function plays an important role as issues that may seem topical at first glance may lose amplification over time.

### Weight Calculation

$$
\text{Weight (W) = Number of Tokens (T) } \times \text{ Lock Duration (D)}
$$

$$
W = T \times D
$$

After locking, commitment weight decays over time based on a configurable decay function. The decay function can be tailored to the organization's needs, and options include:

- **Exponential Decay:** Weight decays exponentially over time, providing a rapid decrease in influence. For example, if tokens are locked for 3 months, the weight might decrease by half every month.
- **Linear Decay:** Weight decreases at a constant rate over time, providing a more predictable reduction. For instance, if tokens are locked for 3 months, the weight could decrease by an equal amount each month until it reaches zero.
- **Step Decay:** Weight decreases in steps after specific time intervals, allowing for more distinct phases of influence. For example, the weight could remain constant for the first month and then drop significantly after each subsequent month.

### Example

- **Alice** locks 300 tokens for 1 month: **Weight = 300**
- **Bob** locks 100 tokens for 3 months: **Weight = 300**

Bob achieves the same voting weight as Alice by locking tokens three times longer, even though he holds only one-third the tokens.

## Rationale

Smaller token holders may be more willing to lock tokens for ideas they strongly believe in, as their risk lies in opportunity cost.\
Large token holders ("whales") may be less inclined to lock tokens for long periods, particularly if they have mercenary motives. This dampens larger voices.

## Parameters

Configurations can be customized for the organization:

- **Threshold:** Minimum tokens required to submit an idea.
- **Tags:** Tagging ideas (future version).
- **Conviction Bonus:** Maximum multiple allowed.
- **Decay Curve:** Configurable decay (e.g., exponential, linear, or step decay).

### Tailwinds

- **Reputation Benefits:** Proposers and supporters can be issued attestations or POAPs for accepted ideas.
- **External Support:** Third parties can support initiatives in a trustless manner.

## Reward System

Introducing financial rewards could be risky, potentially incentivising unwanted behaviors. Reputation-based rewards are preferable.

## Additional Considerations

- **Lock Duration Cap:** Limit lock duration to avoid abuses.
- **Proposal Caps:** Limit the number of suggestions per epoch.
- **Spam Prevention:** Once an idea reaches sufficient weight, tokens are returned if accepted within a 7-day period. If tokens are not returned within this period, the proposal can be canceled by any user, and the proposer loses their locked tokens, which may discourage spam submissions and promote timely decision-making.
- **Optimal Threshold:** Uncertain. Potentially require 51% of votable supply to accept.

## Feedback

### Why Use SIGNALS?

DAOs require web3-native tools for governance. Existing web2 forums, such as Discourse or Discord, are centralized, unstructured, and not machine-readable, making it difficult to efficiently aggregate and analyze community input.

Participation is siloed across various platforms, making it difficult to aggregate and reflect individual contributions and reputation at the macro scale.

Community engagement is fragmented across different platforms, making contributions difficult to track.

SIGNALS provides a way for ideas to be formalized on-chain, increasing utility for governance tokens and enabling trustless external support.

### How SIGNALS Differs

While forums often get cluttered, SIGNALS enables the best ideas to surface quickly and allows contributors to back ideas they truly believe in. It acts as an additive tool for on-chain governance, similar to traditional product prioritization frameworks but adapted to web3 needs, emphasizing ideation and consensus-building.

After locking, commitment weight decays over time based on a configurable decay function. The decay function can be tailored to the organization's needs, and options include:

- **Exponential Decay:** Weight decays exponentially over time, providing a rapid decrease in influence. For example, if tokens are locked for 3 months, the weight might decrease by half every month.
- **Linear Decay:** Weight decreases at a constant rate over time, providing a more predictable reduction. For instance, if tokens are locked for 3 months, the weight could decrease by an equal amount each month until it reaches zero.
- **Step Decay:** Weight decreases in steps after specific time intervals, allowing for more distinct phases of influence. For example, the weight could remain constant for the first month and then drop significantly after each subsequent month.

