import { LocalFileEntry, RemoteFileEntry, TransferItem } from '../RustDeskSessionTypes';
import { RemoteFilePath } from '../RemoteFilePath';
import { FloatingDepthOverlay } from './FloatingDepth';
import { FloatingActionSurface, FloatingGlassSurface } from './FloatingSurface';

type TransferPrimaryPane = 'local' | 'remote';

export interface TransferDrawerProps {
  scroller: Scroller;
  titleSpacerHeight: number;
  downloadRootPath: string;
  rootStatus: string;
  sessionReady: boolean;
  sessionStatus: string;
  localEntries: LocalFileEntry[];
  remoteDirectory: string;
  remoteEntries: RemoteFileEntry[];
  selectedLocalName: string;
  selectedRemoteName: string;
  transfers: TransferItem[];
  bottomAvoidInset: number;
  onSelectLocal: (name: string) => void;
  onSelectRemote: (name: string) => void;
  onUpload: () => void;
  onDownload: () => void;
  onOpenRemoteDirectory: (name: string) => void;
  onRemoteBack: () => void;
  onResolveOverride: (id: number, needOverride: boolean) => void;
  onCancel: (id: number) => void;
  onClose: () => void;
}

@ComponentV2
export struct TransferDrawer {
  @Param scroller: Scroller = new Scroller();
  @Param titleSpacerHeight: number = 0;
  @Param downloadRootPath: string = '';
  @Param rootStatus: string = '';
  @Param sessionReady: boolean = false;
  @Param sessionStatus: string = '正在连接';
  @Param localEntries: LocalFileEntry[] = [];
  @Param remoteDirectory: string = '/';
  @Param remoteEntries: RemoteFileEntry[] = [];
  @Param selectedLocalName: string = '';
  @Param selectedRemoteName: string = '';
  @Param transfers: TransferItem[] = [];
  @Param bottomAvoidInset: number = 0;
  @Local viewportWidth: number = 390;
  @Local compactLayout: boolean = true;
  @Local primaryPane: TransferPrimaryPane = 'remote';
  @Event onSelectLocal: (name: string) => void = (_name: string) => {};
  @Event onSelectRemote: (name: string) => void = (_name: string) => {};
  @Event onUpload: () => void = () => {};
  @Event onDownload: () => void = () => {};
  @Event onOpenRemoteDirectory: (name: string) => void = (_name: string) => {};
  @Event onRemoteBack: () => void = () => {};
  @Event onResolveOverride: (id: number, needOverride: boolean) => void = (_id: number, _needOverride: boolean) => {};
  @Event onCancel: (id: number) => void = (_id: number) => {};
  @Event onClose: () => void = () => {};

