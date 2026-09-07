import { getEventStatus, getFeaturedEvent, getStartGuide, sortEventsByTime } from '../src/data/openCampus';
import type { CampusEvent } from '../src/types/events';

const first: CampusEvent = {
  id: 'first', title: '学校説明', time: '10:00', endTime: '10:30', location: '講義室', department: '全体',
};
const second: CampusEvent = { ...first, id: 'second', time: '11:00', endTime: '11:30' };
const now = (time: string) => new Date(`2026-09-05T${time}:00`);

test.each([
  ['09:59', 'next'], ['10:00', 'live'], ['10:29', 'live'], ['10:30', 'ended'],
])('開始・終了の境界 %s でイベントを %s と判定する', (time, expected) => {
  expect(getEventStatus(first, [second, first], now(time))).toBe(expected);
});

test('次のイベントだけを next にし、後続イベントを upcoming にする', () => {
  expect(getEventStatus(second, [second, first], now('09:00'))).toBe('upcoming');
  expect(getEventStatus(second, [second, first], now('10:30'))).toBe('next');
});

test('時刻不明のイベントを末尾へ置き、呼び出し元の配列順序を保持する', () => {
  const unknown = { ...first, id: 'unknown', time: '--:--' };
  const input = [second, unknown, first];
  expect(sortEventsByTime(input).map(event => event.id)).toEqual(['first', 'second', 'unknown']);
  expect(input.map(event => event.id)).toEqual(['second', 'unknown', 'first']);
  expect(getStartGuide(unknown, now('09:00'))).toBe('開始時刻を確認してください');
});

test('開催中のイベントを優先表示し、イベントがなければ未選択とする', () => {
  expect(getFeaturedEvent([second, first], now('10:15'))?.id).toBe('first');
  expect(getFeaturedEvent([], now('10:15'))).toBeUndefined();
});
