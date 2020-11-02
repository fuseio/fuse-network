var BN = require('bn.js');

var gasToUse = 0x47E7C4;

function receiptShouldSucceed(result) {
    return new Promise(function(resolve, reject) {
        var receipt = web3.eth.getTransaction(result.tx);

        if(result.receipt.gasUsed == gasToUse) {
            try {
                assert.notEqual(result.receipt.gasUsed, gasToUse, "tx failed, used all gas");
            }
            catch(err) {
                reject(err);
            }
        }
        else {
            resolve();
        }
    });
}

function receiptShouldFailed(result) {
    return new Promise(function(resolve, reject) {
        var receipt = web3.eth.getTransaction(result.tx);

        if(result.receipt.gasUsed == gasToUse) {
            resolve();
        }
        else {
            try {
                assert.equal(result.receipt.gasUsed, gasToUse, "tx succeed, used not all gas");
            }
            catch(err) {
                reject(err);
            }
        }
    });
}

function catchReceiptShouldFailed(err) {
    if (err.message.indexOf("invalid opcode") == -1 && err.message.indexOf("revert") == -1) {
        throw err;
    }
}

function receiptShouldSucceedS(receipt) {
    return new Promise(function(resolve, reject) {
        if(receipt.gasUsed == gasToUse) {
            try {
                assert.notEqual(receipt.gasUsed, gasToUse, "tx failed, used all gas");
            }
            catch(err) {
                reject(err);
            }
        }
        else {
            resolve();
        }
    });
}

function receiptShouldFailedS(receipt) {
    return new Promise(function(resolve, reject) {
        if(receipt.gasUsed == gasToUse) {
            resolve();
        }
        else {
            try {
                assert.equal(receipt.gasUsed, gasToUse, "tx succeed, used not all gas");
            }
            catch(err) {
                reject(err);
            }
        }
    });
}


function balanceShouldEqualTo(instance, address, expectedBalance, notCall) {
    return new Promise(function(resolve, reject) {
        var promise;

        if(notCall) {
            promise = instance.balanceOf(address)
                .then(function() {
                    return instance.balanceOf.call(address);
                });
        }
        else {
            promise = instance.balanceOf.call(address);
        }

        promise.then(function(balance) {
            try {
                assert.equal(balance.valueOf(), expectedBalance, "balance is not equal");
            }
            catch(err) {
                reject(err);

                return;
            }

            resolve();
        });
    });
}

function getDividend(instance, id) {
    return instance.dividends.call(id)
        .then(function(obj) {
            return {
                id: obj[0].valueOf(),
                block: obj[1].valueOf(),
                time: obj[2].valueOf(),
                amount: obj[3].valueOf(),

                claimedAmount: obj[4].valueOf(),
                transferedBack: obj[5].valueOf(),

                totalSupply: obj[6].valueOf(),
                recycleTime: obj[7].valueOf(),

                recycled: obj[8],

                claimed: obj[9]
            }
        });
}

function checkDividend(dividend, id, amount, claimedAmount, transferedBack, totalSupply, recycleTime, recycled) {
    return new Promise(function(resolve, reject) {
        try {
            assert.equal(dividend.id, id, "dividend id is not equal");
            assert.equal(dividend.amount, amount, "dividend amount id is not equal");
            assert.equal(dividend.claimedAmount, claimedAmount, "dividend claimed amount is not equal");
            assert.equal(dividend.transferedBack, transferedBack, "dividend transfered back is not equal");
            assert.equal(dividend.totalSupply, totalSupply, "dividend total supply is not equal");
            assert.equal(dividend.recycleTime, recycleTime, "dividend recycle time is not equal");
            assert.equal(dividend.recycled, recycled, "dividend recycled is not equal");

            resolve();
        }
        catch(err) {
            reject(err);
        }
    });
}

function getEmission(instance, id) {
    "use strict";

    return instance.emissions.call(id)
        .then(function(obj) {
            return {
                blockDuration: obj[0].valueOf(),
                blockTokens: obj[1].valueOf(),
                periodEndsAt: obj[2].valueOf(),
                removed: obj[3].valueOf()
            }
        });
}

