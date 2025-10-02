function dx = ship_dynamics(x, u, params)
%SHIP_DYNAMICS 计算船舶五自由度状态的一阶微分。
%
% 输入:
%   x      - 当前状态向量 [x; y; psi; u; r]。
%   u      - 控制输入 [thrust; rudder]。
%   params - ship_parameters 返回的结构体。
%
% 输出:
%   dx - 状态导数向量, 用于数值积分。
%
% 模型为二维平面上的简化 3 自由度模型, 假设侧向速度较小并隐含在
% 艏向角速度 r 中。纵向速度 u 与艏向角 psi 一起决定质心速度。该模型
% 适合演示 NMPC 算法, 但在实际部署时需替换为更高保真度的动力学。

% 状态解包
px = x(1);
py = x(2);
psi = x(3);
surge = x(4);
r = x(5);

% 控制输入
thrust = u(1);
rudder = u(2);

% 动力学方程
px_dot = surge * cos(psi);
py_dot = surge * sin(psi);
psi_dot = r;
surge_dot = (params.Kthrust * thrust + params.Xu * surge) / params.m;
r_dot = (params.Kdelta * rudder + params.Nr * r) / params.Iz;

% 输出导数
dx = [px_dot; py_dot; psi_dot; surge_dot; r_dot];

end
