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

    function getReserveConfigurationData(address asset) external view returns (
        uint256 decimals,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 reserveFactor,
        bool usageAsCollateralEnabled,
        bool borrowingEnabled,
        bool stableBorrowRateEnabled,
        bool isActive,
        bool isFrozen
    );

    function getReserveData(address asset) external view returns (
        uint256 availableLiquidity,
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256 liquidityRate,
        uint256 variableBorrowRate,
        uint256 stableBorrowRate,
        uint256 averageStableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex,
        uint40 lastUpdateTimestamp
    );

    function getReserveTokensAddresses(address asset) external view returns (
        address aTokenAddress,
        address stableDebtTokenAddress,
        address variableDebtTokenAddress
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

interface TokenInterface {
    function totalSupply() external view returns (uint);
}

interface AaveAddressProvider {
    function getLendingPool() external view returns (address);
    function getPriceOracle() external view returns (address);
}

interface AavePriceOracle {
    function getAssetPrice(address _asset) external view returns(uint256);
    function getAssetsPrices(address[] calldata _assets) external view returns(uint256[] memory);
    function getSourceOfAsset(address _asset) external view returns(uint256);
    function getFallbackOracle() external view returns(uint256);
}

interface AaveIncentivesInterface {
    struct AssetData {
        uint128 emissionPerSecond;
        uint128 lastUpdateTimestamp;
        uint256 index;
    }

    function getRewardsBalance(
        address[] calldata assets,
        address user
    ) external view returns (uint256);

    function assets(
        address asset
    ) external view returns (AssetData memory);
}

interface ChainLinkInterface {
    function latestAnswer() external view returns (int256);
    function decimals() external view returns (uint256);
}

contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y <= x ? x - y : 0;
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}

