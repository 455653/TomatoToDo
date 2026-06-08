// ===== utils/AuthGuard.ets =====
// 登录态守卫 —— 内存静态变量管理当前用户 ID，支持持久化存储

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * AuthGuard —— 提供登录态读写的静态工具方法
 * 使用静态变量管理当前用户 ID，-1 表示未登录
 * 支持持久化存储，应用重启后自动恢复登录状态
 */
export class AuthGuard {
  /** 当前登录用户 ID，-1 表示未登录 */
  private static currentUserId: number = -1;
  /** Preferences 实例 */
  private static dataPreferences: preferences.Preferences | null = null;
  /** Preferences 文件名 */
  private static readonly PREFERENCES_NAME: string = 'TomatoToDoAuth';
  /** 存储用户 ID 的 Key */
  private static readonly KEY_USER_ID: string = 'currentUserId';
  /** 初始化标记 */
  private static initialized: boolean = false;

  /**
   * 初始化 AuthGuard，从持久化存储恢复登录状态
   */
  static async init(context: common.Context): Promise<void> {
    if (AuthGuard.initialized) {
      return;
    }

    try {
      AuthGuard.dataPreferences = await preferences.getPreferences(context, AuthGuard.PREFERENCES_NAME);
      const storedUserId = await AuthGuard.dataPreferences.get(AuthGuard.KEY_USER_ID, -1) as number;
      AuthGuard.currentUserId = storedUserId;
      AuthGuard.initialized = true;
      console.log(`[AuthGuard] Initialized, userId: ${AuthGuard.currentUserId}`);
    } catch (err) {
      console.error(`[AuthGuard] Init failed: ${JSON.stringify(err)}`);
      AuthGuard.initialized = true;
    }
  }

  /**
   * 判断当前是否已登录
   */
  static isLoggedIn(): boolean {
    return AuthGuard.currentUserId > 0;
  }

  /**
   * 登录：将 userId 写入内存和持久化存储
   */
  static async login(userId: number): Promise<void> {
    AuthGuard.currentUserId = userId;
    if (AuthGuard.dataPreferences) {
      try {
        await AuthGuard.dataPreferences.put(AuthGuard.KEY_USER_ID, userId);
        await AuthGuard.dataPreferences.flush();
        console.log(`[AuthGuard] Login persisted, userId: ${userId}`);
      } catch (err) {
        console.error(`[AuthGuard] Persist login failed: ${JSON.stringify(err)}`);
      }
    }
  }

  /**
   * 登出：将 currentUserId 重置为 -1 并清除持久化存储
   */
  static async logout(): Promise<void> {
    AuthGuard.currentUserId = -1;
    if (AuthGuard.dataPreferences) {
      try {
        await AuthGuard.dataPreferences.delete(AuthGuard.KEY_USER_ID);
        await AuthGuard.dataPreferences.flush();
        console.log(`[AuthGuard] Logout persisted`);
      } catch (err) {
        console.error(`[AuthGuard] Persist logout failed: ${JSON.stringify(err)}`);
      }
    }
  }

  /**
   * 获取当前登录用户 ID
   */
  static getCurrentUserId(): number {
    return AuthGuard.currentUserId;
  }
}
