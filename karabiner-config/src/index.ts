import {
  duoLayer,
  ifApp,
  ifDevice,
  ifInputSource,
  ifVar,
  map,
  mapDoubleTap,
  mapSimultaneous,
  rule,
  toKey,
  toSetVar,
  withCondition,
  writeToProfile,
} from 'karabiner.ts'
import {toSymbol} from "./utils";

// modskey '⌘' | '⌥' | '⌃' | '⇧'

const prefixDomLayer = 'duo-layer-';
const vimLayerKey = 'vimLayerKey';
const vimVisualMode = 'VimLayerVisualMode';
const vimNoticeKey = `${prefixDomLayer}${vimLayerKey}`;

const ignoreVimEmulation = ['^com.jetbrains.[\\w-]+$', '^com.googlecode.iterm2$']

function main() {
  writeToProfile('Default', [
      ruleBasic(),
      ruleApp(),
      ruleOptionSymbol(),
      ruleBuildInKeyboard(),
      ruleNotBuildInKeyboard(),
      ruleIme(),
      // ruleImeForJetBrains(),
      // ruleImeDuo(),
      // ruleVimForJapanese(),
    ],
    {
      'basic.simultaneous_threshold_milliseconds': 150,
      'duo_layer.threshold_milliseconds': 150,
      // 'duo_layer.notification': true,
    },
  )
}

const ruleBasic = () => {
  return rule('Basic').manipulators([
    withCondition(ifApp(['^com.googlecode.iterm2$']).unless())([
      map('c', '⌃').to('escape').to('japanese_eisuu')
        // TODO: fix this
        .toVar(vimVisualMode).toVar(vimLayerKey, 0).toRemoveNotificationMessage(vimNoticeKey),
    ]),
    map('h', '⌃').to('⌫'),
    map('q', '⌘').toIfHeldDown('q', '⌘', {repeat: false}),
    map('m', '⌘').toIfHeldDown('m', '⌘', {repeat: false}),
    map('h', '⌘').to('←'),
    map('j', '⌘').to('↓'),
    map('k', '⌘').to('↑'),
    map('l', '⌘').to('→'),
    map('i', ['⌘']).to('a', '⌃'),
    map('o', ['⌘']).to('e', '⌃'),
    // map('h', ['⇧', '⌘']).to('a', '⌃'),
    // map('l', ['⇧', '⌘']).to('e', '⌃'),
    map(',', ['⌘', '⇧']).to(',', '⌘'),
    withCondition(ifApp(['^com.jetbrains.[\\w-]+$']).unless())([
      map('/', '⌘').to('l', '⌘'),
      map('.', '⌘').to('tab', ['⌃']),
      map(',', '⌘').to('tab', ['⌃', '⇧']),
    ]),
  ])
}

const ruleApp = () => {
  return rule('app').manipulators([
    withCondition(ifApp(['^com.jetbrains.[\\w-]+$']))([
      map('.', '⌘').to(']', ['⌘', '⇧']),
      map(',', '⌘').to('[', ['⌘', '⇧']),
    ]),
    withCondition(ifApp(['^com\\.apple\\.finder$', '^com\\.cocoatech\\.PathFinder$']))([
      map('j', '⌘').to('close_bracket', ['⌘', '⇧']),
      map('k', '⌘').to('open_bracket', ['⌘', '⇧']),
      map('n', '⌃').to('down_arrow'),
      map('p', '⌃').to('up_arrow'),
      map('b', '⌃').to('left_arrow'),
      map('f', '⌃').to('right_arrow'),
    ]),
  ])
}

const ruleBuildInKeyboard = () => {
  return rule("buildIn")
    .condition(
      ifDevice({is_built_in_keyboard: true}))
    .manipulators([
      map('semicolon').to('left_control').toIfAlone('return_or_enter'),
      map('spacebar').to('left_option').toIfAlone('spacebar'),
      map('left_command').to('left_command').toIfAlone('tab'),
      map('right_command').to('right_option').toIfAlone('delete_or_backspace'),
      mapDoubleTap(',').to(toSymbol[':']),
      map('semicolon', 'shift').to('return_or_enter', 'shift'),
      // IME ON
      mapSimultaneous(['d', 'f']).to('japanese_kana'),
      mapSimultaneous(['f', 'j']).to('-'),
      withCondition(ifApp(['^com.jetbrains.[\\w-]+$']))([
        map('.', '⌥').to(']', ['⌘', '⇧']),
        map(',', '⌥').to('[', ['⌘', '⇧']),
      ]),
    ]);
}

