// ===== model/SessionModel.ets =====
// 番茄钟会话数据模型

/** 一次专注/休息会话 */
export interface Session {
  /** 主键 ID */
  id: number;
  /** 所属用户 ID */
  userId: number;
  /** 关联任务 ID */
  taskId: number;
  /** 开始时间戳（毫秒） */
  startTime: number;
  /** 结束时间戳（毫秒） */
  endTime: number;
  /** 实际持续秒数 */
  durationSeconds: number;
  /** 中断次数 */
  interruptions: number;
  /** 是否完成（1=完整完成，0=中途放弃） */
  completed: number;
}
