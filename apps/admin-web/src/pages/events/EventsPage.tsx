import { Box, Button, Card, CardContent, Chip, Table, TableBody, TableCell, TableHead, TableRow, Typography } from '@mui/material';
import { useMutation, useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { useState } from 'react';
import { deleteEvent, fetchEvents, publishEvent } from '../../api/admin';
import { queryClient } from '../../api/queryClient';
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
      setFeedback({ message: 'Event deleted.', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  const publishMutation = useMutation({
    mutationFn: ({ id, isPublished }: { id: string; isPublished: boolean }) => publishEvent(id, isPublished),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['events'] });
      setFeedback({ message: 'Publish state updated.', severity: 'success' });
    },
    onError: (error: Error) => setFeedback({ message: error.message, severity: 'error' }),
  });

  return (
    <Box sx={{ display: 'grid', gap: 2 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h5">Events</Typography>
        <Button variant="contained" onClick={() => navigate('/events/new')}>
          New Event
        </Button>
      </Box>

      <Card>
        <CardContent>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Title</TableCell>
                <TableCell>Start</TableCell>
                <TableCell>End</TableCell>
                <TableCell>Published</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {data.map((event) => (
                <TableRow key={event.id} hover>
                  <TableCell>{event.title}</TableCell>
                  <TableCell>{new Date(event.startsAt).toLocaleString('en-US')}</TableCell>
                  <TableCell>{new Date(event.endsAt).toLocaleString('en-US')}</TableCell>
                  <TableCell>
                    <Chip label={event.isPublished ? 'Published' : 'Draft'} color={event.isPublished ? 'success' : 'default'} />
                  </TableCell>
                  <TableCell align="right" sx={{ display: 'flex', gap: 1, justifyContent: 'flex-end' }}>
                    <Button size="small" onClick={() => navigate(`/events/${event.id}/edit`)}>
                      Edit
                    </Button>
                    <Button size="small" onClick={() => navigate(`/events/${event.id}/qr-issues`)}>
                      QR
                    </Button>
                    <Button size="small" variant="outlined" onClick={() => publishMutation.mutate({ id: event.id, isPublished: !event.isPublished })}>
                      {event.isPublished ? 'Unpublish' : 'Publish'}
                    </Button>
                    <Button size="small" color="error" onClick={() => setSelectedId(event.id)}>
                      Delete
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
        title="Delete event?"
        description="This action cannot be undone."
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
