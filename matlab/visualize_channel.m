function ax = visualize_channel(channel, centerline, obstacles, ax)
%VISUALIZE_CHANNEL 初始化并绘制航道、中心线与障碍物。
%
% 输入:
%   channel    - 航道数据结构体。
%   centerline - 结构体, 包含插值中心线字段 points/halfWidth。
%   obstacles  - 障碍物结构体数组。
%   ax         - (可选) 已有坐标轴句柄。
%
% 输出:
%   ax - 用于后续绘图的坐标轴句柄。
%
% 函数主要用于仿真可视化, 先绘制航道左右边界、多边形背景, 再绘制
% 中心线与障碍物。

if nargin < 4 || isempty(ax)
    figure('Name', 'NMPC 船舶自动航行航道', 'Color', 'w');
    ax = axes('Parent', gcf);
end

hold(ax, 'on'); grid(ax, 'on'); axis(ax, 'equal');
xlabel(ax, 'X [m]'); ylabel(ax, 'Y [m]');
title(ax, '航道与障碍物示意');

% 航道边界
plot(ax, channel.leftBoundary(:, 1), channel.leftBoundary(:, 2), 'k--', ...
    'LineWidth', 1.2, 'DisplayName', '左边界');
plot(ax, channel.rightBoundary(:, 1), channel.rightBoundary(:, 2), 'k--', ...
    'LineWidth', 1.2, 'DisplayName', '右边界');

% 填充航道区域
patch(ax, [channel.leftBoundary(:, 1); flipud(channel.rightBoundary(:, 1))], ...
          [channel.leftBoundary(:, 2); flipud(channel.rightBoundary(:, 2))], ...
          [0.9 0.95 1.0], 'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
          'DisplayName', '航道区域');

% 中心线
plot(ax, centerline.points(:, 1), centerline.points(:, 2), 'b-', 'LineWidth', 1.5, ...
    'DisplayName', '插值中心线');
plot(ax, channel.centerlinePoints(:, 1), channel.centerlinePoints(:, 2), 'bo', ...
    'MarkerFaceColor', 'w', 'DisplayName', '原始航点');

% 障碍物
for i = 1:numel(obstacles)
    obs = obstacles(i);
    th = linspace(0, 2*pi, 80);
    circleX = obs.position(1) + obs.radius * cos(th);
    circleY = obs.position(2) + obs.radius * sin(th);
    fill(ax, circleX, circleY, [1 0.7 0.7], 'FaceAlpha', 0.5, ...
        'EdgeColor', [0.8 0.2 0.2], 'DisplayName', sprintf('障碍物 %d', i));
    text(obs.position(1), obs.position(2), sprintf('R=%.0f m', obs.radius), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 10, 'Color', [0.6 0 0], 'Parent', ax);
end

legend(ax, 'Location', 'best');

end
