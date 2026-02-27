FROM node:22-slim AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@10.30.3 --activate

WORKDIR /app

# Copy workspace root files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Copy only the packages/apps needed by the indexer
COPY packages/abis/ packages/abis/
COPY apps/indexers/ apps/indexers/

# Copy broadcast files needed to resolve contract deployments
COPY apps/protocol/broadcast/ apps/protocol/broadcast/
COPY apps/signals-token-factory/broadcast/ apps/signals-token-factory/broadcast/

# Install dependencies
RUN pnpm install --filter indexers... --frozen-lockfile

WORKDIR /app/apps/indexers

EXPOSE 42069

CMD ["pnpm", "start"]
