# Debug Session: actions-dmg-failure [OPEN]

## 症状

- GitHub Actions 执行 `bash scripts/package_dmg.sh` 失败
- 报错：`Error: Unknown option '--volumeName'`

## 期望

- `scripts/package_dmg.sh` 在本地和 GitHub Actions 的 macOS runner 上都能成功生成 `.dmg`

## 假设

- 假设 1：GitHub Actions runner 上的 `diskutil image create from` 不支持 `--volumeName`
- 假设 2：`diskutil` 在不同 macOS 版本上的 CLI 参数存在差异，本地可用但 CI 不兼容
- 假设 3：应改回更稳定的 `hdiutil create -srcfolder` 方案，而不是继续依赖 `diskutil image create from`
- 假设 4：报错只和参数名有关，去掉卷标参数或改用兼容写法即可通过

## 已有证据

- Actions 日志显示：
  - `Error: Unknown option '--volumeName'`
  - `Usage: diskutil image create from ... [--format <format>] <source> <destination>`

## 当前计划

- 读取当前打包脚本
- 根据现有错误输出判断根因
- 进行最小兼容性修复
- 本地复跑打包脚本验证

## 分析结果

- 假设 1：确认
  - Actions runner 返回的 usage 中不接受 `--volumeName`
- 假设 2：确认
  - 本地 `diskutil` 帮助包含 `--volumeName`，说明 CLI 在不同环境存在差异
- 假设 3：暂不采用
  - 不需要回退到 `hdiutil`，保留 `diskutil` 也可完成兼容修复
- 假设 4：确认
  - 去掉不兼容参数后，本地脚本可再次成功打包

## 修复

- 删除 `diskutil image create from` 的 `--volumeName` 参数
- 将 staging 目录改为 `build/dmg-work/PadSidecar`
- 让卷名通过源目录名 `PadSidecar` 自动推导，避免依赖不兼容参数

## 修复后验证

- 本地执行 `bash scripts/package_dmg.sh` 成功
- 成功产物：`dist/PadSidecar-1.0.0.dmg`
