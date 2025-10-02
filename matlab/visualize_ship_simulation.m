function visualize_ship_simulation(sim, varargin)
%VISUALIZE_SHIP_SIMULATION 可视化 NMPC 船舶自动航行仿真结果。
%
% 输入:
%   sim - simulate_ship_autopilot 返回的仿真结构体。
%   varargin - 名称-值对参数, 支持:
%       'Animate'  - 是否实时动画 (默认 true)
%       'Speed'    - 动画时间缩放 (默认 10)
%
% 函数会绘制航道、障碍物、实际轨迹、参考中心线及控制输入变化。

p = inputParser;
p.addParameter('Animate', true, @islogical);
p.addParameter('Speed', 10, @(x) isnumeric(x) && x > 0);
p.parse(varargin{:});
opt = p.Results;

channel = sim.channel;
centerline = sim.centerline;
obstacles = sim.obstacles;

axPlan = visualize_channel(channel, centerline, obstacles);
plot(axPlan, sim.states(:, 1), sim.states(:, 2), 'r-', 'LineWidth', 1.6, ...
    'DisplayName', '实际轨迹');
legend(axPlan, 'Location', 'bestoutside');

if opt.Animate
    % 使用简单逐帧方式展示船舶运动
    shipPatch = render_autonomous_ship(axPlan, sim.states(1, :).', 'Scale', 25);
    for k = 1:length(sim.time)
        if ~isvalid(shipPatch)
            break;
        end
        % 删除上一帧图元并重绘
        delete(shipPatch);
        shipPatch = render_autonomous_ship(axPlan, sim.states(k, :).', 'Scale', 25);
        drawnow limitrate; % 控制刷新速率
        pause(0.01 / opt.Speed); % 控制动画速度
    end
end

% 控制输入图
figure('Name', '控制输入', 'Color', 'w');
subplot(2,1,1);
plot(sim.time, sim.inputs(:, 1) / 1000, 'LineWidth', 1.2);
ylabel('推力 [kN]'); grid on;
subplot(2,1,2);
plot(sim.time, rad2deg(sim.inputs(:, 2)), 'LineWidth', 1.2);
ylabel('舵角 [deg]'); xlabel('时间 [s]'); grid on;

end
