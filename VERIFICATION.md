# 验证记录

日期：2026-10-13。官方 latest API 返回 v26.3.27；release 发布于 2026-03-27。
测试二进制：Xray 26.3.27，commit d2758a0，Linux amd64，Go 1.26.1。
官方下载包 SHA256：23cd9af937744d97776ee35ecad4972cf4b2109d1e0fe6be9930467608f7c8ae。

## 已通过

- 所有 .sh：Bash 语法检查。
- 三份完整模板及默认配置：官方二进制 `xray run -test -config`。
- configure.sh：RAW、WS、gRPC 的生成文件均通过核心解析和部署参数校验。
- configure.sh：Vision 与 WS 的不支持组合在写入前拒绝。
- systemd 单元：systemd-analyze verify（Exec 路径替换为测试目录，指令保持不变）。
- proxy.sh/unproxy.sh：大小写变量恢复；原值含特殊字符；空值；未设置；声明但未赋值；原导出属性；重复开关；调用者 shell 选项和 traps 不变。
- 本地端口未启动：启用失败，不修改原环境。
- readonly 变量：启用拒绝，不修改原值。
- run-codex.sh：带空格的参数完整透传；proxy.sh/unproxy.sh 直接执行时拒绝。
- 本地真实链路：curl HTTPS CONNECT -> Xray HTTP inbound -> VLESS + RAW + TLS -> Xray server -> HTTPS target；外层/目标 TLS 均验证测试 CA。
- 错误 UUID：链路失败，目标没有收到请求。
- 出口停止：链路失败，目标没有收到直连请求。
- 安装器（安装路径重定向至临时目录、下载使用已校验的官方文件 fixture）：解析真实 release metadata、验证 SHA256、安装真实二进制成功。
- 安装器：被篡改的 ZIP 拒绝安装。

## 验证范围

没有真实 B 地址和认证参数，因此没有连接实际公网出口，没有验证真实 Codex 登录/模型流式请求。
WS/gRPC 已验证配置解析和生成，没有做其端到端传输测试。
当前测试环境没有运行 systemd，未实际创建系统账号或注册/启动服务；service 指令经过静态验证。
并未为“未知未来版本”承诺永久兼容。安装/更新时再次用实际新核心校验配置。
