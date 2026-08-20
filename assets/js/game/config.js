/**
 * The Hollow Ouroboros - Game Configuration
 */
export const GAME_CONFIG = {
  width: 960,
  height: 540,
  backgroundColor: '#1a1a2e',
  title: 'The Hollow Ouroboros',
  version: '0.3.0',
}

export const COLORS = {
  player: 0x3498db,
  enemy: 0xe74c3c,
  hp: 0x2ecc71,
  hpBg: 0x2c3e50,
  stamina: 0xf1c40f,
  staminaBg: 0x2c3e50,
  text: '#ecf0f1',
  textDark: '#2c3e50',
  panelBg: 0x16213e,
  button: 0x2980b9,
  buttonHover: 0x3498db,
  buttonDisabled: 0x7f8c8d,
  success: 0x2ecc71,
  danger: 0xe74c3c,
  warning: 0xf39c12,
}

export const FONTS = {
  default: {
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif',
    fontSize: '16px',
    color: COLORS.text,
  },
  title: {
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif',
    fontSize: '24px',
    fontStyle: 'bold',
    color: COLORS.text,
  },
  kanji: {
    fontFamily: '"Noto Sans JP", "Hiragino Sans", sans-serif',
    fontSize: '48px',
    color: COLORS.text,
  },
  damage: {
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif',
    fontSize: '20px',
    fontStyle: 'bold',
    color: COLORS.danger,
  },
  heal: {
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif',
    fontSize: '20px',
    fontStyle: 'bold',
    color: COLORS.success,
  },
}
