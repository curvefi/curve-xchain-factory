pragma solidity ^0.4.24;

import "./RLP.sol";

/*
Forked from: https://github.com/lorenzb/proveth/blob/master/onchain/ProvethVerifier.sol
*/


library TrieProofs {
    using RLP for RLP.RLPItem;
    using RLP for bytes;

    bytes32 internal constant EMPTY_TRIE_ROOT_HASH = 0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421;

    /**
      @notice Verify a merkle proof
      @param proofRLP is the rlp encoded proof retrieved from eth_getProof
      @param rootHash The root hash of the merkle tree
      @param path32 is the path to traverse ???
      */
    function verify(
        bytes memory proofRLP,
        bytes32 rootHash,
        bytes32 path32
    ) internal pure returns (bytes memory value)
    {
        // TODO: Optimize by using word-size paths instead of byte arrays
        bytes memory path = new bytes(32);
        assembly { mstore(add(path, 0x20), path32) } // careful as path may need to be 64
        // here we have a Bytes[64] where each index is a nibble
        path = decodeNibbles(path, 0); // lol, so efficient

        // decode the proofRLP into a list, where we can index each item
        RLP.RLPItem[] memory proof = proofRLP.toRLPItem().toList();

        uint8 nodeChildren; // no clue
        RLP.RLPItem memory children; // no clue

        // no idea
        uint256 pathOffset = 0; // Offset of the proof
        bytes32 nextHash; // Required hash for the next node

        // edge case where the proof has 0 elements (empty proof)
        if (proof.length == 0) {
            // Root hash of empty tx trie
            require(rootHash == EMPTY_TRIE_ROOT_HASH, "Bad empty proof");
            return new bytes(0); // return b""
        }

        // here we iterate through each index of the proof array
        for (uint256 i = 0; i < proof.length; i++) {
            // We use the fact that an rlp encoded list consists of some
            // encoding of its length plus the concatenation of its
            // *rlp-encoded* items.
            // grab the first element of the proof array as bytes
            bytes memory rlpNode = proof[i].toRLPBytes(); // TODO: optimize by not encoding and decoding?

            if (i == 0) {
                    /// if this is the first elemnt of the proof array hash it and verify it's correct root hash
                require(rootHash == keccak256(rlpNode), "Bad first proof part");
            } else {
                    // other elements we hash and verify the hash matches what we expect
                require(nextHash == keccak256(rlpNode), "Bad hash");
            }

            // here we convert the rlp encoded node to a list  are we going to iterate throug hit too?
            RLP.RLPItem[] memory node = proof[i].toList();

            // Extension or Leaf node
            if (node.length == 2) {
                    // if the length is only two elements ...
                /*
                // TODO: wtf is a divergent node
                // proof claims divergent extension or leaf
                // Does this not matter ? why was it removed
                if (proofIndexes[i] == 0xff) {
                    require(i >= proof.length - 1); // divergent node must come last in proof
                    require(prefixLength != nodePath.length); // node isn't divergent
                    require(pathOffset == path.length); // didn't consume entire path

                    return new bytes(0);
                }

                require(proofIndexes[i] == 1); // an extension/leaf node only has two fields.
                require(prefixLength == nodePath.length); // node is divergent
                */

                // introduce a new var nodePath ?
                // this is similar to path defined before (a array of nibbles), except we skip over
                // either 1 or two of the initial nibbles, also we don't know the lenght of node[0]
                // so this isn't for sure a bytes32 value that'll go into a Bytes[64] array
                bytes memory nodePath = merklePatriciaCompactDecode(node[0].toBytes());
                // pathOffset is initially 0
                // path is the path we defined in the begging a byte array of nibbles
                // nodePath is another byte array of nibbles
                // increase the path offset by the number of indexes which both paths share
                pathOffset += sharedPrefixLength(pathOffset, path, nodePath);

                // last proof item
                if (i == proof.length - 1) {
                        // if i is the last index of the proof list
                        // verify we have the correct path offset
                    require(pathOffset == path.length, "Unexpected end of proof (leaf)");
                    // return the element at node[1] as a bytearray
                    return node[1].toBytes(); // Data is the second item in a leaf node
                } else {
                    // not last proof item
                    // not the last element
                    // children are held in node[1]
                    children = node[1];
                    if (children.isList()) { // if this is a list, convert to a bytearray and hash
                            // set the nextHash var to this
                        nextHash = keccak256(children.toRLPBytes());
                    } else {
                            // if the children is not a list, then call getNextHash
                            // baseically we convert children to a bytearray
                            // and check it is a bytes32 value, this bytes32 value is the hash itself
                            // and then we continue
                        nextHash = getNextHash(children);
                    }
                }
            } else { // if the node has more than 2 elements

                    // verify the length == 17, 17 elemnts ?
                // Must be a branch node at this point
                require(node.length == 17, "Invalid node length");

                if (i == proof.length - 1) {
                        // if this is the last proof
                    // Proof ends in a branch node, exclusion proof in most cases
                    if (pathOffset + 1 == path.length) {
                            // if the pathOffset is the last one, return the last element as bytes
                        return node[16].toBytes();
                    } else {
                        nodeChildren = extractNibble(path32, pathOffset); // extract a nibble at the pathOffset
                        children = node[nodeChildren]; // get the child of this node at that nibbles index

                        // Ensure that the next path item is empty, end of exclusion proof
                        require(children.toBytes().length == 0, "Invalid exclusion proof"); // assert empty byes value
                        return new bytes(0); // return b""
                    }
                } else {
                        // verify pathOffset is < path length
                    require(pathOffset < path.length, "Continuing branch has depleted path");

                    // extract nibble at pathoffset from calldata path32
                    nodeChildren = extractNibble(path32, pathOffset);
                    children = node[nodeChildren]; // get the child at the nibble index

                    pathOffset += 1; // advance by one // increase the pathOffset by 1

                    // not last level
                    if (children.isList()) {
                            // if the child item is a list, get the hash
                        nextHash = keccak256(children.toRLPBytes());
                    } else {
                            // if it isn't get the nextHash, which is just decoding this bytearray into a bytes32
                        nextHash = getNextHash(children);
                    }
                }
            }
        }

        // raise if we don't reach the proof
        // no invalid proof should ever reach this point
        assert(false);
    }

    function getNextHash(RLP.RLPItem memory node) internal pure returns (bytes32 nextHash) {
        bytes memory nextHashBytes = node.toBytes();
        require(nextHashBytes.length == 32, "Invalid node");

        assembly { nextHash := mload(add(nextHashBytes, 0x20)) }
    }

    /*
    * Nibble is extracted as the least significant nibble in the returned byte
    */
    function extractNibble(bytes32 path, uint256 position) internal pure returns (uint8 nibble) {
        require(position < 64, "Invalid nibble position");
        byte shifted = position == 0 ? byte(path >> 4) : byte(path << ((position - 1) * 4));
        return uint8(byte(shifted & 0xF));
    }

    /**
      @dev decode a bytearray into an array of nibbles (4-bits)
      @dev Turns a bytes32 into a Bytes[64] where each index is a 4-bit value
        the nibble, 0xFFa0 ->  [0xF, 0xf, 0xa, 0x0]
      */
    function decodeNibbles(bytes memory compact, uint skipNibbles) internal pure returns (bytes memory nibbles) {
        require(compact.length > 0, "Empty bytes array");

        uint length = compact.length * 2;
        require(skipNibbles <= length, "Skip nibbles amount too large");
        length -= skipNibbles;

        nibbles = new bytes(length);
        uint nibblesLength = 0;

        // shouldn't this be i< length still, what happens when we index past the length of a bytearray
        // ex. compact = bytes32, skipNibbles = 2, (i = 2; i < 2 + 64 == 66; i++), when we reach 64, we get index 32 which doesnt exist for compact
        for (uint i = skipNibbles; i < skipNibbles + length; i += 1) {
            if (i % 2 == 0) {
                nibbles[nibblesLength] = bytes1((uint8(compact[i/2]) >> 4) & 0xF);
            } else {
                nibbles[nibblesLength] = bytes1((uint8(compact[i/2]) >> 0) & 0xF);
            }
            nibblesLength += 1;
        }

        assert(nibblesLength == nibbles.length);
    }

    /// @param compact is just a bytearray that hasn't been decoded into nibbles
    function merklePatriciaCompactDecode(bytes memory compact) internal pure returns (bytes memory nibbles) {
        require(compact.length > 0, "Empty bytes array");
        uint first_nibble = uint8(compact[0]) >> 4 & 0xF; // grab the first nibble 0xABCDE -> 0xA
        uint skipNibbles;  // new var
        /**
          assert byte0 < 4
          if byte0 % 2 == 0:
            skipNibbles = 2
          else:
            skipNibbles = 1
          */
        if (first_nibble == 0) { // why 0
            skipNibbles = 2;
        } else if (first_nibble == 1) {
            skipNibbles = 1;
        } else if (first_nibble == 2) {
            skipNibbles = 2;
        } else if (first_nibble == 3) {
            skipNibbles = 1;
        } else {
            // Not supposed to happen!
            revert();
        }
        // return the nibbles skipping over the first 1/2 nibbles
        return decodeNibbles(compact, skipNibbles);
    }

    // iterate through two byte arrays x and y, returning the index at which both elements are different
    // can offset where to start in array x using xsOffset
    // if there the arrays match exactly return the highest index
    function sharedPrefixLength(uint xsOffset, bytes memory xs, bytes memory ys) internal pure returns (uint) {
        uint256 i = 0;
        for (i = 0; i + xsOffset < xs.length && i < ys.length; i++) {
            if (xs[i + xsOffset] != ys[i]) {
                return i;
            }
        }
        return i;
    }
}
