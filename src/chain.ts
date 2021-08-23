import { statSync } from "fs"
import { Account } from "near-api-js"
import path from "path"
import { asyncReadFile } from "./helpers"

export async function deployContract(name: string, account: Account): Promise<Contract> {
  const contract = await readContract(name)

  const buffer = contract.payload.buffer
  const data = new Uint8Array(buffer, 0, buffer.byteLength)

  const outcome = await account.deployContract(data)
  console.log(`Contract ${name} deployed (transaction ${outcome.transaction.hash})`)

  return contract
}

type Contract = {
  name: string
  path: string
  payload: Buffer
}

export async function readContract(name: string): Promise<Contract> {
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
