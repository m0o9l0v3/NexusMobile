import { fireEvent, render, screen } from '@testing-library/react-native';
import { MapSearchOverlay } from '../src/components/map/MapSearchOverlay';
import type { MapSpot } from '../src/types/navigation';

const spots: MapSpot[] = [
  { id: 'current', name: '現在地', category: '現在地', floor: '1F', x: 0, y: 0, congestion: 'normal', kind: 'current' },
  { id: 'lab', name: '情報実習室', category: '実習', floor: '2F', x: 1, y: 1, congestion: 'empty', tags: ['PC', 'プログラミング'] },
  { id: 'reception', name: '受付', category: '案内', floor: '1F', x: 2, y: 2, congestion: 'busy' },
];

function renderSearch(isOpen = true) {
  const onClose = jest.fn();
  const onSelectSpot = jest.fn();
  render(<MapSearchOverlay isOpen={isOpen} spots={spots} onClose={onClose} onSelectSpot={onSelectSpot} />);
  return { onClose, onSelectSpot };
}

test('閉じている間は検索入力と検索結果を表示しない', () => {
  renderSearch(false);
  expect(screen.queryByPlaceholderText('場所・教室・イベントを検索')).toBeNull();
  expect(screen.queryByText('情報実習室')).toBeNull();
});

test('初期候補から現在地を除き、タグを大文字小文字・前後の空白を無視して検索する', () => {
  renderSearch();
  expect(screen.getByText('情報実習室')).toBeOnTheScreen();
  expect(screen.getByText('受付')).toBeOnTheScreen();
  expect(screen.queryByText('現在地')).toBeNull();

  fireEvent.changeText(screen.getByPlaceholderText('場所・教室・イベントを検索'), ' pc ');
  expect(screen.getByText('情報実習室')).toBeOnTheScreen();
  expect(screen.queryByText('受付')).toBeNull();
});

test('検索結果を押すと対象スポットを返して検索を閉じる', () => {
  const { onClose, onSelectSpot } = renderSearch();
  fireEvent.press(screen.getByText('情報実習室'));
  expect(onSelectSpot).toHaveBeenCalledTimes(1);
  expect(onSelectSpot).toHaveBeenCalledWith(spots[1]);
  expect(onClose).toHaveBeenCalledTimes(1);
});

test('一致しない検索では受付の案内を表示し、入力を消すと候補を復元する', () => {
  renderSearch();
  const input = screen.getByPlaceholderText('場所・教室・イベントを検索');
  fireEvent.changeText(input, '存在しない教室');
  expect(screen.getByText('見つからない場合は受付でご確認ください。')).toBeOnTheScreen();
  expect(screen.queryByText('情報実習室')).toBeNull();
  fireEvent.changeText(input, '');
  expect(screen.queryByText('見つからない場合は受付でご確認ください。')).toBeNull();
  expect(screen.getByText('情報実習室')).toBeOnTheScreen();
});
