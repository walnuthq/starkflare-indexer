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
		tableName: 'starkflare_api.account_calls',
	},
}

// export const config: Config<NetworkOptions, Console> = {
// 	...commonConfig,
// 	sinkType: 'console',
// 	sinkOptions: {},
// }

interface AccountCall {
	id: string
	tx_hash: string
	block_number: number
	timestamp: number
	steps_number: number
	sender_address: string
	l1_gas: number
	l1_data_gas: number
	tx_version: number
	contract_address: string
	entrypoint_selector: string
}

export default function transform(block: Block): AccountCall[] {
	if (!block.transactions || !block.header || !block.header.blockNumber || !block.header.timestamp) return []
	const blockNumber = parseInt(block.header.blockNumber)
	const timestamp = parseDateTimeToSeconds(block.header.timestamp)
	return block.transactions.reduce((acc: AccountCall[], tx) => {
		const accountCalls = getAccountCalls({ tx, blockNumber, timestamp })
		acc = acc.concat(accountCalls)
		return acc
	}, [])
}

// TODO: get account calls for tx version 0
function getAccountCalls({ tx, blockNumber, timestamp }: { tx: TransactionWithReceipt; blockNumber: number; timestamp: number }): AccountCall[] {
	const txHash = tx.transaction.meta.hash
	const stepsNumber = tx.receipt.executionResources?.computation?.steps
	const dataAvailability = tx.receipt.executionResources?.dataAvailability
	const txVersion = tx.transaction.meta.version ? parseInt(tx.transaction.meta.version) : undefined
	if (txHash && txVersion && stepsNumber && dataAvailability) {
		const l1Gas = dataAvailability.l1Gas ?? 0
		const l1DataGas = dataAvailability.l1DataGas ?? 0

		let senderAddress: string | undefined
		let calldata: string[] | undefined

		if (txVersion === 1 && tx.transaction.invokeV1) {
			senderAddress = tx.transaction.invokeV1.senderAddress
			calldata = tx.transaction.invokeV1.calldata
		} else if (txVersion === 3 && tx.transaction.invokeV3) {
			senderAddress = tx.transaction.invokeV3.senderAddress
			calldata = tx.transaction.invokeV3.calldata
		} else {
			return []
		}

		if (!senderAddress || !calldata) return []

		return parseCalldata(calldata).map(({ contractAddress, entrypointSelector }, i) => {
			const accountCall: AccountCall = {
				id: `${txHash}_${i}`,
				tx_hash: txHash,
				block_number: blockNumber,
				timestamp,
				steps_number: stepsNumber,
				sender_address: senderAddress,
				l1_gas: l1Gas,
				l1_data_gas: l1DataGas,
				tx_version: txVersion,
				contract_address: contractAddress,
				entrypoint_selector: entrypointSelector,
			}
			return accountCall
		})
	}
	return []
}

function parseCalldata(calldata: string[]): { contractAddress: string; entrypointSelector: string }[] {
	try {
		return parseCalldataVariant1(calldata)
	} catch {
		return parseCalldataVariant2(calldata)
	}
}

function parseCalldataVariant1(calldata: string[]): { contractAddress: string; entrypointSelector: string }[] {
	const result: { contractAddress: string; entrypointSelector: string }[] = []

	let index = 0
	const numberOfCalls = parseInt(calldata[index], 16)
	index++

	let lastDataOffset = 0

	for (let i = 0; i < numberOfCalls; i++) {
		const contractAddress = calldata[index]
		index++

		const entrypointSelector = calldata[index]
		index++

		const dataOffset = parseInt(calldata[index], 16)
		index++

		if (dataOffset !== lastDataOffset) throw new Error('Data offset mismatch')

		const dataLen = parseInt(calldata[index], 16)
		index++

		lastDataOffset += dataLen

		result.push({ contractAddress: contractAddress, entrypointSelector: entrypointSelector })
	}

	return result
}

function parseCalldataVariant2(calldata: string[]): { contractAddress: string; entrypointSelector: string }[] {
	const result: { contractAddress: string; entrypointSelector: string }[] = []

	let index = 0
	const numberOfCalls = parseInt(calldata[index], 16)
	index++

	for (let i = 0; i < numberOfCalls; i++) {
		const contractAddress = calldata[index]
		index++

		const entrypointSelector = calldata[index]
		index++

		const numberOfDataElements = parseInt(calldata[index], 16)
		index++

		// Skip the data elements
		index += numberOfDataElements

		result.push({ contractAddress: contractAddress, entrypointSelector: entrypointSelector })
	}

	return result
}

function parseDateTimeToSeconds(dateTime: string): number {
	return Math.floor(new Date(dateTime).getTime() / 1000)
}
