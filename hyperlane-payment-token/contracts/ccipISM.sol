pragma solidity ^0.8.13;

import {AbstractCcipReadIsm} from "@hyperlane-xyz/core/contracts/isms/ccip-read/AbstractCcipReadIsm.sol";
import {IInterchainSecurityModule, ISpecifiesInterchainSecurityModule} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {Message} from "contracts/utils/Message.sol";
import {Indexed} from "contracts/utils/Indexed.sol";
import {TypeCasts} from "contracts/utils/TypeCasts.sol";
import {Versioned} from "contracts/utils/Versioned.sol";

interface Gateway {
    function getCipher(bytes32 _message) external view returns (bytes memory _meta);
}

interface IMessageRecipient {
 function handleWithCiphertext (uint32  _origin, bytes32  _sender, bytes memory _message) external;
}

contract CipherCCIP is AbstractCcipReadIsm, ISpecifiesInterchainSecurityModule {
    using Message for bytes;
    IMailbox mailbox;
    string[] public offChainURLs;
event sent(bytes message,bytes32 committedhash,bytes32 calculatedhash,bytes metadata);
    function setURL(string memory _urls) internal  {
        delete offChainURLs;
        offChainURLs.push(_urls);
    }
    // Constructor to initialize the offChainURLs array
    constructor(string memory initialURL) {
        setURL(initialURL);
    }

    /**
     * No-op, everything happens in the verify function
     */
    function handle(uint32, bytes32, bytes calldata _report) public {}

    /**
     * @param _metadata ABI encoded module metadata
     * @param _message Formatted Hyperlane message (see Message.sol).
     */
        function verify(
    bytes calldata _metadata,
    bytes calldata _message
) external returns (bool) {
    // Call handleWithCiphertext on CipherTextProcessor
  //  bytes memory encodedMessage = abi.encode( _message,_metadata);
     address recipient=_message.recipientAddress();
     bytes memory message = _message.body();
     (,bytes32 committedHash) = abi.decode(message, (uint8,bytes32));
     bytes memory metadata = _metadata.metadata();
     bytes32 metadataHash = keccak256(metadata);
     bytes memory Ciphertext= abi.encode(message,metadata);
     require(metadataHash==committedHash,"invalid");
     IMessageRecipient(recipient)
       .handleWithCiphertext(_message.origin(),_message.sender(), Ciphertext);
        
    emit sent(Ciphertext,committedHash,metadataHash,metadata);
    return metadataHash==committedHash;
}



// function decoder(bytes calldata meta,bytes calldata _message) public view returns (bytes memory message,bytes memory arb,bytes32 calculatedhash,bytes32 comittedhash,bytes memory metad){
//     bytes memory data=meta.metadata();
//      bytes memory message = _message.body();
//      (bytes32 committedHash,bytes memory arbitrary) = abi.decode(message, (bytes32,bytes));
//      bytes32 metadataHash = keccak256(data);
//     return (message,arbitrary, metadataHash, committedHash,data);
// }






    function interchainSecurityModule()
        external
        view
        returns (IInterchainSecurityModule)
    {
        return IInterchainSecurityModule(address(this));
    }

    function getOffchainVerifyInfo(
        bytes calldata _message
    ) external view override {
        bytes memory message = _message.body();
        (,bytes32 committedHash) = abi.decode(message,(uint8, bytes32));
        revert OffchainLookup(
            address(this),
            offChainURLs,
            abi.encodeWithSelector(Gateway.getCipher.selector, committedHash),
            CipherCCIP.process.selector,
            _message
        );
    }

    /**
     * Provided for full CCIP Read specification compatibility. Relayers
     * will call the Mailbox directly regardless of the selector specified
     * in the `OffchainLookup` error
     */
    function process(
        bytes calldata _metadata,
        bytes calldata _message
    ) external {
        mailbox.process(_metadata, _message);
    }
}
