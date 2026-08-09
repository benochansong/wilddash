export type ToneSfx = {
  frequency: number;
  duration?: number;
  volume?: number;
  waveform?: OscillatorType;
};

export type SamplePlaybackOptions = {
  volume?: number;
  playbackRate?: number;
};

export type MusicPlaybackOptions = {
  loop?: boolean;
  volume?: number;
};

type AudioContextConstructor = typeof AudioContext;

function clampVolume(value: number): number {
  return Math.max(0, Math.min(1, value));
}

/**
 * App-wide Web Audio owner.
 *
 * The AudioContext is created lazily on the first playback request and reused
 * for every sound. SFX and music have separate gain buses so the settings UI
 * can evolve without changing gameplay components.
 */
export class AudioManager {
  private context: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private sfxGain: GainNode | null = null;
  private musicGain: GainNode | null = null;
  private musicSource: AudioBufferSourceNode | null = null;
  private musicTrackGain: GainNode | null = null;

  private muted = false;
  private sfxVolume = 1;
  private musicVolume = 0.65;

  private sfxRegistry = new Map<string, string>();
  private musicRegistry = new Map<string, string>();
  private bufferCache = new Map<string, Promise<AudioBuffer>>();

  setMuted(muted: boolean): void {
    this.muted = muted;
    if (this.masterGain) this.masterGain.gain.value = muted ? 0 : 1;
  }

  isMuted(): boolean {
    return this.muted;
  }

  setSfxVolume(volume: number): void {
    this.sfxVolume = clampVolume(volume);
    if (this.sfxGain) this.sfxGain.gain.value = this.sfxVolume;
  }

  setMusicVolume(volume: number): void {
    this.musicVolume = clampVolume(volume);
    if (this.musicGain) this.musicGain.gain.value = this.musicVolume;
  }

  registerSfx(id: string, url: string): void {
    this.sfxRegistry.set(id, url);
  }

  registerMusic(id: string, url: string): void {
    this.musicRegistry.set(id, url);
  }

  /**
   * Plays either a generated oscillator cue or a registered/file URL SFX.
   */
  playSfx(cue: ToneSfx | string, options: SamplePlaybackOptions = {}): void {
    if (typeof cue === "string") {
      void this.playSampleSfx(cue, options);
      return;
    }
    void this.playTone(cue);
  }

  async playMusic(cue: string, options: MusicPlaybackOptions = {}): Promise<void> {
    const context = this.ensureContext();
    if (!context) return;
    await this.resume();

    const url = this.musicRegistry.get(cue) ?? cue;
    const buffer = await this.loadBuffer(url, context);
    this.stopMusic();

    const source = context.createBufferSource();
    const trackGain = context.createGain();
    source.buffer = buffer;
    source.loop = options.loop ?? true;
    trackGain.gain.value = clampVolume(options.volume ?? 1);
    source.connect(trackGain);
    trackGain.connect(this.musicGain!);
    source.start();

    this.musicSource = source;
    this.musicTrackGain = trackGain;
    source.onended = () => {
      if (this.musicSource === source) {
        this.musicSource = null;
        this.musicTrackGain = null;
      }
    };
  }

  stopMusic(): void {
    if (this.musicSource) {
      try {
        this.musicSource.stop();
      } catch {
        // The source may already have ended.
      }
      this.musicSource.disconnect();
      this.musicSource = null;
    }
    this.musicTrackGain?.disconnect();
    this.musicTrackGain = null;
  }

  async resume(): Promise<void> {
    const context = this.ensureContext();
    if (!context || context.state !== "suspended") return;
    try {
      await context.resume();
    } catch {
      // Browsers may reject resume until the next explicit user gesture.
    }
  }

  private async playTone(cue: ToneSfx): Promise<void> {
    const context = this.ensureContext();
    if (!context) return;
    await this.resume();

    const duration = Math.max(0.01, cue.duration ?? 0.08);
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = cue.waveform ?? "square";
    oscillator.frequency.value = cue.frequency;

    const startVolume = Math.max(0.0001, clampVolume(cue.volume ?? 0.05));
    gain.gain.setValueAtTime(startVolume, context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, context.currentTime + duration);
    oscillator.connect(gain);
    gain.connect(this.sfxGain!);
    oscillator.start();
    oscillator.stop(context.currentTime + duration);
    oscillator.onended = () => {
      oscillator.disconnect();
      gain.disconnect();
    };
  }

  private async playSampleSfx(cue: string, options: SamplePlaybackOptions): Promise<void> {
    const context = this.ensureContext();
    if (!context) return;
    await this.resume();

    const url = this.sfxRegistry.get(cue) ?? cue;
    const buffer = await this.loadBuffer(url, context);
    const source = context.createBufferSource();
    const gain = context.createGain();
    source.buffer = buffer;
    source.playbackRate.value = Math.max(0.1, options.playbackRate ?? 1);
    gain.gain.value = clampVolume(options.volume ?? 1);
    source.connect(gain);
    gain.connect(this.sfxGain!);
    source.start();
    source.onended = () => {
      source.disconnect();
      gain.disconnect();
    };
  }

  private ensureContext(): AudioContext | null {
    if (this.context) return this.context;
    if (typeof window === "undefined") return null;

    const AudioCtx = window.AudioContext
      ?? (window as typeof window & { webkitAudioContext?: AudioContextConstructor }).webkitAudioContext;
    if (!AudioCtx) return null;

    const context = new AudioCtx();
    const masterGain = context.createGain();
    const sfxGain = context.createGain();
    const musicGain = context.createGain();

    masterGain.gain.value = this.muted ? 0 : 1;
    sfxGain.gain.value = this.sfxVolume;
    musicGain.gain.value = this.musicVolume;

    sfxGain.connect(masterGain);
    musicGain.connect(masterGain);
    masterGain.connect(context.destination);

    this.context = context;
    this.masterGain = masterGain;
    this.sfxGain = sfxGain;
    this.musicGain = musicGain;
    return context;
  }

  private loadBuffer(url: string, context: AudioContext): Promise<AudioBuffer> {
    const cached = this.bufferCache.get(url);
    if (cached) return cached;

    const pending = fetch(url)
      .then((response) => {
        if (!response.ok) throw new Error(`Failed to load audio: ${url}`);
        return response.arrayBuffer();
      })
      .then((data) => context.decodeAudioData(data));

    this.bufferCache.set(url, pending);
    pending.catch(() => this.bufferCache.delete(url));
    return pending;
  }
}

export const audio = new AudioManager();
