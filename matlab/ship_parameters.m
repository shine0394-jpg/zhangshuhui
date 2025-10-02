function params = ship_parameters()
%SHIP_PARAMETERS 返回自动驾驶船舶的物理与控制参数。
%
% 输出:
%   params - 结构体, 包含船舶动力学、控制器与约束参数。
%
% 参数来源于常见的 3 自由度 (纵向-横向-艏向) 中小型工作船模型。
% 数值仅供示例使用, 可根据具体应用进行调整。

% 船舶惯性与阻尼参数
params.m = 5.0e5;        % 质量 (kg)
params.Iz = 8.0e7;       % 艏向转动惯量 (kg*m^2)
params.Xu = -5.0e4;      % 纵向阻尼 (N*s/m)
params.Nr = -6.0e7;      % 艏向阻尼 (N*s*s)

% 舵力矩和推力系数 (简化)
params.Kdelta = 6.0e6;   % 舵角到力矩系数 (N*m/rad)
params.Kthrust = 1.0;    % 推力增益 (N)

% 控制输入限制
params.maxRudder = deg2rad(30);   % 舵角限制 (rad)
params.maxThrust = 1.2e5;         % 推力限制 (N)
params.minThrust = 1.0e4;         % 最小有效推力 (N)

% NMPC 配置
params.Ts = 2.0;          % 采样周期 (s)
params.horizon = 15;      % 控制预测步长
params.Q = diag([40, 40, 30, 5, 10]); % 状态误差权重 (x,y,psi,u,r)
params.R = diag([1e-4, 20]);        % 控制增量权重 (delta thrust, delta rudder)
params.gammaObs = 1e5;    % 障碍物惩罚权重
params.safeDistance = 80; % 安全距离 (m)
params.channelPenalty = 2e4; % 航道边界惩罚系数

% 期望速度/艏向
params.desiredSpeed = 4.0; % m/s

end
