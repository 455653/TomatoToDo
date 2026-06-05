// ===== database/TaskDao.ets =====
// 任务表数据访问对象

import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { Task } from '../model/TaskModel';

/**
 * 创建任务的参数（不含 id）
 */
export interface CreateTaskParams {
  userId: number;
  title: string;
  estimatedPomodoros: number;
  done: boolean;
  priority: number;
  createdAt: number;
}

/**
 * TaskDao —— 封装 tasks 表的增删改查
 */
export class TaskDao {

  /**
   * 插入一条任务记录
   * @returns 新插入记录的自增 ID
   */
  async insert(task: CreateTaskParams): Promise<number> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'user_id': task.userId,
        'title': task.title,
        'estimated_pomodoros': task.estimatedPomodoros,
        'done': task.done ? 1 : 0,
        'priority': task.priority,
        'created_at': task.createdAt,
      };
      const rowId: number = await store.insert('tasks', valueBucket);
      return rowId;
    } catch (err) {
      throw new Error(`任务插入失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询某用户的所有任务，按优先级降序、创建时间降序排列
   */
  async findAllByUser(userId: number): Promise<Task[]> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const sql = 'SELECT * FROM tasks WHERE user_id = ? ORDER BY priority DESC, created_at DESC';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [userId.toString()]);

      const tasks: Task[] = [];
      while (resultSet.goToNextRow()) {
        tasks.push(this.rowToTask(resultSet));
      }
      resultSet.close();
      return tasks;
    } catch (err) {
      throw new Error(`任务查询失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 更新一条任务的全部字段（按 id 匹配）
   */
  async update(task: Task): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'title': task.title,
        'estimated_pomodoros': task.estimatedPomodoros,
        'done': task.done ? 1 : 0,
        'priority': task.priority,
        'created_at': task.createdAt,
      };
      const predicates = new relationalStore.RdbPredicates('tasks');
      predicates.equalTo('id', task.id);
      await store.update(valueBucket, predicates);
    } catch (err) {
      throw new Error(`任务更新失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 按 ID 删除任务
   */
  async deleteById(id: number): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const predicates = new relationalStore.RdbPredicates('tasks');
      predicates.equalTo('id', id);
      await store.delete(predicates);
    } catch (err) {
      throw new Error(`任务删除失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 更新任务的完成状态
   */
  async markDone(id: number, done: boolean): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'done': done ? 1 : 0,
      };
      const predicates = new relationalStore.RdbPredicates('tasks');
      predicates.equalTo('id', id);
      await store.update(valueBucket, predicates);
    } catch (err) {
      throw new Error(`任务状态更新失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 将 ResultSet 当前行转为 Task 对象（done INTEGER → boolean）
   */
  private rowToTask(rs: relationalStore.ResultSet): Task {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      userId: rs.getLong(rs.getColumnIndex('user_id')),
      title: rs.getString(rs.getColumnIndex('title')),
      estimatedPomodoros: rs.getLong(rs.getColumnIndex('estimated_pomodoros')),
      done: rs.getLong(rs.getColumnIndex('done')) === 1,
      priority: rs.getLong(rs.getColumnIndex('priority')),
      createdAt: rs.getLong(rs.getColumnIndex('created_at')),
    };
  }
}
