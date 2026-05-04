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
import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { createQrIssue, fetchEvent, fetchEventTimeslots, fetchQrIssues, revokeQrIssue } from '../../api/admin';
import { queryClient } from '../../api/queryClient';
import { FeedbackSnackbar } from '../../components/FeedbackSnackbar';
import { ConfirmDialog } from '../../components/ConfirmDialog';

export function EventQrIssuesPage() {
  const { id = '' } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [selectedTimeslotId, setSelectedTimeslotId] = useState('');
  const [expiresAt, setExpiresAt] = useState('');
  const [issuedUrl, setIssuedUrl] = useState<string | null>(null);
  const [selectedIssueId, setSelectedIssueId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ message: string; severity: 'success' | 'error' } | null>(null);

  const { data: eventItem } = useQuery({
    queryKey: ['event', id],
    queryFn: () => fetchEvent(id),
    enabled: Boolean(id),
  });

  const { data: timeslots = [] } = useQuery({
    queryKey: ['event-timeslots', id],
    queryFn: () => fetchEventTimeslots(id),
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
      setFeedback({ message: 'QR issued.', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const revokeMutation = useMutation({
    mutationFn: (qrIssueId: string) => revokeQrIssue(qrIssueId, null),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['qr-issues', id] });
      setFeedback({ message: 'QR revoked.', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const now = useMemo(() => new Date(), []);

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Typography variant="h5">QR Issues</Typography>
        <Button variant="outlined" onClick={() => navigate('/events')}>
          Back
        </Button>
      </Box>

      <Typography variant="subtitle1">{eventItem?.title ?? 'Event'}</Typography>

      <Card>
        <CardContent sx={{ display: 'grid', gap: 2 }}>
          <Typography variant="subtitle1">Create QR</Typography>
          <FormControl fullWidth>
            <InputLabel id="timeslot-select">Timeslot</InputLabel>
            <Select
              labelId="timeslot-select"
              label="Timeslot"
              value={selectedTimeslotId}
              onChange={(event) => setSelectedTimeslotId(event.target.value)}
            >
              {timeslots.map((timeslot) => (
                <MenuItem key={timeslot.id} value={timeslot.id}>
                  {new Date(timeslot.startsAt).toLocaleString('en-US')} - {new Date(timeslot.endsAt).toLocaleTimeString('en-US')}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          <TextField
            label="Expiry"
            type="datetime-local"
            InputLabelProps={{ shrink: true }}
            value={expiresAt}
            onChange={(event) => setExpiresAt(event.target.value)}
          />

          <Button variant="contained" disabled={!selectedTimeslotId} onClick={() => createMutation.mutate()}>
            Issue
          </Button>

          {issuedUrl && (
            <Box sx={{ display: 'grid', gap: 1 }}>
              <Typography variant="subtitle2">Issued URL</Typography>
              <TextField value={issuedUrl} fullWidth InputProps={{ readOnly: true }} />
              <Button
                variant="outlined"
                onClick={async () => {
                  await navigator.clipboard.writeText(issuedUrl);
                  setFeedback({ message: 'URL copied.', severity: 'success' });
                }}
              >
                Copy
              </Button>
            </Box>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <Typography variant="subtitle1" sx={{ mb: 2 }}>
            Issued Codes
          </Typography>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Timeslot</TableCell>
                <TableCell>Expiry</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Scans</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {qrIssues.map((issue) => {
                const isRevoked = Boolean(issue.revokedAt);
                const isExpired = new Date(issue.expiresAt) < now;
                const statusLabel = isRevoked ? 'Revoked' : isExpired ? 'Expired' : 'Active';
                const statusColor = isRevoked ? 'default' : isExpired ? 'warning' : 'success';

                return (
                  <TableRow key={issue.qrIssueId} hover>
                    <TableCell>
                      {issue.timeslot
                        ? `${new Date(issue.timeslot.startsAt).toLocaleString('en-US')} - ${new Date(issue.timeslot.endsAt).toLocaleTimeString('en-US')}`
                        : '-'}
                    </TableCell>
                    <TableCell>{new Date(issue.expiresAt).toLocaleString('en-US')}</TableCell>
                    <TableCell>
                      <Chip label={statusLabel} color={statusColor as 'default' | 'success' | 'warning'} />
                    </TableCell>
                    <TableCell>{issue.scanCount}</TableCell>
                    <TableCell align="right">
                      <Button size="small" color="error" disabled={isRevoked} onClick={() => setSelectedIssueId(issue.qrIssueId)}>
                        Revoke
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
        title="Revoke QR?"
        description="This QR code will no longer be valid."
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
