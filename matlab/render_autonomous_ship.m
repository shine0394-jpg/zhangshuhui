function h = render_autonomous_ship(ax, state, varargin)
%RENDER_AUTONOMOUS_SHIP 在给定坐标轴上绘制船舶示意图。
%
% 输入:
%   ax     - 坐标轴句柄。
%   state  - 船舶状态 [x; y; psi; u; r]。
%   varargin - 名称-值对参数, 支持:
%       'Color'     - 船体颜色 (默认 [0 0.4 0.8])
%       'Scale'     - 船体缩放比例 (默认 20 m)
%       'Tag'       - 图元标签
%
% 输出:
%   h - patch 图元句柄。

p = inputParser;
p.addParameter('Color', [0 0.4 0.8]);
p.addParameter('Scale', 20);
p.addParameter('Tag', 'autonomous-ship');
p.parse(varargin{:});
opt = p.Results;

x = state(1);
y = state(2);
psi = state(3);
L = opt.Scale;

% 船体轮廓 (等腰三角形)
shipBody = L * [
    1,   0;
   -0.6, 0.35;
   -0.4, 0;
   -0.6, -0.35
];

% 构造平面旋转矩阵并完成坐标变换
R = [cos(psi), -sin(psi); sin(psi), cos(psi)];
rotated = (R * shipBody.').';
translated = rotated + [x, y];

h = patch('Parent', ax, 'XData', translated(:, 1), 'YData', translated(:, 2), ...
    'FaceColor', opt.Color, 'FaceAlpha', 0.8, 'EdgeColor', 'k', 'LineWidth', 1.2, ...
    'Tag', opt.Tag);

end
