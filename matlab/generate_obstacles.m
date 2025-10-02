function obstacles = generate_obstacles(channel)
%GENERATE_OBSTACLES 根据航道信息生成静态圆形障碍物。
%
% 输入:
%   channel - channel_dataset 返回的结构体。
%
% 输出:
%   obstacles - 结构体数组, 每个元素包含:
%       .position  - 障碍物中心 [x, y]
%       .radius    - 障碍物半径 (m)
%       .safety    - NMPC 使用的安全系数 (m)
%
% 此示例函数构造三个固定障碍物, 可以根据实际场景扩展为动态或随机
% 障碍物。生成的安全系数可用于调节避碰缓冲距离。

points = channel.centerlinePoints;
obstacles(1).position = points(4, :) + [50, -30];
obstacles(1).radius = 25;
obstacles(1).safety = 35;

obstacles(2).position = points(6, :) + [-40, 40];
obstacles(2).radius = 30;
obstacles(2).safety = 40;

obstacles(3).position = points(8, :) + [30, 20];
obstacles(3).radius = 20;
obstacles(3).safety = 30;

end
