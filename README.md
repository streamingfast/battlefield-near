## NEAR - Battlefield

A repository containing contracts and scripts to effectively testing
all aspects of our NEAR instrumentation.

This repository assumes you have the following tool in available
globally through your terminal:

- neard (Firehose Instrumented)
- yarn (1.13+)
- jq

### Running

Running the whole battlefield test set is simply a matter of
first installing script dependencies (mainly near.js to interact
with the chain):

    yarn install

For now, a single thing can be done, launching a pre-configured chain and executing
some small transactions.

    ./bin/run_local.sh
