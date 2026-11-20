# 安装器错误5：Low完整性标签根因与交付修复

## 结论

旧本地安装器继承了工作目录的Low强制完整性标签。Windows进程完整性取用户与可执行文件级别的较低者，Low进程默认不能写普通Medium目录；普通DACL显示Modify也不能绕过这条限制。此前只补写入预检、在Low工作目录安装成功，并未解决根因，不能用该结果宣称可对外正常安装。

只读`icacls`确认F:\诡异事务局根目录有显式Low(OI)(CI)(NW)，交付目录和原/修正版安装器继承Low。玩家选择的F:\guiyi\游戏安装\AnomalyBureau没有Low标签，按Windows规则是Medium。未确定根目录最初何时或由谁设置，不归咎安全软件或玩家操作。

微软依据：[Mandatory Integrity Control](https://learn.microsoft.com/en-us/windows/win32/secauthz/mandatory-integrity-control)、[SECURITY_INFORMATION中LABEL查询权限](https://learn.microsoft.com/en-us/windows/win32/secauthz/security-information)。

## 可复核的因果对照

证据均在F:\诡异事务局\验收\20261031_安装根因。

- native32.txt/native64.txt：32/64位普通独立探针（未启用RedirectionGuard）在原目标下mkdir和仅写、读写、写加删除三个CreateFile请求均error5，在Low工作目录正常；排除仅Inno或仅位数导致。
- token-native64.txt：探针令牌Mandatory SID S-1-16-4096，即Low。普通PowerShell和Explorer为S-1-16-8192，即Medium。IsTokenRestricted=False、AppContainer=False不能替代完整性查询。
- `installer/IntegrityProbe.cs`原生读取SACL mandatory ACE 0x11及令牌25：旧安装器4096，目标目录8192。此前.NET RawSecurityDescriptor.GetSddlForm漏掉ML的输出不可用于判定标签。
- 在普通F盘新目录以CreateNew流式重建文件，仅传输原始字节。未改任意已有文件/目录的ACL或标签，也未提权。新旧EXE SHA256均为a16124da5794238de6f48094d4109549c7f6c3fd17428e25364603fbd40820d9，新文件8192。内容相同、仅文件安全元数据不同。
- medium-native64.txt：同样探针字节在普通目录重建后，在原目标下mkdir、三个CreateFile、写、删除全部成功。
- medium-install.log/status：同一个安装器字节在原先失败的同一目标F:\guiyi\游戏安装\AnomalyBureau完整安装成功，exit0。无需改目标目录权限。
- acceptance-output.txt：正常Medium交付环境下完整安装、实际主菜单、覆盖、卸载、重装、保留测试存档/设置，9项通过。selected-menu-result.json另验证原目标实际主菜单。

## 持续修复

- build_installer.ps1、build_windows.ps1在开始前检查进程及输出父目录完整性；Low会拒绝，不再把不可正常使用的本地EXE当作完成交付。编译后检查外层/内层Setup和卸载入口标签，记录交付SHA256与完整性。
- installer_integrity.ps1和IntegrityProbe.cs只读，不修改ACL、不重设标签、不调用UAC或启用额外权限。
- export_installer.ps1以字节流CreateNew导出到用户选择的普通F盘新目录，验证摘要和正常标签，保留源文件。移动NTFS原对象并不能保证纠正继承标签。
- 安装验收脚本test_install.ps1同样拒绝Low执行环境与Low交付文件，避免整个测试进程树一起被降到Low而获得误导性成功。
- 默认目录可选其他固定数据盘；只有系统盘时显示当前用户Programs目录供玩家确认，不再让其他玩家必须有F盘。本机安装、构建和测试全部使用F盘，未自动转C盘。

## 最终交付

最终完整重建包：F:\guiyi\诡异事务局_安装包_20261031\AnomalyBureau-Setup-0.8.0.exe。

SHA256：295d5d6d1cce17568c0c153525af34c6990bf6c189ec3175108872557a00242d。delivery-check.json记录文件与构建进程完整性均8192。游戏资源仍为已发行0.8.0，不包含后续两轮未发行玩法/场景改进。

最终包在原目标再次完整覆盖安装，见final-target-install.log。最终包专用完整验收acceptance-final-output.txt为9通过/0失败，acceptance-final-status.txt为passed，私有桌面退出0。源码本地提交，不上传/覆盖现有GitHub附件。没有跨电脑、无F盘机器的人工安装结果，不能宣称已覆盖所有Windows配置。验证使用正常Medium上下文、私有非输入桌面、Dummy音频及独立存档；正式玩家数据未改。
