import { Alert, Snackbar } from '@mui/material';

type FeedbackSnackbarProps = {
  open: boolean;
  message: string;
  severity: 'success' | 'error';
  onClose: () => void;
};

export function FeedbackSnackbar({ open, message, severity, onClose }: FeedbackSnackbarProps) {
  return (
    <Snackbar open={open} autoHideDuration={4000} onClose={onClose} anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}>
      <Alert onClose={onClose} severity={severity} variant="filled" sx={{ width: '100%' }}>
        {message}
      </Alert>
    </Snackbar>
  );
}