function checkEmission(emission, blockDuration, blockTokens, periodEndsAt, removed) {
    "use strict";

    return new Promise(function(resolve, reject) {
        try {
            assert.equal(emission.blockDuration, blockDuration, "emission blockDuration is not equal");
            assert.equal(emission.blockTokens, blockTokens, "emission blockTokens is not equal");
            assert.equal(emission.periodEndsAt, periodEndsAt, "emission periodEndsAt is not equal");
            assert.equal(emission.removed, removed, "emission removed is not equal");

            resolve();
        }
        catch(err) {
            reject(err);
        }
    });
}

function checkClaimedTokensAmount(instance, offsetDate, lastClaimedAt, currentTime, currentBalance, totalSupply, expectedValue) {
    return instance.calculateEmissionTokens(offsetDate + lastClaimedAt, offsetDate + currentTime, currentBalance, totalSupply)
        .then(function() {
            return instance.calculateEmissionTokens.call(offsetDate + lastClaimedAt, offsetDate + currentTime, currentBalance, totalSupply);
        })
        .then(function(result) {
            assert.equal(result.valueOf(), expectedValue.valueOf(), "amount is not equal");
        });
}

function getPhase(instance, id) {
    return instance.phases.call(id)
        .then(function(obj) {
            if(obj.length == 3) {
                return {
                    priceShouldMultiply: obj[0].valueOf(),
                    price: obj[1].valueOf(),
                    maxAmount: obj[2].valueOf(),
                }
            }

            return {
                price: obj[0].valueOf(),
                maxAmount: obj[1].valueOf(),
            }
        });
}

function checkPhase(phase, price, maxAmount) {
    return new Promise(function(resolve, reject) {
        try {
            assert.equal(phase.price, price, "phase price is not equal");
            assert.equal(phase.maxAmount, maxAmount, "phase maxAmount is not equal");

            resolve();
        }
        catch(err) {
            reject(err);
        }
    });
}

function timeout(timeout) {
    return new Promise(function(resolve, reject) {
        setTimeout(function() {
            resolve();
        }, timeout * 1000);
    })
}

function getEtherBalance(_address) {
    return web3.eth.getBalance(_address);
}

function checkEtherBalance(_address, expectedBalance) {
    var balance = web3.eth.getBalance(_address);

    assert.equal(balance.valueOf(), expectedBalance.valueOf(), "address balance is not equal");
}

function getTxCost(result) {
    var tx = web3.eth.getTransaction(result.tx);

    return result.receipt.gasUsed * tx.gasPrice;
}

async function timeJump(seconds) {
    return new Promise(function(resolve, reject) {
        web3.currentProvider.sendAsync({
                jsonrpc: "2.0",
                method: "evm_increaseTime",
                params: [ seconds ],
                id: new Date().getTime(),
            },
            function(error) {
                if (error) {
                    return reject(error);
                }

                web3.currentProvider.sendAsync(
                    {
                        jsonrpc: "2.0",
                        method: "evm_mine",
                        params: [],
                        id: new Date().getTime(),
                    },
                    (err2) => {
                        if (err2) return reject(err2);
                        resolve();
                    },
                );
            },
        );
    });
}

async function sendTransaction(contract, from, value, data, shouldFail) {
    try {
        await contract.sendTransaction({ from, value, data });

        if(shouldFail) {
            assert.fail("sendTransaction succeed");
        }
    }
    catch(err) {
        if(err.constructor.name == "AssertionError") {
            throw err;
        }

        if(!shouldFail) {
            throw err;
        }
    }
}

async function transferERC20(contract, from, to, tokens, shouldFail) {
    try {
        await contract.transfer(to, tokens, { from });

        if(shouldFail) {
            assert.fail("erc20 transfer succeed");
        }
    }
    catch(err) {
        if(err.constructor.name == "AssertionError") {
            throw err;
        }

        if(!shouldFail) {
            throw err;
        }
    }
}

async function balanceERC20(contract, holder, balance) {
    assert.equal(await contract.balanceOf(holder), balance, "erc20 balance is not equal");
}

