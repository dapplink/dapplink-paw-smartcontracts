pragma solidity 0.5.0;


contract Dapplink {
    
    string  public   name;
    string  public   symbol;
    string  internal nft_uri_base;
    string  internal nft_uri_protocol;
    uint256 public   totalSupply;
    
    mapping( address => bool ) public wheel;
    
    uint256 public fee_transfer;
    uint256 public fee_approve;
    
    struct filesystem {
        address file_sha;	
        string  file_mime;
        uint    n_chunks;
    } 
    
    mapping( address => uint256 ) internal balances;
    mapping( uint256 => address ) internal owners;
    mapping( uint256 => address ) internal allowance;
    mapping( uint256 => string  ) public   domains;
    mapping( uint256 => uint256 ) public   index_id;
    mapping( uint256 => bool    ) public   closed;
    
    mapping(  uint256 => mapping( address => filesystem )  ) public files;
    
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    
    event Chunk
        (
            uint256 indexed tokenId,
            address indexed file_sha,
            uint    indexed chunk_index,
            bytes           chunk_data
        ); 
    
    constructor () public {
        name                = "Dapplink";
        symbol              = "DLK";
        wheel[ msg.sender ] = true;
        nft_uri_protocol    = "https://";
        nft_uri_base        = ".dapplink.org";
        totalSupply         = 0;
    }
    
    modifier wheel_only {
        require(  wheel[ msg.sender ]  );
        _;
    }
    
    function mint( string memory _domain, address _owner ) public wheel_only {
        uint256 domain_hash = uint256(keccak256(abi.encodePacked(_domain)));
        uint256 domain_match = uint256(keccak256(abi.encodePacked(domains[domain_hash])));
        require( domain_match != domain_hash );
        balances[ _owner ]++;
        owners[ domain_hash ] = _owner;
        domains[ domain_hash ] = _domain;
        totalSupply++;
        index_id[ totalSupply ] = domain_hash;
        emit Transfer( 0x0000000000000000000000000000000000000000, _owner, domain_hash );
    }
    
    function balanceOf( address _owner ) public view returns ( uint256 ) {
        return balances[ _owner ];
    }
    
    function ownerOf( uint256 _tokenId ) public view returns ( address ) {
        require( _tokenId != 0 );
        return owners[ _tokenId ];
    }
    
    function safeTransferFrom( address _from, address _to, uint256 _tokenId, bytes memory data ) public payable {
        transferFrom(_from, _to, _tokenId);
        uint32 size;
        assembly {
            size := extcodesize(_to)
        }
        if(size > 0){
            ERC721TokenReceiver receiver = ERC721TokenReceiver(_to);
            require(receiver.onERC721Received(msg.sender,_from,_tokenId,data) == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")));
        }
    }
    
    function safeTransferFrom( address _from, address _to, uint256 _tokenId ) public payable {
        safeTransferFrom( _from, _to, _tokenId, "" );
    }
    
    function transferFrom( address _from, address _to, uint256 _tokenId ) public payable {
        address owner = ownerOf( _tokenId );
        require (   msg.value >= fee_transfer || wheel[ msg.sender ]  );
        require ( owner == msg.sender  || allowance[_tokenId] == msg.sender );
        require ( owner == _from );
        require ( _to != 0x0000000000000000000000000000000000000000 );
        emit Transfer( _from, _to, _tokenId );
        owners[ _tokenId ] = _to;
        balances[ _from ]--;
        balances[ _to ]++;
        if(  allowance[ _tokenId ] != 0x0000000000000000000000000000000000000000  ) {
            delete allowance[ _tokenId ];
        }
    }
    
    function approve( address _approved, uint256 _tokenId ) external payable {
        address owner = ownerOf( _tokenId );
        require( owner == msg.sender, "You have no rights" );
        require ( msg.value >= fee_approve );
        allowance[ _tokenId ] = _approved;
        emit Approval( owner, _approved, _tokenId );
    }
    
    function setApprovalForAll( address _operator, bool _approved ) external {
        require( false, "setApprovalForAll method is deprecated");
    }
    
    function getApproved( uint256 _tokenId ) external view returns ( address ) {
        require( _tokenId != 0 );
        return allowance[_tokenId];
    }
    
    function isApprovedForAll( address _owner, address _operator ) external view returns ( bool ) {
        return false;
    }
    
    function tokenURI( uint256 _tokenId ) public view returns (string memory) {
        return string(abi.encodePacked( nft_uri_protocol, domains[_tokenId], nft_uri_base, "/nft.json" ));
    }
    
    function tokenByIndex( uint256 _index ) external view returns (uint256) {
        require ( _index <= totalSupply );
        return index_id[ _index ];
    }

    function tokensOfOwner( address _owner ) public view returns (uint256[] memory) {
        uint256 n = balances[_owner];
        uint256[] memory ids = new uint256[](n);
        uint256 push_pointer = 0;
        for ( uint256 i = 1; i <= totalSupply; i++ ) {
            if ( owners[index_id[i]] == _owner ) {
                ids[ push_pointer ] = index_id[ i ];
                push_pointer++;
            }
        }
        return ids;
    }

    function tokenOfOwnerByIndex( address _owner, uint256 _index ) external view returns (uint256) {
        require( _index <= balanceOf(_owner) );
        uint256[] memory ids = tokensOfOwner(_owner);
        return ids[_index-1];
    }
    
    function supportsInterface( bytes4 interfaceID ) external view returns ( bool ) {
        if ( interfaceID == 0x80ac58cd ) return true; // ERC721
        if ( interfaceID == 0xffffffff ) return true; // ERC165
        if ( interfaceID == 0x5b5e139f ) return true; // ERC721Metadata
        if ( interfaceID == 0x780e9d63 ) return true; // ERC721Enumerable
        return false;
    }

    function add_admin( address _address ) external wheel_only {
        wheel[ _address ] = true;
    }
    
    function remove_admin( address _address ) external wheel_only {
        delete wheel[ _address ];
    }
        
    function set_transfer_fee( uint256 _fee ) external wheel_only {
        fee_transfer = _fee;
    }
        
    function set_approve_fee( uint256 _fee ) external wheel_only {
        fee_approve = _fee;
    }
    
    function setURI( string calldata _protocol, string calldata _base_uri ) external wheel_only {
        nft_uri_protocol = _protocol;
        nft_uri_base     = _base_uri;
    }

    function withdraw( address payable _address ) external wheel_only {
        _address.send(  address( this ).balance  );
    }
    
    function addressToString( address _address ) private pure returns( string memory ) {
        bytes32 _bytes = bytes32( uint256( _address));
        bytes memory HEX = "0123456789abcdef";
        bytes memory _string = new bytes(42);
        _string[ 0 ] = '0';
        _string[ 1 ] = 'x';
        for (uint i = 0; i < 20; i++) {
            _string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
            _string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
        }
        return string( _string );
    }
    
    function isProfileDomain( uint256 token_id, address _address ) private view returns ( bool ) {
        return uint256( keccak256( abi.encodePacked( addressToString( _address)))) == token_id;
    }

    modifier token_owner_only( uint256 tokenId ) {
        require( msg.sender == ownerOf( tokenId) || isProfileDomain( tokenId, msg.sender));
        require( closed[ tokenId ] == false);
        _;
    } 
        
    function upload_chunk
        (
            uint256        tokenId,
            address        file_sha,
            uint           chunk_index,
            bytes   memory chunk_data
        ) 
        public token_owner_only( tokenId )
        {
            emit Chunk (
                tokenId,
                file_sha, 
                chunk_index,
                chunk_data
            );
        } 
        
    function link
        (
            uint256         tokenId,
            address         pathname_sha,
            address         file_sha,
            string   memory file_mime,
            uint            n_chunks
        ) 
        public token_owner_only( tokenId )
        {
            files[ tokenId ][ pathname_sha ].file_sha  = file_sha;
            files[ tokenId ][ pathname_sha ].file_mime = file_mime;
            files[ tokenId ][ pathname_sha ].n_chunks  = n_chunks;
        } 
        
    function unlink( uint256 tokenId, address pathname_sha ) public token_owner_only( tokenId ) {
        delete files[ tokenId ][ pathname_sha ];
    }
        
    function close( uint256 tokenId ) public token_owner_only( tokenId ) {
        closed[ tokenId ] = true;
    }

}


interface ERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4);
}


