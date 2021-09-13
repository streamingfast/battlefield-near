import { readFile } from "fs"
import {
  ExecutionOutcomeWithId,
  FinalExecutionOutcome,
  JsonRpcProvider,
} from "near-api-js/lib/providers"
import { stringify } from "querystring"
import { promisify } from "util"

const trace = process.env["TRACE"] === "true"

export const asyncReadFile = promisify(readFile)

export async function okTrx(tag: string, promise: Promise<FinalExecutionOutcome>) {
  let receipt: FinalExecutionOutcome
  try {
    receipt = await promise
  } catch (error) {
    throw new Error("An unexpected error occurred")
  }

  if (trace) {
    console.log(JSON.stringify(receipt, null, "  "))
  }

  if (receipt.status == "Failure") {
    console.log(`KO | ${tag} (${finalExecutionOutput(receipt)})`)
    throw new Error(`Unxpected failure for ${tag}, expected a success`)
  }

  console.log(`OK | ${tag} (${finalExecutionOutput(receipt)})`)
}

export function requireProcessEnv(name: string): string {
  const value = process.env[name]
  if (value == null) {
    console.error(`environment variable ${name} required`)
    process.exit(1)
  }

  return value!
}

export function finalExecutionOutput(outcome: FinalExecutionOutcome): String {
  const receipts = outcome.receipts_outcome
    .map((value) => `{${receiptExecutionOutcome(value)}}`)
    .join(", ")

  return `Trx ${transactionHash(outcome.transaction)} [${
    outcome.receipts_outcome.length
  } receipts: ${receipts}]`
}

export function receiptExecutionOutcome(outcome: ExecutionOutcomeWithId): String {
  let parts = []
  const status = outcome.outcome.status
  if (typeof status === "object") {
    if (status.Failure) {
      parts.push(
        `${outcome.id} failed (${status.Failure.error_type}: ${status.Failure.error_message})`
      )
    } else {
      let success = `${outcome.id} succeed`
      if (status.SuccessReceiptId) {
        success += ` => ${status.SuccessReceiptId})`
      }

      if (status.SuccessValue) {
        if (!status.SuccessReceiptId) {
          success += ` =>`
        }

        success += ` returned ${status.SuccessValue})`
      }

      parts.push(success)
    }
  }

  if (outcome.outcome.receipt_ids.length > 0) {
    parts.push(`[${outcome.outcome.receipt_ids.join(",")}]`)
  }

  return parts.join(" ")
}

export function transactionHash(transaction: any) {
  if (transaction.hash) {
    return transaction.hash
  }

  return "N/A"
}
