// escrow.sol
// SPDX-License-Identifier: MIT

import {myfamilynft} from "https://github.com/FamilyNFT/FamilyHackathon/blob/backend/contracts/contracts/myfamilynft.sol";
import {LSP8Marketplace} from "./LSP8Marketplace.sol";

pragma solidity ^0.8.0;

contract LSP8MarketplaceEscrow is LSP8Marketplace, familynft {
    struct escrowTrade {
        address LSP8Address;
        bytes32 tokenId;
        address LSP7Address;
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

    function _newEscrowSaleLSP7(
        address LSP8Address,
        bytes32 tokenId,
        address LSP7Address,
        uint256 amount,
        address seller,
        address buyer
    ) internal returns (address) {
        require(!LSP7Address == NULL, "LSP7 address cannot be null");
        count++;
        escrowTrade memory _trade = escrowTrade(
            LSP8Address,
            tokenId,
            LSP7Address,
            amount,
            seller,
            buyer,
            PENDING,
            PENDING,
            PENDING
        );
        trades[count] = _trade;
        return address(this);
    }

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
            NULL,
            PriceLYX,
            seller,
            buyer,
            PENDING,
            PENDING,
            PENDING
        );
        trades[count] = _trade;
        return address(this);
    }

    /**
     * Called by buyer or seller to report the item as lost.
     * Checks status of buyer and seller and closes trade accordingly
     * (or waits for the second responses).
     * @dev updated bStatus or sStatus to LOST when called.
     *
     * @param _Id ID of the trade.
     *
     * @notice only seller or buyer of the trade can call this function
     */
    function reportLost(uint256 _Id) external {
        require(
            msg.sender == trades[_Id].to || msg.sender == trades[_Id].from,
            "You are not buyer or seller for this trade"
        );
        // buyer
        if (msg.sender == trades[_Id].to) {
            trades[_Id].bStatus == LOST;
            if (trades[_Id].sStatus == LOST) {
                _lostTrade(_Id);
                trades[_id].tradeStatus = LOST;
            } else if (trades[_Id].sStatus == CONFIRMED) {
                _resolveTrade(_Id);
                trades[_id].tradeStatus = CONFLICT;
            }
        }
        // seller
        if (msg.sender == trades[_Id].from) {
            trades[_Id].sStatus == LOST;
            if (trades[_Id].bStatus == LOST) {
                _lostTrade(_Id);
                trades[_id].tradeStatus = LOST;
            } else if (trades[_Id].bStatus == CONFIRMED) {
                _resolveTrade(_Id);
                trades[_id].tradeStatus = CONFLICT;
            }
        }
    }

    /**
     * Called by buyer or seller to report the item as confirmed.
     * Checks status of buyer and seller and closes trade accordingly
     * (or waits for the second responses).
     * @dev updated bStatus or sStatus to CONFIRMED when called.
     *
     * @param _Id ID of the trade.
     *
     * @notice only seller or buyer of the trade can call this function.
     */
    function reportConfirm(uint256 _Id) external {
        require(
            msg.sender == trades[_Id].to || msg.sender == trades[_Id].from,
            "not buyer or seller for this trade"
        );
        // buyer
        if (msg.sender == trades[_Id].to) {
            trades[_Id].bStatus == CONFIRMED;
            if (trades[_Id].sStatus == CONFIRMED) {
                _confirmTrade(_Id);
                trades[_id].tradeStatus = CONFIRMED;
            } else if (trades[_Id].sStatus == LOST) {
                _resolveTrade(_Id);
                trades[_id].tradeStatus = CONFLICT;
            }
        }
        // seller
        if (msg.sender == trades[_Id].from) {
            trades[_Id].sStatus == CONFIRMED;
            if (trades[_Id].bStatus == CONFIRMED) {
                _confirmTrade(_Id);
                trades[_id].tradeStatus = CONFIRMED;
            } else if (trades[_Id].bStatus == lOST) {
                _resolveTrade(_Id);
                trades[_id].tradeStatus = CONFLICT;
            }
        }
    }

    /**
     * returns status of trade for a give tradeID

     * @param _Id ID of the trade.
     *
     * @notice anyone can call this function
     */
    function getStatus(uint256 _id) public view returns (status) {
        return trades[_id].tradeStatus;
    }

    /**
     * returns status of trade for a give tradeID

     * @param _Id ID of the trade.
     *
     * @notice anyone can call this function
     */
    function getMinter(address _LSP8Address, uint256 _tokenId)
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
     * @param _Id ID of the trade.
     *
     * @notice only this contract can call this function. For more
     * information see _transferLS7 and _transferLS8 functions in
     * LSP8MarketplaceTrade.sol.
     */
    function _confirmTrade(uint256 _Id) private payable {
        uint256 _valueSeller = ((trades[_Id].amount) * 90) / 100;
        uint256 _valueMinter = ((trades[_Id].amount) * 10) / 100;
        tokenMinter = _getMinterInfo(trades[_id].LSP8Address); // <<<<< still need to do this

        // transfer LSP8 asset to buyer
        _transferLSP8(
            trades[_Id].tokenAddress,
            trades[_Id].from,
            trades[_Id].to,
            trades[_Id].tokenId,
            true,
            1
        );

        // transfer funds to SELLER+MINTER depending on payment type (LSP7 or LYX)
        if (!trades[_Id].LSP7Address == NULL) {
            // SELLER
            _transferLSP7(
                trades[_Id].LSP7Address,
                address(this),
                _seller,
                _valueSeller,
                true
            );
            // MINTER
            _transferLSP7(
                trades[_Id].LSP7Address,
                address(this),
                tokenMinter, // <------ TO-DO
                _valueRoyalty,
                true
            );
        } else {
            // transfer LYX to SELLER+MINTER
            trades[_Id].from.transfer(_valueSeller);
            tokenMinter.transfer(_valueMinter);
        }
        trades[_id].tradeStatus = CONFIRMED;
    }

    /**
     * This function is called when the buyer & seller report the trade
     * item as lost. Transfers assets back to their respective owners
     * & updates Trade state on-chain.
     *
     * @param _Id ID of the trade.
     *
     * @notice only this contract can call this function. For more
     * information see _transferLS7 and _transferLS8 functions in
     * LSP8MarketplaceTrade.sol.
     */
    function _lostTrade(uint256 _Id) private payable {
        // transfer LS8 asset back to seller
        _transferLSP8(
            trades[_Id].LSP8Address,
            address(this),
            trades[_Id].from,
            tokenId,
            true,
            amount
        );
        // transfer funds back to buyer
        if (!trades[_Id].LSP7Address == NULL) {
            _transferLSP7(
                trades[_Id].LSP7Address,
                address(this),
                trades[_Id].to,
                trades[_Id].amount,
                true
            );
        } else {
            trades[_Id].to.transfer(trades[_Id].amount);
        }
        trades[_id].tradeStatus = LOST;
    }

    /**
     * This function is called if both parties call a different report
     * function (Confirm/Lost). All assets are transferred to the contract.
     *
     * @param _Id ID of the trade.
     *
     * @notice only this contract can call this function. For more
     * information see _transferLS7 and _transferLS8 functions in
     * LSP8MarketplaceTrade.sol.
     */
    function _resolveTrade(_Id) private payable {
        _transferLSP8(
            trades[_Id].tokenAddress, // ???
            address(this), // which address should this be?? Marketplace? This contract? Is there an Appeal court?
            admin,
            trades[_Id].tokenId,
            true,
            amount
        );
        if (!trades[_Id].LSP7Address == NULL) {
            _transferLSP7(
                trades[_Id].LSP7Address,
                address(this),
                admin,
                trades[_Id].amount,
                true
            );
        } else {
            WHERE.transfer(trades[_Id].amount); // WHERE ARE RESOLVED FUNDS KEPT?
        }

        trades[_id].tradeStatus = CONFLICT;
    }
}