async function testTransferFrom(contract, granter, grantee, to, tokens) {
    const granterBeforeBalance = await contract.balanceOf(granter);
    const granteeBeforeBalance = await contract.balanceOf(grantee);

    await contract.approve(grantee, tokens, { from: granter });

    // try to transfer more than allowed

    let trasnferFromResponse = await contract.transferFrom.call(granter, to, tokens + 1, {from: grantee});

    assert.equal(trasnferFromResponse.valueOf(), false, "transferFrom with exceding amount succeed");

    await contract.transferFrom(granter, to, tokens + 1, { from: grantee });

    await checkState({ contract }, {
        contract: {
            balanceOf: [
                {[granter]: granterBeforeBalance},
                {[grantee]: granteeBeforeBalance}
            ],
            allowance: {
                __val: tokens,
                _owner: granter,
                _spender: grantee
            }
        }
    });

    // try to transfer less than allowed
    transferFromResponse = await contract.transferFrom.call(granter, to, tokens / 2, { from: grantee });

    assert.equal(transferFromResponse, true, "transferFrom with lower amount failed");
    await contract.transferFrom(granter, to, tokens / 2, { from: grantee });

    await checkState({ contract }, {
        contract: {
            balanceOf: [
                { [granter]: new BN(granterBeforeBalance).sub(new BN(tokens).div(2)).valueOf() },
                { [to]: new BN(granteeBeforeBalance).add(new BN(tokens).div(2)).valueOf() }
            ],

            allowance: {
                __val: new BN(tokens).sub(new BN(tokens).div(2)).valueOf(),
                _owner: granter,
                _spender: grantee
            }
        }
    });
}

async function checkStateMethod(contract, contractId, stateId, args) {
    if(Array.isArray(args)) {
        for(let item of args) {
            await checkStateMethod(contract, contractId, stateId, item);
        }
    }
    else if(typeof args == "object" && args.constructor.name != "BN") {
        const keys = Object.keys(args);

        if(keys.length == 1) {
            const val = (await contract[stateId].call(keys[0])).valueOf();

            assert.equal(val, args[keys[0]],
                `Contract ${contractId} state ${stateId} with arg ${keys[0]} & value ${val} is not equal to ${args[keys[0]]}`);

            return;
        }

        const passArgs = [];

        if(! args.hasOwnProperty("__val")) {
            assert.fail(new Error("__val is not present"));
        }

        for(let arg of Object.keys(args)) {
            if(arg == "__val") {
                continue;
            }

            passArgs.push(args[arg]);
        }

        const val = (await contract[stateId].call( ...passArgs )).valueOf();

        assert.equal(val, args["__val"], `Contract ${contractId} state ${stateId} with value ${val} is not equal to ${args['__val']}`);
    }
    else {
        const val = (await contract[stateId].call()).valueOf();

        assert.equal(val, args, `Contract ${contractId} state ${stateId} with value ${val} is not equal to ${args.valueOf()}`);
    }
}

async function checkState(contracts, states) {
    for(let contractId in states) {
        if(! contracts.hasOwnProperty(contractId)) {
            assert.fail("no such contract " + contractId);
        }

        let contract = contracts[contractId];

        for(let stateId in states[contractId]) {
            if(! contract.hasOwnProperty(stateId)) {
                assert.fail("no such property " + stateId);
            }

            await checkStateMethod(contract, contractId, stateId, states[contractId][stateId]);
        }
    }
}

async function shouldFail(call) {
    try {
        await call;

        assert.fail("call succeed");
    }
    catch(err) {
        if(err.constructor.name == "AssertionError") {
            throw err;
        }
    }
}

module.exports = {
    receiptShouldSucceed: receiptShouldSucceed,
    receiptShouldFailed: receiptShouldFailed,
    receiptShouldSucceedS: receiptShouldSucceedS,
    receiptShouldFailedS: receiptShouldFailedS,
    catchReceiptShouldFailed: catchReceiptShouldFailed,
    balanceShouldEqualTo: balanceShouldEqualTo,
    getDividend: getDividend,
    checkDividend: checkDividend,
    getPhase: getPhase,
    checkPhase: checkPhase,
    getEmission: getEmission,
    checkEmission: checkEmission,
    checkClaimedTokensAmount: checkClaimedTokensAmount,
    timeout: timeout,
    getEtherBalance: getEtherBalance,
    checkEtherBalance: checkEtherBalance,
    getTxCost: getTxCost,
    timeJump: timeJump,

    sendTransaction: sendTransaction,

    checkState: checkState,

    shouldFail: shouldFail,

    // erc20
    erc20: {
        transfer: transferERC20,
        balanceShouldEqualTo: balanceERC20,
        test: {
            transferFrom: testTransferFrom
        }
    },
};