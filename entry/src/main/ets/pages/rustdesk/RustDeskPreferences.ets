import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { SavedConnectionSettings } from './RustDeskTypes';

const PREF_NAME = 'rustdesk_connection';
const TARGET_KEY = 'target';
const PASSWORD_KEY = 'password';
const REMEMBER_PASSWORD_KEY = 'remember_password';

export class RustDeskPreferences {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private getStore(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context, { name: PREF_NAME });
  }

  load(): SavedConnectionSettings {
    try {
      const store = this.getStore();
      return {
        target: store.getSync(TARGET_KEY, '10.52.176.1') as string,
        password: store.getSync(PASSWORD_KEY, '') as string,
        rememberPassword: store.getSync(REMEMBER_PASSWORD_KEY, false) as boolean,
      };
    } catch (_) {
      return {
        target: '10.52.176.1',
        password: '',
        rememberPassword: false,
      };
    }
  }

  saveTarget(target: string): void {
    try {
      const store = this.getStore();
      store.putSync(TARGET_KEY, target);
      store.flush();
    } catch (_) {
    }
  }

  savePassword(password: string, rememberPassword: boolean): void {
    try {
      const store = this.getStore();
      store.putSync(REMEMBER_PASSWORD_KEY, rememberPassword);
      store.putSync(PASSWORD_KEY, rememberPassword ? password : '');
      store.flush();
    } catch (_) {
    }
  }

  clearPassword(): void {
    this.savePassword('', false);
  }
}
