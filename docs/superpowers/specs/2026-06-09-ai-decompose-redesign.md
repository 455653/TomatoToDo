# AI Task Decomposition Redesign

**Date:** 2026-06-09
**Scope:** 修改 AI 任务拆解功能模块

---

## 1. 需求背景

当前 AI 拆解功能存在以下问题：
1. 用户需要自己填写 DeepSeek API Key（不应暴露给用户）
2. AI 仅返回子任务标题，属性用固定默认值填充
3. 缺少 AI 反向询问环节，拆解不够精准

## 2. 目标

1. DeepSeek API Key **硬编码**在 App 内，用户无需填写
2. 用户输入目标后，AI 先询问若干问题（一次列出），用户回答后再生成拆解结果
3. AI 生成的子任务包含完整属性（优先级、任务类型、日期），用户可内联编辑后一键导入

## 3. 改动范围

**仅修改以下2个文件，其余代码不动：**

| 文件 | 改动类型 |
|------|----------|
| `entry/src/main/ets/utils/DeepSeekApi.ets` | 新增方法、升级模型、硬编码Key |
| `entry/src/main/ets/components/AiDrawer.ets` | 状态机扩展、UI重构 |

**明确不修改的文件：** TaskModel.ets、TaskDao.ets、TaskViewModel.ets、TaskPage.ets、ProfilePage.ets、CollectionModel.ets、CollectionViewModel.ets 等。

## 4. 数据模型设计

### 4.1 升级 SubTask（DeepSeekApi.ets）

```typescript
// 旧：只有 title
export interface SubTask {
  title: string;
}

// 新：包含完整任务属性
export interface SubTask {
  title: string;
  priority: number;      // 0=LOW, 1=MEDIUM, 2=HIGH
  taskType: number;      // 0=MILESTONE, 1=HABIT
  startDate: number;     // 毫秒时间戳，习惯性任务为0
  endDate: number;       // 毫秒时间戳，习惯性任务为0
}
```

### 4.2 新增 AiQuestion 模型

```typescript
export interface AiQuestion {
  id: string;              // 问题ID，如 "q1"
  question: string;        // 问题文本
  type: 'select';          // 问题类型（仅选择题）
  options: string[];       // 选项列表
}
```

## 5. API 层设计（DeepSeekApi.ets）

### 5.1 API Key 硬编码

```typescript
// 删除原来的 getApiKey() + preferences 读取逻辑
// 改为常量
const HARDCODED_API_KEY = 'sk-your-deepseek-api-key-here';
```

### 5.2 新增方法：generateQuestions

```typescript
static async generateQuestions(
  context: common.Context,
  goal: string,
  onChunk: (text: string) => void
): Promise<AiQuestion[]>
```

**System Prompt:**
```
你是任务规划助手。分析用户的目标描述，生成3-5个问题来了解拆解需求。
问题应该涵盖：希望拆解为多少个子任务、任务默认优先级、任务类型（阶段性/习惯性）、时间范围等。
只返回JSON数组，格式：[{"id":"q1","question":"你希望拆解为几个子任务？","type":"select","options":["3个以内","4-6个","7个以上"]}]
不要有任何其他文字。
```

### 5.3 新增方法：decomposeWithAnswers

```typescript
static async decomposeWithAnswers(
  context: common.Context,
  goal: string,
  questions: AiQuestion[],
  answers: Record<string, string>,
  onChunk: (text: string) => void
): Promise<SubTask[]>
```

**System Prompt:**
```
你是任务规划助手。用户有一个目标，并且回答了一些澄清问题。
根据目标和用户回答，将目标拆解为3-6个子任务。
每个子任务包含完整属性。
只返回JSON数组，格式：
[{"title":"子任务名","priority":1,"taskType":0,"startDate":1750000000000,"endDate":1750600000000}]

字段说明：
- priority: 0=低优先级, 1=中优先级, 2=高优先级
- taskType: 0=阶段性任务, 1=习惯性任务
- startDate: 阶段开始日期毫秒时间戳（习惯性任务为0）
- endDate: 阶段结束日期毫秒时间戳（习惯性任务为0）
不要有任何其他文字。
```

### 5.4 删除的方法

