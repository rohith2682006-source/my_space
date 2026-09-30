import { IStorageProvider } from './storage.interface';
import { LocalStorageProvider } from './local.storage';
import { env } from '../../config/env';

function createStorageProvider(): IStorageProvider {
  switch (env.STORAGE_PROVIDER) {
    case 'local':
    default:
      return new LocalStorageProvider();
  }
}

export const storage = createStorageProvider();
export * from './storage.interface';
