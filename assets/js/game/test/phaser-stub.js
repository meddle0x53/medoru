globalThis.window = globalThis.window || { gameData: {} }
globalThis.localStorage = globalThis.localStorage || { getItem: () => null, setItem: () => {}, removeItem: () => {} }
globalThis.fetch = globalThis.fetch || (async () => { throw new Error('network disabled') })
globalThis.Phaser = globalThis.Phaser || {
  Scene: class {
    constructor(cfg) { this.key = cfg?.key }
  },
}
