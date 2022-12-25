-include .env
.EXPORT_ALL_VARIABLES:

FOUNDRY_BLOCK_NUMBER=36992329
FOUNDRY_ETH_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}

test:
	forge test -vvv

build:
	forge build --force --sizes

deploy:
	forge script script/DeploySpleth.sol --private-key ${PRIVATE_KEY} --broadcast 

.PHONY: test build deploy