contract Minter {
    
    Dapplink private dapplink;
    PAW      private paw;
    
    address   public admin;
    address   public profit;
    uint256[] public price_by_word;
    uint256   public ordinary_domain_price;
    
    event Mint( string _domain, address indexed _owner );
    
    constructor( address _dapplink_contract, address payable _paw_contract ) public {
        
        dapplink      = Dapplink( _dapplink_contract );
        paw           = PAW     ( _paw_contract );
        
        price_by_word = [10,9,8,7,6,5]; // TODO put into constructor para
        ordinary_domain_price = 2; // TODO put into constructor para
        admin = msg.sender;
        profit = msg.sender;
    }
    
    modifier admin_only {
        require( msg.sender == admin );
        _;
    } 
    
    function get_total_price( string memory _domain ) public view returns( uint price ){
        uint256 total_price = ordinary_domain_price;
        uint256 len = bytes( _domain ).length;
        if ( len <= price_by_word.length ) {
            total_price = price_by_word[ len - 1 ];
        }
        return total_price;
    }
    
    function mint( string memory _domain ) public payable {
        
        uint256 total_price = get_total_price( _domain );
        require(  paw.allowance( msg.sender,  address(this) ) >= total_price, "No enough approved PAWs"  );
        
        bytes memory byte_string = bytes( _domain );
        bytes1 firstSymbol = byte_string[0];
        bool start_with_digit = firstSymbol >= "0" && firstSymbol <= "9";
        require( !start_with_digit, "Domain can not start with digit" );
        require( byte_string.length < 64, "Domain name is too long" );
        
        uint256 domain_hash = uint256(keccak256(abi.encodePacked(_domain)));
        uint256 domain_match = uint256(keccak256(abi.encodePacked(dapplink.domains(domain_hash))));
        require( domain_match != domain_hash );
        
        paw.transferFrom( msg.sender, address(this), total_price );
        paw.transfer( profit, total_price );
        dapplink.mint( _domain, msg.sender );
        emit Mint( _domain, msg.sender );
        
    }
    
    function get_prices() public view returns( uint256[] memory ) {
        return price_by_word;
    }
    
    function set_prices( uint256[] memory _arr) public admin_only {
        price_by_word = _arr;
    }
    
    function set_ordinary_domain_price( uint256 _price ) public admin_only {
        ordinary_domain_price = _price;
    }
    
    function set_admin( address _admin ) external admin_only {
        admin = _admin;
    }
    
    function set_profit( address _profit ) external admin_only {
        profit = _profit;
    }
    
}


