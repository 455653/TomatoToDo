// ===== database/DailyTaskLogDao.ets =====
// 每日打卡记录数据访问对象

import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { DailyTaskLog } from '../model/DailyTaskLogModel';

export interface CreateDailyLogParams {
  taskId: number;
  userId: number;
  logDate: string;     // 'YYYY-MM-DD'
  completedAt: number;
}

export class DailyTaskLogDao {

  /**
   * 插入今日打卡记录，返回自增ID
   */
  async insert(params: CreateDailyLogParams): Promise<number> {
    try {
      const store = await DbHelper.getInstance().getRdb();
      const bucket: relationalStore.ValuesBucket = {
        'task_id': params.taskId,
        'user_id': params.userId,
        'log_date': params.logDate,
        'completed_at': params.completedAt,
      };
      return await store.insert('daily_task_log', bucket);
    } catch (err) {
      throw new Error(`打卡记录插入失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询用户某日所有已打卡的任务ID列表
   */
  async findCompletedTaskIdsByDate(userId: number, dateStr: string): Promise<number[]> {
    try {
      const store = await DbHelper.getInstance().getRdb();
      const sql = `SELECT task_id FROM daily_task_log WHERE user_id = ? AND log_date = ?`;
      const rs = await store.querySql(sql, [userId.toString(), dateStr]);
      const ids: number[] = [];
      while (rs.goToNextRow()) {
        ids.push(rs.getLong(rs.getColumnIndex('task_id')));
      }
      rs.close();
      return ids;
    } catch (err) {
      throw new Error(`查询打卡记录失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 删除指定任务在指定日期的打卡记录（取消打卡）
   */
  async deleteByTaskAndDate(taskId: number, dateStr: string): Promise<void> {
    try {
      const store = await DbHelper.getInstance().getRdb();
      const predicates = new relationalStore.RdbPredicates('daily_task_log');
      predicates.equalTo('task_id', taskId);
      predicates.equalTo('log_date', dateStr);
      await store.delete(predicates);
    } catch (err) {
      throw new Error(`删除打卡记录失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 删除指定任务的所有打卡记录（任务被删除时调用）
   */
  async deleteAllByTaskId(taskId: number): Promise<void> {
    try {
      const store = await DbHelper.getInstance().getRdb();
      const predicates = new relationalStore.RdbPredicates('daily_task_log');
      predicates.equalTo('task_id', taskId);
      await store.delete(predicates);
    } catch (err) {
      throw new Error(`删除任务打卡记录失败: ${JSON.stringify(err)}`);
    }
  }
}
