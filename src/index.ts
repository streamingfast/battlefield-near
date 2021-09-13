import BN from "bn.js"
import { connect, keyStores, utils } from "near-api-js"
import { NearConfig } from "near-api-js/lib/near"
import * as path from "path"
import { deployContract } from "./chain"
import { okTrx } from "./helpers"

const networkId = "local"

const rootPath = path.join(__dirname, "..")
const keyStorePath = path.join(rootPath, "boot", "local", "keystore")
const keyStore = new keyStores.UnencryptedFileSystemKeyStore(keyStorePath)

const config: NearConfig = {
  networkId,
  nodeUrl: "http://localhost:3030",
}

async function main() {
  console.log("Starting")

  const near = await connect({ ...config, keyStore, masterAccount: "near" })
  const battlefieldNearKeyPair = await keyStore.getKey(networkId, "battlefield.near")
  const bobNearKeyPair = await keyStore.getKey(networkId, "bob.near")
  const repeat = process.argv.some((arg) => arg === "--repeat")

  console.log("Account commands")
  // FIXME: Promisfy.All + expand results to speed up stuff!
  const battlefieldNear = await near.createAccount(
    "battlefield.near",
    battlefieldNearKeyPair.getPublicKey()
  )
  const bobNear = await near.createAccount("bob.near", bobNearKeyPair.getPublicKey())

  console.log("Contract commands")
  const battlefieldContract = await deployContract("battlefield", battlefieldNear)

  let i = 0
  do {
    console.log("Transfer commands")
    await okTrx("transfer: tiny amount", bobNear.sendMoney("near", nearAmount("0.0001")))

    console.log("Function Calls & Args")
    await Promise.allSettled([
      okTrx(
        "function: standard counter",
        battlefieldContract.functionCall(battlefieldCounterMethod(i), {})
      ),

      okTrx(
        "function: add to file",
        battlefieldContract.functionCall("add_file", {
          name: `file #${i}`,
        })
      ),

      okTrx(
        "function: providing args where not expected",
        battlefieldContract.functionCall("no_args", {
          name: `file #${i}`,
          complex: {
            value: "multi",
          },
        })
      ),
    ])

    console.log("Failure(s)")
    await Promise.allSettled([
      battlefieldNear.functionCall({
        contractId: battlefieldNear.accountId,
        methodName: "does_not_exist_understood?",
        args: {
          name: `file #${i}`,
          complex: {
            value: "multi",
          },
        },
      }),

      battlefieldNear.functionCall({
        contractId: battlefieldNear.accountId,
        methodName: "payable_no_annotation",
        args: {},
        attachedDeposit: nearAmount("0.0001"),
      }),
    ]),
      i++
  } while (repeat)

  // FIXME: Think about moving those into a log file directly
  // console.log(prettify(outcome));

  // echo "Account commands" | tee -a "$near_log_file"
  // $near_cmd --masterAccount near --keyPath "${keys}/near.json" --publicKey "$(public_key ${keys}/bob.near.json)" create-account bob.near 1>> "$near_log_file"
  // sleep 1s
  // echo "" >> "$near_log_file"

  // echo "Transfer commands" | tee -a "$near_log_file"

  // Trying to have a 0 balance here, the gas cost for a transfer is 453060601875000000000, so
  // `math "100000000000000000000000000 - 453060601875000000000" == 99999546939398125000000000. When this exact
  // amount is transferred (i.e. `99.999546939398125`), the chain complains that not enough Near are available
  // to cover the state storage of 182 (in bytes?). It says 1820000000000000000000 yoctoNEAR more are required
  // to cover the state storage for the account.
  //
  // The following value transfer below generates the message above
  // $near_cmd --masterAccount near --keyPath "${keys}/bob.near.json" send bob.near near 99.999546939398125 1>> "$near_log_file"
  //
  // This one leads to account with `1826695476875000000000` while I wanted to left the account with `1820000000000000000000`
  // $near_cmd --masterAccount near --keyPath "${keys}/bob.near.json" send bob.near near 99.997726939398125 1>> "$near_log_file"
  //

  console.log("Completed transactions")
}

function nearAmount(value: number | string): BN {
  let input: string
  if (typeof value === "number") {
    input = value.toFixed()
  } else {
    input = value
  }

  const amount = utils.format.parseNearAmount(input)
  if (amount == null) {
    throw new Error(`invalid transfer amount ${value}`)
  }

  return new BN(amount)
}

function battlefieldCounterMethod(i: number) {
  if (i <= 12) {
    return i % 2 == 0 ? "increment" : "decrement"
  }

  return "reset"
}

function prettify(data: any): String {
  return JSON.stringify(data, null, "  ")
}

main()
  .catch((error) => {
    console.log("An error occurred", error)
  })
  .finally(() => {
    console.log("Terminated")
  })
