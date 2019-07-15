# Fuse Network Validators App

Network validators, as part of their validating responsibilities, need to run this app along side the Parity node.

This app is responsible for calling the `emitInitiateChange` function on the `Consensus` contract.

The function is responsible for emitting the `InitiateChange` event [described in Parity Wiki](https://wiki.parity.io/Validator-Set.html#non-reporting-contract).
After this function is called successfully the validator set changes to a new one.

All the validators call this function and only the first call is successful, but there's no loss of gas because this function is called using a zero-gas transaction.

When running the [quickstart script](https://github.com/ColuLocalNetwork/fuse-network/blob/master#quickstart) as valiadtor, this app is run automatically.

It can be started manually as well:
```
$ docker run --detach --name fuseapp --volume /home/fuse/fusenet/config:/config --restart=on-failure fusenetwork/fuseapp
```

Note that `/home/fuse/fusenet/config` is the folder where the key file and `pass.pwd` of the validator account should be placed. This is the default location for the quickstart script so there shouldn't be any problems there.