import { Link } from 'expo-router';
import { SafeAreaView, StyleSheet, Text, View } from 'react-native';

export default function HomeScreen() {
  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>Nexus Mobile</Text>
      <Text style={styles.copy}>オープンキャンパス来場者向けナビゲーションアプリ</Text>
      <View style={styles.ctaWrap}>
        <Link href="/map" style={styles.cta}>マップを開く</Link>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24 },
  title: { fontSize: 28, fontWeight: '700', marginBottom: 12 },
  copy: { fontSize: 16, textAlign: 'center', marginBottom: 24 },
  ctaWrap: { backgroundColor: '#007AFF', borderRadius: 10 },
  cta: { color: '#fff', paddingHorizontal: 16, paddingVertical: 12, fontWeight: '600' }
});
