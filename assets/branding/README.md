# branding 资源说明

`assets/branding` 存放应用内需要随包发布的品牌矢量资源。当前只包含 Bangumi
官方 iOS 仓库提供的 favicon 全尺寸 SVG，用于底部导航和 Bangumi 标题栏图标。

## 当前包含文件

- `bangumi_favicon_full_size.svg`：来自 `bangumi/Bangumi-iOS` 仓库
  `App/AppIcon.icon/Assets/bangumiFaviconFullSize.svg` 的官方矢量图标。它保留
  bgm.tv 电视气泡、天线和表情的完整填充轮廓，避免 PNG 灰底和手绘轮廓偏差。

## 设计边界

1. 本目录只放品牌识别资源，不放运行时下载的封面、头像或缓存文件。
2. 新增品牌资源时，需要优先使用官方 SVG 或明确许可来源，并在本 README 记录来源。
3. Flutter 代码应通过专门组件封装品牌资源，例如 `BangumiLogoIcon`，避免业务页面
   直接散落 asset 路径。
