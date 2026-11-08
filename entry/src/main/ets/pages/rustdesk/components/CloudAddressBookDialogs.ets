import { LuminousButton, LuminousControlSize, LuminousTextField, LuminousTone } from 'luminous_neo';

@ComponentV2
export struct CloudPeerEditorDialog {
  @Param visible: boolean = false;
  @Param isNew: boolean = true;
  @Param initialPeerId: string = '';
  @Param initialAlias: string = '';
  @Param initialTags: string = '';
  @Param inFlight: boolean = false;
  @Param errorText: string = '';
  @Local peerId: string = '';
  @Local alias: string = '';
  @Local tagsText: string = '';
  @Local localError: string = '';
  @Local viewportWidth: number = 390;
  @Event onSave: (id: string, alias: string, tags: string[]) => void = (_id: string, _alias: string, _tags: string[]): void => {};
  @Event onCancel: () => void = (): void => {};

  aboutToAppear(): void {
    this.peerId = this.initialPeerId;
    this.alias = this.initialAlias;
    this.tagsText = this.initialTags;
  }

  @Monitor('initialPeerId', 'initialAlias', 'initialTags')
  private onInitChanged(_monitor: IMonitor): void {
    this.peerId = this.initialPeerId;
    this.alias = this.initialAlias;
    this.tagsText = this.initialTags;
    this.localError = '';
  }

  private panelWidth(): number {
    return Math.max(280, Math.min(480, this.viewportWidth - 32));
  }

  private fieldWidth(): number {
    return Math.max(200, this.panelWidth() - 48);
  }

  private handleSave(): void {
    const trimmedId = this.peerId.trim();
    if (trimmedId.length === 0) {
      this.localError = '设备 ID 不能为空';
      return;
    }
    const tags = this.tagsText
      .split(/[,，]/)
      .map((t: string): string => t.trim())
      .filter((t: string): boolean => t.length > 0);
    this.localError = '';
    this.onSave(trimmedId, this.alias.trim(), tags);
  }

  build() {
    if (this.visible) {
      Stack() {
        Column({ space: 16 }) {
          Text(this.isNew ? '添加云端设备' : '编辑云端设备')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.neu_text_primary'));

          Column({ space: 6 }) {
            Text('RustDesk ID (设备标识)')
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.neu_text_secondary'));
            LuminousTextField({
              value: this.peerId,
              placeholder: '例如 123456789',
              fieldWidth: this.fieldWidth(),
              fieldHeight: 48,
              isEnabled: this.isNew && !this.inFlight,
              motionEnabled: true,
              onChange: (val: string): void => {
                this.peerId = val;
              },
            });
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          Column({ space: 6 }) {
            Text('设备别名')
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.neu_text_secondary'));
            LuminousTextField({
              value: this.alias,
              placeholder: '可选显示名称',
              fieldWidth: this.fieldWidth(),
              fieldHeight: 48,
              isEnabled: !this.inFlight,
              motionEnabled: true,
              onChange: (val: string): void => {
                this.alias = val;
              },
            });
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          Column({ space: 6 }) {
            Text('设备标签 (用逗号分隔)')
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.neu_text_secondary'));
            LuminousTextField({
              value: this.tagsText,
              placeholder: '如 办公, 服务器',
              fieldWidth: this.fieldWidth(),
              fieldHeight: 48,
              isEnabled: !this.inFlight,
              motionEnabled: true,
              onChange: (val: string): void => {
                this.tagsText = val;
              },
            });
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          if (this.localError.length > 0 || this.errorText.length > 0) {
            Text(this.localError.length > 0 ? this.localError : this.errorText)
              .fontSize(12)
              .fontColor($r('app.color.error'));
          }

          Row({ space: 12 }) {
            Button('取消', { type: ButtonType.Normal })
              .layoutWeight(1)
              .height(44)
              .borderRadius(12)
              .backgroundColor($r('app.color.surface_secondary'))
              .fontColor($r('app.color.neu_text_primary'))
              .onClick((): void => this.onCancel());

            Button(this.inFlight ? '保存中…' : '保存', { type: ButtonType.Normal })
              .layoutWeight(1)
              .height(44)
              .borderRadius(12)
              .backgroundColor($r('app.color.brand_primary'))
              .fontColor(Color.White)
              .enabled(!this.inFlight)
              .onClick((): void => this.handleSave());
          }
          .width('100%');
        }
        .width(this.panelWidth())
        .padding(24)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(20)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
      .backgroundColor($r('app.color.overlay'))
      .zIndex(100)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.viewportWidth = Number(newArea.width);
      });
    }
  }
}

@ComponentV2
export struct CloudPeerDeleteDialog {
  @Param visible: boolean = false;
  @Param peerId: string = '';
  @Param inFlight: boolean = false;
  @Local viewportWidth: number = 390;
  @Event onConfirm: () => void = (): void => {};
  @Event onCancel: () => void = (): void => {};

  private panelWidth(): number {
    return Math.max(260, Math.min(420, this.viewportWidth - 40));
  }

  build() {
    if (this.visible) {
      Stack() {
        Column({ space: 16 }) {
          Text('删除云端设备')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.neu_text_primary'));

          Text(`确定要从云端通讯录中删除设备 ${this.peerId} 吗？此操作将同步至服务器。`)
            .fontSize(14)
            .lineHeight(20)
            .fontColor($r('app.color.neu_text_secondary'));

          Row({ space: 12 }) {
            Button('取消', { type: ButtonType.Normal })
              .layoutWeight(1)
              .height(44)
              .borderRadius(12)
              .backgroundColor($r('app.color.surface_secondary'))
              .fontColor($r('app.color.neu_text_primary'))
              .onClick((): void => this.onCancel());

            Button(this.inFlight ? '正在删除…' : '确认删除', { type: ButtonType.Normal })
              .layoutWeight(1)
              .height(44)
              .borderRadius(12)
              .backgroundColor($r('app.color.error'))
              .fontColor(Color.White)
              .enabled(!this.inFlight)
              .onClick((): void => this.onConfirm());
          }
          .width('100%');
        }
        .width(this.panelWidth())
        .padding(24)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(20)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
      .backgroundColor($r('app.color.overlay'))
      .zIndex(100)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.viewportWidth = Number(newArea.width);
      });
    }
  }
}

@ComponentV2
export struct CloudTagsDialog {
  @Param visible: boolean = false;
  @Param tags: string[] = [];
  @Param inFlight: boolean = false;
  @Local newTagInput: string = '';
  @Local renamingTag: string = '';
  @Local renamingNewInput: string = '';
  @Local viewportWidth: number = 390;
  @Event onAddTag: (name: string) => void = (_name: string): void => {};
  @Event onRenameTag: (oldName: string, newName: string) => void = (_old: string, _new: string): void => {};
  @Event onDeleteTag: (name: string) => void = (_name: string): void => {};
  @Event onClose: () => void = (): void => {};

