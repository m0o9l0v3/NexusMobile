import { Card, CardContent, Table, TableBody, TableCell, TableHead, TableRow, Typography } from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { fetchRecentLogs } from '../api/admin';

export function LogsPage() {
  const { data = [] } = useQuery({ queryKey: ['logs'], queryFn: () => fetchRecentLogs(100) });

  return (
    <Card>
      <CardContent>
        <Typography variant="h5" sx={{ mb: 2 }}>
          最近のログ
        </Typography>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>発生日時</TableCell>
              <TableCell>イベント</TableCell>
              <TableCell>スポットコード</TableCell>
              <TableCell>セッションID</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {data.map((log) => (
              <TableRow key={log.id}>
                <TableCell>{new Date(log.occurredAt).toLocaleString('ja-JP')}</TableCell>
                <TableCell>{log.eventType}</TableCell>
                <TableCell>{log.spotCode ?? '-'}</TableCell>
                <TableCell>{log.sessionId}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