const ruleNotBuildInKeyboard = () => {
  return rule("notBuildIn")
    .condition(
      ifDevice({is_built_in_keyboard: false}))
    .manipulators([
      map('delete_or_backspace', '⌃').to('spacebar', ['⌃']),
      // for alfred
      map('delete_or_backspace', ['⌃', '⌘']).to('japanese_eisuu').to('spacebar', ['⌃', '⌘']),
      // 押しっぱなしで日本語
      map('right_shift')
        .to([
          toSetVar('caps_lock_pressed', 1),
          toKey('japanese_kana'),
        ])
        .toAfterKeyUp([
          toSetVar('caps_lock_pressed', 0),
          toKey('japanese_eisuu'),
        ]),
    ]);
}

const ruleOptionSymbol = () => {
  return rule("optionSymbol").manipulators([
    map('q', '⌥').to(toSymbol['!']),
    map('w', '⌥').to(toSymbol['@']),
    map('e', '⌥').to(toSymbol['#']),
    map('r', '⌥').to(toSymbol['$']),
    map('t', '⌥').to(toSymbol['%']),
    map('y', '⌥').to(toSymbol['^']),
    map('u', '⌥').to(toSymbol['&']),
    map('i', '⌥').to(toSymbol['*']),
    map('o', '⌥').to(toSymbol['`']),
    map('p', '⌥').to(toSymbol['~']),

    map('a', '⌥').to(toSymbol['+']),
    mapDoubleTap('s', '⌥').to(toSymbol['[']).singleTap(toKey('9', ['left_shift'])),
    mapDoubleTap('d', '⌥').to(toSymbol[']']).singleTap(toKey('0', ['left_shift'])),
    map('f', '⌥').to(toSymbol['=']),
    map('g', '⌥').to(toSymbol[':']),
    map('h', '⌥').to('←'),
    map('j', '⌥').to('↓'),
    map('k', '⌥').to('↑'),
    map('l', '⌥').to('→'),

    map('z', '⌥').to(toSymbol['|']),
    mapDoubleTap('x', '⌥').to(toSymbol['<']).singleTap(toKey('open_bracket', ['left_shift'])),
    mapDoubleTap('c', '⌥').to(toSymbol['>']).singleTap(toKey('close_bracket', ['left_shift'])),
    map('v', '⌥').to(toSymbol['\'']),
    map('b', '⌥').to(toSymbol['\"']),
    map('n', '⌥').to(toSymbol['\\']),
    map('m', '⌥').to(toSymbol['_']),
    map('/', '⌥').to(toSymbol['-']),
    map(';', '⌥').to(toSymbol[';']),
    withCondition(ifApp(['^com.jetbrains.[\\w-]+$']).unless())([
      map(',', '⌥').to(toSymbol['[']),
      map('.', '⌥').to(toSymbol[']']),
    ]),
  ])
}

const jkSimultaneous = () => mapSimultaneous(['j', 'k']).to('japanese_eisuu');

const ruleIme = () => {
  return rule('Ime').manipulators([
    map('f16').to('japanese_kana').toVar(vimVisualMode).toVar(vimLayerKey, 0).toRemoveNotificationMessage(vimNoticeKey), // for QMK
    map('escape').to('escape').to('japanese_eisuu').toVar(vimVisualMode).toVar(vimLayerKey, 0).toRemoveNotificationMessage(vimNoticeKey), // for QMK
    withCondition(ifInputSource({language: 'ja'}))([
      map('slash').to('hyphen'),
      map('return_or_enter', '⌃').to('semicolon', '⌃'),
      // for iterm2
      map('u', ['⌃', '⌘']).to('u', ['⌃', '⌘']).to('japanese_eisuu'),
    ]),
    // jk で日本語
    withCondition(ifInputSource({language: 'ja'}))([
      jkSimultaneous(),
    ]),
    // jk で IME:OFFだったらESCAPE
    withCondition(ifInputSource({language: 'ja'}).unless())([
      mapSimultaneous(['j', 'k']).to('escape')
    ]),
    // for jetbrains
    withCondition(
      ifApp(ignoreVimEmulation),
      ifInputSource({language: 'ja'}),
    )([
      jkSimultaneous().to('open_bracket', 'left_control'),
    ]),
    withCondition(
      ifApp(ignoreVimEmulation),
      ifInputSource({language: 'ja'}).unless(),
    )([
      jkSimultaneous().to('escape'),
    ]),
  ])
}