contract Residue {
    
    mapping( uint256 => mapping( uint8 => address )) public beneficiaries;
    mapping( uint256 => mapping( uint8 => uint8   )) public share_of_beneficiary;
    mapping( uint256 => uint8 )                      public number_of_beneficiaries;
    mapping( uint256 => uint8 )                      public residue_percent;
    
    uint256 public residue_percent_limit;
    
    Dapplink dapplink;
    
    constructor( address _dapplink_contract ) public {
        dapplink = Dapplink( _dapplink_contract );
        residue_percent_limit = 10;
    }
    
     modifier token_owner_only( uint256 _token_id ) {
            require( msg.sender == dapplink.ownerOf( _token_id ) );
            require( dapplink.closed( _token_id ) != true );
            _;
    } 
    
    function add_beneficiary( uint256 _token_id, address _beneficiary, uint8 _share ) public token_owner_only( _token_id ) {
        number_of_beneficiaries[ _token_id ]++;
        beneficiaries       [ _token_id ][ number_of_beneficiaries[_token_id] ] = _beneficiary;
        share_of_beneficiary[ _token_id ][ number_of_beneficiaries[_token_id] ] = _share;
    }
    
    function remove_last_beneficiary( uint256 _token_id ) public token_owner_only( _token_id ){
        delete beneficiaries       [ _token_id ][ number_of_beneficiaries[_token_id] ];
        delete share_of_beneficiary[ _token_id ][ number_of_beneficiaries[_token_id] ];
        number_of_beneficiaries[ _token_id ]--;
    }
    
    function set_residue_percent( uint256 _token_id, uint8 _residue_percent ) public token_owner_only( _token_id ) {
        require( _residue_percent <= residue_percent_limit );
        residue_percent[ _token_id ] = _residue_percent;
    }
    
}


