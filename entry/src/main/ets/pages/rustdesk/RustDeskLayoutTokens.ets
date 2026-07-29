export class RustDeskLayoutTokens {
  static WIDE_CONTENT_EDGE: number = 32;
  static PAGE_TITLE_SPACER: number = 96;
  static DEVICE_PAGE_TITLE_SPACER: number = 76;
  static PAGE_CONTENT_TOP_PADDING: number = 18;
  static HOME_TWO_COLUMN_MIN_WIDTH: number = 980;

  static useWideContentAnchor(viewportWidth: number, wideLayout: boolean): boolean {
    return wideLayout && viewportWidth > 0;
  }
}
