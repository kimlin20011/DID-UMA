pragma solidity ^0.7.0;

contract DIDRegistry {
    mapping(address => address) public owners; //identity => ownerAddress
    mapping(address => bytes) public DIDsDocumentUrls; //identity => DIDsDocumentsUrlHash
    mapping(address => mapping(bytes32 => bytes32)) public DIDsDocumentInfo; //mapping identity => urlHash => docInfoHash
    mapping(address => mapping(bytes32 => uint256)) public DIDsUrlExpiration; //mapping identity => urlHash => docInfoHash

    modifier onlyOwner(address identity, address actor) {
        require(actor == owners[identity]);
        _;
    }

    string public method;
    address public contractOwner;

    event Registered(
        address indexed identity,
        address owner,
        bytes32 url_hash_keccak256,
        uint256 timestamp
    );

    event DocumentUrlChanged(
        address indexed identity,
        bytes url,
        uint256 timestamp
    );

    event DIDOwnerChanged(
        address indexed identity,
        address owner,
        uint256 timestamp
    );

    event DocumentInfoChanged(
        address indexed identity,
        bytes32 url_hash_keccak256,
        bytes32 docHash,
        uint256 validTo,
        uint256 timestamp
    );

    event DIDrevoked(address indexed identity, bool status);

    constructor(string memory _method) {
        contractOwner = msg.sender;
        method = _method;
    }

    //map the identity to owner address;map the identity to DIDUrl
    function registerIdentity(address _identity, bytes memory _url)
        public
        returns (bool)
    {
        owners[_identity] = msg.sender;
        //(keccak256(abi.encodePacked(_url, msg.sender, random_number))) ;
        DIDsDocumentUrls[_identity] = _url;
        emit Registered(
            _identity,
            msg.sender,
            (keccak256(abi.encodePacked(DIDsDocumentUrls[_identity]))),
            block.timestamp
        );
        return true;
    }

    function revokeIdentity(address _identity)
        public
        onlyOwner(_identity, msg.sender)
    {
        delete DIDsDocumentUrls[_identity];
        delete DIDsDocumentInfo[_identity][
            (keccak256(abi.encodePacked(DIDsDocumentUrls[_identity])))
        ];
        emit DIDrevoked(_identity, true);
    }

    /* function checkSignature(address _identity, uint8 _sigV, bytes32 _sigR, bytes32 _sigS, bytes32 hash) internal returns(address) {
        address signer = ecrecover(hash, _sigV, _sigR, _sigS);
        require(signer == owners[_identity]);
        nonce[signer]++;
        return signer;
    } */

    function changeOwner(address _identity, address _newOwner)
        public
        onlyOwner(_identity, msg.sender)
    {
        owners[_identity] = _newOwner;
        emit DIDOwnerChanged(_identity, _newOwner, block.timestamp);
    }

    function changeDIDDocumentUrl(
        address _identity,
        bytes memory _previous_url,
        bytes memory _new_url
    ) public onlyOwner(_identity, msg.sender) {
        require(
            (keccak256(abi.encodePacked(DIDsDocumentUrls[_identity]))) ==
                (keccak256(abi.encodePacked(_previous_url)))
        );
        DIDsDocumentUrls[_identity] = _new_url;
        emit DocumentUrlChanged(
            _identity,
            DIDsDocumentUrls[_identity],
            block.timestamp
        );
    }

    //map the identity to the document information hash
    function setDocumentInfo(
        address _identity,
        bytes memory _url,
        bytes memory _doc,
        uint256 _expTime
    ) public onlyOwner(_identity, msg.sender) {
        bytes32 url = (keccak256(abi.encodePacked(_url)));
        bytes32 doc = (keccak256(abi.encodePacked(_doc)));
        DIDsDocumentInfo[_identity][url] = doc;
        DIDsUrlExpiration[_identity][url] = block.timestamp + _expTime;
        emit DocumentInfoChanged(
            _identity,
            url,
            doc,
            block.timestamp + _expTime,
            block.timestamp
        );
    }

    function verifyUrl(address _identity, bytes memory _url)
        public
        view
        returns (bool)
    {
        bytes32 url = (keccak256(abi.encodePacked(_url)));
        if ((keccak256(abi.encodePacked(DIDsDocumentUrls[_identity]))) == url) {
            return true;
        } else {
            return false;
        }
    }

    function verifyDocument(
        address _identity,
        bytes memory _url,
        bytes memory _doc
    ) public view returns (bool) {
        bytes32 url = (keccak256(abi.encodePacked(_url)));
        bytes32 doc = (keccak256(abi.encodePacked(_doc)));
        if (DIDsDocumentInfo[_identity][url] == doc) {
            return true;
        } else {
            return false;
        }
    }
}

