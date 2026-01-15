import { Box, Button, Card, CardContent, Typography } from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { fetchSpot, fetchSpotQr } from '../../api/admin';
import { useEffect, useMemo, useState } from 'react';
import { FeedbackSnackbar } from '../../components/FeedbackSnackbar';

export function SpotDetailPage() {
  const { id } = useParams();
  const [qrUrl, setQrUrl] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<string | null>(null);
  const participantBaseUrl = import.meta.env.VITE_PARTICIPANT_BASE_URL ?? 'https://example.local';
  const { data } = useQuery({ queryKey: ['spot', id], queryFn: () => fetchSpot(id ?? ''), enabled: Boolean(id) });

  const participantUrl = useMemo(() => {
    if (!data) {
      return '';
    }
    return `${participantBaseUrl.replace(/\/$/, '')}/?code=${encodeURIComponent(data.code)}`;
  }, [data, participantBaseUrl]);

  useEffect(() => {
    return () => {
      if (qrUrl) {
        URL.revokeObjectURL(qrUrl);
      }
    };
  }, [qrUrl]);

  const handleQrGenerate = async () => {
    if (!id) return;
    try {
      const blob = await fetchSpotQr(id);
      const objectUrl = URL.createObjectURL(blob);
      setQrUrl(objectUrl);
    } catch (error) {
      setFeedback((error as Error).message);
    }
  };

  const handleDownload = () => {
    if (!qrUrl) return;
    const link = document.createElement('a');
    link.href = qrUrl;
    link.download = `spot-${data?.code ?? 'qr'}.png`;
    link.click();
  };

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Typography variant="h5">スポット詳細</Typography>
      <Card>
        <CardContent sx={{ display: 'grid', gap: 2 }}>
          <Typography variant="subtitle1">コード</Typography>
          <Typography variant="h6">{data?.code ?? '-'}</Typography>
          <Typography variant="subtitle1">参加者URL</Typography>
          <Typography variant="body1">{participantUrl || '-'}</Typography>
          <Box sx={{ display: 'flex', gap: 2 }}>
            <Button variant="contained" onClick={handleQrGenerate}>
              QRコードを生成
            </Button>
            <Button variant="outlined" onClick={handleDownload} disabled={!qrUrl}>
              PNGをダウンロード
            </Button>
          </Box>
          {qrUrl && (
            <Box sx={{ mt: 2 }}>
              <img src={qrUrl} alt="QRコード" style={{ width: 240, height: 240 }} />
            </Box>
          )}
        </CardContent>
      </Card>
      <FeedbackSnackbar
        open={Boolean(feedback)}
        message={feedback ?? ''}
        severity="error"
        onClose={() => setFeedback(null)}
      />
    </Box>
  );
}
