function sim = simulate_ship_autopilot(simDuration)
%SIMULATE_SHIP_AUTOPILOT 运行 NMPC 船舶自动驾驶仿真。
%
% 输入:
%   simDuration - 仿真时长 (s), 默认 1800 s。
%
% 输出:
%   sim - 结构体, 包含以下字段:
%       .time         - 时间序列
%       .states       - 船舶状态轨迹 (T×5)
%       .inputs       - 控制输入轨迹 (T×2)
%       .references   - 每个采样时刻的参考信息结构数组
%       .obstacles    - 障碍物集合
%       .channel      - 航道数据
%
% 仿真采用固定步长, 每个采样时刻调用 NMPC 控制器求解最优舵角与推力,
% 并通过 Runge-Kutta 数值积分推进船舶动力学。函数返回的 sim 结构体可
% 直接用于可视化。

if nargin < 1
    simDuration = 1800; % 30 分钟
end

params = ship_parameters();
channel = channel_dataset();
[sCoord, centerlineInterp] = interpolate_centerline(channel, 5);
obstacles = generate_obstacles(channel);

% 插值得到半宽
halfWidthInterp = interp1( ...
    linspace(0, sCoord(end), numel(channel.halfWidth)), ...
    channel.halfWidth, ...
    sCoord, 'linear', 'extrap');

Ts = params.Ts;
steps = floor(simDuration / Ts);

% 初始状态: 位于起点附近, 略有偏差
x = [centerlineInterp(1, 1) - 10; ...
     centerlineInterp(1, 2) - 5; ...
     atan2(centerlineInterp(2, 2) - centerlineInterp(1, 2), ...
           centerlineInterp(2, 1) - centerlineInterp(1, 1)); ...
     params.desiredSpeed * 0.8; ...
     0];

states = zeros(steps, numel(x));
inputs = zeros(steps, 2);
refs(steps) = struct('position', [], 'heading', [], 'speed', [], 'halfWidth', []); %#ok<AGROW>

uPrev = [params.minThrust; 0];

for k = 1:steps
    % 当前时间
    time = (k-1) * Ts;

    % 找到最近的中心线索引
    % 在插值后的中心线上寻找与当前船位最近的点
    diffs = centerlineInterp - x(1:2).';
    [~, idx] = min(sum(diffs.^2, 2));

    % 构建预测参考
    horizonIdx = idx + (0:params.horizon-1);
    horizonIdx(horizonIdx > size(centerlineInterp, 1)) = size(centerlineInterp, 1);

    % 预测时域内的参考位置
    posRef = centerlineInterp(horizonIdx, :);
    % 根据中心线切向方向生成参考艏向
    headingRef = zeros(numel(horizonIdx), 1);
    for ii = 1:numel(horizonIdx)
        if horizonIdx(ii) < size(centerlineInterp, 1)
            dxy = centerlineInterp(min(horizonIdx(ii)+1, end), :) - centerlineInterp(max(horizonIdx(ii)-1, 1), :);
        else
            dxy = centerlineInterp(end, :) - centerlineInterp(end-1, :);
        end
        headingRef(ii) = atan2(dxy(2), dxy(1));
    end

    % 纵向速度与可用航道宽度参考
    speedRef = params.desiredSpeed * ones(numel(horizonIdx), 1);
    halfWidthRef = halfWidthInterp(horizonIdx);

    ref.position = posRef;
    ref.heading = headingRef;
    ref.speed = speedRef;
    ref.halfWidth = halfWidthRef;

    % 调用 NMPC 控制器
    % 求解 NMPC 最优控制输入
    [uOpt, ~, info] = nmpc_ship_autopilot(x, ref, params, obstacles, uPrev);
    if info.exitflag <= 0
        warning('NMPC solver did not converge at step %d (time=%.1f s).', k, time);
    end

    % 将控制输入应用于真实系统
    % 使用高阶积分器推进动力学
    x = rk4_step(@ship_dynamics, x, uOpt, params, Ts);

    % 记录状态与控制历史
    states(k, :) = x.';
    inputs(k, :) = uOpt.';
    % 保存本时刻参考信息, 便于后续分析
    refs(k) = ref;
    uPrev = uOpt;

    % 到达终点附近则提前终止
    % 判断是否抵达终点附近
    if idx >= size(centerlineInterp, 1) - 3
        states = states(1:k, :);
        inputs = inputs(1:k, :);
        refs = refs(1:k);
        steps = k;
        break;
    end
end

% 整理输出结果
sim.time = (0:steps-1).' * Ts;
sim.states = states;
sim.inputs = inputs;
sim.references = refs;
sim.obstacles = obstacles;
sim.channel = channel;
sim.centerline.s = sCoord;
sim.centerline.points = centerlineInterp;
sim.centerline.halfWidth = halfWidthInterp;

end

function xNext = rk4_step(dynamicsFun, x, u, params, Ts)
% 内部积分器, 为避免与控制器重复定义, 在此再次实现。

k1 = dynamicsFun(x, u, params);
k2 = dynamicsFun(x + 0.5 * Ts * k1, u, params);
k3 = dynamicsFun(x + 0.5 * Ts * k2, u, params);
k4 = dynamicsFun(x + Ts * k3, u, params);

xNext = x + Ts / 6 * (k1 + 2*k2 + 2*k3 + k4);
end
