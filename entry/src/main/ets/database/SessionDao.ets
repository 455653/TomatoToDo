// ===== database/SessionDao.ets =====
// 番茄钟会话数据访问对象

import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { Session } from '../model/SessionModel';

/**
 * 创建会话的参数（不含 id）
 */
export interface CreateSessionParams {
  userId: number;
  taskId: number;
  startTime: number;
  endTime: number;
  durationSeconds: number;
  interruptions: number;
  completed: number;
}

/**
 * SessionDao —— 封装 sessions 表的读写
 */
export class SessionDao {

  /**
   * 插入一条会话记录
   * @returns 新插入记录的自增 ID
   */
  async insert(session: CreateSessionParams): Promise<number> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'user_id': session.userId,
        'task_id': session.taskId,
        'start_time': session.startTime,
        'end_time': session.endTime,
        'duration_seconds': session.durationSeconds,
        'interruptions': session.interruptions,
        'completed': session.completed,
      };
      const rowId: number = await store.insert('sessions', valueBucket);
      return rowId;
    } catch (err) {
      throw new Error(`会话插入失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询用户会话（可选时间起点）
   * @param userId 用户 ID
   * @param fromTime 起始时间戳，默认 0 查全部
   */
  async findByUser(userId: number, fromTime?: number): Promise<Session[]> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const from = fromTime ?? 0;
      const sql = 'SELECT * FROM sessions WHERE user_id = ? AND start_time >= ? ORDER BY start_time DESC';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [userId.toString(), from.toString()]);

      const sessions: Session[] = [];
      while (resultSet.goToNextRow()) {
        sessions.push(this.rowToSession(resultSet));
      }
      resultSet.close();
      return sessions;
    } catch (err) {
      throw new Error(`会话查询失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询用户今日会话（今日 00:00 到现在）
   */
  async findTodayByUser(userId: number): Promise<Session[]> {
    try {
      const todayStart = this.getTodayStartMs();
      return await this.findByUser(userId, todayStart);
    } catch (err) {
      throw new Error(`今日会话查询失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 统计某时间之后的总专注时长（秒）
   */
  async sumDurationByUser(userId: number, fromTime: number): Promise<number> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const sql = 'SELECT SUM(duration_seconds) AS total FROM sessions WHERE user_id = ? AND start_time >= ? AND completed = 1';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [userId.toString(), fromTime.toString()]);

      let total = 0;
      if (resultSet.goToFirstRow()) {
        total = resultSet.getLong(resultSet.getColumnIndex('total'));
      }
      resultSet.close();
      return total;
    } catch (err) {
      throw new Error(`时长统计失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 统计指定任务的总专注时长（秒），仅统计已完成的会话
   */
  async sumDurationByTaskId(taskId: number): Promise<number> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const sql = 'SELECT SUM(duration_seconds) AS total FROM sessions WHERE task_id = ? AND completed = 1';
      const rs: relationalStore.ResultSet = await store.querySql(sql, [taskId.toString()]);
      let total = 0;
      if (rs.goToFirstRow()) {
        total = rs.getLong(rs.getColumnIndex('total'));
      }
      rs.close();
      return total;
    } catch (err) {
      throw new Error(`统计任务时长失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 计算今日 00:00:00 的时间戳（毫秒）
   */
  private getTodayStartMs(): number {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    return now.getTime();
  }

  /**
   * ResultSet 当前行 → Session 对象
   */
  private rowToSession(rs: relationalStore.ResultSet): Session {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      userId: rs.getLong(rs.getColumnIndex('user_id')),
      taskId: rs.getLong(rs.getColumnIndex('task_id')),
      startTime: rs.getLong(rs.getColumnIndex('start_time')),
      endTime: rs.getLong(rs.getColumnIndex('end_time')),
      durationSeconds: rs.getLong(rs.getColumnIndex('duration_seconds')),
      interruptions: rs.getLong(rs.getColumnIndex('interruptions')),
      completed: rs.getLong(rs.getColumnIndex('completed')),
    };
  }
}