contract AaveHelpers is DSMath {
     /**
     * @dev Return ethereum address
     */
    function getEthAddr() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // MATIC Address
    }

    /**
     * @dev Return Weth address
    */
    function getWethAddr() internal pure returns (address) {
        return 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // polygon mainnet WMATIC Address
    }
    
    /**
     * @dev get Aave Provider Address
    */
    function getAaveAddressProvider() internal pure returns (address) {
        return 0xd05e3E715d945B59290df0ae8eF85c1BdB684744; // polygon mainnet
    }

    /**
     * @dev get Aave Protocol Data Provider
    */
    function getAaveProtocolDataProvider() internal pure returns (address) {
        return 0x7551b5D2763519d4e37e8B81929D336De671d46d; // polygon mainnet
    }

    /**
     * @dev get Chainlink ETH price feed Address
    */
    function getChainlinkEthFeed() internal pure returns (address) {
        return 0xF9680D99D6C9589e2a93a78A04A279e509205945; // polygon mainnet
    }

    /**
     * @dev Aave Incentives address
    */
    function getAaveIncentivesAddress() internal pure returns (address) {
        return 0x357D51124f59836DeD84c8a1730D72B749d8BC23; // polygon mainnet
    }

    struct AaveUserTokenData {
        uint tokenPriceInEth;
        uint tokenPriceInUsd;
        uint supplyBalance;
        uint stableBorrowBalance;
        uint variableBorrowBalance;
        uint supplyRate;
        uint stableBorrowRate;
        uint userStableBorrowRate;
        uint variableBorrowRate;
        bool isCollateral;
        AaveTokenData aaveTokenData;
    }

    struct AaveUserData {
        uint totalCollateralETH;
        uint totalBorrowsETH;
        uint availableBorrowsETH;
        uint currentLiquidationThreshold;
        uint ltv;
        uint healthFactor;
        uint ethPriceInUsd;
        uint pendingRewards;
    }

    struct AaveTokenData {
        uint ltv;
        uint threshold;
        uint reserveFactor;
        bool usageAsCollEnabled;
        bool borrowEnabled;
        bool stableBorrowEnabled;
        bool isActive;
        bool isFrozen;
        uint totalSupply;
        uint availableLiquidity;
        uint totalStableDebt;
        uint totalVariableDebt;
        uint collateralEmission;
        uint debtEmission;
    }

     struct TokenPrice {
        uint priceInEth;
        uint priceInUsd;
    }

    function getTokensPrices(AaveAddressProvider aaveAddressProvider, address[] memory tokens) 
    internal view returns(TokenPrice[] memory tokenPrices, uint ethPrice) {
        uint[] memory _tokenPrices = AavePriceOracle(aaveAddressProvider.getPriceOracle()).getAssetsPrices(tokens);
        ethPrice = uint(ChainLinkInterface(getChainlinkEthFeed()).latestAnswer());
        tokenPrices = new TokenPrice[](_tokenPrices.length);
        for (uint i = 0; i < _tokenPrices.length; i++) {
            tokenPrices[i] = TokenPrice(
                _tokenPrices[i],
                wmul(_tokenPrices[i], uint(ethPrice) * 10 ** 10)
            );
        }
    }

    function collateralData(
        AaveProtocolDataProvider aaveData,
        address token
    ) internal view returns (AaveTokenData memory aaveTokenData) {
        (
            ,
            aaveTokenData.ltv,
            aaveTokenData.threshold,
            ,
            aaveTokenData.reserveFactor,
            aaveTokenData.usageAsCollEnabled,
            aaveTokenData.borrowEnabled,
            aaveTokenData.stableBorrowEnabled,
            aaveTokenData.isActive,
            aaveTokenData.isFrozen
        ) = aaveData.getReserveConfigurationData(token);

        (
            address aToken,
            ,
            address debtToken
        ) = aaveData.getReserveTokensAddresses(token);

        AaveIncentivesInterface.AssetData memory _data;
        AaveIncentivesInterface incentives = AaveIncentivesInterface(getAaveIncentivesAddress());

        _data = incentives.assets(aToken);
        aaveTokenData.collateralEmission = _data.emissionPerSecond;
        _data = incentives.assets(debtToken);
        aaveTokenData.debtEmission = _data.emissionPerSecond;
        aaveTokenData.totalSupply = TokenInterface(aToken).totalSupply();
    }

    function getTokenData(
        AaveProtocolDataProvider aaveData,
        address user,
        address token,
        uint tokenPriceInEth,
        uint tokenPriceInUsd
    ) internal view returns(AaveUserTokenData memory tokenData) {
        AaveTokenData memory aaveTokenData = collateralData(aaveData, token);

        (
            tokenData.supplyBalance,
            tokenData.stableBorrowBalance,
            tokenData.variableBorrowBalance,
            ,,
            tokenData.userStableBorrowRate,
            ,,
            tokenData.isCollateral
        ) = aaveData.getUserReserveData(token, user);

        (
            aaveTokenData.availableLiquidity,
            aaveTokenData.totalStableDebt,
            aaveTokenData.totalVariableDebt,
            tokenData.supplyRate,
            tokenData.variableBorrowRate,
            tokenData.stableBorrowRate,
            ,,,
        ) = aaveData.getReserveData(token);

        tokenData.tokenPriceInEth = tokenPriceInEth;
        tokenData.tokenPriceInUsd = tokenPriceInUsd;
        tokenData.aaveTokenData = aaveTokenData;
    }

    function getPendingRewards(address[] memory _tokens, address user) internal view returns (uint rewards) {
        uint arrLength = 2 * _tokens.length;
        address[] memory _atokens = new address[](arrLength);
        AaveProtocolDataProvider aaveData = AaveProtocolDataProvider(getAaveProtocolDataProvider());
        for (uint i = 0; i < _tokens.length; i++) {
            (_atokens[2*i],,_atokens[2*i + 1]) = aaveData.getReserveTokensAddresses(_tokens[i]);
        }
        rewards = AaveIncentivesInterface(getAaveIncentivesAddress()).getRewardsBalance(_atokens, user);
    }

    function getUserData(AaveLendingPool aave, address user, uint ethPriceInUsd, address[] memory tokens)
    internal view returns (AaveUserData memory userData) {
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = aave.getUserAccountData(user);

        uint256 pendingRewards = getPendingRewards(tokens, user);

        userData = AaveUserData(
            totalCollateralETH,
            totalDebtETH,
            availableBorrowsETH,
            currentLiquidationThreshold,
            ltv,
            healthFactor,
            ethPriceInUsd,
            pendingRewards
        );
    }
}

contract Resolver is AaveHelpers {
    function getPosition(address user, address[] memory tokens) public view returns(AaveUserTokenData[] memory, AaveUserData memory) {
        AaveAddressProvider addrProvider = AaveAddressProvider(getAaveAddressProvider());
        uint length = tokens.length;
        address[] memory _tokens = new address[](length);

        for (uint i = 0; i < length; i++) {
            _tokens[i] = tokens[i] == getEthAddr() ? getWethAddr() : tokens[i];
        }

        AaveUserTokenData[] memory tokensData = new AaveUserTokenData[](length);
        (TokenPrice[] memory tokenPrices, uint ethPrice) = getTokensPrices(addrProvider, _tokens);

        for (uint i = 0; i < length; i++) {
            tokensData[i] = getTokenData(
                AaveProtocolDataProvider(getAaveProtocolDataProvider()),
                user,
                _tokens[i],
                tokenPrices[i].priceInEth,
                tokenPrices[i].priceInUsd
            );
        }

        return (tokensData, getUserData(AaveLendingPool(addrProvider.getLendingPool()), user, ethPrice, _tokens));
    }
}

contract InstaAaveV2Resolver is Resolver {
    string public constant name = "AaveV2-Resolver-v1.6";
}