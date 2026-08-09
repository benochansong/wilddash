import type { GameProfile, GameSettings } from "../types/game";

const PROFILE_KEY = "wild-dash-profile";
const SETTINGS_KEY = "wild-dash-settings";
const TUTORIAL_KEY = "wild-dash-tutorial";

function readJson<T>(key: string): T | null {
  if (typeof localStorage === "undefined") return null;
  try {
    const value = localStorage.getItem(key);
    return value ? JSON.parse(value) as T : null;
  } catch {
    return null;
  }
}

function writeJson(key: string, value: unknown): void {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Device-local persistence is optional.
  }
}

export const saveManager = {
  loadProfile(): GameProfile | null {
    return readJson<GameProfile>(PROFILE_KEY);
  },

  saveProfile(profile: GameProfile): void {
    writeJson(PROFILE_KEY, profile);
  },

  loadSettings(): GameSettings | null {
    return readJson<GameSettings>(SETTINGS_KEY);
  },

  saveSettings(settings: GameSettings): void {
    writeJson(SETTINGS_KEY, settings);
  },

  hasCompletedTutorial(): boolean {
    if (typeof localStorage === "undefined") return false;
    try {
      return localStorage.getItem(TUTORIAL_KEY) === "done";
    } catch {
      return false;
    }
  },

  markTutorialComplete(): void {
    if (typeof localStorage === "undefined") return;
    try {
      localStorage.setItem(TUTORIAL_KEY, "done");
    } catch {
      // Device-local persistence is optional.
    }
  },
};
