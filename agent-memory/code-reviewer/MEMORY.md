# 底盘控制代码审查记忆

## 模块地图
- ChassisTask: 主控制循环(1kHz), 调用Parse->Process->Distribute
- Chassis_APIFunction: 算法编排(LQR/VMC/五连杆/卡尔曼滤波)
- Chassis_Stratgy: 模式状态机(9种模式)
- Algorithm: 核心算法实现(PID/TD/LQR/VMC/KF)

## 反复出现的问题
- [2026-02] 函数行数超标: Chassis_Stratgy.c中3个函数超50行限制
- [2026-02] 全局变量直接访问: LQR_K_MatrixUpdate违反函数参数化原则
- [2026-02] 除零保护缺失: VMC_Cal中sin(phi3-phi2)可能为0
- [2026-02] 位移积分无上限检查: DisFB累积可能溢出

## 项目惯例
- 数据流: Parse(解析) -> Process(处理) -> Distribute(分发)
- 命名: G/S前缀 + ST/st/EM/F类型 + CH/GB组件
- 状态机: Layer1全局中断 -> Layer2状态流转 -> Layer3模式执行

## 调试经验
- VMC计算需添加sin(phi3-phi2)除零检查(参考Algorithm.c:527-531)
- 跳跃模式状态机JumpPhase需设为全局变量供VOFA观察
- 离地时卡尔曼滤波R矩阵需动态调整(Algorithm.c:498)
