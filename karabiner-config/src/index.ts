import {
  ifApp,
  ifDevice,
  ifInputSource,
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

// modskey '⌘' | '⌥' | '⌃' | '⇧' | '⌫' |'⌦'

const ignoreVimEmulation = ['^com.jetbrains.[\\w-]+$', '^com.googlecode.iterm2$']

function main() {
  writeToProfile('Default', [
      ruleBasic(),
      ruleApp(),
      ruleOptionSymbol(),
      ruleBuildInKeyboard(),
      ruleNotBuildInKeyboard(),
      ruleIme(),
    ],
    {
      'basic.simultaneous_threshold_milliseconds': 150,
    },
  )
}

const ruleBasic = () => {
  return rule('Basic').manipulators([
    withCondition(ifApp(['^com.googlecode.iterm2$', 'com.mitchellh.ghostty']).unless())([
      map('c', '⌃').to('escape').to('japanese_eisuu')
    ]),
    map('h', '⌃').to('⌫'),
    // map('q', '⌘').toIfHeldDown('q', '⌘', {repeat: false}),
    map('q', '⌘').to('tab', '⌘', {repeat: false}),
    map('m', '⌘').toIfHeldDown('m', '⌘', {repeat: false}),
    map('h', '⌘').to('←'),
    map('j', '⌘').to('↓'),
    map('k', '⌘').to('↑'),
    map('l', '⌘').to('→'),
    map('i', ['⌘']).to('a', '⌃'),
    map('o', ['⌘']).to('e', '⌃'),
    // map('⌫', ['⌃']).to('⌦'),
    // map('h', ['⇧', '⌘']).to('a', '⌃'),
    // map('l', ['⇧', '⌘']).to('e', '⌃'),
    map(',', ['⌘', '⇧']).to(',', '⌘'),
    withCondition(ifApp(['^com.jetbrains.[\\w-]+$', '^com\\.tinyapp\\.TablePlus$']).unless())([
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
      map('s', '⌘').to('s', ['⌘']).to('[', ['⌃']),
    ]),
    withCondition(ifApp(['^com\\.apple\\.finder$', '^com\\.cocoatech\\.PathFinder$']))([
      map('j', '⌘').to('close_bracket', ['⌘', '⇧']),
      map('k', '⌘').to('open_bracket', ['⌘', '⇧']),
      map('n', '⌃').to('down_arrow'),
      map('p', '⌃').to('up_arrow'),
      map('b', '⌃').to('left_arrow'),
      map('f', '⌃').to('right_arrow'),
    ]),
    withCondition(ifApp(['^com\\.tinyapp\\.TablePlus$']))([
      // map('.', '⌘').to('close_bracket', ['⌘']),
      // map(',', '⌘').to('open_bracket', ['⌘']),
      map('.', '⌘').to(']', ['⌘']),
      map(',', '⌘').to('[', ['⌘']),
    ]),
  ])
}

const ruleBuildInKeyboard = () => {
  return rule("buildIn")
    .condition(
      ifDevice({is_built_in_keyboard: true}))
    .manipulators([
      // map('semicolon').to('left_control').toIfAlone('return_or_enter'),
      map('return_or_enter').to('left_control').toIfAlone('return_or_enter'),
      map('left_command').to('left_command').toIfAlone('spacebar'),
      // map('left_option').to('left_option').toIfAlone('tab'),
      // map('tab').to('left_option').toIfAlone('tab'),
      map('left_option').to('left_option').toIfAlone('tab'),
      map('left_option', 'right_shift').to('tab', 'shift'),
      map('right_command').to("right_option").toIfAlone('delete_or_backspace'),
      map('delete_or_backspace').to("right_option").toIfAlone('delete_or_backspace'),
      mapDoubleTap(',').to(toSymbol[':']),
      map('semicolon', 'shift').to('return_or_enter', 'shift'),
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
      // cmd + del to ctrl + k
      map('delete_forward', '⌘').to('k', ['⌃']),
      // for alfred
      map('delete_or_backspace', ['⌃', '⌘']).to('japanese_eisuu').to('delete_or_backspace', ['⌃', '⌘']),
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
    mapDoubleTap('s', '⌥').to(toKey('0', ['left_shift'])).singleTap(toKey('9', ['left_shift'])),
    mapDoubleTap('d', '⌥').to(toSymbol[']']).singleTap(toKey('open_bracket')),
    map('f', '⌥').to(toSymbol['-']),
    map('g', '⌥').to(toSymbol['=']),
    map('h', '⌥').to('←'),
    map('j', '⌥').to('↓'),
    map('k', '⌥').to('↑'),
    map('l', '⌥').to('→'),
    map('z', '⌥').to(toSymbol['\"']),
    mapDoubleTap('x', '⌥').to(toKey('close_bracket', ['left_shift'])).singleTap(toKey('open_bracket', ['left_shift'])),
    mapDoubleTap('c', '⌥').to(toSymbol['>']).singleTap(toKey('comma', ['left_shift'])),
    map('v', '⌥').to(toSymbol['\'']),
    map('b', '⌥').to(toSymbol['\"']),
    map('n', '⌥').to(toSymbol['|']),
    map('m', '⌥').to(toSymbol['_']),
    map('/', '⌥').to(toSymbol['\\']),
    map(';', '⌥').to(toSymbol[';']),
    map('return_or_enter', '⌥').to(toSymbol[';']),
    withCondition(ifApp(['^com.jetbrains.[\\w-]+$']).unless())([
      map(',', '⌥').to(toSymbol['[']),
      map('.', '⌥').to(toSymbol[']']),
    ]),
  ])
}

const jkSimultaneous = () => mapSimultaneous(['j', 'k']).to('japanese_eisuu');

const ruleIme = () => {
  return rule('Ime').manipulators([
    // map('f16').to('japanese_kana'), // for QMK
    map('escape').to('escape').to('japanese_eisuu'), // for QMK
    withCondition(ifInputSource({language: 'ja'}))([
      map('slash').to('hyphen'),
      map('hyphen').to('slash'),
      map('return_or_enter', '⌃').to('semicolon', '⌃'),
      // for iterm2
      map('u', ['⌃', '⌘']).to('u', ['⌃', '⌘']).to('japanese_eisuu'),
      map('n', ['⌘']).to('n', ['⌘']).to('japanese_eisuu'),
    ]),
    // IME ON
    mapSimultaneous(['d', 'f']).to('japanese_kana'),
    // IME OFF
    withCondition(
      ifInputSource({language: 'ja'}))([
      jkSimultaneous(),
    ]),
    // jk で IME:OFFだったらESCAPE
    withCondition(
      ifInputSource({language: 'ja'}).unless())([
      mapSimultaneous(['j', 'k']).to('escape')
      // mapSimultaneous(['j', 'k']).to('open_bracket', '⌃')
    ]),
  ])
}

main();