contract Authorization {
    struct AuthorizationInfo {
        uint256 registerTime;
        bytes32 claimHash;
        address claimIssuer;
        uint256 expireTime;
    }

    mapping(address => bool) public owners;
    mapping(address => bool) public protectedResourceDIDs;
    mapping(bytes32 => address) public permissionTickets; //tickets => DID
    mapping(address => AuthorizationInfo) public authorizationPolicies; //requestPartyDID => AuthorizationInfo
    mapping(address => bytes32) public accessToken; //ticket => token
    mapping(bytes32 => uint256) public tokenValidTime; //token => timestamp
    //mapping(bytes32 => address) public tokenTarget; //token => DIDrqp

    modifier onlyOwner(address _sender) {
        require(owners[_sender] == true);
        _;
    }

    modifier verifyDID(address _identity) {
        DIDRegistry RC = DIDRegistry(DIDRegistryAddress);
        require(RC.owners(_identity) != address(0), "identity not found");
        _;
    }

    address public DIDRegistryAddress;
    address public contractOwner;
    string public DID_method;
    uint256 public tokenExpireDays = 100;

    event DIDRegistryAddressChanged(
        address indexed DIDRegistryAddress,
        string method,
        uint256 timestamp
    );

    event PolicyRegistered(
        address indexed targetDID,
        address msgSender,
        address claimIssuer,
        bytes32 claimHash,
        uint256 timestamp,
        uint256 expireTime
    );

    event ProtectedResourceDIDCreated(
        address indexed protectedResourceDID,
        uint256 timestamp
    );

    event TicketGenerated(
        address protectedResourceIdentifier,
        bytes32 permissionTicket,
        address msgSender,
        string DID_Method
    );

    event TokenReleased(
        address DIDrqp,
        address msgSender,
        bytes32 accessToken,
        uint256 timestamp,
        uint256 expireTime
    );

    constructor(address _DIDRegistryAddress, string memory _method) {
        contractOwner = msg.sender;
        owners[msg.sender] = true;
        DID_method = _method;
        DIDRegistryAddress = _DIDRegistryAddress;
    }

    function addOwner(address _newOwnerAddress) public onlyOwner(msg.sender) {
        owners[_newOwnerAddress] = true;
    }

    function setDIDRegistry(
        address _DIDRegistryAddress,
        string memory _DID_method
    ) public onlyOwner(msg.sender) {
        DIDRegistryAddress = _DIDRegistryAddress;
        DID_method = _DID_method;
        emit DIDRegistryAddressChanged(
            _DIDRegistryAddress,
            DID_method,
            block.timestamp
        );
    }

    function setProtectedResourceDID(address _identity)
        public
        onlyOwner(msg.sender)
    {
        protectedResourceDIDs[_identity] = true;
        emit ProtectedResourceDIDCreated(_identity, block.timestamp);
    }

    function setPolicy(
        address _identity,
        address _issuer,
        bytes memory _claim,
        uint256 _expireDate
    ) public onlyOwner(msg.sender) {
        require(protectedResourceDIDs[_identity] == true, "identity not found");
        bytes32 claimHash = (keccak256(abi.encodePacked(_claim)));
        uint256 expireDate = block.timestamp + _expireDate * 1 days;
        authorizationPolicies[_identity] = AuthorizationInfo(
            block.timestamp,
            claimHash,
            _issuer,
            expireDate
        );
        emit PolicyRegistered(
            _identity,
            msg.sender,
            _issuer,
            claimHash,
            block.timestamp,
            expireDate
        );
    }

    function ticketGenerate(address _DeviceIdentity, string memory _DID_method)
        public
        verifyDID(_DeviceIdentity)
    {
        //要先檢查msg.sender(resource server)與identifier是否存在
        require(protectedResourceDIDs[_DeviceIdentity] == true, "identifier");
        require(
            (keccak256(abi.encodePacked(_DID_method))) ==
                (keccak256(abi.encodePacked(DID_method))),
            "invalid_method"
        );
        uint256 random_number =
            (uint256(keccak256(abi.encodePacked(block.timestamp))) % 100) + 1;
        bytes32 ticket =
            (
                keccak256(
                    abi.encodePacked(random_number, msg.sender, _DeviceIdentity)
                )
            );
        //用ticket mapping到identifier 以利查詢ticket是要對應到什麼resource
        permissionTickets[ticket] = _DeviceIdentity;
        emit TicketGenerated(_DeviceIdentity, ticket, msg.sender, DID_method);
    }

    function accessAuthorize(
        bytes32 _ticket,
        uint8 _ticket_v,
        bytes32 _ticket_r,
        bytes32 _ticket_s,
        bytes memory _claim,
        address _DIDrqp
    ) public returns (bool) {
        //ticket mapping到identifier 以查詢ticket是要對應到什麼resource
        require(permissionTickets[_ticket] != address(0), "invaild_ticket");
        AuthorizationInfo storage authorizationInfo =
            authorizationPolicies[permissionTickets[_ticket]];
        //first check the claim
        bytes32 claimHash = (keccak256(abi.encodePacked(_claim)));
        require(claimHash == authorizationInfo.claimHash, "claim invaild");
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        //驗證提供ticket的是不是RqP
        address signer =
            ecrecover(
                (keccak256(abi.encodePacked(prefix, _ticket))),
                _ticket_v,
                _ticket_r,
                _ticket_s
            );

        //驗證提供ticket的signer是不是RqP，驗證成功則生成access token
        if (signer == _DIDrqp) {
            // Token透過msg.sender/timestamp/random number/隨機生成
            uint256 random_number =
                (uint256(keccak256(abi.encodePacked(block.timestamp))) % 100) +
                    1;
            uint256 expireDate = block.timestamp + tokenExpireDays * 1 days;
            bytes32 token =
                (
                    keccak256(
                        abi.encodePacked(
                            block.timestamp,
                            _DIDrqp,
                            _ticket,
                            random_number
                        )
                    )
                );
            accessToken[_DIDrqp] = token;
            tokenValidTime[token] = expireDate;
            //tokenTarget[token] = _DIDrqp;
            emit TokenReleased(
                _DIDrqp,
                msg.sender,
                token,
                block.timestamp,
                expireDate
            );
            return true;
        } else {
            return false;
        }
    }

    function TokenIntrospect(
        bytes32 _token,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public view returns (bool) {
        if (block.timestamp >= tokenValidTime[_token]) {
            //expired
            return false;
        }

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        address signer =
            ecrecover(
                (keccak256(abi.encodePacked(prefix, _token))),
                _v,
                _r,
                _s
            );

        if (accessToken[signer] == _token) {
            return true;
        } else {
            return false;
        }
    }
}
