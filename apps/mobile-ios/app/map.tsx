import { useLocalSearchParams } from 'expo-router';
import { MapScreen } from '../src/components/MapScreen';

export default function MapRoute() {
  const params = useLocalSearchParams<{ spotName?: string }>();

  return <MapScreen focusSpotName={params.spotName} />;
}
