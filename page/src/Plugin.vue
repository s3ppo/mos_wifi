<template>
  <div class="pa-4">
    <v-skeleton-loader v-if="loading" :loading="true" type="card" />
    <div v-else style="margin-bottom: 80px">
      <!-- Header -->
      <div class="mb-6">
        <h2 class="text-h5 font-weight-bold mb-2">WiFi Treiber und Firmware</h2>
        <p class="text-body2 text-medium-emphasis">Installiert häufig verwendete WLAN-Firmware und Treiber</p>
      </div>

      <!-- Main Action Card -->
      <v-card class="mb-6" elevation="2">
        <v-card-title class="bg-light d-flex align-center flex-wrap gap-3">
          <v-icon large color="primary">mdi-wifi</v-icon>
          <span>Installation</span>
          <v-spacer />
          <v-btn 
            color="primary" 
            size="large"
            :loading="wifiInstallRunning" 
            @click="installWifiDrivers"
            :disabled="wifiInstallRunning"
          >
            <v-icon start>mdi-download</v-icon>
            Installieren
          </v-btn>
        </v-card-title>

        <!-- Status/Output -->
        <v-card-text class="pa-4">
          <div v-if="wifiInstallMessage" class="mb-4">
            <v-alert 
              :type="installStatus"
              :icon="`mdi-${getStatusIcon()}`"
              variant="tonal"
              class="mb-3"
            >
              <div class="text-body2">
                {{ getStatusMessage() }}
              </div>
            </v-alert>

            <!-- Output Box -->
            <div 
              v-if="showOutput"
              class="bg-surface-dark pa-3 rounded text-monospace text-caption"
              style="
                background: #1e1e1e;
                color: #00ff00;
                max-height: 200px;
                overflow-y: auto;
                border: 1px solid #444;
                font-family: 'Courier New', monospace;
                white-space: pre-wrap;
                word-break: break-word;
              "
            >
              {{ wifiInstallMessage }}
            </div>
          </div>
          <div v-else class="text-caption text-medium-emphasis">
            Klicke auf "Installieren" um die WLAN-Treiber zu installieren.
          </div>
        </v-card-text>
      </v-card>

      <!-- Info Sections -->
      <div class="row">
        <div class="col-12 col-md-6 mb-4">
          <v-card elevation="1">
            <v-card-title class="text-body2 font-weight-bold pa-3 bg-light">
              <v-icon start small>mdi-package</v-icon>
              Enthaltene Treiber
            </v-card-title>
            <v-card-text class="pa-3">
              <ul class="text-caption" style="margin: 0; padding-left: 20px;">
                <li>Intel WiFi (iwlwifi)</li>
                <li>Realtek WLAN</li>
                <li>Atheros (ATH9K)</li>
                <li>Broadcom (brcmfmac)</li>
                <li>Regulatory Database</li>
              </ul>
            </v-card-text>
          </v-card>
        </div>

        <div class="col-12 col-md-6 mb-4">
          <v-card elevation="1">
            <v-card-title class="text-body2 font-weight-bold pa-3 bg-light">
              <v-icon start small>mdi-information</v-icon>
              Information
            </v-card-title>
            <v-card-text class="pa-3 text-caption">
              <p class="mb-2">
                Der Installer wird automatisch ausgeführt bei:
              </p>
              <ul style="margin: 0; padding-left: 20px;">
                <li>Plugin-Installation</li>
                <li>Systembeginn</li>
                <li>OS-Updates</li>
              </ul>
            </v-card-text>
          </v-card>
        </div>
      </div>

      <!-- Links -->
      <v-card class="mt-4" elevation="1">
        <v-card-text class="pa-3 text-center">
          <a href="https://github.com/s3ppo/mos_wifi" target="_blank" class="text-decoration-none mx-2">
            <v-icon small>mdi-github</v-icon>
            GitHub Repository
          </a>
          <span class="text-medium-emphasis mx-2">•</span>
          <a href="https://github.com/s3ppo/mos_wifi/issues" target="_blank" class="text-decoration-none mx-2">
            <v-icon small>mdi-bug</v-icon>
            Support
          </a>
        </v-card-text>
      </v-card>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';

const loading = ref(true);
const wifiInstallRunning = ref(false);
const wifiInstallMessage = ref('');
const lastExitCode = ref(null);
const timedOut = ref(false);

const showOutput = computed(() => Boolean(wifiInstallMessage.value));

const installStatus = computed(() => {
  if (timedOut.value) return 'warning';
  if (lastExitCode.value === 0) return 'success';
  if (lastExitCode.value !== null && lastExitCode.value !== 0) return 'error';
  return 'info';
});

const getStatusMessage = () => {
  if (timedOut.value) return '⏱️ Installation läuft noch (Timeout nach 600s)';
  if (lastExitCode.value === 0) return '✓ Installation erfolgreich abgeschlossen';
  if (lastExitCode.value !== null && lastExitCode.value !== 0) return '✗ Installation fehlgeschlagen';
  return 'Installation läuft...';
};

const getStatusIcon = () => {
  if (timedOut.value) return 'clock';
  if (lastExitCode.value === 0) return 'check-circle';
  if (lastExitCode.value !== null && lastExitCode.value !== 0) return 'alert-circle';
  return 'information';
};

const getAuthHeaders = () => ({
  Authorization: 'Bearer ' + localStorage.getItem('authToken'),
});

const installWifiDrivers = async () => {
  wifiInstallRunning.value = true;
  wifiInstallMessage.value = '';
  lastExitCode.value = null;
  timedOut.value = false;

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

    const data = await res.json();

    if (!res.ok) {
      wifiInstallMessage.value = data.output || data.message || 'Treiberinstallation fehlgeschlagen.';
      lastExitCode.value = typeof data.exit_code === 'number' ? data.exit_code : 1;
      timedOut.value = Boolean(data.timed_out);
      return;
    }

    wifiInstallMessage.value = data.output || 'Treiberinstallation abgeschlossen.';
    lastExitCode.value = typeof data.exit_code === 'number' ? data.exit_code : 0;
    timedOut.value = Boolean(data.timed_out);
  } catch (e) {
    console.error('Failed to install WiFi drivers:', e);
    wifiInstallMessage.value = `Fehler: ${e.message}`;
    lastExitCode.value = 1;
  } finally {
    wifiInstallRunning.value = false;
  }
};

onMounted(async () => {
  loading.value = false;
});
</script>

<style scoped>
:deep(.bg-light) {
  background-color: rgba(0, 0, 0, 0.04);
}

:deep(.bg-surface-dark) {
  background-color: #1e1e1e;
}

.text-monospace {
  font-family: 'Courier New', 'Monaco', monospace;
}

a {
  color: rgb(25, 118, 210);
  text-decoration: none;
  transition: color 0.2s;
}

a:hover {
  color: rgb(13, 71, 161);
  text-decoration: underline;
}
</style>
