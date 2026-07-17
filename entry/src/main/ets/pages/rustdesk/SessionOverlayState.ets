export type SessionOverlayPanel =
  'home' | 'chat' | 'display' | 'quality';

export class SessionOverlayState {
  private activePanel: SessionOverlayPanel = 'home';

  public open(panel: SessionOverlayPanel): boolean {
    if (panel === 'home' || this.activePanel === panel) {
      return false;
    }
    this.activePanel = panel;
    return true;
  }

  public close(): boolean {
    if (this.activePanel === 'home') {
      return false;
    }
    this.activePanel = 'home';
    return true;
  }

  public getActivePanel(): SessionOverlayPanel {
    return this.activePanel;
  }

  public isOpen(panel: SessionOverlayPanel): boolean {
    return this.activePanel === panel;
  }
}
