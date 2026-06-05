 // ===== database/DbHelper.ets =====
// 数据库单例辅助类，负责 RDB 初始化与建表

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/** 数据库文件名 */
const DB_NAME = 'TomatoToDo.db';

/** RDB 配置 */
const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1,
};

/**
 * 建表 SQL —— 使用 IF NOT EXISTS 避免重复建表
 */
const CREATE_USERS_TABLE = `
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at INTEGER
  );
`;

const CREATE_TASKS_TABLE = `
  CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    title TEXT,
    estimated_pomodoros INTEGER DEFAULT 1,
    done INTEGER DEFAULT 0,
    priority INTEGER DEFAULT 1,
    created_at INTEGER
  );
`;

const CREATE_SESSIONS_TABLE = `
  CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    task_id INTEGER,
    start_time INTEGER,
    end_time INTEGER,
    duration_seconds INTEGER,
    interruptions INTEGER DEFAULT 0,
    completed INTEGER DEFAULT 1
  );
`;

/**
 * DbHelper —— 单例模式
 * 使用前必须先调用 init(context) 传入应用上下文
 */
export class DbHelper {
  private static instance: DbHelper;
  private rdbStore: relationalStore.RdbStore | null = null;
  private context: common.Context | null = null;

  private constructor() {}

  /** 获取 DbHelper 单例 */
  static getInstance(): DbHelper {
    if (!DbHelper.instance) {
      DbHelper.instance = new DbHelper();
    }
    return DbHelper.instance;
  }

  /**
   * 初始化：传入应用上下文，以便后续创建 RDB 时使用
   * 应在 EntryAbility.onCreate 中调用
   */
  init(context: common.Context): void {
    this.context = context;
  }

  /**
   * 获取 RDB 存储实例
   * 首次调用会自动建库建表
   */
  async getRdb(): Promise<relationalStore.RdbStore> {
    if (this.rdbStore) {
      return this.rdbStore;
    }
    if (!this.context) {
      throw new Error('DbHelper 尚未初始化，请先调用 init(context)');
    }
    try {
      this.rdbStore = await relationalStore.getRdbStore(this.context, STORE_CONFIG);
      await this.createTables();
      return this.rdbStore;
    } catch (err) {
      throw new Error(`数据库初始化失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 执行建表语句（使用 IF NOT EXISTS 幂等）
   */
  private async createTables(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }
    try {
      await this.rdbStore.executeSql(CREATE_USERS_TABLE);
      await this.rdbStore.executeSql(CREATE_TASKS_TABLE);
      await this.rdbStore.executeSql(CREATE_SESSIONS_TABLE);
    } catch (err) {
      throw new Error(`建表失败: ${JSON.stringify(err)}`);
    }
  }
}
