// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.7;
import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';



contract Trustless is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;
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
setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);

    }
bytes32 private jobId;
    uint256 private fee;


    IERC20 erc20;
    using SafeERC20 for IERC20;
    mapping(uint256=>Txn)database;
    uint256 tkn;
    address owner;
    event eventTxn(address indexed buyer,address indexed seller,uint256 token);
    event dispute(uint256 indexed token,address indexed owner,string reason);
jobId = 'ca98366cc7314957b8c012c72f05aeeb';
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)

function fulfill(bytes32 _requestId, uint256 _volume) public recordChainlinkFulfillment(_requestId) {
                volume = _volume;
    }

function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }


function requestVolumeData() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        // Set the URL to perform the GET request on
        req.add('get', 'https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD');

        // Set the path to find the desired data in the API response, where the response format is:
        // {"RAW":
        //   {"ETH":
        //    {"USD":
        //     {
        //      "VOLUME24HOUR": xxx.xxx,
        //     }
        //    }
        //   }
        //  }
        // request.add("path", "RAW.ETH.USD.VOLUME24HOUR"); // Chainlink nodes prior to 1.0.0 support this format
        req.add('path', 'RAW,ETH,USD,VOLUME24HOUR');


        // Sends the request
        return sendChainlinkRequest(req, fee);
    }



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
