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
import { useMemo, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { deleteSpot, fetchSpots, publishSpot } from '../../api/admin';
import { queryClient } from '../../api/queryClient';
import { FeedbackSnackbar } from '../../components/FeedbackSnackbar';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useNavigate } from 'react-router-dom';

export function SpotsPage() {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [publishFilter, setPublishFilter] = useState('all');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ message: string; severity: 'success' | 'error' } | null>(null);

  const { data = [] } = useQuery({ queryKey: ['spots'], queryFn: fetchSpots });

  const deleteMutation = useMutation({
    mutationFn: deleteSpot,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['spots'] });
      setFeedback({ message: 'スポットを削除しました。', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const publishMutation = useMutation({
    mutationFn: ({ id, isPublished }: { id: string; isPublished: boolean }) => publishSpot(id, isPublished),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['spots'] });
      setFeedback({ message: '公開状態を更新しました。', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const filtered = useMemo(() => {
    return data.filter((spot) => {
      const matchesSearch =
        spot.code.toLowerCase().includes(search.toLowerCase()) ||
        spot.name.toLowerCase().includes(search.toLowerCase());
      const matchesPublish =
        publishFilter === 'all' ||
        (publishFilter === 'published' && spot.isPublished) ||
        (publishFilter === 'unpublished' && !spot.isPublished);
      return matchesSearch && matchesPublish;
    });
  }, [data, search, publishFilter]);

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h5">スポット管理</Typography>
        <Button variant="contained" onClick={() => navigate('/spots/new')}>
          新規スポット
        </Button>
      </Box>
      <Card>
        <CardContent sx={{ display: 'grid', gap: 2 }}>
          <Box sx={{ display: 'flex', gap: 2 }}>
            <TextField
              label="検索"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
            <FormControl sx={{ minWidth: 180 }}>
              <InputLabel id="publish-filter">公開状態</InputLabel>
              <Select
                labelId="publish-filter"
                value={publishFilter}
                label="公開状態"
                onChange={(event) => setPublishFilter(event.target.value)}
              >
                <MenuItem value="all">すべて</MenuItem>
                <MenuItem value="published">公開中</MenuItem>
                <MenuItem value="unpublished">非公開</MenuItem>
              </Select>
            </FormControl>
          </Box>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>コード</TableCell>
                <TableCell>名称</TableCell>
                <TableCell>更新日時</TableCell>
                <TableCell>公開</TableCell>
                <TableCell align="right">操作</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filtered.map((spot) => (
                <TableRow key={spot.id} hover>
                  <TableCell>{spot.code}</TableCell>
                  <TableCell>{spot.name}</TableCell>
                  <TableCell>{new Date(spot.updatedAt).toLocaleString('ja-JP')}</TableCell>
                  <TableCell>
                    <Chip label={spot.isPublished ? '公開中' : '非公開'} color={spot.isPublished ? 'success' : 'default'} />
                  </TableCell>
                  <TableCell align="right" sx={{ display: 'flex', gap: 1, justifyContent: 'flex-end' }}>
                    <Button size="small" onClick={() => navigate(`/spots/${spot.id}`)}>
                      詳細
                    </Button>
                    <Button size="small" onClick={() => navigate(`/spots/${spot.id}/edit`)}>
                      編集
                    </Button>
                    <Button
                      size="small"
                      variant="outlined"
                      onClick={() =>
                        publishMutation.mutate({ id: spot.id, isPublished: !spot.isPublished })
                      }
                    >
                      {spot.isPublished ? '非公開' : '公開'}
                    </Button>
                    <Button size="small" color="error" onClick={() => setSelectedId(spot.id)}>
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
        title="スポットを削除しますか？"
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
