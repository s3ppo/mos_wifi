<template>
  <div class="pa-4">
    <v-skeleton-loader v-if="loading" :loading="true" type="card" />
    <div v-else style="margin-bottom: 80px">
      <!-- Header -->
      <div class="mb-6">
        <h2 class="text-h5 font-weight-bold mb-2">{{ $t('plugin_wifi.title') }}</h2>
        <p class="text-body2 text-medium-emphasis">{{ $t('plugin_wifi.description') }}</p>
      </div>

      <!-- Main Action Card -->
      <v-card class="mb-6" elevation="2">
        <v-card-title class="bg-light d-flex align-center flex-wrap gap-3">
          <v-icon large color="primary">mdi-wifi</v-icon>
          <span>{{ $t('plugin_wifi.installation') }}</span>
          <v-spacer />
          <v-btn 
            color="primary" 
            size="large"
            :loading="wifiInstallRunning" 
            @click="installWifiDrivers"
            :disabled="wifiInstallRunning"
          >
            <v-icon start>mdi-download</v-icon>
            {{ $t('plugin_wifi.install') }}
          </v-btn>
        </v-card-title>

        <!-- Driver Package Path Configuration -->
        <v-card-text class="pa-4 border-bottom">
          <div class="mb-4">
            <label class="text-body2 font-weight-bold mb-2 d-block">
              <v-icon x-small>mdi-folder</v-icon>
              Pfad zur WiFi-Treiber .deb Datei
            </label>
            <p class="text-caption text-medium-emphasis mb-3">
              Optionales Eingabefeld um einen benutzerdefinierten Pfad zur .deb Datei anzugeben. Wenn leer, wird automatisch nach der Datei gesucht.
            </p>
            <v-text-field
              v-model="debFilePath"
              placeholder="/boot/optional/drivers/mos-wifi-driver/6.1.0-mos/mos-wifi-modules-1.0.deb"
              hint="Beispiel: /pfad/zur/mos-wifi-modules-*.deb"
              variant="outlined"
              density="compact"
              clearable
              :disabled="wifiInstallRunning"
            />
          </div>
        </v-card-text>

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
            {{ $t('plugin_wifi.initial_prompt') }}
          </div>
        </v-card-text>
      </v-card>

      <!-- Info Sections -->
      <div class="row">
        <div class="col-12 col-md-6 mb-4">
          <v-card elevation="1">
            <v-card-title class="text-body2 font-weight-bold pa-3 bg-light">
              <v-icon start small>mdi-package</v-icon>
              {{ $t('plugin_wifi.included_drivers') }}
            </v-card-title>
            <v-card-text class="pa-3">
              <ul class="text-caption" style="margin: 0; padding-left: 20px;">
                <li>{{ $t('plugin_wifi.driver_intel') }}</li>
                <li>{{ $t('plugin_wifi.driver_realtek') }}</li>
                <li>{{ $t('plugin_wifi.driver_atheros') }}</li>
                <li>{{ $t('plugin_wifi.driver_broadcom') }}</li>
                <li>{{ $t('plugin_wifi.driver_regulatory_database') }}</li>
              </ul>
            </v-card-text>
          </v-card>
        </div>

        <div class="col-12 col-md-6 mb-4">
          <v-card elevation="1">
            <v-card-title class="text-body2 font-weight-bold pa-3 bg-light">
              <v-icon start small>mdi-information</v-icon>
              {{ $t('plugin_wifi.information') }}
            </v-card-title>
            <v-card-text class="pa-3 text-caption">
              <p class="mb-2">
                {{ $t('plugin_wifi.installer_runs_at') }}
              </p>
              <ul style="margin: 0; padding-left: 20px;">
                <li>{{ $t('plugin_wifi.plugin_installation') }}</li>
                <li>{{ $t('plugin_wifi.system_start') }}</li>
                <li>{{ $t('plugin_wifi.os_updates') }}</li>
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
            {{ $t('plugin_wifi.github_repository') }}
          </a>
          <span class="text-medium-emphasis mx-2">•</span>
          <a href="https://github.com/s3ppo/mos_wifi/issues" target="_blank" class="text-decoration-none mx-2">
            <v-icon small>mdi-bug</v-icon>
            {{ $t('plugin_wifi.support') }}
          </a>
        </v-card-text>
      </v-card>
    </div>
  </div>
</template>

<script setup>
import { getCurrentInstance, ref, onMounted, computed } from 'vue';

const loading = ref(true);
const wifiInstallRunning = ref(false);
const wifiInstallMessage = ref('');
const lastExitCode = ref(null);
const timedOut = ref(false);
const debFilePath = ref('');

const instance = getCurrentInstance();

const t = (key, params = {}) => {
  const translate = instance?.proxy?.$t;
  if (typeof translate === 'function') {
    return translate(key, params);
  }

  return key;
};

const showOutput = computed(() => Boolean(wifiInstallMessage.value));

const installStatus = computed(() => {
  if (timedOut.value) return 'warning';
  if (lastExitCode.value === 0) return 'success';
  if (lastExitCode.value !== null && lastExitCode.value !== 0) return 'error';
  return 'info';
});

const getStatusMessage = () => {
  if (timedOut.value) return t('plugin_wifi.timeout', { seconds: 600 });
  if (lastExitCode.value === 0) return t('plugin_wifi.success');
  if (lastExitCode.value !== null && lastExitCode.value !== 0) return t('plugin_wifi.failed');
  return t('plugin_wifi.running');
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
    // Prepare arguments: pass the DEB path if provided
    const args = debFilePath.value ? [debFilePath.value] : [];

    const res = await fetch('/api/v1/mos/plugins/query', {
      method: 'POST',
      headers: { ...getAuthHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        command: 'mos-wifi-driver-install',
        args: args,
        timeout: 600,
        parse_json: false,
      }),
    });

    const data = await res.json();

    if (!res.ok) {
      wifiInstallMessage.value = data.output || data.message || t('plugin_wifi.install_failed');
      lastExitCode.value = typeof data.exit_code === 'number' ? data.exit_code : 1;
      timedOut.value = Boolean(data.timed_out);
      return;
    }

    wifiInstallMessage.value = data.output || t('plugin_wifi.install_complete');
    lastExitCode.value = typeof data.exit_code === 'number' ? data.exit_code : 0;
    timedOut.value = Boolean(data.timed_out);
  } catch (e) {
    console.error('Failed to install WiFi drivers:', e);
    wifiInstallMessage.value = `${t('plugin_wifi.error_prefix')}: ${e.message}`;
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
