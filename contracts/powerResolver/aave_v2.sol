pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface AaveProtocolDataProvider {
    function getUserReserveData(address asset, address user) external view returns (
        uint256 currentATokenBalance,
        uint256 currentStableDebt,
        uint256 currentVariableDebt,
        uint256 principalStableDebt,
        uint256 scaledVariableDebt,
        uint256 stableBorrowRate,
        uint256 liquidityRate,
        uint40 stableRateLastUpdated,
        bool usageAsCollateralEnabled
    );
}

interface AaveLendingPool {
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

interface AaveAddressProvider {
    function getLendingPool() external view returns (address);
    function getPriceOracle() external view returns (address);
}

contract Helpers {

    struct AaveData {
        uint collateral;
        uint debt;
    }

    struct data {
        address user;
        AaveData[] tokensData;
    }
    
    struct datas {
        AaveData[] tokensData;
    }

    /**
     * @dev get Aave Provider Address
    */
    function getAaveAddressProvider() internal pure returns (address) {
        return 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5; // Mainnet
        // return 0x652B2937Efd0B5beA1c8d54293FC1289672AFC6b; // Kovan
    }

}

contract Resolver is Helpers {

    function getPositionByAddress(
        address[] memory owners
    )
        public
        view
        returns (AaveData[] memory tokensData)
    {
        AaveAddressProvider addrProvider = AaveAddressProvider(getAaveAddressProvider());
        AaveLendingPool aave = AaveLendingPool(addrProvider.getLendingPool();
        tokensData = new AaveData[](owners.length);
        for (uint i = 0; i < owners.length; i++) {
            (uint256 collateral,uint256 debt,,,,) = aave.getUserAccountData(owners[i]);
            tokensData[i] = AaveData(
                collateral,
                debt
            );
        }
    }

}