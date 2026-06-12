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
            :disabled="wifiInstallRunning"
            @click="installWifiDrivers"
          >
            <v-icon start>mdi-download</v-icon>
            {{ $t('plugin_wifi.install') }}
          </v-btn>
        </v-card-title>

        <!-- Optionaler manueller .deb-Pfad -->
        <v-card-text class="pa-4 border-bottom">
          <div class="mb-2">
            <label class="text-body2 font-weight-bold mb-2 d-block">
              <v-icon x-small>mdi-folder</v-icon>
              {{ $t('plugin_wifi.deb_path_label') }}
            </label>
            <p class="text-caption text-medium-emphasis mb-3">
              {{ $t('plugin_wifi.deb_path_hint') }}
            </p>
            <v-text-field
              v-model="debFilePath"
              :placeholder="debPathPlaceholder"
              :hint="$t('plugin_wifi.deb_path_field_hint')"
              variant="outlined"
              density="compact"
              clearable
              :disabled="wifiInstallRunning"
            />
          </div>

          <!-- Hinweis: automatischer GitHub-Download -->
          <v-alert
            v-if="!debFilePath"
            type="info"
            variant="tonal"
            density="compact"
            icon="mdi-github"
            class="mt-2"
          >
            {{ $t('plugin_wifi.auto_download_hint') }}
          </v-alert>
        </v-card-text>

        <!-- Fortschritt während Installation -->
        <v-card-text v-if="wifiInstallRunning" class="pa-4 border-bottom">
          <div class="d-flex align-center gap-3 mb-2">
            <v-progress-circular indeterminate color="primary" size="20" width="2" />
            <span class="text-body2">{{ currentStageLabel }}</span>
          </div>
          <v-progress-linear
            :model-value="progressPercent"
            color="primary"
            height="4"
            rounded
            class="mb-2"
          />
          <p class="text-caption text-medium-emphasis">
            {{ $t('plugin_wifi.progress_note') }}
          </p>
        </v-card-text>

        <!-- Ergebnis nach Abschluss -->
        <v-card-text v-if="!wifiInstallRunning && wifiInstallMessage" class="pa-4">
          <v-alert
            :type="installStatus"
            :icon="`mdi-${statusIcon}`"
            variant="tonal"
            class="mb-3"
          >
            <div class="text-body2 font-weight-bold">{{ statusHeadline }}</div>
            <div class="text-caption mt-1">{{ statusSubtext }}</div>
          </v-alert>

          <!-- Log-Ausgabe aufklappbar -->
          <v-expansion-panels v-if="wifiInstallMessage" variant="accordion" class="mt-2">
            <v-expansion-panel>
              <v-expansion-panel-title class="text-caption">
                <v-icon start size="small">mdi-console</v-icon>
                {{ $t('plugin_wifi.show_log') }}
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <div
                  class="pa-3 rounded text-monospace text-caption"
                  style="
                    background: #1e1e1e;
                    color: #00ff00;
                    max-height: 300px;
                    overflow-y: auto;
                    border: 1px solid #444;
                    font-family: 'Courier New', monospace;
                    white-space: pre-wrap;
                    word-break: break-word;
                  "
                >{{ wifiInstallMessage }}</div>
              </v-expansion-panel-text>
            </v-expansion-panel>
          </v-expansion-panels>
        </v-card-text>

        <!-- Leerzustand -->
        <v-card-text v-if="!wifiInstallRunning && !wifiInstallMessage" class="pa-4">
          <div class="text-caption text-medium-emphasis">
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
              <p class="mb-2">{{ $t('plugin_wifi.installer_runs_at') }}</p>
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
import { getCurrentInstance, ref, computed, onMounted, onUnmounted } from 'vue';

// ── Konstanten ───────────────────────────────────────────────────────────────

const INSTALL_TIMEOUT_S = 600;

// Fortschritts-Stages: [Label-i18n-Key, Dauer in Sekunden (geschätzt)]
const STAGES = [
  { key: 'plugin_wifi.stage_init',     duration: 5  },
  { key: 'plugin_wifi.stage_apt',      duration: 15 },
  { key: 'plugin_wifi.stage_download', duration: 60 },
  { key: 'plugin_wifi.stage_install',  duration: 15 },
  { key: 'plugin_wifi.stage_modules',  duration: 5  },
];
const TOTAL_STAGE_DURATION = STAGES.reduce((s, x) => s + x.duration, 0); // 100s

// ── State ────────────────────────────────────────────────────────────────────

const loading            = ref(true);
const wifiInstallRunning = ref(false);
const wifiInstallMessage = ref('');
const lastExitCode       = ref(null);
const timedOut           = ref(false);
const debFilePath        = ref('');

