# Debug Session: actions-dmg-failure [RESOLVED]

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

## 追加分析

- 去掉 `--volumeName` 后，用户在 Actions 上又遇到新的 `No such file or directory`
- 该错误信息不足以精确定位到 `ditto`、`ln` 或 `diskutil` 的哪一步
- 但连续两次失败都发生在 `diskutil` 方案切换后，说明继续依赖该新链路的收益不高

## 最终修复

- 回退到更成熟的 `hdiutil create -srcfolder` 方案
- 保留 `WORK_DIR` 与 `STAGING_DIR` 组织方式，不影响 DMG 内容结构

## 最终验证

- 本地执行：
  - `VERSION=0.0.0-dev.2 BUILD_NUMBER=2 bash scripts/package_dmg.sh`
- 结果：
  - 成功生成 `dist/PadSidecar-0.0.0-dev.2.dmg`
