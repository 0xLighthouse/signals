#!/usr/bin/env node

/**
 * Prune old Ponder deployment schemas from Postgres.
 *
 * Usage: node scripts/prune-schemas.mjs [--keep-days N] [--keep-min N] [--dry-run]
 *
 * Defaults: keep last 5 schemas, prune others older than 30 days.
 * Requires DATABASE_URL env var.
 */

import pg from 'pg'

const args = process.argv.slice(2)
let keepDays = 30
let keepMin = 5
let dryRun = false

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--keep-days') keepDays = Number.parseInt(args[++i], 10)
  else if (args[i] === '--keep-min') keepMin = Number.parseInt(args[++i], 10)
  else if (args[i] === '--dry-run') dryRun = true
}

const databaseUrl = process.env.DATABASE_URL
if (!databaseUrl) {
  console.log('No DATABASE_URL set, skipping schema pruning.')
  process.exit(0)
}

const client = new pg.Client({ connectionString: databaseUrl })

try {
  await client.connect()

  // Get all deploy schemas sorted newest first
  const { rows: allSchemas } = await client.query(`
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name ~ '^deploy_[0-9]{6}_[0-9]{6}$'
    ORDER BY schema_name DESC
  `)

  const total = allSchemas.length
  console.log(`Found ${total} deploy schema(s).`)

  if (total <= keepMin) {
    console.log(`At or below minimum (${keepMin}). Nothing to prune.`)
    process.exit(0)
  }

  // Protect the N most recent
  const protectedSchemas = new Set(
    allSchemas.slice(0, keepMin).map((r) => r.schema_name),
  )

  // Find stale schemas beyond the protected set
  const { rows: staleSchemas } = await client.query(`
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name ~ '^deploy_[0-9]{6}_[0-9]{6}$'
      AND to_timestamp(substr(schema_name, 8), 'YYMMDD_HH24MISS')
          < now() - interval '${keepDays} days'
    ORDER BY schema_name
  `)

  const toPrune = staleSchemas.filter(
    (r) => !protectedSchemas.has(r.schema_name),
  )

  if (toPrune.length === 0) {
    console.log('No stale schemas to prune.')
    process.exit(0)
  }

  console.log(
    `Pruning ${toPrune.length} schema(s) (keeping newest ${keepMin}):`,
  )
  for (const { schema_name } of toPrune) {
    console.log(`  - ${schema_name}`)
  }

  if (dryRun) {
    console.log('(dry run — no schemas dropped)')
    process.exit(0)
  }

  for (const { schema_name } of toPrune) {
    console.log(`Dropping ${schema_name}...`)
    await client.query(
      `DROP SCHEMA ${client.escapeIdentifier(schema_name)} CASCADE`,
    )
  }

  console.log(
    `Done. ${toPrune.length} dropped, ${total - toPrune.length} remaining.`,
  )
} finally {
  await client.end()
}
