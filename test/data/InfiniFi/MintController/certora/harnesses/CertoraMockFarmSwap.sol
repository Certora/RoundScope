import "./ERC20Like/DummyERC20A.sol";
import "../../test/mock/MockERC20.sol";

contract CertoraMockFarmSwap {
    address public wrapToken;
    address public assetToken;
    uint256 public wrapAmount;
    uint256 public assetAmount;

    constructor(address _wrapToken, address _assetToken, uint256 _wrapAmount, uint256 _assetAmount) {
        wrapToken = _wrapToken;
        assetToken = _assetToken;
        wrapAmount = _wrapAmount;
        assetAmount = _assetAmount;
    }

    function routeAssetToWrapSwap() external {
        DummyERC20A(assetToken).transferFrom(msg.sender, address(this), assetAmount);
        MockERC20(wrapToken).mint(msg.sender, wrapAmount);
    }

    function routeWrapToAssetSwap() external {
        MockERC20(wrapToken).burn(wrapAmount);
        DummyERC20A(assetToken).transferFrom(address(this), msg.sender, assetAmount);
    }

    function swapFail() external pure {
        revert();
    }
}