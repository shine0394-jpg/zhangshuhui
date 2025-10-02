function [s, centerlineInterp] = interpolate_centerline(channel, ds)
%INTERPOLATE_CENTERLINE 对航道中心线进行样条插值。
%
% 输入:
%   channel - channel_dataset 返回的结构体, 需要包含 centerlinePoints 字段。
%   ds      - (可选) 插值步长, 单位米。默认 5 m。
%
% 输出:
%   s                 - 累计航程坐标, 与插值后的中心线坐标对应。
%   centerlineInterp  - N×2 矩阵, 插值后的 (x, y) 坐标。
%
% 函数使用三次样条对航道中心线进行平滑化处理, 并生成等距采样点,
% 便于 NMPC 控制器进行轨迹跟踪。

if nargin < 2
    ds = 5;
end

points = channel.centerlinePoints;
dist = [0; cumsum(sqrt(sum(diff(points).^2, 2)))];
sampleS = 0:ds:dist(end);

% 三次样条插值
xSpline = spline(dist, points(:, 1));
ySpline = spline(dist, points(:, 2));
centerlineInterp = [ppval(xSpline, sampleS).', ppval(ySpline, sampleS).'];
s = sampleS.';

end
