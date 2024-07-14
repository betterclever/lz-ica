// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// MyOApp imports
import { ICARouter } from "../../contracts/ICARouter.sol";

// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OAppOptionsType3.sol";
import { MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract ICARouterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    ICARouter private aOApp;
    ICARouter private bOApp;

    address private userA = address(0x1);
    address private userB = address(0x2);

    address private userC = address(0x3);

    uint256 private initialBalance = 100 ether;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        console.log("endpoints[aEid]: %s", address(endpoints[aEid]));

        aOApp = ICARouter(_deployOApp(type(ICARouter).creationCode, abi.encode(aEid, address(endpoints[aEid]), address(this))));
        bOApp = ICARouter(_deployOApp(type(ICARouter).creationCode, abi.encode(bEid, address(endpoints[bEid]), address(this))));

        console.log("aOApp: %s", address(aOApp));
        console.log("bOApp: %s", address(bOApp));
        address[] memory oapps = new address[](2);
        oapps[0] = address(aOApp);
        oapps[1] = address(bOApp);
        this.wireOApps(oapps);
    }

    function test_constructor() public {
        assertEq(aOApp.owner(), address(this));
        assertEq(bOApp.owner(), address(this));

        assertEq(address(aOApp.endpoint()), address(endpoints[aEid]));
        assertEq(address(bOApp.endpoint()), address(endpoints[bEid]));
    }

    function test_call() public {

        // user A sends 10 ether to interchain account on chain B
        address interchainAccount = aOApp.getRemoteInterchainAccount(
            userA,
            address(aOApp)
        );

        console.log("interchainAccount: %s", interchainAccount);

        // deal funds to ICA
        vm.deal(interchainAccount, 10 ether);

        bytes memory options = OptionsBuilder.newOptions()
            .addExecutorLzReceiveOption(400000, 0);

        // get fee qoute
        MessagingFee memory fee = aOApp.quote(
            bEid,
            interchainAccount,
            1 ether,
            abi.encodeWithSignature("0x00"),
            options
        );

        aOApp.call{value: fee.nativeFee}(
                bEid,
                address(this),
                1 ether,
                abi.encodeWithSignature("0x00"),
                // create layerzero options
                options
            );
    }
}
