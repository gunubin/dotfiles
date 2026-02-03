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
    map('q', 'right_option').to(toSymbol['!']),
    map('w', 'right_option').to(toSymbol['@']),
    map('e', 'right_option').to(toSymbol['#']),
    map('r', 'right_option').to(toSymbol['$']),
    map('t', 'right_option').to(toSymbol['%']),
    map('y', 'right_option').to(toSymbol['^']),
    map('u', 'right_option').to(toSymbol['&']),
    map('i', 'right_option').to(toSymbol['*']),
    map('o', 'right_option').to(toSymbol['`']),
    map('p', 'right_option').to(toSymbol['~']),

    map('a', 'right_option').to(toSymbol['+']),
    mapDoubleTap('s', 'right_option').to(toKey('0', ['left_shift'])).singleTap(toKey('9', ['left_shift'])),
    mapDoubleTap('d', 'right_option').to(toSymbol[']']).singleTap(toKey('open_bracket')),
    map('f', 'right_option').to(toSymbol['-']),
    map('g', 'right_option').to(toSymbol['=']),
    map('h', 'right_option').to('←'),
    map('j', 'right_option').to('↓'),
    map('k', 'right_option').to('↑'),
    map('l', 'right_option').to('→'),
    map('z', 'right_option').to(toSymbol['\"']),
    mapDoubleTap('x', 'right_option').to(toKey('close_bracket', ['left_shift'])).singleTap(toKey('open_bracket', ['left_shift'])),
    mapDoubleTap('c', 'right_option').to(toSymbol['>']).singleTap(toKey('comma', ['left_shift'])),
    map('v', 'right_option').to(toSymbol['\'']),
    map('b', 'right_option').to(toSymbol['\"']),
    map('n', 'right_option').to(toSymbol['|']),
    map('m', 'right_option').to(toSymbol['_']),
    map('/', 'right_option').to(toSymbol['\\']),
    map(';', 'right_option').to(toSymbol[';']),
    map('return_or_enter', 'right_option').to(toSymbol[';']),
    withCondition(ifApp(['^com.jetbrains.[\\w-]+$']).unless())([
      map(',', 'right_option').to(toSymbol['[']),
      map('.', 'right_option').to(toSymbol[']']),
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
