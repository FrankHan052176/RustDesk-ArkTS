import { LuminousSegmentedControl, LuminousSelectionItem, LuminousSwitch, LuminousTextField } from 'luminous_neo';
import { PeerProtocol, PeerRecord } from '../RustDeskDirectoryTypes';
import { copyPeerRecord, peerProtocolOf } from '../RustDeskPeerDirectoryModel';
import { deviceDefaultPort, migrateDeviceRecord, splitDeviceAddress } from '../SavedDeviceModel';
import { checkRdpUser } from '../DirectWireCredentials';

@ComponentV2
struct DeviceEditorTextField {
  @Param label: ResourceStr = '';
  @Param value: string = '';
  @Param fieldWidth: number = 240;
  @Event onChange: (value: string) => void = (_value: string): void => {};

  build(): void {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.neu_text_primary'));
      LuminousTextField({ value: this.value, placeholder: this.label,
        fieldWidth: this.fieldWidth, fieldHeight: 48, motionEnabled: true,
        onChange: (value: string): void => this.onChange(value) })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }
}

@ComponentV2
export struct SavedDeviceEditor {
  @Param peer: PeerRecord = new PeerRecord();
  @Local protocol: PeerProtocol = 'rustdesk';
  @Local address: string = '';
  @Local port: string = '';
  @Local alias: string = '';
  @Local favorite: boolean = false;
  @Local username: string = '';
  @Local errorText: ResourceStr = '';
  @Local viewportWidth: number = 390;
  @Event onSave: (peer: PeerRecord) => ResourceStr =
    (_peer: PeerRecord): ResourceStr => $r('app.string.device_editor_save_unavailable');
  @Event onCancel: () => void = (): void => {};

  aboutToAppear(): void {
    const source = migrateDeviceRecord(this.peer);
    this.protocol = peerProtocolOf(source);
    this.address = source.address;
    this.port = source.port > 0 ? String(source.port) : '';
    this.alias = source.alias;
    this.favorite = source.favorite;
    this.username = source.rdpUsername;
  }

  private panelWidth(): number {
    return Math.max(280, Math.min(520, this.viewportWidth - 32));
  }

  private fieldWidth(): number {
    return Math.max(200, this.panelWidth() - 80);
  }

  private protocolIndex(): number {
    return this.protocol === 'rustdesk' ? 0 : (this.protocol === 'vnc' ? 1 : 2);
  }

  private selectProtocol(index: number): void {
    const next: PeerProtocol = index === 0 ? 'rustdesk' : (index === 1 ? 'vnc' : 'rdp');
    if (this.port.length === 0 || Number(this.port) === deviceDefaultPort(this.protocol, this.address)) {
      const defaultPort = deviceDefaultPort(next, this.address);
      this.port = defaultPort > 0 ? String(defaultPort) : '';
    }
    this.protocol = next;
    this.errorText = '';
  }
  private updateAddress(value: string): void {
    this.address = value;
    const parts = splitDeviceAddress(value, this.protocol);
    if (parts.valid && (/^\[[^\]]+\]:\d+$/.test(value.trim()) || /^[^:]+:\d+$/.test(value.trim()))) {
      this.port = String(parts.port);
    }
  }


  private save(): void {
    const parts = splitDeviceAddress(this.address, this.protocol);
    const port = this.port.trim().length === 0 ? parts.port : Number(this.port);
    if (!parts.valid || !Number.isInteger(port) || port < 0 || port > 65535 ||
      (port === 0 && this.protocol !== 'rustdesk') || !/^\d*$/.test(this.port.trim())) {
      this.errorText = $r('app.string.device_editor_address_error');
      return;
    }
    if (this.protocol === 'rdp' && !checkRdpUser(this.username).ok && this.username.trim().length > 0) {
      this.errorText = $r('app.string.device_editor_rdp_error');
      return;
    }
    const peer = copyPeerRecord(this.peer);
    peer.protocol = this.protocol;
    peer.address = parts.address;
    peer.port = port;
    peer.alias = this.alias.trim();
    peer.favorite = this.favorite;
    peer.rdpUsername = this.protocol === 'rdp' ? this.username.trim() : '';
    // The page fills this projection from the host:port trust store, never a typed pin.
    peer.rdpCertificateSha256 = '';
    if (this.protocol !== peerProtocolOf(this.peer) || parts.address !== this.peer.address) {
      peer.rustdeskIdOnly = false;
    }
    this.errorText = this.onSave(migrateDeviceRecord(peer));
  }


  build(): void {
    Row() {
      Column({ space: 12 }) {
        Text($r('app.string.device_editor_edit'))
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.neu_text_primary'));
        Scroll() {
          Column({ space: 12 }) {
            LuminousSegmentedControl({
              items: [new LuminousSelectionItem('rustdesk', 'RustDesk', ''),
                new LuminousSelectionItem('vnc', 'VNC', ''), new LuminousSelectionItem('rdp', 'RDP', '')],
              selectedIndex: this.protocolIndex(), controlWidth: this.fieldWidth(), controlHeight: 48,
              motionEnabled: true,
              onChange: (index: number): void => this.selectProtocol(index),
            })
            DeviceEditorTextField({ label: $r('app.string.device_editor_name'), value: this.alias, fieldWidth: this.fieldWidth(),
              onChange: (value: string): void => { this.alias = value; } })
            DeviceEditorTextField({ label: $r('app.string.device_editor_address'), value: this.address, fieldWidth: this.fieldWidth(),
              onChange: (value: string): void => this.updateAddress(value) })
            DeviceEditorTextField({ label: $r('app.string.device_editor_port'), value: this.port, fieldWidth: this.fieldWidth(),
              onChange: (value: string): void => { this.port = value; } })
            LuminousSwitch({ label: $r('app.string.device_editor_favorite'), description: '', isOn: this.favorite,
              rowWidth: this.fieldWidth(), motionEnabled: true,
              onChange: (value: boolean): void => { this.favorite = value; } })
            if (this.protocol === 'rdp') {
              DeviceEditorTextField({ label: $r('app.string.device_editor_username'), value: this.username, fieldWidth: this.fieldWidth(),
                onChange: (value: string): void => { this.username = value; } })
            }
            Text($r('app.string.device_editor_no_password'))
              .fontSize($r('app.float.font_caption'))
              .lineHeight(18)
              .fontColor($r('app.color.neu_text_secondary'));
            if (this.errorText !== '') {
              Text(this.errorText)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.error'));
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center);
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);
        Row({ space: 12 }) {
          Button($r('app.string.device_note_cancel')).height(44).layoutWeight(1).onClick(this.onCancel)
          Button($r('app.string.device_note_save')).height(44).layoutWeight(1).onClick((): void => this.save())
        }
        .width('100%');
      }
      .width(this.panelWidth())
      .height('85%')
      .constraintSize({ maxHeight: 720 })
      .padding(24)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(24)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.overlay'))
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.viewportWidth = Number(newArea.width);
    });
  }
}
