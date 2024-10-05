# 📡 Signals by Lighthouse

A [Turborepo](https://turbo.build/) configured with the following web interfaces and shared packages:

## Tools

* [shovel](https://indexsupply.com/shovel/)

## Getting Started

* Use `yarn` as our package manager.
* Use [direnv](https://github.com/direnv/direnv) to manage environment variables.

```bash
# Setup .env
cp .envrc.example .envrc
```

## Apps

* `interface`: a [Next.js](https://nextjs.org/) app
* `contracts`: EVM Contracts using [Foundry](https://github.com/foundry-rs/foundry)

Spin up local development servers with: `yarn <app>` (e.g. `yarn interface` )

## Packages

* `tsconfig`: `tsconfig.json`s used throughout the monorepo

## Appendix

### Turborepo

Learn more about the power of Turborepo:

* [Tasks](https://turbo.build/repo/docs/core-concepts/monorepos/running-tasks)
* [Caching](https://turbo.build/repo/docs/core-concepts/caching)
* [Remote Caching](https://turbo.build/repo/docs/core-concepts/remote-caching)
* [Filtering](https://turbo.build/repo/docs/core-concepts/monorepos/filtering)
* [Configuration Options](https://turbo.build/repo/docs/reference/configuration)
* [CLI Usage](https://turbo.build/repo/docs/reference/command-line-reference)
