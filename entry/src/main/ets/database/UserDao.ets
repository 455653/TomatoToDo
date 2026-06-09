// ===== database/UserDao.ets =====
// 用户表数据访问对象

import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { User } from '../model/UserModel';

/**
 * UserDao —— 封装 users 表的增删改查
 */
export class UserDao {

  /**
   * 插入一条用户记录
   * @param username 用户名
   * @param passwordHash SHA-256 哈希后的密码
   * @returns 新插入记录的自增 ID
   */
  async insert(username: string, passwordHash: string): Promise<number> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'username': username,
        'password_hash': passwordHash,
        'created_at': Date.now(),
      };
      const rowId: number = await store.insert('users', valueBucket);
      return rowId;
    } catch (err) {
      throw new Error(`用户插入失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 根据用户名查找用户
   * @param username 用户名
   * @returns 找到的用户对象，不存在则返回 null
   */
  async findByUsername(username: string): Promise<User | null> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      // 使用 RdbPredicates 构建查询条件
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('users');
      predicates.equalTo('username', username);
      const resultSet: relationalStore.ResultSet = await store.query(predicates);

      let user: User | null = null;
      if (resultSet.goToFirstRow()) {
        user = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          username: resultSet.getString(resultSet.getColumnIndex('username')),
          passwordHash: resultSet.getString(resultSet.getColumnIndex('password_hash')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
        };
      }
      resultSet.close();
      return user;
    } catch (err) {
      throw new Error(`用户查询失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 根据用户 ID 查找用户
   * @param id 用户 ID
   * @returns 找到的用户对象，不存在则返回 null
   */
  async findById(id: number): Promise<User | null> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('users');
      predicates.equalTo('id', id);
      const resultSet: relationalStore.ResultSet = await store.query(predicates);

      let user: User | null = null;
      if (resultSet.goToFirstRow()) {
        user = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          username: resultSet.getString(resultSet.getColumnIndex('username')),
          passwordHash: resultSet.getString(resultSet.getColumnIndex('password_hash')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
        };
      }
      resultSet.close();
      return user;
    } catch (err) {
      throw new Error(`用户查询失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 更新用户密码哈希
   * @param id 用户 ID
   * @param newPasswordHash 新的 SHA-256 密码哈希
   */
  async updatePassword(id: number, newPasswordHash: string): Promise<boolean> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'password_hash': newPasswordHash,
      };
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('users');
      predicates.equalTo('id', id);
      const rowsAffected: number = await store.update(valueBucket, predicates);
      return rowsAffected > 0;
    } catch (err) {
      throw new Error(`密码更新失败: ${JSON.stringify(err)}`);
    }
  }
}
