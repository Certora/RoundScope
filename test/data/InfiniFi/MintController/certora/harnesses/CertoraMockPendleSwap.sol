import "./ERC20Like/DummyERC20A.sol";
import "../../test/mock/MockERC20.sol";

contract CertoraMockPendleSwap {
    address public ptToken;
    address public assetToken;
    uint256 public ptAmount;
    uint256 public assetAmount;

    constructor(address _ptToken, address _assetToken, uint256 _ptAmount, uint256 _assetAmount) {
        ptToken = _ptToken;
        assetToken = _assetToken;
        ptAmount = _ptAmount;
        assetAmount = _assetAmount;
    }

    function routeAssetToPtSwap() external {
        DummyERC20A(assetToken).transferFrom(msg.sender, address(this), assetAmount);
        MockERC20(ptToken).mint(msg.sender, ptAmount);
    }

    function routePtToAssetSwap() external {
        MockERC20(ptToken).burn(ptAmount);
        DummyERC20A(assetToken).transferFrom(address(this), msg.sender, assetAmount);
    }

    function swapFail() external pure {
        revert();
    }
}