<template>
  <div>
    <h2 class="mb-4">WiFi Drivers</h2>
    <v-skeleton-loader v-if="loading" :loading="true" type="card" />
    <div v-else style="margin-bottom: 80px">
      <v-card class="mb-4 pa-0">
        <v-card-title class="d-flex align-center flex-wrap gap-2">
          <span>WiFi Drivers</span>
          <v-spacer />
          <v-btn color="primary" :loading="wifiInstallRunning" @click="installWifiDrivers">Treiber installieren</v-btn>
        </v-card-title>
        <v-card-text class="pa-4">
          <div class="text-caption text-medium-emphasis">
            Installiert die ueblichen WLAN-Firmware- und Treiberpakete im MOS-Container.
          </div>
          <div class="text-caption text-medium-emphasis mt-2">
            Der gleiche Installer wird auch ueber die MOS-Lifecycle-Hooks bei Start und Update ausgefuehrt.
          </div>
          <div v-if="wifiInstallMessage" class="text-caption mt-3" style="white-space: pre-wrap">
            {{ wifiInstallMessage }}
          </div>
        </v-card-text>
      </v-card>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';

const loading = ref(true);
const wifiInstallRunning = ref(false);
const wifiInstallMessage = ref('');

const getAuthHeaders = () => ({
  Authorization: 'Bearer ' + localStorage.getItem('authToken'),
});

const installWifiDrivers = async () => {
  wifiInstallRunning.value = true;
  wifiInstallMessage.value = '';
  try {
    const res = await fetch('/api/v1/mos/plugins/query', {
      method: 'POST',
      headers: { ...getAuthHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        command: 'mos-wifi-driver-install',
        args: [],
        timeout: 600,
        parse_json: false,
      }),
    });
    if (!res.ok) {
      wifiInstallMessage.value = 'Treiberinstallation fehlgeschlagen.';
      return;
    }

    const data = await res.json();
    wifiInstallMessage.value = data.output || 'Treiberinstallation abgeschlossen.';
  } catch (e) {
    console.error('Failed to install WiFi drivers:', e);
    wifiInstallMessage.value = 'Fehler bei der Treiberinstallation.';
  } finally {
    wifiInstallRunning.value = false;
  }
};

onMounted(async () => {
  loading.value = false;
});
</script>
