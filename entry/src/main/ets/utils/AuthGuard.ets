// ===== utils/AuthGuard.ets =====
// 登录态守卫 —— 内存静态变量管理当前用户 ID

/**
 * AuthGuard —— 提供登录态读写的静态工具方法
 * 使用静态变量管理当前用户 ID，-1 表示未登录
 */
export class AuthGuard {
  /** 当前登录用户 ID，-1 表示未登录 */
  private static currentUserId: number = -1;

  /**
   * 判断当前是否已登录
   */
  static isLoggedIn(): boolean {
    return AuthGuard.currentUserId > 0;
  }

  /**
   * 登录：将 userId 写入内存
   */
  static login(userId: number): void {
    AuthGuard.currentUserId = userId;
  }

  /**
   * 登出：将 currentUserId 重置为 -1
   */
  static logout(): void {
    AuthGuard.currentUserId = -1;
  }

  /**
   * 获取当前登录用户 ID
   */
  static getCurrentUserId(): number {
    return AuthGuard.currentUserId;
  }
}
