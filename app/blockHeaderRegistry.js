const path = require("path");
const logger = require("pino")({
    level: process.env.LOG_LEVEL || "info",
    prettyPrint: { translateTime: true },
});
const Web3 = require("web3");
const ethers = require("ethers");
const { sign, signFuse } = require("./utils");

const blockchains = {};

function initBlockchain({
    consensus,
    blockRegistry,
    signer,
    walletProvider,
    chainId,
    rpc,
}) {
    logger.info("initBlockchain");
    try {
        blockchains[chainId] = {
            account: walletProvider.addresses[0],
            web3: new Web3(walletProvider),
            rpc,
            signer: new ethers.Wallet(pkey),
            blocks: {},
        };
        blockchains[chainId].web3.eth.subscribe(
            "newBlockHeaders",
            async (block) => {
                try {
                    if (chainId == 122) {
                        let cycleEnd = (
                            await consensus.methods.getCurrentCycleEndBlock.call()
                        ).toNumber();
                        let validators = await consensus.methods
                            .currentValidators()
                            .call();
                        blockchains[chainId].blocks[block.hash] =
                            await signFuse(
                                block,
                                chainId,
                                blockchain.rpc,
                                blockchain.signer,
                                cycleEnd,
                                validators
                            );
                    } else {
                        blockchains[chainId].blocks[block.hash] = await sign(
                            block,
                            chainId,
                            blockchain.provider,
                            blockchain.signer
                        );
                    }
                } catch (e) {
                    logger.error(`newBlockHeaders: ${e.toString()}`);
                }
            }
        );
    } catch (e) {
        throw `initBlockchain(${chainId}, ${rpc}) failed: ${e.toString()}`;
    }
}

async function emitRegistry({
    consensus,
    blockRegistry,
    walletProvider,
    signer,
    web3,
}) {
    try {
        logger.info("emitRegistry");
        const currentBlock = (await web3.eth.getBlockNumber()).toNumber();
        const numRpcs = (
            await blockRegistry.methods.getRpcsLength().call()
        ).toNumber();
        const chains = await Promise.all(
            new Array(numRpcs).map(
                async (_, i) => await blockRegistry.methods.rpcs(i)
            )
        );
        await Promise.all(
            chains
                .filter(
                    (chain) =>
                        !blockchains[chain[0]] ||
                        blockchains[chain[0]].rpc != chain[1]
                )
                .map(async (chain) =>
                    initBlockchain({
                        consensus,
                        blockRegistry,
                        signer,
                        walletProvider,
                        chainId: chain[0],
                        rpc: chain[1],
                    })
                )
        );
        const blocks = {};
        const chainIds = {};
        Object.entries(blockchains).forEach((chainId, blockchain) => {
            Object.entries(blockchain.blocks).forEach((hash, signed) => {
                blocks[hash] = signed;
                chainIds[hash] = chainId;
                delete blockchain.blocks[hash];
            });
        });
    } catch (e) {
        throw `emitRegistry failed trying to update rpcs`;
    }
    try {
        const receipt = await blockRegistry.methods
            .addSignedBlocks(Object.values(blocks))
            .send({ from: account });
        logger.info(`transactionHash: ${receipt.transactionHash}`);
        logger.debug(`receipt: ${JSON.stringify(receipt)}`);
    } catch (e) {
        if (!e.data) throw e;
        else {
            logger.error(e);
            const data = e.data;
            const txHash = Object.keys(data)[0];
            const reason = data[txHash].reason;
            Object.entries(blocks)
                .filter((hash, signed) => hash != reason)
                .forEach(
                    (hash, signed) =>
                        (blockchains[chainIds[hash]].blocks[hash] = signed)
                );
        }
    }
}

module.exports = { initBlockchain, emitRegistry, blockchains }
