import BN from "bn.js"
import { statSync } from "fs"
import { Account } from "near-api-js"
import { FunctionCallOptions as NearFunctionCallOptions } from "near-api-js/lib/account"
import { ExecutionOutcomeWithId, FinalExecutionOutcome } from "near-api-js/lib/providers"
import {
  deployContract as nearDeployContract,
  functionCall as nearFunctionCall,
} from "near-api-js/lib/transaction"

import path from "path"
import { asyncReadFile } from "./helpers"

export async function deployContract(
  name: string,
  account: Account,
  options: { initArgs?: object } = {}
): Promise<Contract> {
  const contractFile = await readContract(name)

  const buffer = contractFile.payload.buffer
  const data = new Uint8Array(buffer, 0, buffer.byteLength)

  let actions = [nearDeployContract(data)]
  if (options.initArgs !== undefined) {
    actions.push(nearFunctionCall("new", options.initArgs, new BN(1_000_000_000), new BN(0)))
  }

  // @ts-ignore Protected but let's don't care for now and make your way through anyway
  const outcome = await account.signAndSendTransaction({
    receiverId: account.accountId,
    actions: actions,
  })

  console.log(`Contract ${name} deployed (transaction ${outcome.transaction.hash})`)
  return new Contract(name, account)
}

export class Contract {
  constructor(public name: string, public account: Account) {}

  async functionCall(
    name: string,
    args: object | Uint8Array,
    options: { gas?: BN; deposit?: BN } = {}
  ): Promise<FinalExecutionOutcome> {
    return this.account.functionCall({
      contractId: this.account.accountId,
      methodName: name,
      args: args,
      attachedDeposit: options.deposit,
      gas: options.gas,
    })
  }
}

type ContractFile = {
  name: string
  path: string
  payload: Buffer
}

export async function readContract(name: string): Promise<ContractFile> {
  const contractPath = path.join(__dirname, "..", "contracts", "build", `${name}.wasm`)
  if (!fileExists(contractPath)) {
    throw new Error(`the contract ${name} (at path ${contractPath}) does not exist`)
  }

  const buffer = await asyncReadFile(contractPath)

  return {
    name,
    path: contractPath,
    payload: buffer,
  }
}

export function fileExists(path: string) {
  const stat = statSync(path)

  return stat.isFile
}
