import type { Block, FieldElement, Filter, TransactionWithReceipt } from 'https://esm.sh/@apibara/indexer/starknet'
import type { Config, Finality, NetworkOptions } from 'https://esm.sh/@apibara/indexer'
import type { Console } from 'https://esm.sh/@apibara/indexer/sink/console'
import type { Postgres } from 'https://esm.sh/@apibara/indexer/sink/postgres'

const commonConfig = {
	streamUrl: 'https://mainnet.starknet.a5a.ch',
	startingBlock: 642_235,
	network: 'starknet',
	finality: 'DATA_STATUS_ACCEPTED' as Finality,
	filter: {
		transactions: [{}],
		header: {},
	},
}

export const config: Config<NetworkOptions, Postgres> = {
	...commonConfig,
	sinkType: 'postgres',
	sinkOptions: {
		tableName: 'starkflare_api.transactions',
		connectionString: 'postgresql://postgres:password@localhost:5432/postgres',
	},
}

// export const config: Config<NetworkOptions, Console> = {
// 	...commonConfig,
// 	sinkType: 'console',
// 	sinkOptions: {},
// }

interface Transaction {
	hash: string
	block_number: number
	timestamp: number
	steps_number: number
	sender_address: string
}

export default function transform(block: Block): Transaction[] {
	if (!block.transactions || !block.header || !block.header.blockNumber || !block.header.timestamp) return []
	const block_number = parseInt(block.header.blockNumber)
	const timestamp = parseDateTimeToSeconds(block.header.timestamp)
	return block.transactions.reduce((acc: Transaction[], tx) => {
		const transformedTx = transformTransaction({ tx, block_number, timestamp })
		if (transformedTx) acc.push(transformedTx)
		return acc
	}, [])
}

function transformTransaction({ tx, block_number, timestamp }: { tx: TransactionWithReceipt; block_number: number; timestamp: number }): Transaction | null {
	if (tx.transaction.meta.hash && tx.receipt.executionResources?.computation?.steps) {
		const steps_number = tx.receipt.executionResources.computation.steps
		const hash = tx.transaction.meta.hash
		const sender_address = extractSenderAddress(tx)
		if (!sender_address) return null
		return { hash, block_number, timestamp, steps_number, sender_address }
	}
	return null
}

function extractSenderAddress(tx: TransactionWithReceipt) {
	return tx.transaction.invokeV1?.senderAddress || tx.transaction.invokeV3?.senderAddress || tx.transaction.invokeV0?.contractAddress || null
}

function parseDateTimeToSeconds(dateTime: string): number {
	return Math.floor(new Date(dateTime).getTime() / 1000)
}
