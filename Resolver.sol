// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";

contract MyToken is ERC721, ERC721URIStorage, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant HOLDER_ROLE = keccak256("HOLDER_ROLE");

    // Names of issuers and holders will be converted to hash than mapped to addresses
    mapping(bytes32 => address) issuers;
    mapping(bytes32 => address) holders;

    mapping(uint256 => Request) userRequests;
    uint256[] free_ids;
    uint256 private init_id = 0;

    // enum Status{PENDING, DENIED, APPROVED}
    
    struct Request {
        uint256 id;
        address requester;
        address issuer;
        bool status;  // true - request fulfilled, false - request declined
    }
    Request request; 

    // Events 

    event RequestCreated(Request request);
    event RequestAnswered(Request request);
    event CertificateMinted(address to, uint256 tokenId, string uri);



    constructor(address defaultAdmin) ERC721("MyToken", "MTK") {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        // _grantRole(MINTER_ROLE, minter);
        // _grantRole(HOLDER_ROLE, holder);
    }

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyRole(MINTER_ROLE)
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }



    // Add address that can mint tokens 
    function addIssuer(address issuer, bytes32 issuer_name) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, issuer);
        issuers[issuer_name] = issuer;
    }

    // Add address of holders, that request certifications
    function addHolder(address holder, bytes32 holder_name) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(HOLDER_ROLE, holder);
        holders[holder_name] = holder;
    }

    function requestCertificate(bytes32 issuer_name) public onlyRole(HOLDER_ROLE) {
        address requester = msg.sender;
        address issuer = issuers[issuer_name];
        uint256 id = 0;

        if (free_ids.length == 0) {
            init_id++;
            id = init_id;
        } 
        else {
            id = free_ids[free_ids.length - 1];
            free_ids.pop();
        }

        request = Request(id, requester, issuer, false);
        userRequests[id] = request;
        emit RequestCreated(request);
    }

    function rejectRequest(uint256 id) public onlyRole(MINTER_ROLE) {
        userRequests[id].status = false;

        if (id == init_id) {
            init_id--;
        } 
        else {  
            free_ids.push(id);
        }

        emit RequestAnswered(userRequests[id]);
        delete userRequests[id];
    }

    function approveRequest(uint256 id, uint256 tokenId, string memory uri) public onlyRole(MINTER_ROLE) {
        userRequests[id].status = true;

        safeMint(userRequests[id].requester, tokenId, uri);

        if (id == init_id) {
            init_id--;
        }
        else {
            free_ids.push(id);
        }

        emit RequestAnswered(userRequests[id]);
        emit CertificateMinted(userRequests[id].requester, tokenId, uri);
        delete userRequests[id];
    }
    
}

// я писал систему освобождения айдишек запросов после их выполнения, но потом понял, может я это зря....
// максимальное число uint256 MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935
