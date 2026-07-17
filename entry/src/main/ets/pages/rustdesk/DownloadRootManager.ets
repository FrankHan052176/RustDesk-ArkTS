import { common } from '@kit.AbilityKit';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { DownloadRoot } from './RustDeskSessionTypes';

export class DownloadRootManager {
  public buildChildPath(rootPath: string, fileName: string): string | undefined {
    const root = rootPath.trim().replace(/\/+$/, '');
    if (root.length === 0 || fileName.length === 0 || fileName === '.' || fileName === '..') {
      return undefined;
    }
    if (fileName.includes('/') || fileName.includes('\\') || fileName.includes('\0')) {
      return undefined;
    }
    const childPath = `${root}/${fileName}`;
    if (!this.isInsideRoot(root, childPath)) {
      return undefined;
    }
    return childPath;
  }

  public isInsideRoot(rootPath: string, candidatePath: string): boolean {
    const root = rootPath.trim().replace(/\/+$/, '');
    if (root.length === 0) {
      return false;
    }
    return candidatePath.startsWith(`${root}/`);
  }

  public async acquire(context: common.UIAbilityContext): Promise<DownloadRoot | undefined> {
    try {
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSaveOptions();
      options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      const result = await documentPicker.save(options);
      if (result.length === 0) {
        return undefined;
      }
      const uri = result[0];
      const path = new fileUri.FileUri(uri).path;
      if (path.trim().length === 0) {
        return undefined;
      }
      fileIo.listFileSync(path);
      return { uri, path };
    } catch (_) {
      return undefined;
    }
  }
}
