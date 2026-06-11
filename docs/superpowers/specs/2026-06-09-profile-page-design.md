# "我的" 页面功能设计

**日期:** 2026-06-09
**范围:** 将"我的" Tab 从占位符改为功能完善的个人中心页面

## 1. 功能概述

实现两个核心功能：
1. **修改密码** — 验证旧密码 → 输入新密码 → 确认新密码 → 修改成功自动退出到登录页
2. **退出登录** — 清除登录态，跳转到登录/注册页

## 2. 界面布局

### 2.1 "我的"主页面

- **用户信息卡片**（顶部）：显示用户头像图标 + 当前用户名 + "已登录"状态
- **功能列表**（卡片式）：
  - 修改密码入口（🔑 图标 + 说明文字 + 右箭头）
  - 退出登录入口（🚪 图标 + 说明文字 + 右箭头）

### 2.2 修改密码页面

独立页面（`router.pushUrl` 跳转），包含三个输入框和确认按钮：
- 旧密码输入框（密码类型）
- 新密码输入框（密码类型）
- 确认新密码输入框（密码类型）
- "确认修改"按钮
- 错误提示文字区域

## 3. 数据流

### 3.1 修改密码

```
用户输入旧密码 + 新密码 + 确认新密码
  → 前端校验（新密码 >= 6位，两次一致，新旧不同）
  → AuthViewModel.changePassword(oldPwd, newPwd)
    → UserDao.findByUsername(username) 获取用户
    → SHA-256(oldPwd) 与存储哈希比对
    → 不匹配 → 返回 {ok: false, msg: "旧密码错误"}
    → 匹配 → UserDao.updatePassword(id, SHA-256(newPwd))
  → 成功 → AuthGuard.logout() → router.replaceUrl → LoginPage
```

### 3.2 退出登录

```
用户点击"退出登录"
  → 弹出确认对话框
  → 确认 → AuthGuard.logout()
  → router.replaceUrl({ url: 'pages/LoginPage' })
```

## 4. 涉及文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `pages/ProfilePage.ets` | 新建 | "我的"页面主体 |
| `pages/ChangePasswordPage.ets` | 新建 | 修改密码页面 |
| `viewmodel/AuthViewModel.ets` | 修改 | 新增 `changePassword()` 方法 |
| `pages/Index.ets` | 修改 | 将 SettingsPlaceholder 替换为 ProfilePage |

## 5. 错误处理

| 场景 | 处理方式 |
|------|----------|
| 旧密码错误 | 保留已输入的新密码，显示错误提示 |
| 两次新密码不一致 | 实时提示（失焦时检查 + 提交时检查） |
| 新密码与旧密码相同 | 提示"新密码不能与旧密码相同" |
| 新密码不足6位 | 提示"密码至少需要6位" |
| 数据库异常 | 捕获并显示友好提示 |
| 所有输入框为空 | 按钮 disabled |

## 6. 边界情况

- Loading 态：点击确认后按钮变为 loading，防止重复提交
- 修改成功后：Toast 提示"密码修改成功，请重新登录"，0.5s 后跳转登录页
- 退出登录：AlertDialog 确认，防止误触
- ProfilePage 在 aboutToAppear 时获取当前用户名显示
