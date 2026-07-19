export class RemoteFilePath {
  public static isDirectoryType(entryType: number): boolean {
    return entryType === 0 || entryType === 2 || entryType === 3;
  }

  public static isFileType(entryType: number): boolean {
    return entryType === 4 || entryType === 5;
  }

  public static join(directory: string, name: string): string {
    const base = directory.trim();
    if (base.length === 0 || base === '/') {
      if (RemoteFilePath.hasWindowsDrivePrefix(name)) {
        return `${name}\\`;
      }
      return `/${name}`;
    }
    if (RemoteFilePath.isWindowsPath(base)) {
      return `${base.replace(/[\\/]+$/, '')}\\${name}`;
    }
    return `${base.replace(/\/+$/, '')}/${name}`;
  }

  public static parent(path: string): string {
    const value = path.trim();
    if (value.length === 0 || value === '/') {
      return '/';
    }
    if (RemoteFilePath.isWindowsPath(value)) {
      const normalized = value.replace(/\\/g, '/').replace(/\/+$/, '');
      if (normalized.length <= 2 && RemoteFilePath.hasWindowsDrivePrefix(normalized)) {
        return '/';
      }
      const separator = normalized.lastIndexOf('/');
      if (separator <= 2 && RemoteFilePath.hasWindowsDrivePrefix(normalized)) {
        return `${normalized.substring(0, 2)}\\`;
      }
      if (separator < 0) {
        return '/';
      }
      return normalized.substring(0, separator).replace(/\//g, '\\');
    }
    const normalized = value.replace(/\/+$/, '');
    const separator = normalized.lastIndexOf('/');
    return separator <= 0 ? '/' : normalized.substring(0, separator);
  }

  public static isSafeAbsoluteDirectory(path: string): boolean {
    const normalized = path.trim().replace(/\\/g, '/');
    if (normalized.length === 0 || normalized.includes('\0')) {
      return false;
    }
    if (!normalized.startsWith('/') && !RemoteFilePath.hasWindowsDrivePrefix(normalized)) {
      return false;
    }
    const segments = normalized.split('/');
    for (let index = 0; index < segments.length; index += 1) {
      if (segments[index] === '..') {
        return false;
      }
    }
    return true;
  }

  private static isWindowsPath(path: string): boolean {
    return path.includes('\\') || RemoteFilePath.hasWindowsDrivePrefix(path);
  }

  private static hasWindowsDrivePrefix(path: string): boolean {
    if (path.length < 2 || path.charAt(1) !== ':') {
      return false;
    }
    const code = path.charCodeAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }
}
