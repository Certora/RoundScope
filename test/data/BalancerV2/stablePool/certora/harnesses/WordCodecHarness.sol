pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {WordCodec} from "../munged/solidity-utils/contracts/helpers/WordCodec.sol";

// This contract calls internal functions from the WordCodec library using 
// public wrapper functions.
contract WordCodecHarness {
    using WordCodec for *;

    // In-place insertion

    function insertUint(
        bytes32 word,
        uint256 value,
        uint256 offset,
        uint256 bitLength
    ) public pure returns (bytes32) { // HARNESS: internal -> public
        return WordCodec.insertUint(word, value, offset, bitLength);
    }

    function insertInt(
        bytes32 word,
        int256 value,
        uint256 offset,
        uint256 bitLength
    ) public pure returns (bytes32) { // HARNESS: internal -> public
        return WordCodec.insertInt(word, value, offset, bitLength);
    }

    // Encoding

    function encodeUint(
        uint256 value,
        uint256 offset,
        uint256 bitLength
    ) public pure returns (bytes32) { // HARNESS: internal -> public
        return WordCodec.encodeUint(value, offset, bitLength);
    }

    function encodeInt(
        int256 value,
        uint256 offset,
        uint256 bitLength
    ) public pure returns (bytes32) { // HARNESS: internal -> public
        return WordCodec.encodeInt(value, offset, bitLength);
    }

    // Decoding

    function decodeUint(
        bytes32 word,
        uint256 offset,
        uint256 bitLength
    ) public pure returns (uint256) { // HARNESS: internal -> public
        return WordCodec.decodeUint(word, offset, bitLength);
    }

    function decodeInt(
        bytes32 word,
        uint256 offset,
        uint256 bitLength
    ) public pure returns (int256) { // HARNESS: internal -> public
        return WordCodec.decodeInt(word, offset, bitLength);
    }

    // Special cases

    function decodeBool(bytes32 word, uint256 offset) public pure returns (bool) { // HARNESS: internal -> public
        return WordCodec.decodeBool(word, offset);
    }

    function insertBits192(
        bytes32 word,
        bytes32 value,
        uint256 offset
    ) public pure returns (bytes32) { // HARNESS: internal -> public
        return WordCodec.insertBits192(word, value, offset);
    }

    function insertBool(
        bytes32 word,
        bool value,
        uint256 offset
    ) public pure returns (bytes32) { // HARNESS: internal -> public
        return WordCodec.insertBool(word, value, offset);
    }

    // Helpers

    function validateEncodingParamsUint(
        uint256 value,
        uint256 offset,
        uint256 bitLength
    ) public pure {
        return WordCodec._validateEncodingParams(value, offset, bitLength);
    }

    function validateEncodingParamsInt(
        int256 value,
        uint256 offset,
        uint256 bitLength
    ) public pure {
        return WordCodec._validateEncodingParams(value, offset, bitLength);
    }    
}
