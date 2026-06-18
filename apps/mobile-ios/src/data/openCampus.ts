import type { CampusEvent } from '../types/events';

export type EventStatus = 'live' | 'next' | 'upcoming' | 'ended';

export const openCampusEvents: CampusEvent[] = [
  {
    id: 'reception',
    title: '受付開始',
    time: '09:00',
    endTime: '09:30',
    location: '受付',
    floor: '1F',
    department: '全体',
    category: '受付',
    audience: '全来場者',
    priority: 'high',
    description: 'パンフレットを受け取り、今日の流れと困ったときの相談先を確認できます。',
    checkpoints: ['資料の受け取り', '今日の流れ', 'スタッフへの相談先'],
  },
  {
    id: 'school-briefing',
    title: '学校説明',
    time: '09:40',
    endTime: '10:10',
    location: '講義室',
    floor: '1F',
    department: '全体',
    category: '学校説明',
    audience: '学生・保護者',
    priority: 'high',
    description: '日本航空学園と北海道キャンパスでの学び、入学後の流れを確認できます。',
    checkpoints: ['学校の特色', '北海道キャンパスの学び', '入学後の流れ'],
  },
  {
    id: 'engineering-briefing',
    title: '工学部説明会',
    time: '10:20',
    endTime: '10:55',
    location: '講義室',
    floor: '1F',
    department: '航空・情報・ものづくり',
    category: '学科説明',
    audience: '進路検討中の学生・保護者',
    priority: 'high',
    description: '航空・情報・ものづくりをどのように学ぶのか、入学後の流れを確認できます。',
    checkpoints: ['学科ごとの学び', '実習の進め方', '将来の進路'],
  },
  {
    id: 'campus-tour',
    title: 'キャンパスツアー',
    time: '11:10',
    endTime: '11:50',
    location: '受付前集合',
    floor: '1F',
    department: '全体',
    category: 'ツアー',
    audience: '学生・保護者',
    priority: 'standard',
    description: '実習施設、教室、学生生活の動線を見ながら、入学後の一日をイメージできます。',
    checkpoints: ['実習施設', '教室の雰囲気', '学生生活の動線'],
  },
  {
    id: 'experience-class',
    title: '体験授業',
    time: '13:00',
    endTime: '13:50',
    location: '実習エリア',
    floor: '1F',
    department: '航空・情報・ものづくり',
    category: '体験授業',
    audience: '学生中心',
    priority: 'high',
    description: '実際の授業に近い体験を通じて、学ぶ内容とキャンパスの空気感を確認できます。',
    checkpoints: ['実習環境', '授業の雰囲気', '自分に合う学び方'],
  },
  {
    id: 'parent-consultation',
    title: '保護者向け個別相談',
    time: '14:00',
    endTime: '15:20',
    location: '相談会場',
    floor: '1F',
    department: '生活・進路',
    category: '相談',
    audience: '保護者',
    priority: 'support',
    description: '学費・生活・就職・寮について相談できます。',
    checkpoints: ['学費・奨学金', '寮・生活環境', '就職実績'],
  },
  {
    id: 'individual-consultation',
    title: '個別相談・質問タイム',
    time: '15:20',
    endTime: '16:00',
    location: '相談会場',
    floor: '1F',
    department: '全体',
    category: '相談',
    audience: '学生・保護者',
    priority: 'support',
    description: '進路、学校生活、通学や寮など、気になったことを個別に確認できます。',
    checkpoints: ['進路の不安', '学校生活', '受付・スタッフへの相談'],
  },
];

export const eventCategories = ['すべて', '学校説明', '学科説明', 'ツアー', '体験授業', '相談'];

export const eventDepartments = ['全体', '航空・情報・ものづくり', '生活・進路'];

export const checkItems = [
  '実習環境',
  '学科の学び',
  '学生生活',
  '寮・通学環境',
  '進路・就職',
  '個別相談',
];

const parseEventMinutes = (time: string | undefined): number | undefined => {
  if (!time) return undefined;
  const match = time.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return undefined;
  return Number(match[1]) * 60 + Number(match[2]);
};

const getCurrentMinutes = (now: Date): number => now.getHours() * 60 + now.getMinutes();

export const sortEventsByTime = (events: CampusEvent[]): CampusEvent[] => {
  return [...events].sort((a, b) => {
    return (parseEventMinutes(a.time) ?? Number.MAX_SAFE_INTEGER) - (parseEventMinutes(b.time) ?? Number.MAX_SAFE_INTEGER);
  });
};

