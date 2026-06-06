// ===== database/CollectionDao.ets =====
// 任务合集表数据访问对象

import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { Collection } from '../model/CollectionModel';

/**
 * 创建合集的参数（不含 id）
 */
export interface CreateCollectionParams {
  userId: number;
  name: string;
  color: string;
  createdAt: number;
}

/**
 * CollectionDao —— 封装 collections 表的增删改查
 */
export class CollectionDao {

  /**
   * 插入一条合集记录
   * @returns 新插入记录的自增 ID
   */
  async insert(params: CreateCollectionParams): Promise<number> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'user_id': params.userId,
        'name': params.name,
        'color': params.color,
        'created_at': params.createdAt,
      };
      const rowId: number = await store.insert('collections', valueBucket);
      return rowId;
    } catch (err) {
      throw new Error(`合集插入失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询某用户的所有合集，按创建时间降序排列
   */
  async findAllByUser(userId: number): Promise<Collection[]> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const sql = 'SELECT * FROM collections WHERE user_id = ? ORDER BY created_at DESC';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [userId.toString()]);

      const collections: Collection[] = [];
      while (resultSet.goToNextRow()) {
        collections.push(this.rowToCollection(resultSet));
      }
      resultSet.close();
      return collections;
    } catch (err) {
      throw new Error(`合集查询失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 更新合集（名称、颜色）
   */
  async update(collection: Collection): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'name': collection.name,
        'color': collection.color,
      };
      const predicates = new relationalStore.RdbPredicates('collections');
      predicates.equalTo('id', collection.id);
      await store.update(valueBucket, predicates);
    } catch (err) {
      throw new Error(`合集更新失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 删除合集，同时将该合集下所有任务的 collectionId 置为 0（未分类）
   */
  async deleteById(id: number): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      // 将该合集下所有任务的 collection_id 置为 0
      const valueBucket: relationalStore.ValuesBucket = {
        'collection_id': 0,
      };
      const predicates = new relationalStore.RdbPredicates('tasks');
      predicates.equalTo('collection_id', id);
      await store.update(valueBucket, predicates);
      // 删除合集
      const collectionPredicates = new relationalStore.RdbPredicates('collections');
      collectionPredicates.equalTo('id', id);
      await store.delete(collectionPredicates);
    } catch (err) {
      throw new Error(`合集删除失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 检查合集名称是否已存在（同用户下不允许重名）
   * @returns 存在则返回 true
   */
  async isNameExists(userId: number, name: string, excludeId?: number): Promise<boolean> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      let sql = 'SELECT COUNT(*) as cnt FROM collections WHERE user_id = ? AND name = ?';
      const params: string[] = [userId.toString(), name];
      if (excludeId !== undefined) {
        sql += ' AND id != ?';
        params.push(excludeId.toString());
      }
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, params);
      let exists = false;
      if (resultSet.goToNextRow()) {
        exists = resultSet.getLong(resultSet.getColumnIndex('cnt')) > 0;
      }
      resultSet.close();
      return exists;
    } catch (err) {
      throw new Error(`合集重名检查失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 将 ResultSet 当前行转为 Collection 对象
   */
  private rowToCollection(rs: relationalStore.ResultSet): Collection {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      userId: rs.getLong(rs.getColumnIndex('user_id')),
      name: rs.getString(rs.getColumnIndex('name')),
      color: rs.getString(rs.getColumnIndex('color')),
      createdAt: rs.getLong(rs.getColumnIndex('created_at')),
    };
  }
}