contract Charity {
    
    Dapplink dapplink;
    
    address admin;
    mapping ( uint16  => address ) public charity_list;
    mapping ( address => uint16  ) public charity_list_index;
    mapping ( address => bool    ) public allowance;
    uint16                         public number_of_charities;
    mapping ( uint256 => address ) public charity_orders;

    constructor( address _dapplink_contract ) public {
        dapplink = Dapplink( _dapplink_contract );
        admin = msg.sender;
        number_of_charities = 0;
    }

    modifier admin_only {
        require( msg.sender == admin );
        _;
    } 

    function add_charity( address _charity_address ) public admin_only {
        bool is_charity_not_registered = charity_list_index[ _charity_address ] == 0;
        require( is_charity_not_registered );
        number_of_charities++;
        charity_list[ number_of_charities ] = _charity_address;
        charity_list_index[ _charity_address ] = number_of_charities; 
        allowance[ _charity_address ] = true;
    }
    
    function set_charity_allowance( address _charity_address, bool _status ) public admin_only {
        allowance[ _charity_address ] = _status;
    }
    
    function make_charity_order( uint256 _token_id, address _charity_address ) public {
        bool is_sender_owner_of_token = dapplink.ownerOf( _token_id ) == msg.sender;
        // bool is_nft_not_closed = ! dapplink.closed( _token_id );
        bool is_charity_registered = charity_list_index[ _charity_address ] != 0;
        require( is_sender_owner_of_token );
        // require( is_nft_not_closed );
        require( is_charity_registered );
        charity_orders[ _token_id ] = _charity_address;
    }
    
    function change_admin( address _admin ) public admin_only {
        admin = _admin;
    }
}


contract Market {
    
    Dapplink private dapplink;
    PAW      private paw;
    Charity  private charity;
    Residue  private residue;
    
    uint256 public sale_fee_permille;
    uint256 public listing_fee;
    uint256 public charity_permille;
    
    address public admin;
    address public profit_getter;
    
    mapping( uint256 => uint256 ) public pricelist;
    
    constructor 
        (
            address         _dapplink_contract, 
            address         _charity_contract, 
            address         _residue_contract,
            address payable _paw_contract,
            address         _profit_getter
        ) public {
        dapplink          = Dapplink ( _dapplink_contract );
        paw               = PAW      ( _paw_contract      );
        charity           = Charity  ( _charity_contract  );
        residue           = Residue  ( _residue_contract  );
        admin             = msg.sender;
        profit_getter     = _profit_getter;
        sale_fee_permille = 29;
        charity_permille  = 10;
        listing_fee       = 0;
    }


    modifier sale_req( uint256 _token_id ) {
        require(  dapplink.getApproved  ( _token_id ) == address(this), "Token is not approved for sale"  );
        require(  charity.charity_orders( _token_id ) != address(0),    "No charity address specified"    );
        _;
    }
    
    
    function add_sale( uint256 _token_id, uint256 _price ) public sale_req( _token_id ) {

        require(  dapplink.ownerOf( _token_id )              == msg.sender,  "Unauthorized call"                    );
        require(  paw.allowance( msg.sender, address(this) ) >= listing_fee, "No enough approved PAWs for listing"  );
        
        if ( listing_fee > 0 ) {
            paw.transferFrom( msg.sender, address(this), listing_fee );
            paw.transferFrom( address(this), profit_getter, listing_fee );
        }
        
        pricelist[ _token_id ] = _price;
        
    }
    
    
    function cancel_sale( uint256 _token_id ) public {
        
        require(  dapplink.ownerOf( _token_id ) == msg.sender,  "Unauthorized call"  );
        
        delete pricelist[_token_id];
        
    }
    
    
    function buy( uint256 _token_id ) public sale_req( _token_id ) {
    
        require(  paw.allowance( msg.sender, address(this) ) >= pricelist[ _token_id ], "No enough approved PAWs for purchase"  );

        paw.transferFrom(  msg.sender,  address(this),  pricelist[ _token_id ]  );
        uint rest = pricelist[ _token_id ];
        
        uint charity_volume  = pricelist[ _token_id ] * charity_permille  / 1000;
        uint sale_fee_volume = pricelist[ _token_id ] * sale_fee_permille / 1000;
        
        bool has_to_pay_residue = residue.residue_percent( _token_id ) > 0 && residue.number_of_beneficiaries( _token_id ) > 0;
        if ( has_to_pay_residue ) {
            uint residue_volume = pricelist[ _token_id ] * residue.residue_percent( _token_id ) / 100;
            uint total_shares = 0;
            for (uint8 i = 1; i <= residue.number_of_beneficiaries( _token_id ); i++) {
                total_shares += residue.share_of_beneficiary( _token_id, i );
            }
            for (uint8 i = 1; i <= residue.number_of_beneficiaries( _token_id ); i++) {
                uint payment = residue_volume / total_shares * residue.share_of_beneficiary( _token_id, i );
                paw.transfer(  residue.beneficiaries( _token_id, i ),  payment  );
                rest -= payment;
            }
        }
        
        paw.transfer(  charity.charity_orders( _token_id ), charity_volume  );
        rest -= charity_volume;
        
        paw.transfer( profit_getter, sale_fee_volume );
        rest -= sale_fee_volume;
        
        paw.transfer( dapplink.ownerOf( _token_id ), rest );
        
        dapplink.transferFrom(  dapplink.ownerOf( _token_id ),  msg.sender,  _token_id  );
        
        delete pricelist[ _token_id ];
        
    }
    
    function set_profit_getter( address _profit_getter ) public {
        require( msg.sender == admin) ;
        profit_getter = _profit_getter;
    } 
    
    function set_admin( address _admin ) public {
        require( msg.sender == admin );
        admin = _admin;
    }
    
    function set_listing_fee( uint _fee ) public {
        require( msg.sender == admin );
        listing_fee = _fee;
    }
    
}


