# 炉石传说日志格式速查

本文档给出 `Power.log`、`Hearthstone.log` 与 `GameNetLogger.log` 中与战棋辅助相关的常见片段，方便理解解析逻辑与测试。

## 日志路径与开启方式
- **macOS 默认路径**：
  - `/Applications/Hearthstone/Logs/Power.log`（安装目录下最新补丁子目录也会生成）
  - `/Applications/Hearthstone/Logs/Hearthstone.log`
  - `/Applications/Hearthstone/Logs/GameNetLogger.log`
  - `~/Library/Logs/Blizzard Entertainment/Hearthstone/*.log`
- **开启日志**：需在 `~/Library/Preferences/Blizzard/Hearthstone/log.config` 中开启（或使用 HSTracker/HDTR 配置向导）。

## Power.log 核心片段
- **开局重置**：
  ```text
  PowerTaskList.DebugPrintPower() - CREATE_GAME
  ```
  用于重置缓存与玩家映射。

- **模式识别**（`GameType` 数值或枚举）：
  ```text
  GameState.DebugPrintPower() -     GameType=GT_BATTLEGROUNDS
  GameState.DebugPrintPower() -     GameType=8
  ```
  其中 `8` 与 `50` 也是战棋模式的数值枚举。

- **玩家与名称映射**：
  ```text
  PlayerID=1, PlayerName=玩家A
  Player EntityID=64 PlayerID=1 GameAccountId=[hi=123 lo=456]
  TAG_CHANGE Entity=Player#1 tag=LOCAL_PLAYER value=1
  ```
  用于确定本地玩家 ID 与昵称。

- **资源/阶段标签**（通过 `TAG_CHANGE` 行获取）：
  ```text
  TAG_CHANGE Entity=Player#1 tag=RESOURCES value=5
  TAG_CHANGE Entity=Player#1 tag=TEMP_RESOURCES value=2
  TAG_CHANGE Entity=Player#1 tag=RESOURCES_USED value=3
  TAG_CHANGE Entity=Player#1 tag=TURN value=7
  TAG_CHANGE Entity=someentity tag=PLAYER_TECH_LEVEL value=4
  TAG_CHANGE Entity=someentity tag=STEP value=MAIN_READY
  TAG_CHANGE Entity=someentity tag=GAMETAG_2022 value=1
  TAG_CHANGE Entity=someentity tag=GAMETAG_3533 value=0
  ```
  - `STEP` 可落在 `MAIN_*`（招募阶段）或 `COMBAT`（战斗阶段）。
  - `GAMETAG_2022`、`GAMETAG_3533` 组合可在战斗/商店切换时出现 1→0 的翻转。

## Hearthstone.log 关键行
- **模式/场景提示**：
  ```text
  LoadingScreen.OnSceneLoaded() - scene=Bacon
  Network [Info]: GameType=GT_BATTLEGROUNDS
  Network [Info]: GameType=8
  ```
  其中 `Bacon`/`BATTLEGROUNDS` 字样与 `GameType` 提示用于补充模式识别。

- **步骤/阶段**（部分客户端版本会记录）：
  ```text
  Network [Info]: STEP=MAIN_ACTION
  Network [Info]: STEP=COMBAT
  ```

## GameNetLogger.log 关键行
- **大厅与模式切换**：
  ```text
  Client.Inform - GameType=8 Mission=9000 ScenarioId=903
  ```
  常在进入酒馆大厅或匹配时出现，补充战棋模式判断。

- **场景关键词**：某些构建会在 `Bacon` 或 `Battlegrounds` 文本出现时写入，作为兜底模式信号。

## 解析器与正则对应关系
| 解析器 | 关键信息 | 使用的正则/关键词 |
| --- | --- | --- |
| `PowerLogMonitor` | `GameType` 模式识别 | `GameType=([A-Z_]+|\d+)` |
|  | 玩家 ID / 名称 | `PlayerID=(\d+),\s+PlayerName=([^\s]+)`、`Player EntityID=\d+\s+PlayerID=(\d+)` |
|  | 资源/阶段标签 | `tag=([A-Z0-9_]+)\s+value=([^\s]+)` + `GAMETAG_2022` / `GAMETAG_3533` |
| `HearthstoneLogMonitor` | 模式识别 | 同 `GameType` 正则，或 `Bacon`/`BATTLEGROUNDS` 关键词 |
|  | 步骤/阶段 | `STEP=([A-Z_]+)` 与 `MAIN_*` / `COMBAT` 关键词 |

> 这些样例来自常见的国服/国际服客户端日志输出，可直接用于手工测试或模拟尾随解析。
