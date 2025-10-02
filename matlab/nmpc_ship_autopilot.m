function [uOpt, prediction, info] = nmpc_ship_autopilot(x0, ref, params, obstacles, uPrev)
%NMPC_SHIP_AUTOPILOT NMPC 船舶自动驾驶求解器 (带避碰约束)。
%
% 输入:
%   x0         - 当前状态向量 [x; y; psi; u; r]。
%   ref        - 结构体, 包含预测步长 N 的参考轨迹:
%                .position (N×2) 参考位置
%                .heading  (N×1) 参考艏向 (rad)
%                .speed    (N×1) 参考纵向速度 (m/s)
%                .halfWidth(N×1) 航道半宽 (m)
%   params     - ship_parameters 返回的结构体。
%   obstacles  - 障碍物结构体数组。
%   uPrev      - 上一时刻控制输入 [thrust; rudder]。
%
% 输出:
%   uOpt       - 本周期最优控制输入。
%   prediction - 结构体, 包含预测状态轨迹和控制序列。
%   info       - 求解器诊断信息 (fmincon 输出)。
%
% 算法采用直接单射 (direct shooting) 方式, 将控制序列作为优化变量。
% 目标函数由轨迹跟踪误差、控制增量以及对障碍物/航道的软约束组成。
% 通过罚函数和障碍距离约束实现自动避碰。

N = params.horizon;
Ts = params.Ts;
stateDim = numel(x0);
inputDim = 2;

if nargin < 5 || isempty(uPrev)
    uPrev = [params.minThrust; 0];
end

% 初始化优化变量 (维度: N×inputDim)
z0 = repmat(uPrev, N, 1);

lb = repmat([params.minThrust; -params.maxRudder], N, 1);
ub = repmat([params.maxThrust; params.maxRudder], N, 1);

costFun = @(z) nmpc_cost(z, x0, ref, params, obstacles, uPrev, Ts);

options = optimoptions('fmincon', ...
    'Algorithm', 'sqp', ...
    'Display', 'none', ...
    'MaxIterations', 60, ...
    'SpecifyObjectiveGradient', false);

[zOpt, fval, exitflag, output] = fmincon(costFun, z0, [], [], [], [], lb, ub, [], options);

% 提取预测
uMatrix = reshape(zOpt, inputDim, N).';
statePred = zeros(N, stateDim);
x = x0;
for k = 1:N
    u = uMatrix(k, :).';
    x = rk4_step(@ship_dynamics, x, u, params, Ts);
    statePred(k, :) = x.';
end

uOpt = uMatrix(1, :).';

prediction.states = statePred;
prediction.inputs = uMatrix;

info.exitflag = exitflag;
info.fval = fval;
info.output = output;

end

function J = nmpc_cost(z, x0, ref, params, obstacles, uPrev, Ts)
% 内部目标函数: 计算给定控制序列的总成本。

N = params.horizon;
inputDim = 2;

uMatrix = reshape(z, inputDim, N).';
x = x0;
J = 0;
previousInput = uPrev;

for k = 1:N
    u = uMatrix(k, :).';
    x = rk4_step(@ship_dynamics, x, u, params, Ts);

    posError = x(1:2) - ref.position(k, :).';
    headingError = wrapToPiLocal(x(3) - ref.heading(k));
    speedError = x(4) - ref.speed(k);
    yawRateError = x(5); % 目标 yaw rate 为 0

    e = [posError; headingError; speedError; yawRateError];
    J = J + e.' * params.Q * e;

    du = u - previousInput;
    J = J + du.' * params.R * du;
    previousInput = u;

    % 航道软约束: 偏离中心线的距离
    distToCenter = norm(x(1:2) - ref.position(k, :).');
    exceed = max(0, distToCenter - ref.halfWidth(k));
    J = J + params.channelPenalty * exceed^2;

    % 障碍物软约束
    for iObs = 1:numel(obstacles)
        obs = obstacles(iObs);
        d = norm(x(1:2) - obs.position.');
        safetyRadius = obs.radius + obs.safety;
        avoid = max(0, safetyRadius - d);
        J = J + params.gammaObs * avoid^2;
    end
end

end

function xNext = rk4_step(dynamicsFun, x, u, params, Ts)
%RK4_STEP 四阶 Runge-Kutta 积分器。

k1 = dynamicsFun(x, u, params);
k2 = dynamicsFun(x + 0.5 * Ts * k1, u, params);
k3 = dynamicsFun(x + 0.5 * Ts * k2, u, params);
k4 = dynamicsFun(x + Ts * k3, u, params);

xNext = x + Ts / 6 * (k1 + 2*k2 + 2*k3 + k4);
end

function angle = wrapToPiLocal(angle)
%WRAPTOPILOCAL 将角度限制在 [-pi, pi]。
angle = mod(angle + pi, 2*pi) - pi;
end
