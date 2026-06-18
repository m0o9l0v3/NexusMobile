import { StatusBar } from 'expo-status-bar';
import { Stack } from 'expo-router';

export default function Layout() {
  return (
    <>
      <StatusBar style="dark" />
      <Stack screenOptions={{ headerShown: false }} />
    </>
  );
}
