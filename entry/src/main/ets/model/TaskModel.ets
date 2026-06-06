// ===== model/TaskModel.ets =====
// 任务数据模型

/** 任务实体 */
export interface Task {
  /** 主键 ID */
  id: number;
  /** 所属用户 ID */
  userId: number;
  /** 所属合集 ID，0 表示"未分类" */
  collectionId: number;
  /** 任务标题 */
  title: string;
  /** 是否已完成 */
  done: boolean;
  /** 优先级 */
  priority: number;
  /** 创建时间戳（毫秒） */
  createdAt: number;
  /** 任务类型 0=阶段性 1=习惯性 */
  taskType: number;
  /** 阶段开始日期时间戳（毫秒），习惯性任务为0 */
  startDate: number;
  /** 阶段结束日期时间戳（毫秒），习惯性任务为0 */
  endDate: number;
}

/** 任务优先级枚举 */
export enum Priority {
  LOW = 0,
  MEDIUM = 1,
  HIGH = 2,
}

/** 任务类型 */
export enum TaskType {
  MILESTONE = 0,  // 阶段性任务
  HABIT = 1,      // 习惯性任务
}
