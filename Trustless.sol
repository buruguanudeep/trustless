
contract Trustless{
    struct Txn{
        address buyer;
        address seller;
        uint256 amt;
        uint256 lock_time;
        bool dispute;
        bool settled;
    }
    uint256 grace_period=24*60*60;

    constructor(address token,address ow){
        owner=ow;
        erc20=IERC20(token);
    }

    IERC20 erc20;
    using SafeERC20 for IERC20;
    mapping(uint256=>Txn)database;
    uint256 tkn;
    address owner;
    event eventTxn(address indexed buyer,address indexed seller,uint256 token);
    event dispute(uint256 indexed token,address indexed owner,string reason);

    //deposit tokens and lock'em;
    function deposit(address buyer,uint256 amt)public {
        tkn+=1;
        database[tkn]=Txn(buyer,msg.sender,amt,block.timestamp,false,false);
        erc20.safeTransferFrom(msg.sender ,address(this), amt);
        emit eventTxn(buyer,msg.sender,tkn);
    }
    //seller confirms
    function release(uint256 token)public{
        require(!database[token].settled);
        require(msg.sender==database[token].seller,"only seller can release");
        erc20.safeTransfer(database[token].buyer,database[token].amt);
        database[token].settled=true;
        emit eventTxn(database[token].buyer,database[token].seller,database[token].amt);
    }

    //or buyer cancels
    function cancel(uint256 token)public{
        require(!database[token].settled);
        require(database[token].buyer==msg.sender,"only buyer can cancel txn");
        erc20.safeTransfer(database[token].seller,database[token].amt);
        database[token].settled=true;
        emit eventTxn(database[token].buyer,database[token].seller,database[token].amt);
    }
    //no response from buyer after locking tokens,you could withdraw tokens;
    function grace_revert(uint256 token)public{
        require(!database[token].settled);
        require(!database[token].dispute && block.timestamp>database[token].lock_time + grace_period);
        require(msg.sender==database[token].seller,"only seller can revert");
        erc20.safeTransfer(database[token].seller,database[token].amt);
        database[token].settled=true;
    }
    //call dispute incase seller disagrees to release tokens 
    function call_dispute(uint256 token,string calldata reason)public{
        require(!database[token].settled,"txn has been settled!");
        require(msg.sender==database[token].buyer,"only buyer can dispute");
        database[token].dispute=true;
        emit dispute(token,owner,reason);
    }
    // call only if buyer wants to revert tokens back to seller
    function call_dispute_settled(uint256 token,string calldata reason)public{
        require(!database[token].settled && database[token].dispute,"either txn has been settled or not disputed");
        require(msg.sender==database[token].buyer,"only buyer can call dispute settled");
        erc20.safeTransfer(database[token].seller,database[token].amt);
        database[token].settled=true;
        emit dispute(token,owner,reason);
    }


}
