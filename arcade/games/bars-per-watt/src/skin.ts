import defaults from '../skins/placeholder/skin.json';
import type { Presentation } from '../../../core/src/cartridge';

type Palette = Record<string, string>;
type Pack = { id: string; game: string; palette?: Palette; strings?: Record<string, string> };
export class Skin {
  current: Presentation = {
    id: 'placeholder', strings: { ...defaults.strings }, sfx: {}, volume: 0
  };
  palette: Palette = { ...defaults.palette };
  private generation = 0;
  private controller?: AbortController;
  constructor(private host: HTMLElement, private emit: (name: string, detail?: Record<string, unknown>) => void) {}
  async load(path: string | null) {
    const generation = ++this.generation;
    this.controller?.abort();
    this.controller = new AbortController();
    const fallback = () => {
      this.current = { id: 'placeholder', strings: { ...defaults.strings }, sfx: {}, volume: 0 };
      this.palette = { ...defaults.palette };
      this.apply();
    };
    fallback();
    if (!path) return;
    try {
      const url = new URL(path, document.baseURI);
      if (!['http:', 'https:', 'data:'].includes(url.protocol)) throw Error('Invalid skin URL');
      const response = await fetch(url, { signal: this.controller.signal });
      if (!response.ok) throw Error('Skin HTTP ' + response.status);
      const raw = await response.text();
      if (raw.length > 256000) throw Error('Skin too large');
      const data = JSON.parse(raw) as Pack;
      if (data.game !== 'bars-per-watt' || !/^[a-z0-9-]{1,64}$/.test(data.id) ||
          (data.palette && Object.values(data.palette).some(v => !/^#[0-9a-fA-F]{6}$/.test(v))) ||
          (data.strings && Object.values(data.strings).some(v => typeof v !== 'string' || v.length > 500)))
        throw Error('Invalid skin');
      if (generation !== this.generation) return;
      this.current = { id: data.id, strings: { ...defaults.strings, ...data.strings }, sfx: {}, volume: 0 };
      this.palette = { ...defaults.palette, ...data.palette }; this.apply();
      this.emit('game:skin-loaded', { skin: data.id });
    } catch (error) {
      if (generation !== this.generation || this.controller.signal.aborted) return;
      fallback();
      this.emit('game:error', { message: String(error), code: 'SKIN_LOAD_FAILED' });
    }
  }
  private apply() {
    for (const [name, color] of Object.entries(this.palette))
      this.host.style.setProperty('--bpw-' + name, color);
  }
  dispose() { ++this.generation; this.controller?.abort(); }
}
