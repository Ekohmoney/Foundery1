
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


contract TwoNumTest {
     uint num1 = 42;
        uint num2 = 24;

    function beforeEach() public {
        twoNum = new TwoNum();
    }

    function testAssigns() public {
        uint256 num1 = 42;
        uint256 num2 = 24;

        twoNum.assigns(num1, num2);

        uint256 result1 = twoNum.number1();
        uint256 result2 = twoNum.number2();

        Assert.equal(result1, num1, "Number1 is incorrect");
        Assert.equal(result2, num2, "Number2 is incorrect");
    }
}
