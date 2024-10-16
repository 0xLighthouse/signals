# SIGNALS, a protocol for prioritising community objectives

**Created:** October 2, 2024\
**Authors:**
Arnold ([1a35e1.eth](https://t.me/x1a35e1) / [arnold@lighthouse.cx](mailto\:arnold@lighthouse.cx)),
James ([jkm.eth](https://warpcast.com/jkm.eth) / [james@lighthouse.cx](mailto\:james@lighthouse.cx))

## Abstract

SIGNALS allows on-chain governance groups to discover which initiatives are most important to the community, by allowing participants to stake their governance tokens on the issues they care about most. Lockup and decay mechanisms create a level playing field, preventing whales from having an outsized impact on the discussion.

## Motivation

Many on-chain organisations and DAOs allow thier participants to submit open-ended proposals, which are then voted on by governance token holders. Proposals which pass (based on the group's rules around thresholds, quorum, etc.) are executed autonomously. This common system has multiple flaws:

**1. Participants who hold a large number of governance tokens can dominate the discussion.**

In many of these groups, a small number of "whale" token holders hold all the power to make or break a proposal. This leads to proposers needing to tailor their proposals to suit the opinions of an elite minority, which might not actually represent the interests of the community. This results in most participants only enjoying the illusion of participation, and defeats the purpose of decentralised governance.

Also, these whales could collude to forcibly pass proposals that are harmful to the community.

**2. Proposers have no mechanism to discover the optimal proposal, other than putting it up for a vote.**

Many proposals include multiple variables, such as an amount of money to be paid, a duration for which an initiative should run, or various other details.

It is common for voters to agree with the majority of the proposal, but take issue with one or more details (it's too expensive, it runs for too long, etc). In this case, the voter's only option is to reject the proposal completely (and hope it is resubmitted with more favourable terms) or vote in favour, even though they disagree with what is being presented.

When a proposal fails, proposers often don't know if it was because of minor details which can easily be corrected, or if the idea as a whole has been rejected by the community. Proposers will try to get feedback on their proposal before submission, but it is rare for the community to give honest feedback unless the proposal is up for a vote and at risk of being passed as presented.

**3. Community activists have no visibility into the community's top priorities.**

In this case, an "activist" can be a founder, organiser, passionate community member who drives a lot of initiatives, or even a new group member who wants to contribute in a substantial way.

With the current proposal system, proposers are left to guess for themselves what kind of proposals will pass. Popular participants can leverage their reputation to get proposals passed, even if they are not a top priority for the community, and new proposers might have their good ideas defeated simply because each voter assumes the idea is not a top priority.

***There is no way for the community to express, in a substantive way, what kind of proposals it would like to see.***

## The SIGNALS solution

The SIGNALS protocol uses an on-chain smart contract and works in the following way:

**1. Users submit initiatives to the system.** It is up to the community to decide what amount of detail is expected to be included. For example, a community could require initiatives to be specific, detailed proposals of actions to take, or they could encourage participants to submit rough ideas as a way to surface what should be explored more.

**2. Community members who hold governance tokens (or other tokens designated for use with SIGNALS) can lock up and stake their tokens in support of, or opposition to, the initiatives they care about most most.** It us up to the individual to decide how many tokens and for how long they should be locked. This allows users who hold less tokens to lock them up for longer, exchanging furture opportunity cost for immediate staking weight.

**3. The community can easily see which initiatives have received the most support, and initiatives that surpass a specified threshold of support can be "actioned."** This removes the initiative from the system, immediately returns all staked funds to the original owners, and signals to the community that the initiative is ready to be acted upon: e.g. a proposal is popular enough to submit for a formal vote, a need is high enough priority to add to the budget, etc.

**4. Initiatives that receive no support for a specified period of time can be "deactivated."** These initiates are removed from the system, and tokens are returned to their original owners after a cooldown period.

**5. The weight of tokens decays over time, keeping initiatives timely.** Although a lukewarm idea that gets moderate support contunually over a long period of time could add up to a lot of tokens staked, it is not as powerful as an idea that has a lot of support all at once.

Decay is also essential for making lockup time a more balanced alternative to staking more tokens. A longer lockup essentially takes future opportunity cost and applies it to the current staking weight right now. If that weight did not decay, there would be no temporal transfer of opportunity cost from the future to the present.

## Configuration

The community can decide on various aspects of the system, by setting smart contract variables:

- The requirements for submitting initiatives (whitelist, token threshold, etc)
- The threshold weight required for actioning an initiative, and who can trigger it.
- The inactivity period after which initiatives can be deactivated.
- The cooldown period for returning tokens from failed initiatives.
- The function for calculating weight.
- The function for calculating decay.
- The length of an epoch (e.g. 24 hours).

Similarly, what happens to an initiative after it is actioned is up to the community and outside the scope of this system (i.e. SIGNALS does not execute any on-chain transactions as the result of an initiative being actioned or deactivated)

## Weight calculation

The default weight caclulation, at the time of staking, is:
  $$
  \text{Starting Weight (W) = Number of Tokens (T) } \times \text{ Lock Duration (D)}
  $$

  The lock duration is an integer representing the number of epochs, and must be greater than zero. It is not possible to specify partial epochs as part of the lockup duration.

## Decay function

The default decay function reduces the weight of staked tokens by 10% of the starting weight, every 1/10th of the lockup duration:


1. Calculate \( k \):

   \[
   k = \left\lfloor \dfrac{10 \times (t - 1)}{D} \right\rfloor
   \]

2. Calculate \( V(t) \):

   \[
   V(t) = \dfrac{W \times (10 - k)}{10}
   \]


In Javascript, this could look like:
```javascript
let decay = 0;
if (epochsElapsed > 1) {
  decay = Math.floor((epochs - 1) * 10 / lockDuration);
}
let currentWeight = 0;
if (decay < 10) {
  currentWeight = Math.floor(startingWeight * (10 - decay) / 10);
}
return currentWeight;
```

This behaviour makes it easier for stakers to coordinate, as all stakes will carry full weight for at least the first epoch, and it is quite easy to figure out exactly how much weight will be left after a certain number of epochs have passed.

## Reward system [WIP]

Supporters of a particular initiative can deposit tokens into the contract which are then distributed, as rewards, to all token holders who staked tokens in favour of the initiative once it is actioned.

<!-- 
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

 -->
