import type { CheckinProfile, CheckinProfileData } from "../types";

const CHECKIN_PROFILE_KEY = "nexus.profile.v1";

export const loadCheckinProfile = (): CheckinProfile | null => {
  try {
    const raw = localStorage.getItem(CHECKIN_PROFILE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as CheckinProfile;
    if (!parsed?.checkedIn || !parsed.profile) return null;
    return parsed;
  } catch {
    return null;
  }
};

export const saveCheckinProfile = (profile: CheckinProfile): void => {
  localStorage.setItem(CHECKIN_PROFILE_KEY, JSON.stringify(profile));
};

export const buildCheckinProfile = (
  data: CheckinProfileData,
  sessionId?: string,
  checkedAt = new Date().toISOString(),
): CheckinProfile => ({
  checkedIn: true,
  profile: data,
  sessionId,
  checkedAt,
});

export const clearCheckinProfile = (): void => {
  localStorage.removeItem(CHECKIN_PROFILE_KEY);
};

export const isCheckedIn = (): boolean => Boolean(loadCheckinProfile()?.checkedIn);

export const CHECKIN_PROFILE_KEY_NAME = CHECKIN_PROFILE_KEY;
