// ===== model/TaskModel.ets =====
// 任务数据模型

/** 任务实体 */
export interface Task {
  /** 主键 ID */
  id: number;
  /** 所属用户 ID */
  userId: number;
  /** 任务标题 */
  title: string;
  /** 预估番茄数 */
  estimatedPomodoros: number;
  /** 是否已完成 */
  done: boolean;
  /** 优先级 */
  priority: number;
  /** 创建时间戳（毫秒） */
  createdAt: number;
}

/** 任务优先级枚举 */
export enum Priority {
  LOW = 0,
  MEDIUM = 1,
  HIGH = 2,
}
