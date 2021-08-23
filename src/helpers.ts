import { readFile } from "fs"
import { promisify } from "util"

export const asyncReadFile = promisify(readFile)

export function requireProcessEnv(name: string): string {
  const value = process.env[name]
  if (value == null) {
    console.error(`environment variable ${name} required`)
    process.exit(1)
  }

  return value!
}
