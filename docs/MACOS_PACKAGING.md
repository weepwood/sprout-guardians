# macOS 打包及图标
## 安装包
- Godot Universal 导出 ZIP → 原生 Mac 恢复 APP → 同步版本及原生 ICNS → 签名 → ZIP/DMG → 回读验证。
- DMG 使用 HFS+ 和 Applications 符号链接；挂载后拖拽应用至 Applications，再弹出镜像。ZIP 为备选。
- 验证 ZIP CRC、两架构、Info.plist、签名、DMG 校验、实际挂载、Applications 链接、从最终镜像复制的应用原生无头启动。不使用全局关闭 Gatekeeper 的命令。
- GitHub 可信 main 构建可使用 Developer ID Application + hardened runtime + Apple notarization/stapling。PR 仅临时签名，无 secrets。未配置时生成 ad-hoc-unnotarized 状态；这不是公证，也不保证 Finder 首次启动。
- 正式 V0.6 发布默认要求 developer-id-notarized；确认为个人测试的临时签名发布必须手动设置 allow_unnotarized，发布附 macos-signing-status.txt 及 SHA256SUMS.txt。不可将临时签名描述为已公证。
- 如果下载的临时签名应用被阻止，仅在已验证来源和校验值后，使用 macOS 系统设置 → 隐私与安全性中针对该应用的打开选项（若系统提供）。不建议关闭 Gatekeeper 或批量移除隔离属性。
## GitHub Actions 密钥
在仓库 Settings → Secrets and variables → Actions 设置：
- MACOS_CERTIFICATE_BASE64：Developer ID Application 证书及私钥的 PKCS#12 base64。
- MACOS_CERTIFICATE_PASSWORD：PKCS#12 密码。
- MACOS_SIGN_IDENTITY：完整 Developer ID Application 签名身份。
- APPLE_ID、APPLE_TEAM_ID、APPLE_APP_PASSWORD：Apple 公证账户、团队 ID、专用密码。
密钥勿写入仓库、聊天、日志。部分配置将明确失败；全部为空时仅临时签名。可信主分支 CI 使用临时 Keychain，任务结束删除。正式签名/公证路径尚待真实证书验收。
## 图标
复用已批准的高清芽芽原画 assets/generated/hd/actors/actor_0.png（512×512 RGBA），不改变游戏资源。tools/build_app_icons.py --mac 生成 PNG、ICO（16–256 多尺寸）和原生 ICNS（16–1024 Retina 尺寸；高于源分辨率为插值派生）。Godot 和原生导出统一使用该图；旧 icon.svg 保留但不再引用。原画、开发测试和文档不应打入运行包；实际包大小待新构建测量。
## 实际验证
Mac arm64 macOS 27.2.1 上重新下载公开 v0.4.0 DMG/ZIP。旧 DMG CRC/挂载、ZIP、两架构、codesign 全部通过；仅临时签名、无 TeamIdentifier，spctl 拒绝，无 Applications 链接。使用新版脚本对同一旧版 ZIP 在 /tmp 独立重打包：ZIP CRC 与重新解包签名、HFS+ DMG 校验与挂载、Applications 链接、复制后的 ICNS/版本/签名一致、实际复制后的程序无头运行退出0，旧 Godot 退出报告2个 ObjectDB 实例残留，未伪称完全无警告。未安装到系统 Applications，未改变 Gatekeeper。V0.6 尚待新 CI。