export const getEventStatus = (event: CampusEvent, events: CampusEvent[], now = new Date()): EventStatus => {
  const current = getCurrentMinutes(now);
  const start = parseEventMinutes(event.time);
  const end = parseEventMinutes(event.endTime) ?? (start ? start + 30 : undefined);

  if (start !== undefined && end !== undefined && current >= start && current < end) {
    return 'live';
  }

  if (end !== undefined && current >= end) {
    return 'ended';
  }

  const nextEvent = sortEventsByTime(events).find((item) => {
    const itemStart = parseEventMinutes(item.time);
    const itemEnd = parseEventMinutes(item.endTime) ?? (itemStart ? itemStart + 30 : undefined);
    return itemStart !== undefined && (itemEnd === undefined || current < itemEnd);
  });

  return nextEvent?.id === event.id ? 'next' : 'upcoming';
};

export const getStatusLabel = (status: EventStatus): string => {
  switch (status) {
    case 'live':
      return '現在開催中';
    case 'next':
      return '次におすすめ';
    case 'ended':
      return '終了済み';
    default:
      return 'このあと';
  }
};

export const getStartGuide = (event: CampusEvent, now = new Date()): string => {
  const current = getCurrentMinutes(now);
  const start = parseEventMinutes(event.time);
  const end = parseEventMinutes(event.endTime);

  if (start === undefined) return '開始時刻を確認してください';
  if (end !== undefined && current >= start && current < end) return '開催中です';
  if (end !== undefined && current >= end) return '受付で次の案内をご確認ください';

  const remaining = start - current;
  if (remaining <= 0) return 'まもなく開始します';
  if (remaining < 60) return `開始まで約${remaining}分`;
  return `${event.time}開始`;
};

export const getFeaturedEvent = (events: CampusEvent[], now = new Date()): CampusEvent | undefined => {
  const sorted = sortEventsByTime(events);
  return (
    sorted.find((event) => getEventStatus(event, sorted, now) === 'live') ??
    sorted.find((event) => getEventStatus(event, sorted, now) === 'next') ??
    sorted.find((event) => event.id === 'individual-consultation') ??
    sorted[0]
  );
};

const profileByTitle = (event: CampusEvent): Pick<CampusEvent, 'audience' | 'checkpoints' | 'priority'> => {
  if (event.title.includes('保護者')) {
    return {
      audience: '保護者',
      priority: 'support',
      checkpoints: ['学費・奨学金', '寮・生活環境', '就職実績'],
    };
  }
  if (event.title.includes('ツアー')) {
    return {
      audience: '学生・保護者',
      priority: 'standard',
      checkpoints: ['実習施設', '教室の雰囲気', '学生生活の動線'],
    };
  }
  if (event.title.includes('体験') || event.title.includes('授業')) {
    return {
      audience: '学生中心',
      priority: 'high',
      checkpoints: ['実習環境', '授業の雰囲気', '自分に合う学び方'],
    };
  }
  if (event.title.includes('工学') || event.title.includes('学科')) {
    return {
      audience: '進路検討中の学生・保護者',
      priority: 'high',
      checkpoints: ['学科ごとの学び', '実習の進め方', '将来の進路'],
    };
  }
  if (event.title.includes('受付')) {
    return {
      audience: '全来場者',
      priority: 'high',
      checkpoints: ['資料の受け取り', '今日の流れ', 'スタッフへの相談先'],
    };
  }
  return {
    audience: '学生・保護者',
    priority: 'standard',
    checkpoints: ['内容の確認', '場所の確認', '気になる点の相談'],
  };
};

export const enrichCampusEvent = (event: CampusEvent): CampusEvent => {
  const fallback = profileByTitle(event);
  return {
    ...event,
    audience: event.audience ?? fallback.audience,
    checkpoints: event.checkpoints ?? fallback.checkpoints,
    priority: event.priority ?? fallback.priority,
  };
};

export const getSpotNameForEvent = (event: CampusEvent): string => {
  const location = event.location;
  if (location.includes('受付')) return '受付';
  if (location.includes('相談')) return '相談会場';
  if (location.includes('実習')) return '実習エリア';
  if (location.includes('講義')) return '講義室';
  if (location.includes('トイレ')) return 'トイレ';
  if (location.includes('出入口') || location.includes('入口')) return '出入口';
  return location;
};