// const ruleImeForJetBrains = () => {
//   return duoLayer('j', 'k').threshold(100)
//     .condition(ifApp(ignoreVimEmulation))
//     .toIfActivated(toKey("japanese_eisuu"))
//     .toIfActivated(toKey("open_bracket", 'left_control'))
// }
//
// const ruleImeDuo = () => {
//   return duoLayer('j', 'k').threshold(100)
//     .condition(ifApp(ignoreVimEmulation).unless())
//     .toIfActivated(toKey("japanese_eisuu"))
//     .toIfActivated(toSetVar(vimVisualMode, 0))
//     .manipulators([
//       withCondition(ifInputSource({language: 'ja'}).unless())([
//         toKey('escape')
//       ])
//     ])
// }

const ruleVimForJapanese = () => {
  return duoLayer('j', 'k', vimLayerKey)
    .condition(ifApp(ignoreVimEmulation).unless())
    .toIfActivated(toKey("japanese_eisuu"))
    .toIfActivated(toSetVar(vimVisualMode, 0))
    .threshold(100)
    .leaderMode({sticky: true})
    .notification('Normal Mode (Vim Emulation)')
    .manipulators([
      map('a').to('→').toVar(vimLayerKey, 0).toRemoveNotificationMessage(vimNoticeKey),
      map('i').toVar(vimLayerKey, 0).toRemoveNotificationMessage(vimNoticeKey),
      map('o').to('e', 'left_control').to('return_or_enter').toVar(vimLayerKey, 0).toRemoveNotificationMessage(vimNoticeKey),
      map('o', '⇧').to('a', 'left_control').to('return_or_enter').to('↑').toVar(vimLayerKey, 0).toRemoveNotificationMessage(vimNoticeKey),
      map('u').to('z', '⌘'),
      map('x').toVar(vimVisualMode, 0).to('⌦'),
      map('x', '⇧').toVar(vimVisualMode, 0).to('⌫'),
      map('p').to('v', '⌘').toVar(vimVisualMode, 0),
      map('d', '⇧').to('e', '⌃⇧').to('c', 'left_command').to('delete_or_backspace').toVar(vimVisualMode, 0),
      map("r", '⌃').to("z", ['⇧', '⌘']),
      // map("u", '⌃').to('up_arrow', ['⌥']),
      // map("d", '⌃').to('down_arrow', ['⌥']),
      map("g", '⇧').to('up_arrow', ['⌘']),
      mapDoubleTap('g').to('down_arrow', '⌘'),
      withCondition(ifVar(vimVisualMode, 0))([
        map('h').to('←'),
        map('j').to('↓'),
        map('k').to('↑'),
        map('l').to('→'),
        map("w").to('right_arrow', ['⌥']),
        map("b").to('left_arrow', ['⌥']),
        mapDoubleTap('v', 150).toVar(vimVisualMode, 1).to('a', '⌃').to('e', '⌃⇧').singleTap(toSetVar(vimVisualMode, 1)),
        mapDoubleTap('y').to('a', '⌃').to('e', '⌃⇧').to('c', '⌘'),
        mapDoubleTap('d').to('a', '⌃').to('e', '⌃⇧').to('c', 'left_command').to('delete_or_backspace').toVar(vimVisualMode, 0),
      ]),
      withCondition(ifVar(vimVisualMode, 1))([
        mapSimultaneous(['k', 'j']).toVar(vimVisualMode, 0).to('←'),
        map('v').toVar(vimVisualMode, 0).to('←'),
        map('h').to('←', '⇧'),
        map('j').to('↓', '⇧'),
        map('k').to('↑', '⇧'),
        map('l').to('→', '⇧'),
        map('d').to('c', 'left_command').to('delete_or_backspace').toVar(vimVisualMode, 0),
        map('y').to('c', 'left_command').toVar(vimVisualMode, 0),
        map("w").to('right_arrow', ['⌥', '⇧']),
        map("b").to('left_arrow', ['⌥', '⇧']),
      ]),
    ])
}

main();
