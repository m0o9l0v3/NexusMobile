import { useMemo, useState } from 'react';
import { SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View, Pressable } from 'react-native';
import Svg, { Circle, Polyline } from 'react-native-svg';
import { createNavigationApiClient, type Spot, type Route, type FloorMap } from '@nexus/shared';

const api = createNavigationApiClient({ baseUrl: process.env.EXPO_PUBLIC_API_BASE_URL ?? 'http://localhost:5001' });

const mockSpots: Spot[] = [];
const mockFloors: FloorMap[] = [{ id: '1f', name: '1F', width: 320, height: 220 }];
const mockRoute: Route | undefined = undefined;

export default function MapScreen() {
  const [query, setQuery] = useState('');
  const [from, setFrom] = useState<string>('');
  const [to, setTo] = useState<string>('');
  const spots = mockSpots;
  const floors = mockFloors;
  const route = mockRoute;

  const filtered = useMemo(() => spots.filter((s) => s.name.toLowerCase().includes(query.toLowerCase())), [spots, query]);

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.header}>Map</Text>
      <TextInput placeholder="スポット検索" value={query} onChangeText={setQuery} style={styles.input} />
      <Text style={styles.label}>フロア: {floors[0]?.name ?? '-'}</Text>
      <Svg width={320} height={220} style={styles.map}>
        {route && <Polyline points={route.points.map((p) => `${p.x},${p.y}`).join(' ')} stroke="#007AFF" strokeWidth="3" fill="none" />}
        {filtered.map((spot) => <Circle key={spot.id} cx={spot.x} cy={spot.y} r={5} fill="#ef4444" />)}
      </Svg>
      <ScrollView>
        {filtered.map((spot) => (
          <Pressable key={spot.id} onPress={() => (!from ? setFrom(spot.id) : setTo(spot.id))} style={styles.card}>
            <Text>{spot.name}</Text><Text>{spot.floor} / {spot.category}</Text>
          </Pressable>
        ))}
      </ScrollView>
      <View style={styles.summary}>
        <Text>From: {from || '-'}</Text>
        <Text>To: {to || '-'}</Text>
        <Text>Distance: {route?.distanceMeters ?? '-'}m</Text>
        <Text>ETA: {route?.estimatedMinutes ?? '-'} min</Text>
      </View>
    </SafeAreaView>
  );
}

void api;

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  header: { fontSize: 24, fontWeight: '700', marginBottom: 12 },
  input: { borderWidth: 1, borderColor: '#ddd', borderRadius: 8, padding: 10, marginBottom: 8 },
  label: { marginBottom: 8 },
  map: { borderWidth: 1, borderColor: '#ddd', marginBottom: 8 },
  card: { padding: 10, borderBottomWidth: 1, borderColor: '#eee' },
  summary: { paddingTop: 8, borderTopWidth: 1, borderColor: '#ddd' }
});
