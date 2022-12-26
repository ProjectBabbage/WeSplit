# WeSplit

Split expenses automatically.

## Use it

WeSplit is [available on polygonscan](https://polygonscan.com/address/0x748610d5d3061411b00918c41907623dc55aede0#writeContract) !

1. `create` a split with all the participants (don't forget to include yourself)
2. `initialize` a transaction with the receiver and the total amount of token you want to send
3. everyone should `approve` the transaction
4. funds are splitted and sent automatically !

## Develop

Fill the `.env` file with appropriate env variables, see `.env.example` for a list of variables.

Test the project by running `make test`.
