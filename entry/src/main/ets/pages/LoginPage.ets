// ===== pages/LoginPage.ets =====
// 登录 + 注册二合一页面

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AuthViewModel, AuthResult } from '../viewmodel/AuthViewModel';
import { AuthGuard } from '../utils/AuthGuard';
import { common } from '@kit.AbilityKit';

/** Tab 索引：登录 / 注册 */
const TAB_LOGIN = 0;
const TAB_REGISTER = 1;

@Entry
@Component
struct LoginPage {
  /** 当前选中的 Tab */
  @State currentTab: number = TAB_LOGIN;

  /** 用户名输入 */
  @State username: string = '';
  /** 密码输入 */
  @State password: string = '';

  /** 登录/注册按钮 loading 态 */
  @State isLoading: boolean = false;
  /** 错误提示文字 */
  @State errorMsg: string = '';

  /** 认证 ViewModel */
  private authVM: AuthViewModel = new AuthViewModel();

  /**
   * 页面即将出现时，检查是否已登录
   * 若已登录则直接跳转 Index
   */
  async aboutToAppear(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      await AuthGuard.init(context);
      console.log('[LoginPage] AuthGuard 已初始化');
    } catch (err) {
      console.error('[LoginPage] AuthGuard 初始化失败', JSON.stringify(err));
    }
    
    if (AuthGuard.isLoggedIn()) {
      router.replaceUrl({ url: 'pages/Index' });
    }
  }

  build() {
    Column() {
      // ========== Logo 区 ==========
      this.buildLogo()

      // ========== Tab 切换区 ==========
      this.buildTabs()

      // ========== 表单区 ==========
      this.buildForm()

      // ========== 按钮区 ==========
      this.buildButton()

      // ========== 错误提示 ==========
      if (this.errorMsg.length > 0) {
        Text(this.errorMsg)
          .fontSize(14)
          .fontColor('#FF4444')
          .margin({ top: 12 })
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .padding({ left: 32, right: 32 })
    .justifyContent(FlexAlign.Center)
  }

  /**
   * Logo 区域
   */
  @Builder
  buildLogo() {
    Column() {
      Text('🍅 番茄专注')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FF6347')
    }
    .margin({ bottom: 40 })
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * Tab 切换：登录 / 注册
   */
  @Builder
  buildTabs() {
    Row() {
      Text('登录')
        .fontSize(18)
        .fontWeight(this.currentTab === TAB_LOGIN ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === TAB_LOGIN ? '#FF6347' : '#999999')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ bottom: 8 })
        .border({
          width: { bottom: this.currentTab === TAB_LOGIN ? 2 : 0 },
          color: this.currentTab === TAB_LOGIN ? '#FF6347' : Color.Transparent,
        })
        .onClick(() => {
          this.currentTab = TAB_LOGIN;
          this.errorMsg = '';
        })

      Text('注册')
        .fontSize(18)
        .fontWeight(this.currentTab === TAB_REGISTER ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === TAB_REGISTER ? '#FF6347' : '#999999')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ bottom: 8 })
        .border({
          width: { bottom: this.currentTab === TAB_REGISTER ? 2 : 0 },
          color: this.currentTab === TAB_REGISTER ? '#FF6347' : Color.Transparent,
        })
        .onClick(() => {
          this.currentTab = TAB_REGISTER;
          this.errorMsg = '';
        })
    }
    .width('100%')
    .margin({ bottom: 32 })
  }

  /**
   * 表单输入区
   */
  @Builder
  buildForm() {
    Column() {
      // 用户名输入框
      TextInput({ placeholder: '请输入用户名', text: this.username })
        .width('100%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 16 })
        .onChange((value: string) => {
          this.username = value;
          this.errorMsg = '';
        })

      // 密码输入框
      TextInput({ placeholder: '请输入密码', text: this.password })
        .width('100%')
        .height(48)
        .fontSize(16)
        .type(InputType.Password)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 16 })
        .onChange((value: string) => {
          this.password = value;
          this.errorMsg = '';
        })
    }
    .width('100%')
  }

  /**
   * 操作按钮区
   */
  @Builder
  buildButton() {
    Button(this.currentTab === TAB_LOGIN ? '登  录' : '注  册')
      .width('100%')
      .height(48)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .backgroundColor(this.isLoading ? '#CCCCCC' : '#FF6347')
      .borderRadius(24)
      .enabled(!this.isLoading)
      .onClick(() => {
        this.handleSubmit();
      })
  }

  /**
   * 处理提交（登录或注册）
   */
  private async handleSubmit(): Promise<void> {
    this.errorMsg = '';

    // 前端简单校验
    if (this.username.trim().length === 0) {
      this.errorMsg = '请输入用户名';
      return;
    }
    if (this.password.length === 0) {
      this.errorMsg = '请输入密码';
      return;
    }

    this.isLoading = true;

    try {
      let result: AuthResult;

      if (this.currentTab === TAB_LOGIN) {
        result = await this.authVM.login(this.username, this.password);
      } else {
        result = await this.authVM.register(this.username, this.password);
      }

      if (result.ok) {
        promptAction.showToast({ message: result.msg, duration: 1500 });
        if (this.currentTab === TAB_REGISTER) {
          // 注册成功 → 切换到登录 Tab，清空表单
          this.currentTab = TAB_LOGIN;
          this.password = '';
        } else {
          // 登录成功 → 跳转到 Index
          router.replaceUrl({ url: 'pages/Index' });
        }
      } else {
        this.errorMsg = result.msg;
      }
    } catch (err) {
      this.errorMsg = `操作失败: ${JSON.stringify(err)}`;
    } finally {
      this.isLoading = false;
    }
  }
}
