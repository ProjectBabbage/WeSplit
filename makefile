-include .env
.EXPORT_ALL_VARIABLES:

FOUNDRY_BLOCK_NUMBER=16000000
FOUNDRY_ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}

test:
	forge test -vvv

.PHONY: test
