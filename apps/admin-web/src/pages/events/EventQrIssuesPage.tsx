import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { useMutation, useQuery } from '@tanstack/react-query';
import { createQrIssue, fetchEvent, fetchEventTimeslots, fetchQrIssues, revokeQrIssue } from '../../api/admin';
import { queryClient } from '../../api/queryClient';
import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { FeedbackSnackbar } from '../../components/FeedbackSnackbar';
import { ConfirmDialog } from '../../components/ConfirmDialog';

export function EventQrIssuesPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [selectedTimeslotId, setSelectedTimeslotId] = useState('');
  const [expiresAt, setExpiresAt] = useState('');
  const [issuedUrl, setIssuedUrl] = useState<string | null>(null);
  const [selectedIssueId, setSelectedIssueId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ message: string; severity: 'success' | 'error' } | null>(null);

  const { data: eventItem } = useQuery({
    queryKey: ['event', id],
    queryFn: () => fetchEvent(id ?? ''),
    enabled: Boolean(id),
  });

  const { data: timeslots = [] } = useQuery({
    queryKey: ['event-timeslots', id],
    queryFn: () => fetchEventTimeslots(id ?? ''),
    enabled: Boolean(id),
  });

  const { data: qrIssues = [] } = useQuery({
    queryKey: ['qr-issues', id],
    queryFn: () => fetchQrIssues(id),
    enabled: Boolean(id),
  });

  const createMutation = useMutation({
    mutationFn: () => createQrIssue(selectedTimeslotId, expiresAt ? new Date(expiresAt).toISOString() : null),
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['qr-issues', id] });
      setIssuedUrl(data?.url ?? null);
      setFeedback({ message: 'QRを発行しました。', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const revokeMutation = useMutation({
    mutationFn: (qrIssueId: string) => revokeQrIssue(qrIssueId, null),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['qr-issues', id] });
      setFeedback({ message: 'QRを失効しました。', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const now = useMemo(() => new Date(), []);

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Typography variant="h5">QR発行</Typography>
        <Button variant="outlined" onClick={() => navigate('/events')}>
          戻る
        </Button>
      </Box>
      <Typography variant="subtitle1">{eventItem?.title ?? 'イベント'}</Typography>
      <Card>
        <CardContent sx={{ display: 'grid', gap: 2 }}>
          <Typography variant="subtitle1">QR発行</Typography>
          <FormControl fullWidth>
            <InputLabel id="timeslot-select">タイムスロット</InputLabel>
            <Select
              labelId="timeslot-select"
              label="タイムスロット"
              value={selectedTimeslotId}
              onChange={(event) => setSelectedTimeslotId(event.target.value)}
            >
              {timeslots.map((timeslot) => (
                <MenuItem key={timeslot.id} value={timeslot.id}>
                  {new Date(timeslot.startsAt).toLocaleString('ja-JP')} - {new Date(timeslot.endsAt).toLocaleTimeString('ja-JP')}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField
            label="有効期限"
            type="datetime-local"
            InputLabelProps={{ shrink: true }}
            value={expiresAt}
            onChange={(event) => setExpiresAt(event.target.value)}
            helperText="未指定の場合は当日23:59:59(+09:00)まで"
          />
          <Button variant="contained" disabled={!selectedTimeslotId} onClick={() => createMutation.mutate()}>
            発行
          </Button>
          {issuedUrl && (
            <Box sx={{ display: 'grid', gap: 1 }}>
              <Typography variant="subtitle2">発行URL</Typography>
              <TextField value={issuedUrl} fullWidth InputProps={{ readOnly: true }} />
              <Button
                variant="outlined"
                onClick={async () => {
                  await navigator.clipboard.writeText(issuedUrl);
                  setFeedback({ message: 'URLをコピーしました。', severity: 'success' });
                }}
              >
                コピー
              </Button>
            </Box>
          )}
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <Typography variant="subtitle1" sx={{ mb: 2 }}>
            発行履歴
          </Typography>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>タイムスロット</TableCell>
                <TableCell>有効期限</TableCell>
                <TableCell>状態</TableCell>
                <TableCell>スキャン数</TableCell>
                <TableCell align="right">操作</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {qrIssues.map((issue) => {
                const isRevoked = Boolean(issue.revokedAt);
                const isExpired = new Date(issue.expiresAt) < now;
                const statusLabel = isRevoked ? '失効' : isExpired ? '期限切れ' : '有効';
                const statusColor = isRevoked ? 'default' : isExpired ? 'warning' : 'success';
                return (
                  <TableRow key={issue.qrIssueId} hover>
                    <TableCell>
                      {issue.timeslot
                        ? `${new Date(issue.timeslot.startsAt).toLocaleString('ja-JP')} - ${new Date(issue.timeslot.endsAt).toLocaleTimeString('ja-JP')}`
                        : '-'}
                    </TableCell>
                    <TableCell>{new Date(issue.expiresAt).toLocaleString('ja-JP')}</TableCell>
                    <TableCell>
                      <Chip label={statusLabel} color={statusColor as 'default' | 'success' | 'warning'} />
                    </TableCell>
                    <TableCell>{issue.scanCount}</TableCell>
                    <TableCell align="right">
                      <Button
                        size="small"
                        color="error"
                        disabled={isRevoked}
                        onClick={() => setSelectedIssueId(issue.qrIssueId)}
                      >
                        失効
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
      <ConfirmDialog
        open={Boolean(selectedIssueId)}
        title="QRを失効しますか？"
        description="失効すると元に戻せません。"
        onCancel={() => setSelectedIssueId(null)}
        onConfirm={() => {
          if (selectedIssueId) {
            revokeMutation.mutate(selectedIssueId);
            setSelectedIssueId(null);
          }
        }}
      />
      <FeedbackSnackbar
        open={Boolean(feedback)}
        message={feedback?.message ?? ''}
        severity={feedback?.severity ?? 'success'}
        onClose={() => setFeedback(null)}
      />
    </Box>
  );
}
