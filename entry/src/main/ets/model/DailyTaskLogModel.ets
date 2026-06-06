// ===== model/DailyTaskLogModel.ets =====
// 习惯性任务每日打卡记录

/** 每日打卡记录 */
export interface DailyTaskLog {
  id: number;
  taskId: number;
  userId: number;
  /** 打卡日期，格式 'YYYY-MM-DD' */
  logDate: string;
  /** 完成时间戳（毫秒） */
  completedAt: number;
}