  private formatBytes(value: number): string {
    const size = Math.max(value, 0);
    if (size < 1024) {
      return `${size} B`;
    }
    if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`;
    }
    if (size < 1024 * 1024 * 1024) {
      return `${(size / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${(size / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }

  private isDirectory(entry: RemoteFileEntry): boolean {
    return RemoteFilePath.isDirectoryType(entry.entry_type);
  }

  private entrySize(entry: RemoteFileEntry): string {
    return this.isDirectory(entry) ? '文件夹' : this.formatBytes(entry.size);
  }

  private transferDetail(item: TransferItem): string {
    const transferred = this.formatBytes(item.transferredBytes);
    const total = item.totalBytes > 0 ? this.formatBytes(item.totalBytes) : '未知大小';
    const speed = item.speedBytesPerSecond > 0 ? `${this.formatBytes(item.speedBytesPerSecond)}/秒` : '等待速度';
    return `${this.stateText(item.state)} · ${transferred} / ${total} · ${speed}`;
  }

  private transferProgressValue(item: TransferItem): number {
    if (item.totalBytes <= 0) {
      return 0;
    }
    return Math.min(Math.max(item.transferredBytes, 0), item.totalBytes);
  }

  private stateText(state: string): string {
    if (state === 'queued') {
      return '排队中';
    }
    if (state === 'running') {
      return '传输中';
    }
    if (state === 'awaiting_override') {
      return '等待覆盖确认';
    }
    if (state === 'completed') {
      return '已完成';
    }
    if (state === 'failed') {
      return '失败';
    }
    return '已取消';
  }

  private shouldUseCompactLayout(width: number): boolean {
    return width < 920;
  }

  private paneWidth(): number {
    if (this.compactLayout) {
      return this.viewportWidth;
    }
    return Math.max(1, (this.viewportWidth - 1) / 2);
  }

  private compactPeekWidth(): number {
    return Math.max(40, this.viewportWidth * 0.1);
  }

  private compactPaneContentRightPadding(): number {
    return this.compactLayout
      ? this.compactPeekWidth() + 12
      : 16;
  }

  private localPaneOffset(): number {
    if (!this.compactLayout || this.primaryPane === 'local') {
      return 0;
    }
    return -(this.viewportWidth - this.compactPeekWidth());
  }

  private remotePaneOffset(): number {
    if (!this.compactLayout) {
      return this.paneWidth() + 1;
    }
    return this.primaryPane === 'remote'
      ? this.compactPeekWidth()
      : this.viewportWidth - this.compactPeekWidth();
  }

  private dividerOffset(): number {
    if (!this.compactLayout) {
      return this.paneWidth();
    }
    return this.primaryPane === 'remote'
      ? this.compactPeekWidth()
      : this.viewportWidth - this.compactPeekWidth();
  }

  private transferTrayHeight(): number {
    return 132;
  }

  private switchPrimaryPane(pane: TransferPrimaryPane): void {
    if (!this.compactLayout || this.primaryPane === pane) {
      return;
    }
    this.getUIContext().animateTo({
      duration: 320,
      curve: Curve.FastOutSlowIn,
    }, (): void => {
      this.primaryPane = pane;
    });
  }

  private updateViewportWidth(width: number): void {
    if (width <= 0 || Math.abs(width - this.viewportWidth) < 0.5) {
      return;
    }
    const nextCompactLayout = this.shouldUseCompactLayout(width);
    if (nextCompactLayout === this.compactLayout) {
      this.viewportWidth = width;
      return;
    }
    this.getUIContext().animateTo({
      duration: 300,
      curve: Curve.FastOutSlowIn,
    }, (): void => {
      this.viewportWidth = width;
      this.compactLayout = nextCompactLayout;
    });
  }

  private actionEnabled(key: string): boolean {
    if (key === 'upload') {
      return this.sessionReady && this.selectedLocalName.length > 0;
    }
    if (key === 'download') {
      return this.sessionReady && this.selectedRemoteName.length > 0;
    }
    if (key === 'remote-back') {
      return this.sessionReady;
    }
    return true;
  }

  @Builder
  private FloatingAction(key: string, label: string, emphasized: boolean, onClick: () => void) {
    Stack() {
      FloatingActionSurface({
        actionEnabled: this.actionEnabled(key),
        compact: true,
        stopTouchPropagation: true,
        accessibilityLabel: label,
        onActivate: onClick,
      }) {
        Row() {
          Text(label)
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.actionEnabled(key)
              ? (emphasized ? $r('app.color.neu_accent') : $r('app.color.text_primary'))
              : $r('app.color.disabled_text'));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width(68)
    .height($r('app.float.control_small'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private LocalEntry(entry: LocalFileEntry) {
    Stack() {
      FloatingActionSurface({
        actionEnabled: true,
        compact: true,
        subtleDepth: true,
        stopTouchPropagation: true,
        accessibilityLabel: entry.name,
        onActivate: (): void => this.onSelectLocal(entry.name),
      }) {
        Column({ space: $r('app.float.space_2') }) {
          Text(entry.name)
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedLocalName === entry.name
              ? $r('app.color.brand_primary')
              : $r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(this.formatBytes(entry.size))
            .fontSize($r('app.float.font_label'))
            .fontColor($r('app.color.text_secondary'));
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private RemoteEntry(entry: RemoteFileEntry) {
    Stack() {
      FloatingActionSurface({
        actionEnabled: true,
        compact: true,
        subtleDepth: true,
        stopTouchPropagation: true,
        accessibilityLabel: this.isDirectory(entry) ? `打开文件夹 ${entry.name}` : entry.name,
        onActivate: (): void => {
          if (this.isDirectory(entry)) {
            this.onOpenRemoteDirectory(entry.name);
          } else {
            this.onSelectRemote(entry.name);
          }
        },
      }) {
        Row({ space: $r('app.float.space_8') }) {
          Column({ space: $r('app.float.space_2') }) {
            Text(this.isDirectory(entry) ? `文件夹 · ${entry.name}` : entry.name)
              .width('100%')
              .fontSize($r('app.float.font_body'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedRemoteName === entry.name
                ? $r('app.color.brand_primary')
                : $r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(this.entrySize(entry))
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.text_secondary'));
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
          if (this.isDirectory(entry)) {
            Text('进入')
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.brand_primary'));
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
        .alignItems(VerticalAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private TransferRow(item: TransferItem) {
    Column({ space: $r('app.float.space_6') }) {
      Text(`${item.direction === 'upload' ? '上传' : '下载'} · ${item.fileName}`)
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.transferDetail(item))
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.text_secondary'));
      if (item.state === 'queued' || item.state === 'running') {
        if (item.totalBytes > 0) {
          Progress({
            value: this.transferProgressValue(item),
            total: item.totalBytes,
            type: ProgressType.Linear,
          })
            .width('100%')
            .height(4)
            .color($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_secondary'));
        } else {
          LoadingProgress()
            .width($r('app.float.icon_regular'))
            .height($r('app.float.icon_regular'))
            .color($r('app.color.brand_primary'));
        }
      }
      if (item.errorText.length > 0) {
        Text(item.errorText)
          .fontSize($r('app.float.font_label'))
          .fontColor($r('app.color.error'))
          .maxLines(2);
      }
      if (item.state === 'awaiting_override') {
        Row({ space: $r('app.float.space_8') }) {
          this.FloatingAction(`override-${item.id}`, '覆盖', true,
            () => this.onResolveOverride(item.id, true))
          this.FloatingAction(`skip-${item.id}`, '跳过', false,
            () => this.onResolveOverride(item.id, false))
        }
        .width('100%');
      } else if (item.state === 'queued' || item.state === 'running') {
        this.FloatingAction(`cancel-${item.id}`, '取消', false, () => this.onCancel(item.id))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: $r('app.float.space_12'), bottom: $r('app.float.space_12') })
    .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') });
  }

  @Builder
  private LocalEntriesList() {
    List({ space: 8 }) {
      ForEach(this.localEntries, (entry: LocalFileEntry) => {
        ListItem() {
          this.LocalEntry(entry);
        }
      }, (entry: LocalFileEntry) => entry.path)
      if (this.localEntries.length === 0) {
        ListItem() {
          Text('下载位置中没有可直接上传的文件')
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .padding($r('app.float.space_20'));
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding($r('app.float.space_8'))
    .scrollBar(BarState.Off)
    .alignListItem(ListItemAlign.Start);
  }

  @Builder
  private LocalPaneContent(fillAvailable: boolean) {
    Row({ space: $r('app.float.space_8') }) {
      Column({ space: $r('app.float.space_2') }) {
        Text('本机文件')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        Text(this.rootStatus || 'HarmonyOS 下载目录')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      if (this.compactLayout) {
        this.FloatingAction('show-remote', '远端', false, (): void => this.switchPrimaryPane('remote'))
      }
      this.FloatingAction('upload', '上传', true, () => this.onUpload())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);

    Stack() {
      FloatingGlassSurface({
        compact: true,
        inset: true,
        radius: $r('app.float.radius_10'),
        surfaceHeight: 34,
      }) {
        Row() {
          Text(this.downloadRootPath.length > 0 ? this.downloadRootPath : '未选择下载位置')
            .layoutWeight(1)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
          .width('100%')
          .height(34)
          .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
          .alignItems(VerticalAlign.Center);
      }
    }
    .width('100%')
    .height(34)
    .margin({ top: $r('app.float.space_6'), bottom: $r('app.float.space_6') })
    .clip(false);

    Stack({ alignContent: Alignment.TopStart }) {
      FloatingDepthOverlay({
        inset: true,
        radius: $r('app.float.radius_14'),
      });
      this.LocalEntriesList();
    }
    .height(fillAvailable ? 0 : 176)
    .layoutWeight(fillAvailable ? 1 : 0)
    .width('100%')
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private RemoteEntriesList() {
    List({ space: 8 }) {
      ForEach(this.remoteEntries, (entry: RemoteFileEntry) => {
        ListItem() {
          this.RemoteEntry(entry);
        }
      }, (entry: RemoteFileEntry) => `${entry.entry_type}-${entry.name}`)
      if (this.remoteEntries.length === 0) {
        ListItem() {
          Text('远端目录为空或正在加载')
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .padding($r('app.float.space_20'));
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding($r('app.float.space_8'))
    .scrollBar(BarState.Off)
    .alignListItem(ListItemAlign.Start);
  }

  @Builder
  private RemotePaneContent(fillAvailable: boolean) {
    Row({ space: $r('app.float.space_8') }) {
      Column({ space: $r('app.float.space_2') }) {
        Text('远端文件')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        Text(this.sessionStatus)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      if (this.compactLayout) {
        this.FloatingAction('show-local', '本机', false, (): void => this.switchPrimaryPane('local'))
      }
      this.FloatingAction('remote-back', '上级', false, () => this.onRemoteBack())
      this.FloatingAction('download', '下载', true, () => this.onDownload())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);

    Stack() {
      FloatingGlassSurface({
        compact: true,
        inset: true,
        radius: $r('app.float.radius_10'),
        surfaceHeight: 34,
      }) {
        Row() {
          Text(this.remoteDirectory)
            .layoutWeight(1)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
          .width('100%')
          .height(34)
          .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
          .alignItems(VerticalAlign.Center);
      }
    }
    .width('100%')
    .height(34)
    .margin({ top: $r('app.float.space_6'), bottom: $r('app.float.space_6') })
    .clip(false);

    Stack({ alignContent: Alignment.TopStart }) {
      FloatingDepthOverlay({
        inset: true,
        radius: $r('app.float.radius_14'),
      });
      this.RemoteEntriesList();
    }
    .height(fillAvailable ? 0 : 176)
    .layoutWeight(fillAvailable ? 1 : 0)
    .width('100%')
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private TransferRowsContent() {
    Column() {
      ForEach(this.transfers, (item: TransferItem) => {
        this.TransferRow(item);
      }, (item: TransferItem) =>
        `${item.id}-${item.fileNum}-${item.state}-${Math.round(item.transferredBytes)}-${Math.round(item.speedBytesPerSecond)}`)
      if (this.transfers.length === 0) {
        Column({ space: $r('app.float.space_8') }) {
          Text('⇄')
            .fontSize($r('app.float.font_title_large'))
            .fontColor($r('app.color.text_tertiary'));
          Text('暂无传输任务')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'));
        }
        .width('100%')
        .padding({ top: $r('app.float.space_32'), bottom: $r('app.float.space_32') });
      }
    }
    .width('100%');
  }

  @Builder
  private TransferPaneContent(fillAvailable: boolean) {
    Row() {
      Text('传输任务')
        .layoutWeight(1)
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'));
      Text(`${this.transfers.length}`)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_primary'));
    }
    .width('100%')
    .margin({ bottom: $r('app.float.space_8') });

    if (fillAvailable) {
      Scroll() {
        this.TransferRowsContent();
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off);
    } else {
      this.TransferRowsContent();
    }
  }

  @Builder
  private TransferTray() {
    Column() {
      Row({ space: $r('app.float.space_8') }) {
        Text('传输任务')
          .layoutWeight(1)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        Text(this.transfers.length > 0 ? `${this.transfers.length} 项` : '暂无任务')
          .fontSize($r('app.float.font_label'))
          .fontColor(this.transfers.length > 0
            ? $r('app.color.brand_primary')
            : $r('app.color.text_secondary'));
      }
      .width('100%')
      .height(44)
      .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
      .alignItems(VerticalAlign.Center);

      if (this.transfers.length > 0) {
        Scroll() {
          this.TransferRowsContent();
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
        .scrollBar(BarState.Off);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'));
  }

  @Builder
  private LocalWorkspacePane() {
    Column() {
      this.LocalPaneContent(true);
    }
    .width(this.paneWidth())
    .height('100%')
    .padding({
      left: $r('app.float.space_16'),
      right: this.compactPaneContentRightPadding(),
      top: $r('app.float.space_8'),
      bottom: $r('app.float.space_8'),
    })
    .backgroundColor($r('app.color.background'))
    .translate({ x: this.localPaneOffset() })
    .renderGroup(true)
    .animation({ duration: 320, curve: Curve.FastOutSlowIn });
  }

  @Builder
  private RemoteWorkspacePane() {
    Column() {
      this.RemotePaneContent(true);
    }
    .width(this.paneWidth())
    .height('100%')
    .padding({
      left: $r('app.float.space_16'),
      right: this.compactPaneContentRightPadding(),
      top: $r('app.float.space_8'),
      bottom: $r('app.float.space_8'),
    })
    .backgroundColor($r('app.color.background'))
    .translate({ x: this.remotePaneOffset() })
    .renderGroup(true)
    .animation({ duration: 320, curve: Curve.FastOutSlowIn });
  }

  @Builder
  private CompactPaneMask(leftEdge: boolean) {
    Column()
    .width(this.compactPeekWidth())
    .height('100%')
    .backgroundColor($r('app.color.surface_secondary'))
    .border({
      width: leftEdge ? { right: 1 } : { left: 1 },
      color: $r('app.color.divider'),
    })
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no');
  }

  @Builder
  private FileWorkspace() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.LocalWorkspacePane();
      this.RemoteWorkspacePane();

      Column()
        .width(1)
        .height('100%')
        .backgroundColor($r('app.color.divider'))
        .translate({ x: this.dividerOffset() })
        .animation({ duration: 320, curve: Curve.FastOutSlowIn });

      if (this.compactLayout && this.primaryPane === 'remote') {
        this.CompactPaneMask(true);
      } else if (this.compactLayout) {
        Row() {
          this.CompactPaneMask(false);
        }
        .width(this.compactPeekWidth())
        .height('100%')
        .translate({ x: this.viewportWidth - this.compactPeekWidth() });
      }
    }
    .width('100%')
    .height('100%')
    .clip(true);
  }

  build() {
    Column() {
      Blank()
        .width('100%')
        .height(this.titleSpacerHeight)
        .flexShrink(0);

      Column() {
        Stack() {
          this.FileWorkspace();
        }
        .layoutWeight(1)
        .width('100%')
        .clip(true);

        Column()
          .width('100%')
          .height(1)
          .backgroundColor($r('app.color.divider'));

        Column() {
          this.TransferTray();
        }
        .width('100%')
        .height(this.transferTrayHeight())
        .animation({ duration: 260, curve: Curve.FastOutSlowIn });
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ bottom: this.bottomAvoidInset });
    }
    .width('100%')
    .height('100%')
    .layoutWeight(1)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      this.updateViewportWidth(width);
    });
  }
}
