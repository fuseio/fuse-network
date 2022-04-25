pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./structs.sol";
import "./parseBlock.sol";
import "./fuse/IConsensus.sol";

/**

	The purpose of this contract is to store on Fuse block headers 
	from different blockchains signed by the Fuse validators.

**/
contract BlockHeaderRegistry {
    // To prevent double signatures
    mapping(bytes32 => mapping(address => bool)) public hasValidatorSigned;

    // Block hashes per block number for blockchain
    mapping(uint256 => mapping(uint256 => bytes32[])) public blockHashes;

    // Validator signatures per blockHash
    mapping(bytes32 => SignedBlock) public signedBlocks;

    // Block header for blockHash
    mapping(bytes32 => BlockHeader) blockHeaders;

    mapping(uint256 => string) public blockchains;

    address immutable voting;
    address immutable consensus;

    constructor(address _voting, address _consensus) {
        voting = _voting;
        consensus = _consensus;
    }

    event Blockchain(uint256 blockchainId, string rpc);

    modifier onlyVoting() {
        require(msg.sender == voting, "onlyVoting");
        _;
    }

    function addBlockchain(uint256 blockchainId, string memory rpc)
        external
        onlyVoting
    {
        blockchains[blockchainId] = rpc;
        emit Blockchain(blockchainId, rpc);
    }

    modifier onlyValidator() {
        require(_isValidator(msg.sender), "onlyValidator");
        _;
    }

    /**
		  @notice Add a signed block from any blockchain.
		  @notice Costs slightly more if the block has never been registered before.
		  @notice Processes fuse blocks slightly differently.
		  @param blocks List of block headers and signatures to add.
	  */
    function addSignedBlocks(Block[] calldata blocks) external onlyValidator {
        for (uint256 i = 0; i < blocks.length; i++) {
            Block calldata _block = blocks[i];
            bytes32 rlpHeaderHash = keccak256(_block.rlpHeader);
            require(rlpHeaderHash == _block.blockHash, "rlpHeaderHash");
            bool isFuse = _isFuse(_block.blockchainId);
            bytes32 payload = isFuse
                ? keccak256(
                    abi.encodePacked(
                        rlpHeaderHash,
                        _block.validators,
                        _block.cycleEnd
                    )
                )
                : rlpHeaderHash;
            address signer = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(payload),
                _block.signature.r,
                _block.signature.vs
            );
            require(msg.sender == signer, "msg.sender == signer");
            require(!hasValidatorSigned[payload][msg.sender], Strings.toHexString(uint256(payload), 32));
            hasValidatorSigned[payload][signer] = true;
            if (_isNewBlock(payload)) {
                BlockHeader memory blockHeader = parseBlock(_block.rlpHeader);
                blockHeaders[payload] = blockHeader;
                blockHashes[_block.blockchainId][blockHeader.number].push(
                    payload
                );
                if (isFuse) {
                    signedBlocks[payload].validators = _block.validators;
                    signedBlocks[payload].cycleEnd = _block.cycleEnd;
                }
                signedBlocks[payload].creator = msg.sender;
            }
            signedBlocks[payload].signatures.push(
                abi.encodePacked(_block.signature.r, _block.signature.vs)
            );
        }
    }

    function getSignedBlock(uint256 blockchainId, uint256 number)
        public
        view
        returns (
            bytes32 blockHash,
            BlockHeader memory blockHeader,
            SignedBlock memory signedBlock
        )
    {
        bytes32[] memory _blockHashes = blockHashes[blockchainId][number];
        require(_blockHashes.length != 0, "_blockHashes.length");
        blockHash = _blockHashes[0];
        uint256 _signatures = signedBlocks[blockHash].signatures.length;
        for (uint256 i = 1; i < _blockHashes.length; i++) {
            uint256 _sigs = signedBlocks[_blockHashes[i]].signatures.length;
            if (_sigs > _signatures) {
                _signatures = _sigs;
                blockHash = _blockHashes[i];
            }
        }
        SignedBlock storage _block = signedBlocks[blockHash];
        signedBlock.signatures = _block.signatures;
        signedBlock.creator = _block.creator;
        if (_isFuse(blockchainId)) {
            signedBlock.validators = _block.validators;
            signedBlock.cycleEnd = _block.cycleEnd;
        }
        blockHeader = blockHeaders[blockHash];
    }

    function _isValidator(address person) internal virtual returns (bool) {
        return IConsensus(consensus).isValidator(person);
    }

    function _isNewBlock(bytes32 key) private view returns (bool) {
        return signedBlocks[key].signatures.length == 0;
    }

    function _isFuse(uint256 blockchainId)
        internal
        view
        virtual
        returns (bool)
    {
        return blockchainId == 0x7a;
    }
}
