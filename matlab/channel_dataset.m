function channel = channel_dataset()
%CHANNEL_DATASET 生成用于航道初始化的示例数据。
%
% 输出:
%   channel - 结构体, 包含航道边界、中心线和航点信息。
%
% 该函数提供一个中等复杂度的航道示例, 用于展示 NMPC 船舶自动航行
% 算法的使用方式。航道由不规则折线构成, 并通过插值函数生成平滑
% 的中心线。所有数据均使用米为单位。

% 航道中心线的原始离散点 (x, y)
channel.centerlinePoints = [
    0,     0;
    200,  30;
    400,  80;
    650, 120;
    900,  90;
    1100, 40;
    1300, -20;
    1500, -80;
    1700, -60;
    1900,  20
];

% 航道宽度(左右等宽), 在每个中心线节点处给定。
channel.halfWidth = [
    60;
    55;
    50;
    50;
    60;
    65;
    70;
    65;
    55;
    50
];

% 生成航道左/右边界 (简化: 沿法向偏移)
numPts = size(channel.centerlinePoints, 1);
leftBoundary = zeros(numPts, 2);
rightBoundary = zeros(numPts, 2);
for i = 1:numPts
    if i == numPts
        tangent = channel.centerlinePoints(i, :) - channel.centerlinePoints(i-1, :);
    else
        tangent = channel.centerlinePoints(i+1, :) - channel.centerlinePoints(i, :);
    end
    tangentNorm = norm(tangent);
    if tangentNorm < 1e-6
        tangentNorm = 1e-6;
    end
    tangent = tangent / tangentNorm;
    normal = [ -tangent(2), tangent(1) ];
    leftBoundary(i, :) = channel.centerlinePoints(i, :) + channel.halfWidth(i) * normal;
    rightBoundary(i, :) = channel.centerlinePoints(i, :) - channel.halfWidth(i) * normal;
end
channel.leftBoundary = leftBoundary;
channel.rightBoundary = rightBoundary;

% 预定义航线参考速度 (m/s)
channel.referenceSpeed = 4.0; % 约 7.8 节

% 关键航点 (用于可视化和调试)
channel.waypoints = channel.centerlinePoints;

end
