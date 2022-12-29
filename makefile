-include .env
.EXPORT_ALL_VARIABLES:

FOUNDRY_BLOCK_NUMBER=36992329
FOUNDRY_ETH_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}

test:
	forge test -vv

storage-check:
	forge inspect src/WeSplit.sol:WeSplit storage-layout --pretty | awk -F\| 'NR>2 {$$7=""; print $$0}' > layout/WeSplit.layout
	forge inspect src/WeSplitProxy.sol:WeSplitProxy storage-layout --pretty | awk -F\| 'NR>2 {$$7=""; print $$0}' > layout/WeSplitProxy.layout
	if ! diff -u layout/reference.layout layout/WeSplit.layout; then false; fi
	if ! diff -u layout/reference.layout layout/WeSplitProxy.layout; then false; fi

build:
	forge build --force --sizes

deploy:
	forge script script/DeployWeSplit.sol --private-key ${PRIVATE_KEY} --broadcast --etherscan-api-key ${POLYGONSCAN_API_KEY} --verify

verify:
	forge verify-contract --chain 137 --watch --constructor-args ${ENCODED_CONSTRUCTOR_ARGS} ${ADDRESS} WeSplit ${POLYGONSCAN_API_KEY}

gasprice:
	cast gas-price --rpc-url ${FOUNDRY_ETH_RPC_URL}

.PHONY: test build deploy verify
