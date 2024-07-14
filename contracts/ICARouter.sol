import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import { InterchainAccountMessage } from "./middleware/libs/InterchainAccountsMessage.sol";
import {CallLib} from "./middleware/libs/Call.sol";
import {OwnableMulticall} from "./middleware/libs/OwnableMulticall.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {MinimalProxy} from "./libs/MinimalProxy.sol";
import {TypeCasts} from "./libs/TypeCasts.sol";

import "hardhat/console.sol";

contract ICARouter is OApp {

    uint32 internal selfEid = 0;
    address internal implementation;
    bytes32 internal bytecodeHash;

    struct AccountOwner {
        uint32 endpointId;
        bytes32 owner; // remote owner
    }

    mapping(address => AccountOwner) public accountOwners;

    constructor(
        uint32 _endpointId,
        address _endpoint,
        address _delegate
    ) OApp(_endpoint, _delegate) Ownable(_delegate) {

        selfEid = _endpointId;
        implementation = address(new OwnableMulticall(address(this)));
        // cannot be stored immutably because it is dynamically sized
        bytes memory _bytecode = MinimalProxy.bytecode(implementation);
        bytecodeHash = keccak256(_bytecode);
    }
    
    event InterchainAccountCreated(
        uint32 indexed origin,
        bytes32 indexed owner,
        address ism,
        address account
    );

    function quote(
        uint32 _destinationEndpointId,
        address _to,
        uint256 _value,
        bytes memory _data,
        bytes calldata _options
    ) external view returns (MessagingFee memory fee) {

        // _ism is a default value for now
        bytes32 _ism = bytes32(0);
        bytes memory _body = InterchainAccountMessage.encode(
            msg.sender,
            _ism,
            _to,
            _value,
            _data
        );

        fee = _quote(_destinationEndpointId, _body, _options, false);
    }

    // creates an ICA call to the remote account
    function call(
        uint32 _destinationEndpointId,
        address _to,
        uint256 _value,
        bytes memory _data,
        bytes calldata _options
    ) external payable returns (MessagingReceipt memory receipt){

        // _ism is a default value for now
        bytes32 _ism = bytes32(0);
        bytes memory _body = InterchainAccountMessage.encode(
            msg.sender,
            _ism,
            _to,
            _value,
            _data
        );

        console.log("here 1");
        console.log("destinationEndpointId: %s", _destinationEndpointId);

        // send via _lzSend
        receipt = _lzSend(_destinationEndpointId, _body, _options, MessagingFee(msg.value, 0), payable(msg.sender));

        console.log("here 2");
    }

    function isContract(address _account) public view returns (bool) {
        // check if the account is a contract using assembly
        uint32 size;
        assembly {
            size := extcodesize(_account)
        }
        return size > 0;
    }

    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {

        console.log("here 3");
        // decode the message
        (
            bytes32 _owner,
            bytes32 _ism,
            CallLib.Call[] memory _calls
        ) = InterchainAccountMessage.decode(_message);

        console.log("here 4");

        OwnableMulticall _interchainAccount = getDeployedInterchainAccount(
            _origin.srcEid,
            _owner,
            _origin.sender,
            TypeCasts.bytes32ToAddress(_ism)
        );

        console.log("address of interchain account: %s", address(_interchainAccount));
        
        console.log("here 5");
        _interchainAccount.multicall(_calls);

        console.log("here 6");
    }

    function getDeployedInterchainAccount(
        uint32 _origin,
        bytes32 _owner,
        bytes32 _router,
        address _ism
    ) public returns (OwnableMulticall) {
        bytes32 _salt = _getSalt(
            _origin,
            _owner,
            _router,
            TypeCasts.addressToBytes32(_ism)
        );
        address payable _account = _getLocalInterchainAccount(_salt);
        if (!isContract(_account)) {
            bytes memory _bytecode = MinimalProxy.bytecode(implementation);
            _account = payable(Create2.deploy(0, _salt, _bytecode));
            accountOwners[_account] = AccountOwner(_origin, _owner);
            emit InterchainAccountCreated(_origin, _owner, _ism, _account);
        }
        return OwnableMulticall(_account);
    }

    function _getSalt(
        uint32 _origin,
        bytes32 _owner,
        bytes32 _router,
        bytes32 _ism
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_origin, _owner, _router, _ism));
    }

    function _getLocalInterchainAccount(
        bytes32 _salt
    ) private view returns (address payable) {
        return payable(Create2.computeAddress(_salt, bytecodeHash));
    }

    function getRemoteInterchainAccount(
        address _owner,
        address _router
    ) public view returns (address) {
        require(_router != address(0), "no router specified for destination");

        address _ism = address(0);
        // Derives the address of the first contract deployed by _router using
        // the CREATE opcode.
        address _implementation = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xd6),
                            bytes1(0x94),
                            _router,
                            bytes1(0x01)
                        )
                    )
                )
            )
        );
        bytes memory _proxyBytecode = MinimalProxy.bytecode(_implementation);
        bytes32 _bytecodeHash = keccak256(_proxyBytecode);
        bytes32 _salt = _getSalt(
            selfEid,
            TypeCasts.addressToBytes32(_owner),
            TypeCasts.addressToBytes32(address(this)),
            TypeCasts.addressToBytes32(_ism)
        );
        return Create2.computeAddress(_salt, _bytecodeHash, _router);
    }
}