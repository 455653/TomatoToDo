// ===== utils/DeepSeekApi.ets =====
// DeepSeek AI 任务拆解 API 客户端
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
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/** DeepSeek Chat Completions 端点 */
const API_URL = 'https://api.deepseek.com/chat/completions';

/** Preferences 存储名 */
const PREF_STORE_NAME = 'tomato_settings';
const KEY_API_KEY = 'dsApiKey';

/** 系统提示词 —— 限制 JSON 输出格式 */
const SYSTEM_PROMPT =
  '你是任务规划助手。用户输入一个目标，你将其拆解为3-6个具体子任务。' +
  '只返回 JSON 数组，格式：[{"title":"任务名"}]，' +
  '不要有任何其他文字。';

// ═══════════════════════════════════════════════
// 类型定义
// ═══════════════════════════════════════════════

/** AI 拆解的子任务 */
export interface SubTask {
  /** 任务名称 */
  title: string;
}

/** DeepSeek API 响应中单条选项 */
interface DeepSeekChoice {
  message: DeepSeekMessage;
  finish_reason: string;
}

/** API 消息体 */
interface DeepSeekMessage {
  role: string;
  content: string;
}

/** DeepSeek API 完整响应体 */
interface DeepSeekResponse {
  choices: DeepSeekChoice[];
}

/** 请求消息 */
interface ChatMessage {
  role: string;
  content: string;
}

/** Chat Completions 请求体 */
interface ChatRequest {
  model: string;
  messages: ChatMessage[];
  stream: boolean;
  temperature: number;
}

/** 请求超时毫秒 */
const CONNECT_TIMEOUT = 30000;
const READ_TIMEOUT = 60000;

// ═══════════════════════════════════════════════
// DeepSeekApi 工具类
// ═══════════════════════════════════════════════

export class DeepSeekApi {
  /**
   * 从 preferences 读取 API Key
   * @returns 已保存的 API Key 字符串，未填写时返回空字符串
   */
  static async getApiKey(context: common.Context): Promise<string> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, PREF_STORE_NAME);
      const key: preferences.ValueType = await prefs.get(KEY_API_KEY, '');
      return (key as string) ?? '';
    } catch (err) {
      console.error('[DeepSeekApi] getApiKey error:', JSON.stringify(err));
      return '';
    }
  }

  /**
   * 调用 DeepSeek API 拆解大目标为子任务
   * @param context 应用上下文
   * @param goal 用户输入的大目标描述
   * @param onChunk 过程回调（非流式，仅开始/完成两次调用）
   * @returns 拆解出的子任务数组
   */
  static async decompose(
    context: common.Context,
    goal: string,
    onChunk: (text: string) => void
  ): Promise<SubTask[]> {
    // 1) 检查 API Key
    const apiKey: string = await DeepSeekApi.getApiKey(context);
    if (apiKey.length === 0) {
      throw new Error('API_KEY_EMPTY');
    }

    // 2) 开始
    onChunk('正在思考中...');

    // 3) 发起 HTTP 请求
    const httpRequest = http.createHttp();
    try {
      const messages: ChatMessage[] = [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: goal },
      ];
      const chatReq: ChatRequest = {
        model: 'deepseek-chat',
        messages: messages,
        stream: false,
        temperature: 0.7,
      };
      const requestBody = JSON.stringify(chatReq);

      const response = await httpRequest.request(API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        extraData: requestBody,
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT,
      });

      // 4) 解析 HTTP 响应体
      const rawBody: string = response.result as string;
      let apiResponse: DeepSeekResponse;
      try {
        apiResponse = JSON.parse(rawBody) as DeepSeekResponse;
      } catch (err) {
        console.error('[DeepSeekApi] HTTP body JSON parse error:', JSON.stringify(err));
        throw new Error('AI 服务返回异常，请稍后重试');
      }

      // 5) 提取 assistant 回复内容
      const content: string = apiResponse.choices?.[0]?.message?.content ?? '';
      if (content.length === 0) {
        throw new Error('AI 未返回有效内容，请尝试更具体的描述');
      }

      // 6) 解析 content 中的 JSON 数组
      let subtasks: SubTask[];
      try {
        // 去除可能的 markdown 代码块标记
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
        subtasks = JSON.parse(jsonStr) as SubTask[];
      } catch (err) {
        console.error('[DeepSeekApi] content JSON parse error:', JSON.stringify(err));
        throw new Error('AI 返回格式异常，请重试');
      }

      // 7) 校验数组格式
      if (!Array.isArray(subtasks) || subtasks.length === 0) {
        throw new Error('AI 返回格式异常，请重试');
      }

      // 8) 校验并修正每条子任务
      const result: SubTask[] = [];
      for (let i = 0; i < subtasks.length; i++) {
        const st = subtasks[i];
        const title: string = (st.title ?? '').toString().trim();
        if (title.length === 0) {
          continue; // 跳过空标题项
        }
        result.push({ title: title });
      }

      if (result.length === 0) {
        throw new Error('AI 返回格式异常，请重试');
      }

      // 9) 完成回调
      onChunk(`已拆解为 ${result.length} 个子任务`);
      return result;

    } catch (err) {
      // 重新抛出我们自己的错误
      const msg = typeof err === 'object' && (err as Error).message
        ? (err as Error).message
        : '网络请求失败，请检查网络';
      throw new Error(msg);
    } finally {
      httpRequest.destroy();
    }
  }
}
