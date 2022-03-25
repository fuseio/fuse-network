pragma solidity ^0.8.0;

import {BlockHeader} from './structs.sol';

function parseBlock(bytes calldata rlpHeader) pure returns (BlockHeader memory header) {
	assembly {
		// input should be a pointer to start of a calldata slice
		function decode_length(input, length) -> offset, strLen, isList {
			if iszero(length) { revert(0, 1) }

			let prefix := byte(0, calldataload(input))

			function getcd(start, len) -> val {
				mstore(0, 0)
				let dst := sub(32, len)
				calldatacopy(dst, start, len)
				val := mload(0)
				mstore(0, 0)
			}

			if lt(prefix, 0x80) {
				offset := 0
				strLen := 1
				isList := 0
				leave
			}

			if lt(prefix, 0xb8) {
				if iszero(gt(length, sub(prefix, 0x80))) { revert(0, 0xff) }
				strLen := sub(prefix, 0x80)
				offset := 1
				isList := 0
				leave
			}

			if lt(prefix, 0xc0) {
				if iszero(and(
					gt(length, sub(prefix, 0xb7)),
					gt(length, add(sub(prefix, 0xb7), getcd(add(input, 1), sub(prefix, 0xb7))))
				)) { revert(0, 0xff) }

			        let lenOfStrLen := sub(prefix, 0xb7)
				strLen := getcd(add(input, 1), lenOfStrLen)
				offset := add(1, lenOfStrLen)
				isList := 0
				leave
			}

			if lt(prefix, 0xf8) {
				if iszero(gt(length, sub(prefix, 0xc0))) { revert(0, 0xff) }
				// listLen
				strLen := sub(prefix, 0xc0)
				offset := 1
				isList := 1
				leave
			}

			if lt(prefix, 0x0100) {
				if iszero(and(
					gt(length, sub(prefix, 0xf7)),
					gt(length, add(sub(prefix, 0xf7), getcd(add(input, 1), sub(prefix, 0xf7))))
				)) { revert(0, 0xff) }

				let lenOfListLen := sub(prefix, 0xf7)
				// listLen
				strLen := getcd(add(input, 1), lenOfListLen)
				offset := add(1, lenOfListLen)
				isList := 1
				leave
			}

			revert(0, 2)
		}

		// Initialize rlp variables with the block's list
		let iptr := rlpHeader.offset
		let ilen := rlpHeader.length
		let offset
		let len
		let isList
		offset,len,isList := decode_length(iptr, ilen)

		// There's only 1 list in the Ethereum block RLP encoding (the block itself)
		// If the first param isn't a list, revert
		switch isList
		case 0 { revert(0, 3) }

		// The returned offset + length refer to the list's payload
		// We pass those values to begin extracting block properties
		iptr := add(iptr, offset)
		ilen := len

		// bytes32 parentHash;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(header, sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// bytes32 uncleHash;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x20), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// address coinbase;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x40), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)
		
		// bytes32 root;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x60), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// bytes32 txHash;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x80), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// bytes32 receiptHash;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0xa0), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// bytes32[8] bloom;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(mload(add(header, 0xc0)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// uint256 difficulty;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0xe0), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

//			function write(iptr, len, dst_ptr, base_len) {
//				calldatacopy(add(dst_ptr, sub(base_len, len)), iptr, len)
//			}

		// uint256 number;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x100), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// uint256 gasLimit;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x120), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// uint256 gasUsed;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x140), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// uint256 time;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x160), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// bytes extra;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		let free := mload(0x40)
		mstore(add(header, 0x1e0), free)
		mstore(free, len)
		mstore(0x40, add(free, add(0x20, len)))
		calldatacopy(add(free, 0x20), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// bytes32 mixDigest;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x180), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// uint64 nonce;
		offset,len,isList := decode_length(iptr, ilen)
		if isList { revert(0, 4) }
		calldatacopy(add(add(header, 0x1a0), sub(0x20, len)), add(iptr, offset), len)
                iptr := add(iptr, add(len, offset))
                ilen := sub(ilen, len)

		// uint256 baseFee;
		// This might not exist on some chains and legacy blocks
		switch gt(iptr, add(rlpHeader.length, rlpHeader.offset))
		case 0 {
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x1c0), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)
		}
	}
}


