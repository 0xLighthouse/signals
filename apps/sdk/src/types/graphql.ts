export type Maybe<T> = T | null
export type InputMaybe<T> = Maybe<T>
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] }
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> }
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> }
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = {
  [_ in K]?: never
}
export type Incremental<T> =
  | T
  | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never }
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string }
  String: { input: string; output: string }
  Boolean: { input: boolean; output: boolean }
  Int: { input: number; output: number }
  Float: { input: number; output: number }
  BigInt: { input: any; output: any }
  JSON: { input: any; output: any }
}

export type FactoryCreatedEvent = {
  __typename?: 'FactoryCreatedEvent'
  blockTimestamp: Scalars['BigInt']['output']
  chainId: Scalars['Int']['output']
  id: Scalars['String']['output']
  newSignals: Scalars['String']['output']
  owner: Scalars['String']['output']
  transactionHash: Scalars['String']['output']
}

export type FactoryCreatedEventFilter = {
  AND?: InputMaybe<Array<InputMaybe<FactoryCreatedEventFilter>>>
  OR?: InputMaybe<Array<InputMaybe<FactoryCreatedEventFilter>>>
  blockTimestamp?: InputMaybe<Scalars['BigInt']['input']>
  blockTimestamp_gt?: InputMaybe<Scalars['BigInt']['input']>
  blockTimestamp_gte?: InputMaybe<Scalars['BigInt']['input']>
  blockTimestamp_in?: InputMaybe<Array<InputMaybe<Scalars['BigInt']['input']>>>
  blockTimestamp_lt?: InputMaybe<Scalars['BigInt']['input']>
  blockTimestamp_lte?: InputMaybe<Scalars['BigInt']['input']>
  blockTimestamp_not?: InputMaybe<Scalars['BigInt']['input']>
  blockTimestamp_not_in?: InputMaybe<Array<InputMaybe<Scalars['BigInt']['input']>>>
  chainId?: InputMaybe<Scalars['Int']['input']>
  chainId_gt?: InputMaybe<Scalars['Int']['input']>
  chainId_gte?: InputMaybe<Scalars['Int']['input']>
  chainId_in?: InputMaybe<Array<InputMaybe<Scalars['Int']['input']>>>
  chainId_lt?: InputMaybe<Scalars['Int']['input']>
  chainId_lte?: InputMaybe<Scalars['Int']['input']>
  chainId_not?: InputMaybe<Scalars['Int']['input']>
  chainId_not_in?: InputMaybe<Array<InputMaybe<Scalars['Int']['input']>>>
  id?: InputMaybe<Scalars['String']['input']>
  id_contains?: InputMaybe<Scalars['String']['input']>
  id_ends_with?: InputMaybe<Scalars['String']['input']>
  id_in?: InputMaybe<Array<InputMaybe<Scalars['String']['input']>>>
  id_not?: InputMaybe<Scalars['String']['input']>
  id_not_contains?: InputMaybe<Scalars['String']['input']>
  id_not_ends_with?: InputMaybe<Scalars['String']['input']>
  id_not_in?: InputMaybe<Array<InputMaybe<Scalars['String']['input']>>>
  id_not_starts_with?: InputMaybe<Scalars['String']['input']>
  id_starts_with?: InputMaybe<Scalars['String']['input']>
  newSignals?: InputMaybe<Scalars['String']['input']>
  newSignals_contains?: InputMaybe<Scalars['String']['input']>
  newSignals_ends_with?: InputMaybe<Scalars['String']['input']>
  newSignals_in?: InputMaybe<Array<InputMaybe<Scalars['String']['input']>>>
  newSignals_not?: InputMaybe<Scalars['String']['input']>
  newSignals_not_contains?: InputMaybe<Scalars['String']['input']>
  newSignals_not_ends_with?: InputMaybe<Scalars['String']['input']>
  newSignals_not_in?: InputMaybe<Array<InputMaybe<Scalars['String']['input']>>>
  newSignals_not_starts_with?: InputMaybe<Scalars['String']['input']>
  newSignals_starts_with?: InputMaybe<Scalars['String']['input']>
  owner?: InputMaybe<Scalars['String']['input']>
  owner_contains?: InputMaybe<Scalars['String']['input']>
  owner_ends_with?: InputMaybe<Scalars['String']['input']>
  owner_in?: InputMaybe<Array<InputMaybe<Scalars['String']['input']>>>
  owner_not?: InputMaybe<Scalars['String']['input']>
  owner_not_contains?: InputMaybe<Scalars['String']['input']>
  owner_not_ends_with?: InputMaybe<Scalars['String']['input']>
  owner_not_in?: InputMaybe<Array<InputMaybe<Scalars['String']['input']>>>
  owner_not_starts_with?: InputMaybe<Scalars['String']['input']>
  owner_starts_with?: InputMaybe<Scalars['String']['input']>
  transactionHash?: InputMaybe<Scalars['String']['input']>
  transactionHash_contains?: InputMaybe<Scalars['String']['input']>
  transactionHash_ends_with?: InputMaybe<Scalars['String']['input']>
  transactionHash_in?: InputMaybe<Array<InputMaybe<Scalars['String']['input']>>>
  transactionHash_not?: InputMaybe<Scalars['String']['input']>
  transactionHash_not_contains?: InputMaybe<Scalars['String']['input']>
  transactionHash_not_ends_with?: InputMaybe<Scalars['String']['input']>
  transactionHash_not_in?: InputMaybe<Array<InputMaybe<Scalars['String']['input']>>>
  transactionHash_not_starts_with?: InputMaybe<Scalars['String']['input']>
  transactionHash_starts_with?: InputMaybe<Scalars['String']['input']>
}

export type FactoryCreatedEventPage = {
  __typename?: 'FactoryCreatedEventPage'
  items: Array<FactoryCreatedEvent>
  pageInfo: PageInfo
  totalCount: Scalars['Int']['output']
}

export type Meta = {
  __typename?: 'Meta'
  status?: Maybe<Scalars['JSON']['output']>
}

export type PageInfo = {
  __typename?: 'PageInfo'
  endCursor?: Maybe<Scalars['String']['output']>
  hasNextPage: Scalars['Boolean']['output']
  hasPreviousPage: Scalars['Boolean']['output']
  startCursor?: Maybe<Scalars['String']['output']>
}

export type Query = {
  __typename?: 'Query'
  _meta?: Maybe<Meta>
  factoryCreatedEvent?: Maybe<FactoryCreatedEvent>
  factoryCreatedEvents: FactoryCreatedEventPage
}

export type QueryFactoryCreatedEventArgs = {
  id: Scalars['String']['input']
}

export type QueryFactoryCreatedEventsArgs = {
  after?: InputMaybe<Scalars['String']['input']>
  before?: InputMaybe<Scalars['String']['input']>
  limit?: InputMaybe<Scalars['Int']['input']>
  orderBy?: InputMaybe<Scalars['String']['input']>
  orderDirection?: InputMaybe<Scalars['String']['input']>
  where?: InputMaybe<FactoryCreatedEventFilter>
}

export type BoardsByChainIdQueryVariables = Exact<{
  chainId?: InputMaybe<Scalars['Int']['input']>
}>

export type BoardsByChainIdQuery = {
  __typename?: 'Query'
  factoryCreatedEvents: {
    __typename?: 'FactoryCreatedEventPage'
    items: Array<{
      __typename?: 'FactoryCreatedEvent'
      chainId: number
      newSignals: string
      owner: string
      transactionHash: string
      blockTimestamp: any
    }>
  }
}
