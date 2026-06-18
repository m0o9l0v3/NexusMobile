export type CampusEvent = {
  id: string;
  title: string;
  time: string;
  endTime?: string;
  location: string;
  floor?: string;
  department: string;
  category?: string;
  description?: string;
};

export type TodayEventResponse = {
  id: string;
  title: string;
  description?: string | null;
  startTime: string;
  endTime: string;
  location?: string | null;
  tags?: string[];
};
