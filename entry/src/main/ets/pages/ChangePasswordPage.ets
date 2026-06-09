// ===== pages/ChangePasswordPage.ets =====
// 修改密码页面 —— 验证旧密码，设置新密码

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AuthViewModel, AuthResult } from '../viewmodel/AuthViewModel';

@Entry
@Component
struct ChangePasswordPage {
  /** 旧密码 */
  @State oldPassword: string = '';
  /** 新密码 */
  @State newPassword: string = '';
  /** 确认新密码 */
  @State confirmPassword: string = '';
  /** 错误提示 */
  @State errorMsg: string = '';
  /** 按钮 loading 态 */
  @State isLoading: boolean = false;

  private authVM: AuthViewModel = new AuthViewModel();

  build() {
    Column() {
      // ========== 顶部导航栏 ==========
      this.NavBar()

      // ========== 表单区 ==========
      this.FormArea()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  /**
   * 顶部导航栏
   */
  @Builder
  NavBar() {
    Row() {
      Text('← 返回')
        .fontSize(16)
        .fontColor('#FF6347')
        .onClick(() => {
          router.back();
        })

      Text('修改密码')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 占位保持居中
      Text('    ')
        .fontSize(16)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 表单区域
   */
  @Builder
  FormArea() {
    Column() {
      // ---- 提示文字 ----
      Text('请输入旧密码以验证身份，然后设置新密码')
        .fontSize(13)
        .fontColor('#999999')
        .width('100%')
        .padding({ left: 4, bottom: 16 })
        .margin({ top: 16 })

      // ---- 旧密码 ----
      TextInput({ placeholder: '请输入旧密码', text: this.oldPassword })
        .width('100%')
        .height(48)
        .fontSize(16)
        .type(InputType.Password)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.oldPassword = value;
          this.errorMsg = '';
        })

      // ---- 新密码 ----
      TextInput({ placeholder: '请输入新密码（至少6位）', text: this.newPassword })
        .width('100%')
        .height(48)
        .fontSize(16)
        .type(InputType.Password)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .margin({ top: 12 })
        .onChange((value: string) => {
          this.newPassword = value;
          this.errorMsg = '';
        })

      // ---- 确认新密码 ----
      TextInput({ placeholder: '请再次输入新密码', text: this.confirmPassword })
        .width('100%')
        .height(48)
        .fontSize(16)
        .type(InputType.Password)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .margin({ top: 12 })
        .onChange((value: string) => {
          this.confirmPassword = value;
          this.errorMsg = '';
        })

      // ---- 错误提示 ----
      if (this.errorMsg.length > 0) {
        Text(this.errorMsg)
          .fontSize(14)
          .fontColor('#FF4444')
          .width('100%')
          .padding({ left: 4, top: 12 })
      }

      // ---- 确认按钮 ----
      Button('确认修改')
        .width('100%')
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(this.isFormValid() && !this.isLoading ? '#FF6347' : '#CCCCCC')
        .borderRadius(24)
        .margin({ top: 24 })
        .enabled(this.isFormValid() && !this.isLoading)
        .onClick(() => {
          this.handleSubmit();
        })

      // ---- 安全提示 ----
      Text('修改成功后需要重新登录')
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 16 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .layoutWeight(1)
  }

  /**
   * 表单是否有效
   */
  private isFormValid(): boolean {
    return this.oldPassword.length > 0
      && this.newPassword.length > 0
      && this.confirmPassword.length > 0;
  }

  /**
   * 提交修改密码
   */
  private async handleSubmit(): Promise<void> {
    this.errorMsg = '';

    // 前端校验
    if (this.oldPassword.length === 0) {
      this.errorMsg = '请输入旧密码';
      return;
    }
    if (this.newPassword.length < 6) {
      this.errorMsg = '新密码至少需要6位';
      return;
    }
    if (this.oldPassword === this.newPassword) {
      this.errorMsg = '新密码不能与旧密码相同';
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.errorMsg = '两次输入的新密码不一致';
      return;
    }

    this.isLoading = true;

    try {
      const result: AuthResult = await this.authVM.changePassword(
        this.oldPassword,
        this.newPassword
      );

      if (result.ok) {
        promptAction.showToast({ message: result.msg, duration: 2000 });
        // 延迟跳转，让用户看到提示
        setTimeout(() => {
          router.replaceUrl({ url: 'pages/LoginPage' });
        }, 500);
      } else {
        this.errorMsg = result.msg;
        // 旧密码错误时保留已输入的新密码
        if (this.errorMsg !== '旧密码错误') {
          this.oldPassword = '';
        }
      }
    } catch (err) {
      this.errorMsg = `操作失败: ${JSON.stringify(err)}`;
    } finally {
      this.isLoading = false;
    }
  }
}