  private panelWidth(): number {
    return Math.max(280, Math.min(500, this.viewportWidth - 32));
  }

  private handleAdd(): void {
    const name = this.newTagInput.trim();
    if (name.length > 0) {
      this.onAddTag(name);
      this.newTagInput = '';
    }
  }

  private handleRename(): void {
    const oldName = this.renamingTag.trim();
    const newName = this.renamingNewInput.trim();
    if (oldName.length > 0 && newName.length > 0 && oldName !== newName) {
      this.onRenameTag(oldName, newName);
      this.renamingTag = '';
      this.renamingNewInput = '';
    }
  }

  build() {
    if (this.visible) {
      Stack() {
        Column({ space: 16 }) {
          Row() {
            Text('云端标签管理')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));
            Blank();
            Button('完成', { type: ButtonType.Normal })
              .fontSize(13)
              .height(32)
              .borderRadius(8)
              .backgroundColor($r('app.color.surface_secondary'))
              .fontColor($r('app.color.neu_accent'))
              .onClick((): void => this.onClose());
          }
          .width('100%');

          // Add new tag row
          Row({ space: 8 }) {
            TextInput({ text: this.newTagInput, placeholder: '输入新标签名称' })
              .layoutWeight(1)
              .height(40)
              .borderRadius(8)
              .onChange((val: string): void => {
                this.newTagInput = val;
              });
            Button('添加', { type: ButtonType.Normal })
              .height(40)
              .borderRadius(8)
              .enabled(!this.inFlight && this.newTagInput.trim().length > 0)
              .onClick((): void => this.handleAdd());
          }
          .width('100%');

          // Renaming box if active
          if (this.renamingTag.length > 0) {
            Column({ space: 8 }) {
              Text(`重命名标签：${this.renamingTag}`)
                .fontSize(12)
                .fontColor($r('app.color.neu_text_secondary'));
              Row({ space: 8 }) {
                TextInput({ text: this.renamingNewInput, placeholder: '输入新名称' })
                  .layoutWeight(1)
                  .height(36)
                  .borderRadius(8)
                  .onChange((val: string): void => {
                    this.renamingNewInput = val;
                  });
                Button('确认', { type: ButtonType.Normal })
                  .height(36)
                  .borderRadius(8)
                  .enabled(!this.inFlight && this.renamingNewInput.trim().length > 0)
                  .onClick((): void => this.handleRename());
                Button('取消', { type: ButtonType.Normal })
                  .height(36)
                  .borderRadius(8)
                  .backgroundColor($r('app.color.surface_secondary'))
                  .onClick((): void => {
                    this.renamingTag = '';
                    this.renamingNewInput = '';
                  });
              }
              .width('100%');
            }
            .width('100%')
            .padding(10)
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(8);
          }

          // Existing tags list
          Text('现有标签：')
            .fontSize(12)
            .fontColor($r('app.color.neu_text_secondary'));

          List({ space: 8 }) {
            ForEach(this.tags, (tag: string) => {
              ListItem() {
                Row() {
                  Text(tag)
                    .fontSize(14)
                    .fontColor($r('app.color.neu_text_primary'));
                  Blank();
                  Row({ space: 8 }) {
                    Button('改名', { type: ButtonType.Normal })
                      .fontSize(11)
                      .height(28)
                      .borderRadius(6)
                      .backgroundColor($r('app.color.surface_secondary'))
                      .fontColor($r('app.color.neu_text_primary'))
                      .onClick((): void => {
                        this.renamingTag = tag;
                        this.renamingNewInput = tag;
                      });
                    Button('删除', { type: ButtonType.Normal })
                      .fontSize(11)
                      .height(28)
                      .borderRadius(6)
                      .backgroundColor($r('app.color.error_soft'))
                      .fontColor($r('app.color.error'))
                      .onClick((): void => this.onDeleteTag(tag));
                  }
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .backgroundColor($r('app.color.surface_secondary'))
                .borderRadius(8);
              }
            }, (tag: string) => tag)
          }
          .width('100%')
          .constraintSize({ maxHeight: 240 })
          .scrollBar(BarState.Auto);
        }
        .width(this.panelWidth())
        .padding(24)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(20)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
      .backgroundColor($r('app.color.overlay'))
      .zIndex(100)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.viewportWidth = Number(newArea.width);
      });
    }
  }
}
