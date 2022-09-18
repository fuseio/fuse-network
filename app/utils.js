const ethers = require('ethers')

export async function sign(header, chainId, signer) {
  const rlpHeader = hashHeader(header)
  const payload = ethers.utils.keccak256(rlpHeader);
  const { _vs: vs, r } = ethers.utils.splitSignature(
    await signer.signMessage(ethers.utils.arrayify(payload))
  );
  return [rlpHeader,[vs,r],chainId,payload,0,[]]
}
export function hashHeader(web3Header) {
  const rlpHeader = ethers.utils.RLP.encode(
    Object.values(header).map((v) => (v === 0 ? "0x" : v))
  );
  return rlpHeader
}

export async function signFuse(header, chainId, signer, cycleEnd, validators) {
  const rlpHeader = hashHeader(header)
  const packed = ethers.utils.solidityPack(
    ["bytes32", "address[]", "uint256"],
    [blockHash, validators, cycleEnd]
  );
  const payload = ethers.utils.keccak256(packed);
  const { _vs: vs, r } = ethers.utils.splitSignature(
    await signer.signMessage(ethers.utils.arrayify(payload))
  );
  return [rlpHeader,[vs,r],chainId,payload,cycleEnd,validators]
}
