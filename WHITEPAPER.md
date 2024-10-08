# SIGNALS, A protocol for prioritising community objectives

**Created:** October 2, 2024\
**Author:** Arnold ([1a35e1.eth](https://warpcast.com/1a35e1)) [arnold@lighthouse.cx](mailto\:arnold@lighthouse.cx)\
**Contributors:** [jkm.eth](https://warpcast.com/jkm.eth), [x43n](https://warpcast.com/0x43n)

## TL;DR

* **Alice** locks 300 tokens for 1 month: **Weight = 300**
* **Bob** locks 100 tokens for 3 months: **Weight = 300**

Bob achieves the same voting weight as Alice by locking tokens three times longer, even though he holds has one-third of the tokens.

## Abstract

SIGNALS is a protocol designed to prioritize community objectives in decentralized organizations. It leverages tokenization to create structured ideation processes and enhance governance token utility. The protocol allows community members to submit initiatives and signal support by locking tokens, with longer lock periods resulting in greater initial commitment weight

## Motivation

Decentralized communities often struggle with effective prioritization of objectives and ideas. SIGNALS addresses this by:

1. Providing a structured method for idea submission and prioritization
2. Enabling new and existing participants to gauge current community sentiment
3. Amplifying minority voices through collective action
4. Increasing governance token utility

## Specification

* **Idea Submission:** Community members can submit initiatives if they hold the required token threshold.

* **Commitment Mechanism:** Members lock tokens to support initiatives, with longer lock periods resulting in higher initial commitment weight.
**Dynamic Ranking:** Commitment weight decays over time based on a configurable function, ensuring that priorities remain current.

* **Weight Calculation:** Where W is weight, T is number of tokens, and D is lock duration.

  $$
  \text{Weight (W) = Number of Tokens (T) } \times \text{ Lock Duration (D)}
  $$

* **Decay Function:** A differential decay function is proposed, where weight decreases at a rate proportional to the square root of time passed since locking.

* **Reward System:** Reputation-based rewards (e.g., attestations or POAPs) for accepted ideas and supporters.

## Rationale

SIGNALS improves upon existing governance models by:

1. Encouraging thoughtful participation and reducing noise in idea submission
2. Providing a fair system for minority stakeholders to amplify their voice
3. Offering a web3-native solution for community prioritization, unlike centralized web2 forums
4. Enabling trustless external support for initiatives
5. Increasing governance token utility through active participation

The protocol's design considers potential abuses and includes measures such as lock duration caps, proposal limits, and spam prevention mechanisms. By using a token-based weighting system with time decay, SIGNALS creates a dynamic and responsive prioritization process that reflects the community's evolving priorities.

## Appendix

### Analague to existing practices

In traditional product development, product owners gather feedback from stakeholders to shape priorities. However, on-chain organizations operate in networked environments where information is fragmented across multiple channels, making it challenging to collect and understand community priorities.

Aligning community priorities can help set both short- and long-term strategies, serving as a vital measure of collective intent.

## Objectives

### Tailwinds

* Smaller token holders may be more willing to lock tokens for ideas they strongly believe in, as their risk lies in opportunity cost.
* Large token holders ("whales") may be less inclined to lock tokens for long periods, particularly if they have mercenary motives. This dampens larger voices.

* **Reputation Benefits:** Proposers and supporters can be issued attestations or POAPs for accepted ideas.
* **External Support:** Third parties can support initiatives in a trustless manner.

### Headwinds

* Introducing financial rewards could be risky, potentially incentivising unwanted behaviors. Reputation-based rewards are preferable.

## Configuration

* **Submissions Threshold:** Minimum tokens required to submit an idea.
* **Acceptance Threshold:** Number of tokens (weighted) required to accept an idea.
* **Lock Duration Cap:** Cap duration tokens may be locked for.
* **Submission Cap:** Cap number of submissions within an epoch.

## Feedback

### Why Use SIGNALS?

DAOs require web3-native tools for governance. Existing web2 forums, such as Discourse or Discord, are centralized, unstructured, and not machine-readable, making it difficult to efficiently aggregate and analyze community input.

Participation is siloed across various platforms, making it difficult to aggregate and reflect individual contributions and reputation at the macro scale.

Community engagement is fragmented across different platforms, making contributions difficult to track.

SIGNALS provides a way for ideas to be formalized on-chain, increasing utility for governance tokens and enabling trustless external support.

### How SIGNALS Differs

While forums often get cluttered, SIGNALS enables the best ideas to surface quickly and allows contributors to back ideas they truly believe in. It acts as an additive tool for on-chain governance, similar to traditional product prioritization frameworks but adapted to web3 needs, emphasizing ideation and consensus-building.

After locking, commitment weight decays over time based on a configurable decay function. The decay function can be tailored to the organization's needs, and options include:

* **Exponential Decay:** Weight decays exponentially over time, providing a rapid decrease in influence. For example, if tokens are locked for 3 months, the weight might decrease by half every month.
* **Linear Decay:** Weight decreases at a constant rate over time, providing a more predictable reduction. For instance, if tokens are locked for 3 months, the weight could decrease by an equal amount each month until it reaches zero.
* **Step Decay:** Weight decreases in steps after specific time intervals, allowing for more distinct phases of influence. For example, the weight could remain constant for the first month and then drop significantly after each subsequent month.

## Technical Overview

### Weight Calculation

Code Context:
 • The function calculates how much weight (influence, stake, or value) remains for a user’s locked amount over time.
 • The intended model is exponential decay to reflect diminishing returns or influence as time progresses.
 • Due to practical constraints, the implementation uses a linear decay, multiplying the initial amount by the remaining duration.

Premise: The longer tokens are locked, the greater the initial commitment weight. Commitment weight decays over time based on the duration.

$$
\text{Weight (W) = Number of Tokens (T) } \times \text{ Lock Duration (D)}
$$

$$
W = T \times D
$$

Exploring decay functions:

When locking, commitment weight decays over time based on a a configurable decay function:

* **Exponential Decay:** ~~Weight decays exponentially over time, providing a rapid decrease in influence. For example, if tokens are locked for 3 months, the weight might decrease by half every month.~~

> Too complex for the initial version.

* **Step Decay:** ~~Weight decreases in steps after specific time intervals, allowing for more distinct phases of influence. For example, the weight could remain constant for the first month and then drop significantly after each subsequent month.~~

> Too complex for the initial version.

* **Linear Decay:** ~~Weight decreases at a constant rate over time, providing a more predictable reduction. For instance, if tokens are locked for 3 months, the weight could decrease by an equal amount each month until it reaches zero.~~

> Boring.

* **Differential decay**: Weight decreases at a rate proportional to the square root of the time passed since the lock. This provides a balance between the predictability of linear decay and the rapid decrease of exponential decay.

### Graphing the Differential Decay Function

Why? models processes where a quantity decreases at a rate proportional to its current value.
 • Recognizing the limitations of the programming environment helps understand why the decay model is simplified.

To graph the equation
$$
\frac{dW}{dt} = -kW
$$
 where  k  is a constant and  W  is the current weight, you’ll first need to solve this differential equation to find  W  as a function of  t . Once you have  W(t) , you can plot it using graphing software or a calculator.

This is a separable first-order linear ordinary differential equation. Here’s how to solve it:

 1. Separate Variables:

$$
\frac{dW}{W} = -k\,dt
$$

 2. Integrate Both Sides:

$$
\int \frac{1}{W}\,dW = \int -k\,dt
$$

$$
\ln|W| = -k t + C
$$

Here,  C  is the constant of integration.
 3. Solve for  W :
Exponentiate both sides to eliminate the natural logarithm:

$$
W = e^{-k t + C} = e^C \cdot e^{-k t}
$$

Let

$$
W_0 = e^C
$$

(the initial weight when  t = 0 ) Then;

$$
W(t) = W_0 \, e^{-k t}
$$

## Graph the funcion

Step 2: Choose Values for Constants

To graph  W(t) , you need specific values for  W_0  and  k :

 • Initial Weight ( W_0 ): This is the weight at  t = 0 . Choose a positive value that makes sense for your context (e.g.,  W_0 = 100  units).
 • Decay Constant ( k ): This constant determines the rate of decay. Choose a positive value (e.g.,  k = 0.1 ).

Step 3: Create Data Points

Using the equation

$$
W(t) = W_0 \, e^{-k t}
$$

Calculate W for various values of t, to explore parameter space.

Differential Equation:

$$
\frac{dW}{dt} = -kW
$$

Solution to the Differential Equation:

$$
W(t) = W_0 \, e^{-k t}
$$

 • Where:
 •  `W(t)`: Weight at time  `t`.
 •  `W_0`: Initial weight at  `t = 0`.
 •  `k` : Positive decay constant.

<https://www.desmos.com/calculator/slpil4yhlm>
