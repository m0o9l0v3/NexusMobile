import {
  Box,
  Button,
  Card,
  CardContent,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { useMutation, useQuery } from '@tanstack/react-query';
import { createOcDay, deleteOcDay, fetchOcDays } from '../../api/admin';
import { queryClient } from '../../api/queryClient';
import { useState } from 'react';
import { FeedbackSnackbar } from '../../components/FeedbackSnackbar';
import { ConfirmDialog } from '../../components/ConfirmDialog';

export function OcDaysPage() {
  const { data = [] } = useQuery({ queryKey: ['oc-days'], queryFn: fetchOcDays });
  const [date, setDate] = useState('');
  const [name, setName] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ message: string; severity: 'success' | 'error' } | null>(null);

  const createMutation = useMutation({
    mutationFn: () => createOcDay({ date, name: name || null }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['oc-days'] });
      setDate('');
      setName('');
      setFeedback({ message: 'オープンキャンパス日を登録しました。', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteOcDay,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['oc-days'] });
      setFeedback({ message: 'オープンキャンパス日を削除しました。', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Typography variant="h5">オープンキャンパス日程</Typography>
      <Card>
        <CardContent sx={{ display: 'grid', gap: 2 }}>
          <Typography variant="subtitle1">新規登録</Typography>
          <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
            <TextField
              label="日付"
              type="date"
              InputLabelProps={{ shrink: true }}
              value={date}
              onChange={(event) => setDate(event.target.value)}
            />
            <TextField
              label="名称"
              value={name}
              onChange={(event) => setName(event.target.value)}
            />
            <Button variant="contained" disabled={!date} onClick={() => createMutation.mutate()}>
              登録
            </Button>
          </Box>
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>日付</TableCell>
                <TableCell>名称</TableCell>
                <TableCell align="right">操作</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {data.map((item) => (
                <TableRow key={item.id} hover>
                  <TableCell>{item.date}</TableCell>
                  <TableCell>{item.name ?? '-'}</TableCell>
                  <TableCell align="right">
                    <Button color="error" onClick={() => setSelectedId(item.id)}>
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
        title="オープンキャンパス日を削除しますか？"
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
