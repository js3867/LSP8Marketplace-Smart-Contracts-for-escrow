// escrow.sol
// SPDX-License-Identifier: MIT

// import {myfamilynft} from "https://github.com/FamilyNFT/FamilyHackathon/blob/backend/contracts/contracts/myfamilynft.sol";
// import {LSP8Marketplace} from "./LSP8Marketplace.sol";
// import {LSP8Marketplace} from "./LSP8Marketplace.sol";
import {LSP8MarketplaceTrade} from "./LSP8MarketplaceTrade.sol";
import {familynft} from "./familynft.sol";

/**
 * @title LSP8MarketplaceEscrow contract
 * @author Sexton Jim
 *
 * @notice For reference I will assume LSP8 is the same as NFT.
 * @notice ***Additional contract support escrow while IRL products are in delivery
 */

pragma solidity ^0.8.0;

// contract LSP8MarketplaceEscrow is LSP8Marketplace, familynft {
contract LSP8MarketplaceEscrow is LSP8MarketplaceTrade {
    struct escrowTrade {
        address LSP8Address;
        bytes32 tokenId;
        uint256 amount;
        address from;
        address to;
        status tradeStatus;
        status bStatus;
        status sStatus;
    }

    enum status {
        PENDING,
        CONFIRMED,
        CONFLICT,
        LOST
    }

    uint256 count;
    mapping(uint256 => escrowTrade) trades; // trade objects attached to trades

    constructor() {
        address admin = msg.sender;
    }

    /**
     * Called by marketplace when buyer commits to make payment.
     * Locks LSP8 and LSP7 in escrow until exchange is complete.
     *
     * @param LSP8Address Address of the LSP8 to be transfered.
     * @param tokenId Token id of the LSP8 to be transferred.
     * @param amount Sale price of asset.
     * @param seller Address of the LSP8 sender (aka from).
     * @param buyer Address of the LSP8 receiver (aka to).
     *
     * @return address returns address(this) to receive escrowed LSP8 asset
     *
     * @notice this method can only be called once Buyer commits LYX payment
     */
    function _newEscrowSaleLYX(
        address LSP8Address,
        bytes32 tokenId,
        uint256 amount,
        address seller,
        address buyer
    ) internal returns (address) {
        count++;
        escrowTrade memory _trade = escrowTrade(
            LSP8Address,
            tokenId,
            amount,
            seller,
            buyer,
            status.PENDING,
            status.PENDING,
            status.PENDING
        );
        trades[count] = _trade;
        return address(this);
    }

    /**
     * Called by buyer or seller to report the item as lost.
     * Checks status of buyer and seller and closes trade accordingly
     * (or waits for the second responses).
     *
     * @dev updated bStatus or sStatus to LOST when called.
     *
     * @param Id ID of the trade.
     *
     * @notice only seller or buyer of the trade can call this function
     */
    function reportLost(uint256 Id) external {
        require(
            msg.sender == trades[Id].to || msg.sender == trades[Id].from,
            "You are not buyer or seller for this trade"
        );
        require(
            trades[Id].tradeStatus == status.PENDING,
            "Trade has been closed"
        );
        // buyer
        if (msg.sender == trades[Id].to) {
            trades[Id].bStatus == status.LOST;
            if (trades[Id].sStatus == status.LOST) {
                _lostTrade(Id);
            } else if (trades[Id].sStatus == status.CONFIRMED) {
                _resolveTrade(Id);
            }
        }
        // seller
        if (msg.sender == trades[Id].from) {
            trades[Id].sStatus == status.LOST;
            if (trades[Id].bStatus == status.LOST) {
                _lostTrade(Id);
            } else if (trades[Id].bStatus == status.CONFIRMED) {
                _resolveTrade(Id);
            }
        }
    }

    /**
     * Called by buyer or seller to report the item as confirmed.
     * Checks status of buyer and seller and closes trade accordingly
     * (or waits for the second responses).
     * @dev updated bStatus or sStatus to CONFIRMED when called.
     *
     * @param Id ID of the trade.
     *
     * @notice only seller or buyer of the trade can call this function.
     */
    function reportConfirm(uint256 Id) external {
        require(
            msg.sender == trades[Id].to || msg.sender == trades[Id].from,
            "not buyer or seller for this trade"
        );
        // buyer
        if (msg.sender == trades[Id].to) {
            trades[Id].bStatus == status.CONFIRMED;
            if (trades[Id].sStatus == status.CONFIRMED) {
                _confirmTrade(Id);
            } else if (trades[Id].sStatus == status.LOST) {
                _resolveTrade(Id);
            }
        }
        // seller
        if (msg.sender == trades[Id].from) {
            trades[Id].sStatus == status.CONFIRMED;
            if (trades[Id].bStatus == status.CONFIRMED) {
                _confirmTrade(Id);
            } else if (trades[Id].bStatus == status.LOST) {
                _resolveTrade(Id);
            }
        }
    }

    /**
     * returns status of trade for a give tradeID

     * @param Id ID of the trade.
     *
     * @notice anyone can call this function
     */
    function getStatus(uint256 Id) public view returns (status) {
        return trades[Id].tradeStatus;
    }

    /**
     * returns the Minter of a given LSP8 asset

     * @param _LSP8Address the LSP8 collection.
     * @param _tokenId the unique token ID.
     *
     * @notice anyone can call this function
     */
    function _getMinter(address _LSP8Address, uint256 _tokenId)
        public
        view
        returns (address)
    {
        address minter; // THIS NEEDS TO BE SOLVED!
        return minter;
    }

    // PRIVATE SALE-CLOSURE METHODS

    /**
     * This function is called when the buyer confirms the trade.
     * Completes trade by transferring assets to their new respective
     * owners, transfers royalties & updates Trade state on-chain.
     *
     * @param Id ID of the trade.
     *
     * @notice only this contract can call this function. For more
     * information see _transferLS7 and _transferLS8 functions in
     * LSP8MarketplaceTrade.sol.
     */
    function _confirmTrade(uint256 Id) private payable {
        uint256 _valueSeller = ((trades[Id].amount) * 90) / 100;
        uint256 _valueMinter = ((trades[Id].amount) * 10) / 100;
        tokenMinter = _getMinter(trades[Id].LSP8Address, trades[Id].tokenId); // <<<<< still need to do this

        // transfer LSP8 asset to buyer
        _transferLSP8(
            trades[Id].tokenAddress,
            trades[Id].from,
            trades[Id].to,
            trades[Id].tokenId,
            true,
            1
        );
        // transfer LYX to SELLER+MINTER
        trades[Id].from.transfer(_valueSeller);
        tokenMinter.transfer(_valueMinter);
        // updates tradeState
        trades[Id].tradeStatus = status.CONFIRMED;
    }

    /**
     * This function is called when the buyer & seller report the trade
     * item as lost. Transfers assets back to their respective owners
     * & updates Trade state on-chain.
     *
     * @param Id ID of the trade.
     *
     * @notice only this contract can call this function. For more
     * information see _transferLS7 and _transferLS8 functions in
     * LSP8MarketplaceTrade.sol.
     */
    function _lostTrade(uint256 Id) private payable {
        // transfer LS8 asset back to seller
        _transferLSP8(
            trades[Id].LSP8Address,
            address(this),
            trades[Id].from,
            tokenId,
            true,
            amount
        );
        // return LYX to buyer
        trades[Id].to.transfer(trades[Id].amount);
        // updates tradeState
        trades[Id].tradeStatus = status.LOST;
    }

    // /**
    //  * This function is called if both parties call a different report
    //  * function (Confirm/Lost). All assets are transferred to the contract.
    //  *
    //  * @param Id ID of the trade.
    //  *
    //  * @notice only this contract can call this function. For more
    //  * information see _transferLS7 and _transferLS8 functions in
    //  * LSP8MarketplaceTrade.sol.
    //  */
    function _resolveTrade(uint256 Id) private {
        // ESCROW CONTRACT HOLDS ASSETS FOR PURPOSE OF HACKATHON

        // _transferLSP8(
        //     trades[Id].tokenAddress, // ???
        //     address(this), // which address should this be?? Marketplace? This contract? Is there an Appeal court?
        //     admin,
        //     trades[Id].tokenId,
        //     true,
        //     amount
        // );
        // WHERE.transfer(trades[Id].amount); // WHERE ARE RESOLVED FUNDS KEPT?
        trades[Id].tradeStatus = status.CONFLICT;
    }
}
