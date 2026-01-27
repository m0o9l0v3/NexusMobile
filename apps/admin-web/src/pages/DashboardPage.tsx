import { Card, CardContent, Grid, Typography } from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { fetchEvents, fetchOcDays, fetchSpots } from '../api/admin';

export function DashboardPage() {
  const spotsQuery = useQuery({ queryKey: ['spots'], queryFn: fetchSpots });
  const eventsQuery = useQuery({ queryKey: ['events'], queryFn: fetchEvents });
  const ocDaysQuery = useQuery({ queryKey: ['oc-days'], queryFn: fetchOcDays });

  const today = new Date();
  const todayIso = today.toISOString().split('T')[0];
  const todayOcDay = ocDaysQuery.data?.find((item) => item.date === todayIso);
  const lastSpotUpdate = spotsQuery.data
    ? spotsQuery.data.reduce((latest, spot) => (spot.updatedAt > latest ? spot.updatedAt : latest), '1970-01-01T00:00:00Z')
    : null;

  return (
    <Grid container spacing={3}>
      <Grid item xs={12} md={4}>
        <Card>
          <CardContent>
            <Typography variant="subtitle1">スポット数</Typography>
            <Typography variant="h4">{spotsQuery.data?.length ?? '-'}</Typography>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} md={4}>
        <Card>
          <CardContent>
            <Typography variant="subtitle1">イベント数</Typography>
            <Typography variant="h4">{eventsQuery.data?.length ?? '-'}</Typography>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} md={4}>
        <Card>
          <CardContent>
            <Typography variant="subtitle1">オープンキャンパス日程</Typography>
            <Typography variant="h4">{ocDaysQuery.data?.length ?? '-'}</Typography>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} md={6}>
        <Card>
          <CardContent>
            <Typography variant="subtitle1">本日のオープンキャンパス</Typography>
            <Typography variant="h5">{todayOcDay?.name ?? '該当なし'}</Typography>
            <Typography variant="body2" color="text.secondary">
              {todayOcDay?.date ?? todayIso}
            </Typography>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} md={6}>
        <Card>
          <CardContent>
            <Typography variant="subtitle1">スポット最終更新</Typography>
            <Typography variant="h5">{lastSpotUpdate ? new Date(lastSpotUpdate).toLocaleString('ja-JP') : '-'}</Typography>
          </CardContent>
        </Card>
      </Grid>
    </Grid>
  );
}
