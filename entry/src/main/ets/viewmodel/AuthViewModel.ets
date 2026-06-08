// ===== viewmodel/AuthViewModel.ets =====
// 认证业务逻辑 —— 注册与登录

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { UserDao } from '../database/UserDao';
import { AuthGuard } from '../utils/AuthGuard';
import { User } from '../model/UserModel';

/** 用户名正则：3-20 位字母数字 */
const USERNAME_REGEX = /^[a-zA-Z0-9]{3,20}$/;

/** 密码最小长度 */
const PASSWORD_MIN_LENGTH = 6;

/** 认证操作结果 */
export interface AuthResult {
  ok: boolean;
  msg: string;
}

/**
 * AuthViewModel —— 处理注册/登录核心逻辑
 */
export class AuthViewModel {
  private userDao: UserDao = new UserDao();

  /**
   * 用户注册
   * @param username 用户名（3-20 位字母数字）
   * @param password 密码（6 位以上）
   * @returns {ok, msg} 结果
   */
  async register(username: string, password: string): Promise<AuthResult> {
    try {
      // --- 1. 前端校验 ---
      if (!username || username.trim().length === 0) {
        return { ok: false, msg: '用户名不能为空' };
      }
      if (!USERNAME_REGEX.test(username.trim())) {
        return { ok: false, msg: '用户名须为 3-20 位字母或数字' };
      }
      if (!password || password.length < PASSWORD_MIN_LENGTH) {
        return { ok: false, msg: `密码至少需要 ${PASSWORD_MIN_LENGTH} 位` };
      }

      const cleanUsername = username.trim();

      // --- 2. 检查用户名是否已存在 ---
      const existingUser: User | null = await this.userDao.findByUsername(cleanUsername);
      if (existingUser) {
        return { ok: false, msg: '该用户名已被注册' };
      }

      // --- 3. SHA-256 哈希密码 ---
      const passwordHash: string = await this.sha256(password);

      // --- 4. 写入数据库 ---
      const userId: number = await this.userDao.insert(cleanUsername, passwordHash);
      if (userId <= 0) {
        return { ok: false, msg: '注册失败，请重试' };
      }

      // --- 5. 注册成功，不自动登录，提示用户前往登录 ---
      return { ok: true, msg: '注册成功，请登录' };
    } catch (err) {
      return { ok: false, msg: `注册异常: ${JSON.stringify(err)}` };
    }
  }

  /**
   * 用户登录
   * @param username 用户名
   * @param password 密码
   * @returns {ok, msg} 结果
   */
  async login(username: string, password: string): Promise<AuthResult> {
    try {
      // --- 1. 前端校验 ---
      if (!username || username.trim().length === 0) {
        return { ok: false, msg: '请输入用户名' };
      }
      if (!password || password.length === 0) {
        return { ok: false, msg: '请输入密码' };
      }

      const cleanUsername = username.trim();

      // --- 2. 查询用户 ---
      const user: User | null = await this.userDao.findByUsername(cleanUsername);
      if (!user) {
        return { ok: false, msg: '用户名不存在' };
      }

      // --- 3. 比对密码哈希 ---
      const inputHash: string = await this.sha256(password);
      if (inputHash !== user.passwordHash) {
        return { ok: false, msg: '密码错误' };
      }

      // --- 4. 登录成功 ---
      await AuthGuard.login(user.id);
      return { ok: true, msg: '登录成功' };
    } catch (err) {
      return { ok: false, msg: `登录异常: ${JSON.stringify(err)}` };
    }
  }

  /**
   * 使用 cryptoFramework 计算 SHA-256 哈希
   * @param plainText 明文
   * @returns 十六进制哈希字符串
   */
  private async sha256(plainText: string): Promise<string> {
    try {
      // 将字符串转为 Uint8Array
      const textEncoder = new util.TextEncoder();
      const inputData: Uint8Array = textEncoder.encodeInto(plainText);

      // 创建 SHA-256 消息摘要实例
      const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
      await md.update({ data: inputData });

      // 获取摘要结果
      const result = await md.digest();

      // 将 Uint8Array 转为十六进制字符串
      return this.uint8ArrayToHex(result.data);
    } catch (err) {
      throw new Error(`SHA-256 计算失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * Uint8Array → 十六进制字符串
   */
  private uint8ArrayToHex(arr: Uint8Array): string {
    return Array.from(arr)
      .map((b: number) => b.toString(16).padStart(2, '0'))
      .join('');
  }
}
