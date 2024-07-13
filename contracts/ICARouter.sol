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

contract ICARouter is OApp {

    address internal implementation;
    bytes32 internal bytecodeHash;

    struct AccountOwner {
        uint32 endpointId;
        bytes32 owner; // remote owner
    }

    mapping(address => AccountOwner) public accountOwners;

    constructor(address _endpoint, address _delegate) OApp(_endpoint, _delegate) Ownable(_delegate) {}
    

    event InterchainAccountCreated(
        uint32 indexed origin,
        bytes32 indexed owner,
        address ism,
        address account
    );

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

        // send via _lzSend
        receipt = _lzSend(_destinationEndpointId, _body, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    function isContract(address _account) public view returns (bool) {
        // check if the account is a contract using assembly
        uint32 size;
        assembly {
            size := extcodesize(_account)
        }
        return size > 0;
    }

    // TODO: handles call from a remote owner
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {

        // decode the message
        (
            bytes32 _owner,
            bytes32 _ism,
            CallLib.Call[] memory _calls
        ) = InterchainAccountMessage.decode(_message);


        OwnableMulticall _interchainAccount = getDeployedInterchainAccount(
            _origin.srcEid,
            _owner,
            _origin.sender,
            TypeCasts.bytes32ToAddress(_ism)
        );
        _interchainAccount.multicall(_calls);
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
}