import type {
  GameProfile,
  GameRecords,
  GameSaveData,
  GameSettings,
  GameUnlocks,
} from "../types/game";

export const SAVE_VERSION = 1 as const;
export const SAVE_KEY = "wild-dash-save";

const LEGACY_PROFILE_KEY = "wild-dash-profile";
const LEGACY_SETTINGS_KEY = "wild-dash-settings";
const LEGACY_TUTORIAL_KEY = "wild-dash-tutorial";

export const DEFAULT_PROFILE: GameProfile = {
  fans: 0,
  wins: 0,
  best: 50,
};

export const DEFAULT_SETTINGS: GameSettings = {
  sound: true,
  haptics: true,
  reducedMotion: false,
  highContrast: false,
  largeTouch: false,
};

export const DEFAULT_UNLOCKS: GameUnlocks = {
  characters: [],
};

export const DEFAULT_RECORDS: GameRecords = {};

type StorageLike = Pick<Storage, "getItem" | "setItem" | "removeItem">;

type JsonObject = Record<string, unknown>;

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readJson(storage: StorageLike, key: string): unknown | null {
  try {
    const raw = storage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function writeJson(storage: StorageLike, key: string, value: unknown): boolean {
  try {
    storage.setItem(key, JSON.stringify(value));
    return true;
  } catch {
    return false;
  }
}

function safeRemove(storage: StorageLike, key: string): void {
  try {
    storage.removeItem(key);
  } catch {
    // Persistence cleanup is optional and must never interrupt gameplay.
  }
}

function asNonNegativeInteger(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? Math.floor(value)
    : fallback;
}

function asBestRank(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value >= 1 && value <= 50
    ? Math.floor(value)
    : DEFAULT_PROFILE.best;
}

function asBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function validateProfile(value: unknown): GameProfile {
  if (!isObject(value)) return { ...DEFAULT_PROFILE };
  return {
    fans: asNonNegativeInteger(value.fans, DEFAULT_PROFILE.fans),
    wins: asNonNegativeInteger(value.wins, DEFAULT_PROFILE.wins),
    best: asBestRank(value.best),
  };
}

function validateSettings(value: unknown): GameSettings {
  if (!isObject(value)) return { ...DEFAULT_SETTINGS };
  return {
    sound: asBoolean(value.sound, DEFAULT_SETTINGS.sound),
    haptics: asBoolean(value.haptics, DEFAULT_SETTINGS.haptics),
    reducedMotion: asBoolean(value.reducedMotion, DEFAULT_SETTINGS.reducedMotion),
    highContrast: asBoolean(value.highContrast, DEFAULT_SETTINGS.highContrast),
    largeTouch: asBoolean(value.largeTouch, DEFAULT_SETTINGS.largeTouch),
  };
}

function validateUnlocks(value: unknown): GameUnlocks {
  if (!isObject(value) || !Array.isArray(value.characters)) {
    return { characters: [...DEFAULT_UNLOCKS.characters] };
  }
  const characters = value.characters
    .filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0)
    .map((entry) => entry.trim());
  return { characters: [...new Set(characters)] };
}

function validateRecords(value: unknown): GameRecords {
  if (!isObject(value)) return { ...DEFAULT_RECORDS };
  const records: GameRecords = {};
  for (const [key, recordValue] of Object.entries(value)) {
    if (typeof recordValue === "number" && Number.isFinite(recordValue) && recordValue >= 0) {
      records[key] = recordValue;
    }
  }
  return records;
}

function createDefaultSave(): GameSaveData {
  return {
    version: SAVE_VERSION,
    profile: { ...DEFAULT_PROFILE },
    settings: { ...DEFAULT_SETTINGS },
    tutorialCompleted: false,
    unlocks: { characters: [...DEFAULT_UNLOCKS.characters] },
    records: { ...DEFAULT_RECORDS },
  };
}

function normalizeV1(value: unknown): GameSaveData | null {
  if (!isObject(value) || value.version !== SAVE_VERSION) return null;
  return {
    version: SAVE_VERSION,
    profile: validateProfile(value.profile),
    settings: validateSettings(value.settings),
    tutorialCompleted: asBoolean(value.tutorialCompleted, false),
    unlocks: validateUnlocks(value.unlocks),
    records: validateRecords(value.records),
  };
}

function migrateToCurrent(value: unknown): GameSaveData | null {
  if (!isObject(value)) return null;

  switch (value.version) {
    case SAVE_VERSION:
      return normalizeV1(value);
    default:
      // Future migrations should be added here, one version at a time.
      return null;
  }
}

function getBrowserStorage(): StorageLike | null {
  if (typeof localStorage === "undefined") return null;
  return localStorage;
}

export class SaveManager {
  constructor(private readonly providedStorage?: StorageLike | null) {}

  private get storage(): StorageLike | null {
    return this.providedStorage === undefined ? getBrowserStorage() : this.providedStorage;
  }

  load(): GameSaveData {
    const storage = this.storage;
    if (!storage) return createDefaultSave();

    const currentRaw = readJson(storage, SAVE_KEY);
    const current = migrateToCurrent(currentRaw);
    if (current) {
      // Rewrite normalized data so invalid individual fields are repaired on disk.
      writeJson(storage, SAVE_KEY, current);
      return current;
    }

    return this.migrateLegacyOrRecover(storage);
  }

  private migrateLegacyOrRecover(storage: StorageLike): GameSaveData {
    let legacyProfileRaw: string | null = null;
    let legacySettingsRaw: string | null = null;
    let legacyTutorialRaw: string | null = null;

    try {
      legacyProfileRaw = storage.getItem(LEGACY_PROFILE_KEY);
      legacySettingsRaw = storage.getItem(LEGACY_SETTINGS_KEY);
      legacyTutorialRaw = storage.getItem(LEGACY_TUTORIAL_KEY);
    } catch {
      return createDefaultSave();
    }

    const hasLegacyData = legacyProfileRaw !== null || legacySettingsRaw !== null || legacyTutorialRaw !== null;
    if (!hasLegacyData) return createDefaultSave();

    let profile: unknown = null;
    let settings: unknown = null;

    try {
      profile = legacyProfileRaw ? JSON.parse(legacyProfileRaw) : null;
    } catch {
      profile = null;
    }

    try {
      settings = legacySettingsRaw ? JSON.parse(legacySettingsRaw) : null;
    } catch {
      settings = null;
    }

    const migrated: GameSaveData = {
      version: SAVE_VERSION,
      profile: validateProfile(profile),
      settings: validateSettings(settings),
      tutorialCompleted: legacyTutorialRaw === "done",
      unlocks: { characters: [...DEFAULT_UNLOCKS.characters] },
      records: { ...DEFAULT_RECORDS },
    };

    if (writeJson(storage, SAVE_KEY, migrated)) {
      safeRemove(storage, LEGACY_PROFILE_KEY);
      safeRemove(storage, LEGACY_SETTINGS_KEY);
      safeRemove(storage, LEGACY_TUTORIAL_KEY);
    }

    return migrated;
  }

  resetToDefaults(): GameSaveData {
    const defaults = createDefaultSave();
    const storage = this.storage;
    if (storage) writeJson(storage, SAVE_KEY, defaults);
    return defaults;
  }

  loadProfile(): GameProfile {
    return this.load().profile;
  }

  saveProfile(profile: GameProfile): void {
    const current = this.load();
    this.write({ ...current, profile: validateProfile(profile) });
  }

  loadSettings(): GameSettings {
    return this.load().settings;
  }

  saveSettings(settings: GameSettings): void {
    const current = this.load();
    this.write({ ...current, settings: validateSettings(settings) });
  }

  hasCompletedTutorial(): boolean {
    return this.load().tutorialCompleted;
  }

  markTutorialComplete(): void {
    const current = this.load();
    this.write({ ...current, tutorialCompleted: true });
  }

  loadUnlocks(): GameUnlocks {
    return this.load().unlocks;
  }

  saveUnlocks(unlocks: GameUnlocks): void {
    const current = this.load();
    this.write({ ...current, unlocks: validateUnlocks(unlocks) });
  }

  loadRecords(): GameRecords {
    return this.load().records;
  }

  saveRecords(records: GameRecords): void {
    const current = this.load();
    this.write({ ...current, records: validateRecords(records) });
  }

  saveRecord(key: string, value: number): void {
    if (!key.trim() || !Number.isFinite(value) || value < 0) return;
    const current = this.load();
    this.write({
      ...current,
      records: {
        ...current.records,
        [key.trim()]: value,
      },
    });
  }

  private write(data: GameSaveData): void {
    const storage = this.storage;
    if (!storage) return;
    const normalized = normalizeV1(data) ?? createDefaultSave();
    writeJson(storage, SAVE_KEY, normalized);
  }
}

export const saveManager = new SaveManager();
