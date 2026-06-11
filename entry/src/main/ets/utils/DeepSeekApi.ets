// ===== utils/DeepSeekApi.ets =====
// DeepSeek AI 任务拆解 API 客户端 —— 两阶段：
//   阶段1：AI 分析目标，生成澄清问题
//   阶段2：用户回答后，AI 生成带完整属性的子任务
//
// ════════════════════════════════════════════════════════════
// 【module.json5 配置说明】
// 在 entry/src/main/module.json5 顶层 requestPermissions 中追加：
//
// "requestPermissions": [
//   { "name": "ohos.permission.INTERNET" }
// ]
// ════════════════════════════════════════════════════════════

import { http } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';

/** DeepSeek Chat Completions 端点 */
const API_URL = 'https://api.deepseek.com/chat/completions';

/** 硬编码 API Key（软件提供，不暴露给用户） */
const HARDCODED_API_KEY = 'sk-a28cb84768ea4d31ae244b5bcbbac7cf';

// ═══════════════════════════════════════════════
// 类型定义
// ═══════════════════════════════════════════════

/** AI 拆解的子任务（包含完整任务属性） */
export interface SubTask {
  /** 任务名称 */
  title: string;
  /** 优先级：0=低, 1=中, 2=高 */
  priority: number;
  /** 任务类型：0=阶段性, 1=习惯性 */
  taskType: number;
  /** 阶段开始日期毫秒时间戳（习惯性任务为0） */
  startDate: number;
  /** 阶段结束日期毫秒时间戳（习惯性任务为0） */
  endDate: number;
}

/** AI 生成的澄清问题 */
export interface AiQuestion {
  /** 问题ID */
  id: string;
  /** 问题文本 */
  question: string;
  /** 问题类型 */
  type: string;
  /** 选项列表 */
  options: string[];
}

// ═══════════════════════════════════════════════
// 内部类型（API 请求/响应）
// ═══════════════════════════════════════════════

/** API 消息体 */
interface DeepSeekMessage {
  role: string;
  content: string;
}

/** DeepSeek API 响应中单条选项 */
interface DeepSeekChoice {
  message: DeepSeekMessage;
  finish_reason: string;
}

/** DeepSeek API 完整响应体 */
interface DeepSeekResponse {
  choices: DeepSeekChoice[];
}

/** Chat Completions 请求体 */
interface ChatRequest {
  model: string;
  messages: ChatMessage[];
  stream: boolean;
  temperature: number;
}

interface ChatMessage {
  role: string;
  content: string;
}

/** 请求超时毫秒 */
const CONNECT_TIMEOUT = 30000;
const READ_TIMEOUT = 60000;

// ═══════════════════════════════════════════════
// 阶段1：生成澄清问题
// ═══════════════════════════════════════════════

const QUESTIONS_SYSTEM_PROMPT =
  '你是任务规划助手。分析用户的目标描述，生成3-5个问题来了解拆解需求。' +
  '问题应该涵盖：希望拆解为多少个子任务、任务默认优先级、任务类型（阶段性/习惯性）、时间范围等。' +
  '只返回JSON数组，不要有任何其他文字。' +
  '格式：[{"id":"q1","question":"你希望拆解为几个子任务？","type":"select","options":["3个以内","4-6个","7个以上"]}]';

// ═══════════════════════════════════════════════
// 阶段2：根据答案生成带完整属性的子任务
// ═══════════════════════════════════════════════

const DECOMPOSE_SYSTEM_PROMPT =
  '你是任务规划助手。用户有一个目标，并且回答了一些澄清问题。' +
  '根据目标和用户回答，将目标拆解为3-6个子任务。每个子任务包含完整属性。' +
  '只返回JSON数组，不要有任何其他文字。' +
  '格式：[{"title":"子任务名","priority":1,"taskType":0,"startDate":1750000000000,"endDate":1750600000000}]' +
  '字段说明：priority: 0=低, 1=中, 2=高；taskType: 0=阶段性, 1=习惯性；' +
  'startDate/endDate: 毫秒时间戳（习惯性任务这两项设为0）。' +
  '日期根据当前时间和用户回答合理推算，startDate应大于当前时间。';

// ═══════════════════════════════════════════════
// DeepSeekApi 工具类
// ═══════════════════════════════════════════════

export class DeepSeekApi {
  /**
   * 阶段1：AI 分析目标，生成澄清问题列表
   * @param context 应用上下文
   * @param goal 用户输入的目标描述
   * @param onChunk 进度回调
   * @returns 澄清问题数组
   */
  static async generateQuestions(
    context: common.Context,
    goal: string,
    onChunk: (text: string) => void
  ): Promise<AiQuestion[]> {
    onChunk('正在分析你的目标...');

    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    const userMessage = `我的目标是：${goal}\n今天的日期是：${todayStr}`;

    const content = await DeepSeekApi.callApi(QUESTIONS_SYSTEM_PROMPT, userMessage);

    // 解析 JSON 数组
    let questions: AiQuestion[];
    const jsonStr = DeepSeekApi.extractJson(content);
    try {
      questions = JSON.parse(jsonStr) as AiQuestion[];
    } catch (err) {
      console.error('[DeepSeekApi] questions JSON parse error:', JSON.stringify(err));
      throw new Error('AI 返回格式异常，请重试');
    }

    if (!Array.isArray(questions) || questions.length === 0) {
      throw new Error('AI 未返回有效问题，请重试');
    }

    // 校验并清理
    const result: AiQuestion[] = [];
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      if (!q.id || !q.question || q.question.trim().length === 0) {
        continue;
      }
      result.push({
        id: q.id,
        question: q.question.trim(),
        type: q.type || 'select',
        options: Array.isArray(q.options) ? q.options : [],
      });
    }

