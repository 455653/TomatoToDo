// ===== model/UserModel.ets =====
// 用户数据模型

export interface User {
  /** 主键 ID */
  id: number;
  /** 用户名（唯一） */
  username: string;
  /** SHA-256 哈希后的密码 */
  passwordHash: string;
  /** 创建时间戳（毫秒） */
  createdAt: number;
}
