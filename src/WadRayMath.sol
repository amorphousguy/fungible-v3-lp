// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

library WadRayMath {
    using SafeMath for uint256;

    uint256 internal constant WAD = 1e18;
    uint256 internal constant halfWAD = 0.5e18;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant halfRAY = 0.5e27;

    uint256 internal constant WAD_RAY_RATIO = 1e9;

    function ray() internal pure returns (uint256) {
        return RAY;
    }

    function wad() internal pure returns (uint256) {
        return WAD;
    }

    function halfRay() internal pure returns (uint256) {
        return halfRAY;
    }

    function halfWad() internal pure returns (uint256) {
        return halfWAD;
    }

    /**
     * @dev Multiplies times b (wad), rounding half up to the nearest wad
     * @param a Any precision
     * @param b Wad
     * @return c = a*b, in same precision as a
     **/
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        // to avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
        return halfWAD.add(a.mul(b)).div(WAD);
    }

    /**
     * @dev Divides by b (wad), rounding half up to the nearest wad
     * @param a Any precision
     * @param b Wad
     * @return c = a/b, in same precision as a
     **/
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // to avoid overflow, a <= (type(uint256).max - halfB) / WAD
        uint256 halfB = b / 2;
        return halfB.add(a.mul(WAD)).div(b);
    }

    /**
     * @dev Multiplies times b (ray), rounding half up to the nearest ray
     * @param a Any precision
     * @param b Ray
     * @return c = a*b, in same precision as a
     **/
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
        // to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
        return halfRAY.add(a.mul(b)).div(RAY);
    }

    /**
     * @dev Divides by b (ray), rounding half up to the nearest ray
     * @param a Any precision
     * @param b Ray
     * @return c = a/b, in same precision as a
     **/
    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // to avoid overflow, a <= (type(uint256).max - halfB) / RAY
        uint256 halfB = b / 2;
        return halfB.add(a.mul(RAY)).div(b);
    }

    /**
     * @dev Multiplies times b (ray), flooring to the nearest ray
     * @param a Any precision
     * @param b Ray
     * @return c = a*b, in same precision as a
     **/
    function rayMulFloor(uint256 a, uint256 b) internal pure returns (uint256) {
        // to avoid overflow, a <= (type(uint256).max) / b)
        return (a.mul(b)).div(RAY);
    }

    /**
     * @dev Divides by b (ray), flooring to the nearest ray
     * @param a Any precision
     * @param b Ray
     * @return c = a/b, in same precision as a
     **/
    function rayDivFloor(uint256 a, uint256 b) internal pure returns (uint256) {
        // to avoid overflow, a <= (type(uint256).max) / RAY
        return (a.mul(RAY)).div(b);
    }

    /**
     * @dev Casts ray down to wad
     * @param a Ray
     * @return b = a converted to wad, rounded half up to the nearest wad
     **/
    function rayToWad(uint256 a) internal pure returns (uint256) {
        uint256 halfRatio = WAD_RAY_RATIO / 2;

        return halfRatio.add(a).div(WAD_RAY_RATIO);
    }

    /**
     * @dev Converts wad up to ray
     * @param a Wad
     * @return b = a converted in ray
     **/
    function wadToRay(uint256 a) internal pure returns (uint256) {
        return a.mul(WAD_RAY_RATIO);
    }

    /**
     * @dev Calculates x to the power of n (x^n)
     * @dev Power calculated through a loop of binary powers.  Not optimized.
     * @param x ray
     * @param n unsigned integer
     * @return z x^n
     **/
    function rayPow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rayMul(x, x);

            if (n % 2 != 0) {
                z = rayMul(z, x);
            }
        }
    }
}
