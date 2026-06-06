// ===== model/CollectionModel.ets =====
// 任务合集数据模型

/** 任务合集实体 */
export interface Collection {
  /** 主键 ID */
  id: number;
  /** 所属用户 ID */
  userId: number;
  /** 合集名称 */
  name: string;
  /** 合集标识颜色（十六进制字符串，如 '#FF6347'） */
  color: string;
  /** 创建时间戳（毫秒） */
  createdAt: number;
}
