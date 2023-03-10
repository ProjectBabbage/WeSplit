# WeSplit

Split expenses automatically.

## Use it

WeSplit is [available on polygonscan](https://polygonscan.com/address/0x52decE2Fd883628eA46eBae183cd9D78a81Ef916#writeProxyContract) !

1. `create` a split with all the participants (don't forget to include yourself)
2. `initialize` a transaction with the receiver and the total amount of token you want to send
3. everyone should `approve` the transaction
4. funds are splitted and sent automatically !

For convenience, the functions `initializeApprove` and `createInitializeApprove` group multiple actions together.

## Develop

Fill the `.env` file with appropriate env variables, see `.env.example` for a list of variables.

Test the project by running `make test`.
