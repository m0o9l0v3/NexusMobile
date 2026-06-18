import type { FloorMap } from '@nexus/shared';
import type { MapSpot, RouteInfo } from '../../types/navigation';

export const fallbackSpots: MapSpot[] = [
  { id: '1', name: '受付', floor: '1F', x: 30, y: 40, congestion: 'normal', category: '案内', tags: ['案内所', '配布物'], relatedEvents: 2 },
  { id: '2', name: '講義室A', floor: '1F', x: 50, y: 50, congestion: 'busy', category: '教室', tags: ['大教室', '収容200名'], relatedEvents: 3 },
  { id: '3', name: '図書館', floor: '2F', x: 40, y: 35, congestion: 'empty', category: '施設', tags: ['静か', '自習可'], relatedEvents: 0 },
  { id: '4', name: 'カフェテリア', floor: '2F', x: 60, y: 60, congestion: 'full', category: '食堂', tags: ['学生食堂', '休憩'], relatedEvents: 1 },
  { id: '5', name: '階段A', floor: '1F', x: 70, y: 30, congestion: 'normal', category: '移動', tags: ['移動'], relatedEvents: 0 },
  { id: '6', name: '階段A', floor: '2F', x: 70, y: 30, congestion: 'normal', category: '移動', tags: ['移動'], relatedEvents: 0 },
  { id: '7', name: '入口', floor: '1F', x: 20, y: 60, congestion: 'busy', category: '案内', tags: ['正門', '集合場所'], relatedEvents: 1 },
  { id: '8', name: '体育館', floor: 'B1', x: 50, y: 50, congestion: 'empty', category: '施設', tags: ['広い', 'イベント会場'], relatedEvents: 0 },
  { id: '9', name: '実験室B', floor: '3F', x: 45, y: 45, congestion: 'normal', category: '教室', tags: ['少人数', '実習可'], relatedEvents: 1 },
  { id: '10', name: 'ラウンジ', floor: '3F', x: 65, y: 55, congestion: 'empty', category: '施設', tags: ['休憩', 'Wi-Fi'], relatedEvents: 0 },
];

export const fallbackFloors: FloorMap[] = [
  { id: 'outdoor', name: 'Outdoor', width: 320, height: 220 },
  { id: 'b1', name: 'B1', width: 320, height: 220 },
  { id: '1f', name: '1F', width: 320, height: 220 },
  { id: '2f', name: '2F', width: 320, height: 220 },
  { id: '3f', name: '3F', width: 320, height: 220 },
];

export const fallbackRoute: RouteInfo = {
  distance: 180,
  duration: 3,
  nextFloor: '2F',
  nextLandmark: '階段A',
  steps: [
    { floor: '1F', landmark: '受付から階段Aへ', distance: 80 },
    { floor: '2F', landmark: '階段Aから目的地へ', distance: 100 },
  ],
};
