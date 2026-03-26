pragma solidity 0.8.28;

import {Vm} from "@forge-std/Vm.sol";
import {Test} from "@forge-std/Test.sol";

import {AddressStoreLib} from "@deployment/AddressStoreLib.sol";

import {Proposal_0} from "@deployment/proposal_0/Proposal_0.sol";
import {Proposal_9} from "@deployment/proposal_9/Proposal_9.sol";

// Test pending proposals with :
// forge test --match-contract ProtocolUpgradeCheck --rpc-url $ETH_RPC_URL -vvv
contract ProtocolUpgradeCheck is Test {
    using AddressStoreLib for Vm;

    /// @dev Update the setup to include pending proposals, or
    /// parts of the proposals if they have been deployed but have not executed, etc.
    function setUp() public virtual {
        // p0 is a placeholder empty proposal for quick local play
        Proposal_0 p0 = new Proposal_0();
        p0.setDebug(false);
        p0.run();

        Proposal_9 p9 = new Proposal_9();
        p9.setDebug(false);
        p9.run();
    }
}
