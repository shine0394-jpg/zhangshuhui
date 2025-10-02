%RUN_NMPC_AUTOPILOT_DEMO NMPC 船舶自动驾驶与避碰示例脚本。
%
% 本脚本演示如何调用 simulate_ship_autopilot 运行带有自动避碰功能的
% NMPC 船舶自动驾驶仿真, 并使用 visualize_ship_simulation 进行结果
% 可视化。所有函数均为 MATLAB 2021 版本兼容实现。

% 清空环境
clear; clc;

% 运行仿真 (20 分钟)
sim = simulate_ship_autopilot(1200);

% 可视化
visualize_ship_simulation(sim, 'Animate', true, 'Speed', 5);