    if (result.length === 0) {
      throw new Error('AI 未返回有效问题，请重试');
    }

    onChunk('');
    return result;
  }

  /**
   * 阶段2：根据用户回答，生成带完整属性的子任务
   * @param context 应用上下文
   * @param goal 用户原始目标
   * @param questions AI 生成的问题列表
   * @param answers 用户答案 {questionId: answerText}
   * @param onChunk 进度回调
   * @returns 带完整属性的子任务数组
   */
  static async decomposeWithAnswers(
    context: common.Context,
    goal: string,
    questions: AiQuestion[],
    answers: Record<string, string>,
    onChunk: (text: string) => void
  ): Promise<SubTask[]> {
    onChunk('正在生成任务拆解...');

    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    const nowTs = today.getTime();

    // 构建问答上下文
    let qaContext = '';
    for (const q of questions) {
      const answer = answers[q.id] || '未回答';
      qaContext += `问：${q.question}\n答：${answer}\n`;
    }

    const userMessage =
      `我的目标是：${goal}\n` +
      `今天的日期是：${todayStr}（对应毫秒时间戳约${nowTs}）\n` +
      `以下是我对澄清问题的回答：\n${qaContext}\n` +
      `请根据以上信息拆解任务。日期使用毫秒时间戳，startDate应大于${nowTs}。`;

    const content = await DeepSeekApi.callApi(DECOMPOSE_SYSTEM_PROMPT, userMessage);

    // 解析 JSON 数组
    const jsonStr = DeepSeekApi.extractJson(content);
    let subtasks: SubTask[];
    try {
      subtasks = JSON.parse(jsonStr) as SubTask[];
    } catch (err) {
      console.error('[DeepSeekApi] subtasks JSON parse error:', JSON.stringify(err));
      throw new Error('AI 返回格式异常，请重试');
    }

    if (!Array.isArray(subtasks) || subtasks.length === 0) {
      throw new Error('AI 未返回有效内容，请尝试更具体的描述');
    }

    // 校验并清理每条子任务
    const result: SubTask[] = [];
    for (const st of subtasks) {
      const title = (st.title ?? '').toString().trim();
      if (title.length === 0) {
        continue;
      }
      const priority = [0, 1, 2].includes(st.priority) ? st.priority : 1;
      const taskType = [0, 1].includes(st.taskType) ? st.taskType : 0;
      let startDate = typeof st.startDate === 'number' && st.startDate > 0 ? st.startDate : 0;
      let endDate = typeof st.endDate === 'number' && st.endDate > 0 ? st.endDate : 0;
      // 习惯性任务日期为0
      if (taskType === 1) {
        startDate = 0;
        endDate = 0;
      }
      // 如果结束日期不大于开始日期，自动修正
      if (taskType === 0 && endDate <= startDate) {
        endDate = startDate + 7 * 24 * 60 * 60 * 1000; // 默认+7天
      }

      result.push({
        title: title,
        priority: priority,
        taskType: taskType,
        startDate: startDate,
        endDate: endDate,
      });
    }

    if (result.length === 0) {
      throw new Error('AI 返回格式异常，请重试');
    }

    onChunk(`已拆解为 ${result.length} 个子任务`);
    return result;
  }

  // ═══════════════════════════════════════════════
  // 私有方法
  // ═══════════════════════════════════════════════

  /**
   * 调用 DeepSeek API 并返回 assistant 内容
   */
  private static async callApi(systemPrompt: string, userMessage: string): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const messages: ChatMessage[] = [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessage },
      ];
      const chatReq: ChatRequest = {
        model: 'deepseek-chat',
        messages: messages,
        stream: false,
        temperature: 0.7,
      };

      const response = await httpRequest.request(API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${HARDCODED_API_KEY}`,
        },
        extraData: JSON.stringify(chatReq),
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT,
      });

      const rawBody: string = response.result as string;
      let apiResponse: DeepSeekResponse;
      try {
        apiResponse = JSON.parse(rawBody) as DeepSeekResponse;
      } catch (err) {
        console.error('[DeepSeekApi] HTTP body JSON parse error:', JSON.stringify(err));
        throw new Error('AI 服务返回异常，请稍后重试');
      }

      const content: string = apiResponse.choices?.[0]?.message?.content ?? '';
      if (content.length === 0) {
        throw new Error('AI 未返回有效内容，请尝试更具体的描述');
      }

      return content;
    } catch (err) {
      const msg = typeof err === 'object' && (err as Error).message
        ? (err as Error).message
        : '网络请求失败，请检查网络';
      throw new Error(msg);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 从 AI 返回内容中提取 JSON 字符串（去除 markdown 代码块标记）
   */
  private static extractJson(content: string): string {
    let jsonStr = content.trim();
    if (jsonStr.startsWith('```')) {
      const firstNewline = jsonStr.indexOf('\n');
      if (firstNewline > 0) {
        jsonStr = jsonStr.substring(firstNewline + 1);
      } else {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();
    }
    return jsonStr;
  }
}
