// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error CryptoMatrix__NotOwner();
error CryptoMatrix__AlreadyOnLevel();
error CryptoMatrix__LevelNotOpenedYet();
error CryptoMatrix__NotEnoughBNB();
error CryptoMatrix__CallFailed();
error CryptoMatrix__YouNotInWhiteList();
error CryptoMatrix__YouCantBeReferaledByYourself();
error CryptoMatrix__FunctionLockedTakeAWhile();

contract CryptoMatrix {

    event SomeoneJoined(address indexed _from, uint256 indexed _level, uint256 _id);
    event BecomeReferaled(address indexed _from, address indexed _to);

    AggregatorV3Interface internal immutable i_priceFeed;
    address private immutable i_owner;

    mapping (uint256 => uint256) private s_levelToPriceInUsd;
    mapping (uint256 => uint256) private s_levelToUsersIdCounter;
    mapping (uint256 => bool) private s_levelToIsOpen;
    mapping (uint256 => mapping (uint256 => address)) private s_levelAndIdToAdress;
    mapping (address => mapping (uint256 => bool)) private s_addressAndLevelToParticipation;
    mapping (address => mapping (uint256 => uint256)) private s_addressAndLevelToId;

    mapping (address => bool) private s_addressToIsReferaled;
    mapping (address => address) private s_addressToReferaledAddress;

    mapping (uint256 => mapping (uint256 => mapping (address => uint256))) private s_levelAndIdAndAdressToRecievedProcents;
    mapping (uint256 => uint256) private s_levelToLastRecieverId;

    mapping (address => uint256) private s_addressToReferalCounter;
    mapping (address => uint256) private s_addressToReferalProfit;
    mapping (address => uint256) private s_addressToAllTimeProfit;
    
    mapping (address => bool) private s_addressToIsInWhitelist;
    bool private s_isOnlyForWhitelist;
    bool private locked;

    constructor(address _priceFeedAddress) {
        i_owner = msg.sender;
        i_priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    function becomeReferaled(address _address) external payable NoReenterancy() {
        if(msg.sender == _address) {
            revert CryptoMatrix__YouCantBeReferaledByYourself();
        }
        s_addressToIsReferaled[msg.sender] = true;
        s_addressToReferaledAddress[msg.sender] = _address;
        s_addressToReferalCounter[_address]++;
        emit BecomeReferaled(msg.sender, _address);
    }

    function joinGame(uint256 _level) external payable NoReenterancy() {
        if(s_addressAndLevelToParticipation[msg.sender][_level]) {
            revert CryptoMatrix__AlreadyOnLevel();
        }
        if (!s_levelToIsOpen[_level]) {
            revert CryptoMatrix__LevelNotOpenedYet();
        }
        if (s_isOnlyForWhitelist && !s_addressToIsInWhitelist[msg.sender]) {
            revert CryptoMatrix__YouNotInWhiteList();
        }
        if (getConversionRate(msg.value, i_priceFeed) < s_levelToPriceInUsd[_level] * 10 ** 18) {
            revert CryptoMatrix__NotEnoughBNB();
        }

        uint256 curId = s_levelToUsersIdCounter[_level];
        address payingAddress;
        address referal1;
        address referal2;
        address referal3;

        s_addressAndLevelToParticipation[msg.sender][_level] = true;
        s_levelToUsersIdCounter[_level]++;
        s_levelAndIdToAdress[_level][curId] = msg.sender;
        uint256 tempId;
        for (uint256 i = s_levelToLastRecieverId[_level]; i < s_levelToUsersIdCounter[_level]; i++) {
            address tempAddr = s_levelAndIdToAdress[_level][i];
            if (s_levelAndIdAndAdressToRecievedProcents[_level][i][tempAddr] < 140) {
                payingAddress = s_levelAndIdToAdress[_level][i];
                tempId = i;
                s_levelToLastRecieverId[_level] = i;
                break;
            }
            else {
                continue;
            }
        }
        
        if (s_addressToIsReferaled[msg.sender]) {
            referal1 =  s_addressToReferaledAddress[msg.sender];
        }

        s_levelAndIdAndAdressToRecievedProcents[_level][tempId][payingAddress]+=35;
        s_addressToAllTimeProfit[payingAddress]+=35;
        (bool success, ) = payingAddress.call{value:35 * msg.value / 100}("");

        if(s_addressToIsReferaled[msg.sender]) {
        referal1.call{value:10 * msg.value / 100}("");
        s_addressToReferalProfit[referal1]+=10;

            if (s_addressToIsReferaled[referal1]) {
            referal2 = s_addressToReferaledAddress[referal1];
            referal2.call{value:6 * msg.value / 100}("");
            s_addressToReferalProfit[referal2]+=6;

                if (s_addressToIsReferaled[referal2]) {
                referal3 = s_addressToReferaledAddress[referal2];
                referal3.call{value:4 * msg.value / 100}("");
                s_addressToReferalProfit[referal3]+=4;

                                }
                            }
                    }
        emit SomeoneJoined(msg.sender, _level, curId);
    }
        
    function getPrice(AggregatorV3Interface _priceFeed) internal view returns (uint256) {
        (, int price, , ,) = _priceFeed.latestRoundData();
        return uint256(price * 10000000000);
    }

    function getConversionRate(uint256 _bnbAmount, AggregatorV3Interface _priceFeed) internal view returns (uint256) {
        uint256 bnbPrice = getPrice(_priceFeed);
        uint256 bnbAmountInUsd = (bnbPrice * _bnbAmount) / 1000000000000000000;
    
        return bnbAmountInUsd;
    }

    function withdraw() payable external {
        if(msg.sender != i_owner) {
            revert CryptoMatrix__NotOwner();
        }
        (bool success, ) = msg.sender.call{value:address(this).balance}("");
        if (!success) {
            revert CryptoMatrix__CallFailed();
        }
    }

    function whitelistOpener(bool _isOnlyForWhitelist) external {
        if(msg.sender != i_owner) {
            revert CryptoMatrix__NotOwner();
        }
        s_isOnlyForWhitelist = _isOnlyForWhitelist;
    }

    function setWhitelistMemberState(address _memberAddress, bool _state) external {
        if(msg.sender != i_owner) {
            revert CryptoMatrix__NotOwner();
        }
        s_addressToIsInWhitelist[_memberAddress] = _state;
    }

    function setLevelState(uint256 _level, bool _isOpen) external {
        if(msg.sender != i_owner) {
            revert CryptoMatrix__NotOwner();
        }
        s_levelToIsOpen[_level] = _isOpen;
    }

    function setPriceForLevel(uint256 _level, uint256 _price) external {
        if(msg.sender != i_owner) {
            revert CryptoMatrix__NotOwner();
        }
        s_levelToPriceInUsd[_level] = _price;
    }

    modifier NoReenterancy() {
        if (locked) {
            revert CryptoMatrix__FunctionLockedTakeAWhile();
        }
        locked = true;
        _;
        locked = false;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getLevelToPriceInUsd(uint256 _level) external view returns (uint256) {
        return s_levelToPriceInUsd[_level];
    }
    function getLevelToLastRecieverId(uint256 _level) external view returns (uint256) {
        return s_levelToLastRecieverId[_level];
    }

    function getLevelToUsersIdCounter(uint256 _level) external view returns (uint256) {
        return s_levelToUsersIdCounter[_level];
    }

    function getLevelToIsOpen(uint256 _level) external view returns (bool) {
        return s_levelToIsOpen[_level];
    }

    function getAddressAndLevelToParticipation(address _address, uint256 _level) external view returns (bool) {
        return s_addressAndLevelToParticipation[_address][_level];
    }

    function getAddressToIsReferaled(address _address) external view returns (bool) {
        return s_addressToIsReferaled[_address];
    }

    function getAddressToReferaledAddress(address _address) external view returns (address) {
        return s_addressToReferaledAddress[_address];
    }

    function getAddressAndLevelToId(address _address, uint256 _level) external view returns (uint256) {
        return s_addressAndLevelToId[_address][_level];
    }

    function getLevelAndIdToAdress(uint256 _level, uint256 _Id) external view returns (address) {
        return s_levelAndIdToAdress[_level][_Id];
    }

    function getLevelAndIdAndAdressToRecievedProcents(uint256 _level, uint256 _Id, address _address) external view returns (uint256) {
        return s_levelAndIdAndAdressToRecievedProcents[_level][_Id][_address];
    }

    function getsAddressToReferalCounter(address _address) external view returns (uint256) {
        return s_addressToReferalCounter[_address];
    }

    function getAddressToReferalProfit(address _address) external view returns (uint256) {
        return s_addressToReferalProfit[_address];
    }

    function getAddressToAllTimeProfit(address _address) external view returns (uint256) {
        return s_addressToAllTimeProfit[_address];
    }
}
