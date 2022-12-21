-include .env
.EXPORT_ALL_VARIABLES:

FOUNDRY_BLOCK_NUMBER=36992329
FOUNDRY_ETH_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}

test:
	forge test -vvv

build:
	forge build --force --sizes

create:
	forge create --mnemonic ${MNEMONIC_PATH} src/Spleth.sol:Spleth --constructor-args ${CONSTRUCTOR_ARGS}

deploy:
	forge script --mnemonics ${MNEMONIC_PATH} script/DeploySpleth.sol --target-contract DeploySpleth --broadcast --sender 0x6d0acdde929e5e1f33dc11bde288af36f5423bde

.PHONY: test build create deploy
