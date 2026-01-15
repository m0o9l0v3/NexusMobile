import {
  Box,
  Button,
  Card,
  CardContent,
  FormControlLabel,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQuery } from '@tanstack/react-query';
import { createSpot, fetchSpot, updateSpot } from '../../api/admin';
import { useNavigate, useParams } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { FeedbackSnackbar } from '../../components/FeedbackSnackbar';
import { queryClient } from '../../api/queryClient';

const schema = z.object({
  code: z.string().min(1, 'コードは必須です'),
  name: z.string().min(1, '名称は必須です'),
  description: z.string().min(1, '説明は必須です'),
  tags: z.string().optional(),
  lat: z.string().optional(),
  lng: z.string().optional(),
  isPublished: z.boolean(),
});

type FormValues = z.infer<typeof schema>;

export function SpotFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [feedback, setFeedback] = useState<{ message: string; severity: 'success' | 'error' } | null>(null);
  const { data } = useQuery({ queryKey: ['spot', id], queryFn: () => fetchSpot(id ?? ''), enabled: Boolean(id) });

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      code: '',
      name: '',
      description: '',
      tags: '',
      lat: '',
      lng: '',
      isPublished: true,
    },
  });

  useEffect(() => {
    if (data) {
      setValue('code', data.code);
      setValue('name', data.name);
      setValue('description', data.description);
      setValue('tags', data.tags?.join(', ') ?? '');
      setValue('lat', data.lat?.toString() ?? '');
      setValue('lng', data.lng?.toString() ?? '');
      setValue('isPublished', data.isPublished);
    }
  }, [data, setValue]);

  const mutation = useMutation({
    mutationFn: (values: FormValues) => {
      const payload = {
        code: values.code,
        name: values.name,
        description: values.description,
        tags: values.tags ? values.tags.split(',').map((tag) => tag.trim()).filter(Boolean) : null,
        lat: values.lat ? Number(values.lat) : null,
        lng: values.lng ? Number(values.lng) : null,
        isPublished: values.isPublished,
      };
      return id ? updateSpot(id, payload) : createSpot(payload);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['spots'] });
      setFeedback({ message: 'スポットを保存しました。', severity: 'success' });
      setTimeout(() => navigate('/spots'), 500);
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const onSubmit = (values: FormValues) => mutation.mutate(values);

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Typography variant="h5">{id ? 'スポット編集' : 'スポット新規作成'}</Typography>
      <Card>
        <CardContent>
          <Box component="form" onSubmit={handleSubmit(onSubmit)} sx={{ display: 'grid', gap: 2 }}>
            <TextField
              label="コード"
              error={Boolean(errors.code)}
              helperText={errors.code?.message}
              {...register('code')}
            />
            <TextField
              label="名称"
              error={Boolean(errors.name)}
              helperText={errors.name?.message}
              {...register('name')}
            />
            <TextField
              label="説明"
              multiline
              minRows={3}
              error={Boolean(errors.description)}
              helperText={errors.description?.message}
              {...register('description')}
            />
            <TextField label="タグ（カンマ区切り）" {...register('tags')} />
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField label="緯度" {...register('lat')} />
              <TextField label="経度" {...register('lng')} />
            </Box>
            <FormControlLabel control={<Switch {...register('isPublished')} />} label="公開する" />
            <Box sx={{ display: 'flex', gap: 2 }}>
              <Button variant="outlined" onClick={() => navigate('/spots')}>
                戻る
              </Button>
              <Button type="submit" variant="contained" disabled={isSubmitting}>
                保存
              </Button>
            </Box>
          </Box>
        </CardContent>
      </Card>
      <FeedbackSnackbar
        open={Boolean(feedback)}
        message={feedback?.message ?? ''}
        severity={feedback?.severity ?? 'success'}
        onClose={() => setFeedback(null)}
      />
    </Box>
  );
}
