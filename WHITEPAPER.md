# SIGNALS, a protocol for prioritising community objectives
DRAFT

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

The lock duration is an integer representing the number of intervals, and must be greater than zero. It is not possible to specify partial epochs as part of the lockup duration.

For example, if the lockup interval is set to 1 day and the user does a lockup for 10 days, they will get a 10x multiplier to their starting weight.

## Decay function

We have included two default decay functions, linear and exponential.

The linear decay takes a multiplier (greater than 1) and finds the weight as:

$$
\text{Current Weight (cW)} = \text{Starting Weight (W)}-\text{Passed Intervals (I)}*\text{Number of Tokens (T)}*\text{Multiplier (M)}
$$

The exponential decay takes a multiplier (less than 1) and finds the weight as:

$$
\text{Current Weight (cW)} = \text{Starting Weight (W)}*\text{Multiplier (M)}^\text{Passed Intervals (I)}
$$

By using intervals, it easier for stakers to coordinate, as all stakes will carry full weight for at least the first interval, and it is quite easy to figure out exactly how much weight will be left after a certain number of intervals have passed.

## Reward system

Supporters of a particular initiative can deposit tokens into the contract which are then distributed, as rewards, to all token holders who staked tokens in favour of the initiative once it is actioned. By default, a portion of the rewards go to the supporters of the initiative, while another portion goes to the treasury of the DAO itself. These rewards are only paid out if the initiative is accepted, which allows, for example, protocols to propose an integration with a DAO, and reward the DAO and its supporters if the integration proposal is accepted.

## Additional research questions

- Issue ERC721 tokens that can be used to redeem tokens when a lock reaches maturity.
- Explore if we can use Uniswap v4 to create a secondary market for these tokens/bonds.

## Protocol Overview
 - [Source code (Github)](https://github.com/0xLighthouse/signals)
 - [Live demo](https://signals.testnet.lighthouse.cx/)

## References

- [Curve contracts](https://github.com/curvefi/curve-dao-contracts)
- [Aerodrome contracts](https://github.com/aerodrome-finance/contracts)
- [Emergent Outcomes of the veToken Model](https://arxiv.org/abs/2311.17589)