contract SafeMath {
    function safeAdd(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function safeSub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function safeMul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function safeDiv(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


contract PAW is SafeMath {
    
    string  public symbol;
    string  public name;
    uint8   public decimals;
    uint    public totalSupply;
    
    address payable public owner;

    mapping( address => uint) public balances;
    mapping( address => mapping( address => uint )) public allowed;
    
    event Transfer (address indexed from, address indexed to, uint tokens);
    event Approval (address indexed _token_owner, address indexed _spender, uint _tokens);

    constructor() public {
        symbol      = "PAW";
        name        = "Paw dummy token";
        decimals    = 18;
        totalSupply = 1e23;
        owner       = msg.sender;
        balances[ msg.sender ] = totalSupply;
    }

    function balanceOf( address tokenOwner ) public view returns( uint balance ) {
        return balances[ tokenOwner ];
    }

    function transfer( address to, uint tokens ) public returns( bool success ) {
        balances[ msg.sender ] = safeSub(  balances[ msg.sender ],  tokens  );
        balances[ to ]         = safeAdd(  balances[ to ],          tokens  );
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function approve( address spender, uint tokens ) public returns( bool success ) {
        allowed[ msg.sender ][ spender ] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom( address from, address to, uint tokens ) public returns( bool success ) {
        balances[ from ]              = safeSub(  balances[ from ],               tokens  );
        allowed[ from ][ msg.sender ] = safeSub(  allowed[ from ][ msg.sender ],  tokens  );
        balances[ to ]                = safeAdd(  balances[ to ],                 tokens  );
        emit Transfer(from, to, tokens);
        return true;
    }

    function allowance( address tokenOwner, address spender ) public view returns( uint remaining ) {
        return allowed[ tokenOwner ][ spender ];
    }

   /*
    function approveAndCall(address spender, uint tokens, bytes memory data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }
    */
    
    function () external payable {
        uint256 tokens = msg.value * 1000;
        balances[msg.sender] = safeAdd(balances[msg.sender], tokens);
        totalSupply = safeAdd(totalSupply, tokens);
        emit Transfer(address(0), msg.sender, tokens);
        owner.send(msg.value);
    }
}