- `getApiKey()` —— 用户不再需要填写 API Key

## 6. UI 层设计（AiDrawer.ets）

### 6.1 状态机扩展

```
旧：INPUT(0) → LOADING(1) → RESULT(2)
新：INPUT(0) → LOADING_Q(1) → QUESTIONS(2) → LOADING_R(3) → RESULT(4)
```

### 6.2 INPUT 状态（输入目标）

与现版基本一致，变更：
- **删除** API Key 未设置警告条（`hasApiKey` 状态及相关 UI）

### 6.3 LOADING_Q 状态（AI 生成问题中）

显示加载动画 + 提示文字 "正在分析你的目标..."

### 6.4 QUESTIONS 状态（回答 AI 问题）—— 全新

- 顶部：标题 "补充信息" + 说明文字
- 中间（可滚动）：AI 返回的问题列表，每个问题包括：
  - 问题文本（不可编辑）
  - 选项按钮（可点击选择，同一问题内互斥）
- 状态：`@State userAnswers: Record<string, string> = {}`
- 底部按钮："生成拆解"（所有问题必须回答后才可点击）

### 6.5 LOADING_R 状态（AI 生成结果中）

与现版 LOADING 状态相同。

### 6.6 RESULT 状态（编辑结果）—— 增强

**子任务卡片展开布局（每条显示）：**

```
┌──────────────────────────────────────┐
│ [标题 TextInput]              ✕ 删除 │
│ 优先级：  ○低   ●中   ○高            │
│ 类型：    ●阶段性  ○习惯性           │
│ 开始：[日期选择]  结束：[日期选择]    │  ← 仅阶段性任务显示
└──────────────────────────────────────┘
```

- 新增 `updateSubtaskField(index, field, value)` 方法替代旧的 `updateSubtaskTitle`
- 删除旧方法 `updateSubtaskTitle`

### 6.7 业务方法变更

| 方法 | 操作 |
|------|------|
| `checkApiKey()` | 删除 |
| `hasApiKey` 状态 | 删除 |
| `onStartDecompose()` | 改为调用 `generateQuestions` → 进入 QUESTIONS |
| `onSubmitAnswers()` | **新增**，收集答案 → 调用 `decomposeWithAnswers` → 进入 LOADING_R |
| `updateSubtaskTitle()` | 删除，替换为 `updateSubtaskField()` |
| `updateSubtaskField()` | **新增**，更新子任务任意字段 |
| `onBatchAdd()` | 改为使用子任务自带完整属性，不再用默认值 |

### 6.8 一键导入变更

```typescript
// 旧（默认值）
priority: Priority.MEDIUM,
taskType: TaskType.MILESTONE,
startDate: 0,
endDate: 0,

// 新（使用AI返回值）
priority: st.priority,
taskType: st.taskType,
startDate: st.startDate,
endDate: st.endDate,
```

## 7. 完整交互流程

```
用户点击 "AI 拆解" 浮动按钮
  → 打开底部抽屉（INPUT 状态）
  → 输入目标描述，点击 "开始拆解"
  → LOADING_Q：加载动画
  → QUESTIONS：显示AI生成的问题列表
  → 用户回答所有问题，点击 "生成拆解"
  → LOADING_R：加载动画
  → RESULT：显示带完整属性的子任务列表
  → 用户编辑调整每项属性
  → 点击 "一键导入"
  → 批量写入 tasks 表 → 关闭抽屉 → 刷新任务列表
```

## 8. 错误处理

- 网络错误：提示 "网络请求失败，请检查网络"，回到 INPUT
- AI 返回格式异常：提示 "AI 返回格式异常，请重试"，回到 INPUT
- 导入失败：提示具体错误信息，保持在 RESULT（不丢数据）
- 用户未登录：提示 "请先登录"

## 9. 不变的部分

- Task 数据模型（TaskModel.ets）
- 数据库操作（TaskDao.ets）
- 任务业务逻辑（TaskViewModel.ets）
- 任务管理页面（TaskPage.ets）
- 合集相关（CollectionModel.ets, CollectionDao.ets, CollectionViewModel.ets）
- 用户/设置页面（ProfilePage.ets）
- 其他所有非 AI 拆解文件