// Fortschritt
const elapsedSeconds     = ref(0);
let   progressTimer      = null;

// ── Instanz / i18n ───────────────────────────────────────────────────────────

const instance = getCurrentInstance();
const t = (key, params = {}) => {
  const translate = instance?.proxy?.$t;
  return typeof translate === 'function' ? translate(key, params) : key;
};

// ── Computed ─────────────────────────────────────────────────────────────────

/** Placeholder zeigt immer den aktuellen uname-ähnlichen Pfad als Beispiel */
const debPathPlaceholder = computed(() =>
  '/boot/optional/drivers/mos-wifi-driver/$(uname -r)/mos-wifi-modules.deb'
);

/** Fortschritt 0–95 % (nie 100 % solange läuft, damit kein falsches "fertig") */
const progressPercent = computed(() => {
  const pct = (elapsedSeconds.value / TOTAL_STAGE_DURATION) * 95;
  return Math.min(pct, 95);
});

/** Aktuelle Stage anhand der gelaufenen Zeit */
const currentStageLabel = computed(() => {
  let acc = 0;
  for (const stage of STAGES) {
    acc += stage.duration;
    if (elapsedSeconds.value < acc) return t(stage.key);
  }
  return t(STAGES[STAGES.length - 1].key);
});

/** Alert-Typ */
const installStatus = computed(() => {
  if (timedOut.value)                                      return 'warning';
  if (lastExitCode.value === 0)                            return 'success';
  if (lastExitCode.value !== null && lastExitCode.value !== 0) return 'error';
  return 'info';
});

const statusIcon = computed(() => {
  if (timedOut.value)       return 'clock-alert';
  if (lastExitCode.value === 0) return 'check-circle';
  if (lastExitCode.value !== null) return 'alert-circle';
  return 'information';
});

const statusHeadline = computed(() => {
  if (timedOut.value)          return t('plugin_wifi.timeout_headline', { seconds: INSTALL_TIMEOUT_S });
  if (lastExitCode.value === 0) return t('plugin_wifi.success');
  if (lastExitCode.value !== null) return t('plugin_wifi.failed');
  return t('plugin_wifi.running');
});

const statusSubtext = computed(() => {
  if (timedOut.value)          return t('plugin_wifi.timeout_subtext');
  if (lastExitCode.value === 0) return t('plugin_wifi.success_subtext');
  if (lastExitCode.value !== null) return t('plugin_wifi.failed_subtext');
  return '';
});

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

const getAuthHeaders = () => ({
  Authorization: 'Bearer ' + localStorage.getItem('authToken'),
});

const startProgressTimer = () => {
  elapsedSeconds.value = 0;
  progressTimer = setInterval(() => { elapsedSeconds.value++; }, 1000);
};

const stopProgressTimer = () => {
  if (progressTimer) { clearInterval(progressTimer); progressTimer = null; }
};

// ── Hauptaktion ──────────────────────────────────────────────────────────────

const installWifiDrivers = async () => {
  wifiInstallRunning.value = true;
  wifiInstallMessage.value = '';
  lastExitCode.value       = null;
  timedOut.value           = false;

  startProgressTimer();

  try {
    const args = debFilePath.value ? [debFilePath.value] : [];

    const res = await fetch('/api/v1/mos/plugins/query', {
      method: 'POST',
      headers: { ...getAuthHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        command:    'mos-wifi-driver-install',
        args:       args,
        timeout:    INSTALL_TIMEOUT_S,
        parse_json: false,
      }),
    });

    const data = await res.json();

    if (!res.ok) {
      wifiInstallMessage.value = data.output || data.message || t('plugin_wifi.install_failed');
      lastExitCode.value       = typeof data.exit_code === 'number' ? data.exit_code : 1;
      timedOut.value           = Boolean(data.timed_out);
      return;
    }

    wifiInstallMessage.value = data.output || t('plugin_wifi.install_complete');
    lastExitCode.value       = typeof data.exit_code === 'number' ? data.exit_code : 0;
    timedOut.value           = Boolean(data.timed_out);

  } catch (e) {
    console.error('Failed to install WiFi drivers:', e);
    wifiInstallMessage.value = `${t('plugin_wifi.error_prefix')}: ${e.message}`;
    lastExitCode.value       = 1;
  } finally {
    stopProgressTimer();
    wifiInstallRunning.value = false;
  }
};

// ── Lifecycle ────────────────────────────────────────────────────────────────

onMounted(() => { loading.value = false; });
onUnmounted(() => { stopProgressTimer(); });
</script>

<style scoped>
:deep(.bg-light) {
  background-color: rgba(0, 0, 0, 0.04);
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