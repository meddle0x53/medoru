/**
 * Kana utilities used by word/kanji challenge systems.
 *
 * Provides Hepburn romaji conversion with support for:
 *   - sokuon (っ/ッ doubling the next consonant)
 *   - chouon (ー long vowels)
 *   - common Hepburn variants (shi/si, chi/ti, tsu/tu, fu/hu, ji/zi, づ/du, ぢ/di)
 *   - particle readings (は → wa, へ → e, を → o)
 */

const KANA_OPTIONS = {
  // Hiragana
  'あ': ['a'], 'い': ['i'], 'う': ['u'], 'え': ['e'], 'お': ['o'],
  'か': ['ka'], 'き': ['ki'], 'く': ['ku'], 'け': ['ke'], 'こ': ['ko'],
  'さ': ['sa'], 'し': ['shi', 'si'], 'す': ['su'], 'せ': ['se'], 'そ': ['so'],
  'た': ['ta'], 'ち': ['chi', 'ti'], 'つ': ['tsu', 'tu'], 'て': ['te'], 'と': ['to'],
  'な': ['na'], 'に': ['ni'], 'ぬ': ['nu'], 'ね': ['ne'], 'の': ['no'],
  'は': ['ha', 'wa'], 'ひ': ['hi'], 'ふ': ['fu', 'hu'], 'へ': ['he', 'e'], 'ほ': ['ho'],
  'ま': ['ma'], 'み': ['mi'], 'む': ['mu'], 'め': ['me'], 'も': ['mo'],
  'や': ['ya'], 'ゆ': ['yu'], 'よ': ['yo'],
  'ら': ['ra'], 'り': ['ri'], 'る': ['ru'], 'れ': ['re'], 'ろ': ['ro'],
  'わ': ['wa'], 'を': ['wo', 'o'], 'ん': ['n'],
  'が': ['ga'], 'ぎ': ['gi'], 'ぐ': ['gu'], 'げ': ['ge'], 'ご': ['go'],
  'ざ': ['za'], 'じ': ['ji', 'zi'], 'ず': ['zu'], 'ぜ': ['ze'], 'ぞ': ['zo'],
  'だ': ['da'], 'ぢ': ['ji', 'di'], 'づ': ['zu', 'du'], 'で': ['de'], 'ど': ['do'],
  'ば': ['ba'], 'び': ['bi'], 'ぶ': ['bu'], 'べ': ['be'], 'ぼ': ['bo'],
  'ぱ': ['pa'], 'ぴ': ['pi'], 'ぷ': ['pu'], 'ぺ': ['pe'], 'ぽ': ['po'],
  'きゃ': ['kya'], 'きゅ': ['kyu'], 'きょ': ['kyo'],
  'しゃ': ['sha'], 'しゅ': ['shu'], 'しょ': ['sho'],
  'ちゃ': ['cha'], 'ちゅ': ['chu'], 'ちょ': ['cho'],
  'にゃ': ['nya'], 'にゅ': ['nyu'], 'にょ': ['nyo'],
  'ひゃ': ['hya'], 'ひゅ': ['hyu'], 'ひょ': ['hyo'],
  'みゃ': ['mya'], 'みゅ': ['myu'], 'みょ': ['myo'],
  'りゃ': ['rya'], 'りゅ': ['ryu'], 'りょ': ['ryo'],
  'ぎゃ': ['gya'], 'ぎゅ': ['gyu'], 'ぎょ': ['gyo'],
  'じゃ': ['ja'], 'じゅ': ['ju'], 'じょ': ['jo'],
  'びゃ': ['bya'], 'びゅ': ['byu'], 'びょ': ['byo'],
  'ぴゃ': ['pya'], 'ぴゅ': ['pyu'], 'ぴょ': ['pyo'],

  // Katakana
  'ア': ['a'], 'イ': ['i'], 'ウ': ['u'], 'エ': ['e'], 'オ': ['o'],
  'カ': ['ka'], 'キ': ['ki'], 'ク': ['ku'], 'ケ': ['ke'], 'コ': ['ko'],
  'サ': ['sa'], 'シ': ['shi', 'si'], 'ス': ['su'], 'セ': ['se'], 'ソ': ['so'],
  'タ': ['ta'], 'チ': ['chi', 'ti'], 'ツ': ['tsu', 'tu'], 'テ': ['te'], 'ト': ['to'],
  'ナ': ['na'], 'ニ': ['ni'], 'ヌ': ['nu'], 'ネ': ['ne'], 'ノ': ['no'],
  'ハ': ['ha', 'wa'], 'ヒ': ['hi'], 'フ': ['fu', 'hu'], 'ヘ': ['he', 'e'], 'ホ': ['ho'],
  'マ': ['ma'], 'ミ': ['mi'], 'ム': ['mu'], 'メ': ['me'], 'モ': ['mo'],
  'ヤ': ['ya'], 'ユ': ['yu'], 'ヨ': ['yo'],
  'ラ': ['ra'], 'リ': ['ri'], 'ル': ['ru'], 'レ': ['re'], 'ロ': ['ro'],
  'ワ': ['wa'], 'ヲ': ['wo', 'o'], 'ン': ['n'],
  'ガ': ['ga'], 'ギ': ['gi'], 'グ': ['gu'], 'ゲ': ['ge'], 'ゴ': ['go'],
  'ザ': ['za'], 'ジ': ['ji', 'zi'], 'ズ': ['zu'], 'ゼ': ['ze'], 'ゾ': ['zo'],
  'ダ': ['da'], 'ヂ': ['ji', 'di'], 'ヅ': ['zu', 'du'], 'デ': ['de'], 'ド': ['do'],
  'バ': ['ba'], 'ビ': ['bi'], 'ブ': ['bu'], 'ベ': ['be'], 'ボ': ['bo'],
  'パ': ['pa'], 'ピ': ['pi'], 'プ': ['pu'], 'ペ': ['pe'], 'ポ': ['po'],
  'キャ': ['kya'], 'キュ': ['kyu'], 'キョ': ['kyo'],
  'シャ': ['sha'], 'シュ': ['shu'], 'ショ': ['sho'],
  'チャ': ['cha'], 'チュ': ['chu'], 'チョ': ['cho'],
  'ニャ': ['nya'], 'ニュ': ['nyu'], 'ニョ': ['nyo'],
  'ヒャ': ['hya'], 'ヒュ': ['hyu'], 'ヒョ': ['hyo'],
  'ミャ': ['mya'], 'ミュ': ['myu'], 'ミョ': ['myo'],
  'リャ': ['rya'], 'リュ': ['ryu'], 'リョ': ['ryo'],
  'ギャ': ['gya'], 'ギュ': ['gyu'], 'ギョ': ['gyo'],
  'ジャ': ['ja'], 'ジュ': ['ju'], 'ジョ': ['jo'],
  'ビャ': ['bya'], 'ビュ': ['byu'], 'ビョ': ['byo'],
  'ピャ': ['pya'], 'ピュ': ['pyu'], 'ピョ': ['pyo'],
}

