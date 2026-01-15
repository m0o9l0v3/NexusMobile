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
import { createEvent, fetchEvent, updateEvent } from '../../api/admin';
import { useNavigate, useParams } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { FeedbackSnackbar } from '../../components/FeedbackSnackbar';
import { queryClient } from '../../api/queryClient';

const schema = z.object({
  title: z.string().min(1, 'タイトルは必須です'),
  description: z.string().optional(),
  startsAt: z.string().min(1, '開始日時は必須です'),
  endsAt: z.string().min(1, '終了日時は必須です'),
  lat: z.string().optional(),
  lng: z.string().optional(),
  locationText: z.string().optional(),
  isPublished: z.boolean(),
});

type FormValues = z.infer<typeof schema>;

export function EventFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [feedback, setFeedback] = useState<{ message: string; severity: 'success' | 'error' } | null>(null);
  const { data: eventItem } = useQuery({
    queryKey: ['event', id],
    queryFn: () => fetchEvent(id ?? ''),
    enabled: Boolean(id),
  });

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      title: '',
      description: '',
      startsAt: '',
      endsAt: '',
      lat: '',
      lng: '',
      locationText: '',
      isPublished: true,
    },
  });

  useEffect(() => {
    if (eventItem) {
      setValue('title', eventItem.title);
      setValue('description', eventItem.description ?? '');
      setValue('startsAt', eventItem.startsAt.slice(0, 16));
      setValue('endsAt', eventItem.endsAt.slice(0, 16));
      setValue('lat', eventItem.lat?.toString() ?? '');
      setValue('lng', eventItem.lng?.toString() ?? '');
      setValue('locationText', eventItem.locationText ?? '');
      setValue('isPublished', eventItem.isPublished);
    }
  }, [eventItem, setValue]);

  const mutation = useMutation({
    mutationFn: (values: FormValues) => {
      const payload = {
        title: values.title,
        description: values.description || null,
        startsAt: new Date(values.startsAt).toISOString(),
        endsAt: new Date(values.endsAt).toISOString(),
        lat: values.lat ? Number(values.lat) : null,
        lng: values.lng ? Number(values.lng) : null,
        locationText: values.locationText || null,
        isPublished: values.isPublished,
      };
      return id ? updateEvent(id, payload) : createEvent(payload);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['events'] });
      setFeedback({ message: 'イベントを保存しました。', severity: 'success' });
      setTimeout(() => navigate('/events'), 500);
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const onSubmit = (values: FormValues) => mutation.mutate(values);

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Typography variant="h5">{id ? 'イベント編集' : 'イベント新規作成'}</Typography>
      <Card>
        <CardContent>
          <Box component="form" onSubmit={handleSubmit(onSubmit)} sx={{ display: 'grid', gap: 2 }}>
            <TextField
              label="タイトル"
              error={Boolean(errors.title)}
              helperText={errors.title?.message}
              {...register('title')}
            />
            <TextField label="説明" multiline minRows={3} {...register('description')} />
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                label="開始日時"
                type="datetime-local"
                error={Boolean(errors.startsAt)}
                helperText={errors.startsAt?.message}
                InputLabelProps={{ shrink: true }}
                {...register('startsAt')}
              />
              <TextField
                label="終了日時"
                type="datetime-local"
                error={Boolean(errors.endsAt)}
                helperText={errors.endsAt?.message}
                InputLabelProps={{ shrink: true }}
                {...register('endsAt')}
              />
            </Box>
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField label="緯度" {...register('lat')} />
              <TextField label="経度" {...register('lng')} />
            </Box>
            <TextField label="場所の説明" {...register('locationText')} />
            <FormControlLabel control={<Switch {...register('isPublished')} />} label="公開する" />
            <Box sx={{ display: 'flex', gap: 2 }}>
              <Button variant="outlined" onClick={() => navigate('/events')}>
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
