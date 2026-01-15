import { Box, Button, Card, CardContent, Container, TextField, Typography } from '@mui/material';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { zodResolver } from '@hookform/resolvers/zod';
import { login } from '../api/admin';
import { useAuth } from '../hooks/useAuth';
import { FeedbackSnackbar } from '../components/FeedbackSnackbar';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

const schema = z.object({
  username: z.string().min(1, 'ユーザー名を入力してください'),
  password: z.string().min(1, 'パスワードを入力してください'),
});

type FormValues = z.infer<typeof schema>;

export function LoginPage() {
  const { setToken } = useAuth();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const onSubmit = async (values: FormValues) => {
    try {
      const response = await login(values);
      setToken(response.accessToken);
      navigate('/');
    } catch (err) {
      setError((err as Error).message);
    }
  };

  return (
    <Container maxWidth="sm">
      <Box sx={{ mt: 12 }}>
        <Card>
          <CardContent>
            <Typography variant="h5" sx={{ mb: 2 }}>
              管理者ログイン
            </Typography>
            <Box component="form" onSubmit={handleSubmit(onSubmit)} sx={{ display: 'grid', gap: 2 }}>
              <TextField
                label="ユーザー名"
                error={Boolean(errors.username)}
                helperText={errors.username?.message}
                {...register('username')}
              />
              <TextField
                label="パスワード"
                type="password"
                error={Boolean(errors.password)}
                helperText={errors.password?.message}
                {...register('password')}
              />
              <Button type="submit" variant="contained" disabled={isSubmitting}>
                ログイン
              </Button>
            </Box>
          </CardContent>
        </Card>
      </Box>
      <FeedbackSnackbar
        open={Boolean(error)}
        message={error ?? ''}
        severity="error"
        onClose={() => setError(null)}
      />
    </Container>
  );
}