function lastVowel(str) {
  for (let i = str.length - 1; i >= 0; i--) {
    if ('aeiou'.includes(str[i])) return str[i]
  }
  return ''
}

function buildVariants(input, start, prevVowel) {
  if (start >= input.length) return ['']

  const c = input[start]

  // Sokuon: double the first consonant of the following token.
  if (c === 'っ' || c === 'ッ') {
    const rest = buildVariants(input, start + 1, prevVowel)
    return rest.map(r => {
      const first = r.charAt(0)
      if (/[bcdfghjklmpqrstvwxyz]/.test(first)) return first + r
      return r
    })
  }

  // Chouon: repeat the last vowel of the preceding token.
  if (c === 'ー') {
    const rest = buildVariants(input, start + 1, prevVowel)
    return rest.map(r => (prevVowel || '') + r)
  }

  const next = input[start + 1] || ''
  const two = c + next
  let options = KANA_OPTIONS[two]
  let len = 2
  if (!options) {
    options = KANA_OPTIONS[c]
    len = 1
  }

  if (!options) {
    const rest = buildVariants(input, start + 1, prevVowel)
    return rest.map(r => c + r)
  }

  const result = []
  const cache = {}
  for (const opt of options) {
    const lv = lastVowel(opt)
    if (!cache[lv]) cache[lv] = buildVariants(input, start + len, lv)
    const rest = cache[lv]
    for (const r of rest) result.push(opt + r)
  }
  return result
}

export function generateKanaVariants(input) {
  if (!input) return []
  return buildVariants(input.trim(), 0, '')
}

export function kanaToRomaji(input) {
  const variants = generateKanaVariants(input)
  return variants[0] || ''
}

function splitReadings(text) {
  if (!text) return []
  return String(text)
    .split(/[\s\/、；;／・|]+/)
    .map(s => s.trim())
    .filter(Boolean)
}

export function normalizeReadingInput(input) {
  return String(input || '')
    .trim()
    .toLowerCase()
    .replace(/[\s'ʼ＇]/g, '')
}

export function getAcceptedReadings(word) {
  const accepted = new Set()

  const add = (value) => {
    if (!value) return
    const normalized = normalizeReadingInput(value)
    if (normalized) accepted.add(normalized)
  }

  if (word?.reading) {
    for (const part of splitReadings(word.reading)) {
      add(part)
      for (const variant of generateKanaVariants(part)) add(variant)
    }
  }

  if (word?.word) {
    add(word.word)
    for (const variant of generateKanaVariants(word.word)) add(variant)
  }

  return Array.from(accepted)
}

export function getAcceptedKanjiReadings(readings) {
  const accepted = new Set()
  for (const r of readings || []) {
    for (const part of splitReadings(r)) {
      const normalized = normalizeReadingInput(part)
      if (normalized) accepted.add(normalized)
      for (const variant of generateKanaVariants(part)) {
        const v = normalizeReadingInput(variant)
        if (v) accepted.add(v)
      }
    }
  }
  return Array.from(accepted)
}
