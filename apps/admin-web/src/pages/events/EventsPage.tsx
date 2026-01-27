import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { useMutation, useQuery } from '@tanstack/react-query';
import { deleteEvent, fetchEvents, publishEvent } from '../../api/admin';
import { queryClient } from '../../api/queryClient';
import { useNavigate } from 'react-router-dom';
import { useState } from 'react';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { FeedbackSnackbar } from '../../components/FeedbackSnackbar';

export function EventsPage() {
  const navigate = useNavigate();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ message: string; severity: 'success' | 'error' } | null>(null);

  const { data = [] } = useQuery({ queryKey: ['events'], queryFn: fetchEvents });

  const deleteMutation = useMutation({
    mutationFn: deleteEvent,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['events'] });
      setFeedback({ message: 'イベントを削除しました。', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const publishMutation = useMutation({
    mutationFn: ({ id, isPublished }: { id: string; isPublished: boolean }) => publishEvent(id, isPublished),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['events'] });
      setFeedback({ message: '公開状態を更新しました。', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h5">イベント管理</Typography>
        <Button variant="contained" onClick={() => navigate('/events/new')}>
          新規イベント
        </Button>
      </Box>
      <Card>
        <CardContent>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>タイトル</TableCell>
                <TableCell>開始</TableCell>
                <TableCell>終了</TableCell>
                <TableCell>公開</TableCell>
                <TableCell align="right">操作</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {data.map((event) => (
                <TableRow key={event.id} hover>
                  <TableCell>{event.title}</TableCell>
                  <TableCell>{new Date(event.startsAt).toLocaleString('ja-JP')}</TableCell>
                  <TableCell>{new Date(event.endsAt).toLocaleString('ja-JP')}</TableCell>
                  <TableCell>
                    <Chip label={event.isPublished ? '公開中' : '非公開'} color={event.isPublished ? 'success' : 'default'} />
                  </TableCell>
                  <TableCell align="right" sx={{ display: 'flex', gap: 1, justifyContent: 'flex-end' }}>
                    <Button size="small" onClick={() => navigate(`/events/${event.id}/edit`)}>
                      編集
                    </Button>
                    <Button size="small" onClick={() => navigate(`/events/${event.id}/qr-issues`)}>
                      QR発行
                    </Button>
                    <Button
                      size="small"
                      variant="outlined"
                      onClick={() => publishMutation.mutate({ id: event.id, isPublished: !event.isPublished })}
                    >
                      {event.isPublished ? '非公開' : '公開'}
                    </Button>
                    <Button size="small" color="error" onClick={() => setSelectedId(event.id)}>
                      削除
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
      <ConfirmDialog
        open={Boolean(selectedId)}
        title="イベントを削除しますか？"
        description="削除すると元に戻せません。"
        onCancel={() => setSelectedId(null)}
        onConfirm={() => {
          if (selectedId) {
            deleteMutation.mutate(selectedId);
            setSelectedId(null);
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
