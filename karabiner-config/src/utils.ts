import {toKey} from "karabiner.ts";

export const toSymbol = {
  '!': toKey(1, '⇧'),
  '@': toKey(2, '⇧'),
  '#': toKey(3, '⇧'),
  $: toKey(4, '⇧'),
  '%': toKey(5, '⇧'),
  '^': toKey(6, '⇧'),
  '&': toKey(7, '⇧'),
  '*': toKey(8, '⇧'),
  '(': toKey(9, '⇧'),
  ')': toKey(0, '⇧'),

  '[': toKey('['),
  ']': toKey(']'),
  '{': toKey('[', '⇧'),
  '}': toKey(']', '⇧'),

  '-': toKey('-'),
  '=': toKey('='),
  _: toKey('-', '⇧'),
  '+': toKey('=', '⇧'),

  ';': toKey(';'),
  '/': toKey('/'),
  ':': toKey(';', '⇧'),
  '?': toKey('/', '⇧'),

  '\\': toKey('\\'),
  '|': toKey('\\', '⇧'),

  ',': toKey(','),
  '.': toKey('.'),
  '<': toKey(',', '⇧'),
  '>': toKey('.', '⇧'),

  '\'': toKey('quote'),
  '\"': toKey('quote', '⇧'),

  '`': toKey('`'),
  '~': toKey('`', '⇧'),
}

