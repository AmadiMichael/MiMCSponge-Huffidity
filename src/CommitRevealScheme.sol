// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

error TooEarly();
error Mismatch();
error ProofAlreadySubmitted();
error InvalidProof();
error TransferFailed();

contract CommitRevealScheme {
    uint256 constant MiMCSpongeHasherOffset = 645; // replace this with whatever `console2.logUint(solidityBytecode.length);` in the test file logs out

    constructor(bytes memory solidityBytecode, bytes memory huffBytecode) payable {
        // concat the solidity and huff runtime code together
        bytes memory fullRuntimeCode = bytes.concat(solidityBytecode, huffBytecode);

        // return the concatenated runtime code as the runtime code
        assembly {
            return(add(0x20, fullRuntimeCode), mload(fullRuntimeCode))
        }
    }

    struct Hash {
        bytes32 first;
        bytes32 second;
    }

    mapping(uint256 => bool) proofSubmitted;
    mapping(address => Hash) commitments;
    mapping(address => uint256) proofWait;

    function register(Hash calldata _commitment) external {
        commitments[msg.sender] = _commitment;
        proofWait[msg.sender] = block.timestamp + 120;
    }

    function submitProof(bytes32 _proof, bytes32 _randomSalt) external {
        if (!(block.timestamp > proofWait[msg.sender])) revert TooEarly();

        function() internal c;
        function() internal d = submitProof_inner1;
        assembly {
            // store the parameters in memory
            mstore(0x00, _proof)
            mstore(0x20, _randomSalt)

            // store return jumpdest in memory
            // Note: If your code has or uses uninitialized dynamic memory variables use the current free memory pointer instead
            mstore(0x60, d)

            // assign c with jumpdest for execution
            c := MiMCSpongeHasherOffset
        }

        c();
    }

    function submitProof_inner1() internal {
        Hash memory _commitment;
        uint256 _proof;
        uint256 _randomSalt;

        assembly {
            _proof := calldataload(0x04)
            _randomSalt := calldataload(0x24)

            // copy _commitment from mem[0x00:0x40] to [fmp:(fmp + 0x40)] since solidity will overwrite it when calculating the mapping slot below
            let fmp := mload(0x40)
            mstore(0x40, add(fmp, 0x40))

            mstore(fmp, mload(0x00))
            mstore(add(fmp, 0x20), mload(0x20))
            _commitment := fmp
        }

        if (commitments[msg.sender].first != _commitment.first || commitments[msg.sender].second != _commitment.second)
        {
            revert Mismatch();
        }
        if (proofSubmitted[_proof]) revert ProofAlreadySubmitted();

        proofSubmitted[_proof] = true;
        (bool success,) = payable(msg.sender).call{value: 1 ether}("");
        if (!success) revert TransferFailed();

        assembly {
            return(0x00, 0x00)
        }
    }
}
