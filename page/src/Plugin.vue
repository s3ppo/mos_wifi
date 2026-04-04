<template>
  <div>
    <h2 class="mb-4">htop</h2>
    <v-skeleton-loader v-if="loading" :loading="true" type="card" />
    <div v-else style="margin-bottom: 80px">
      <!-- System Overview Card -->
      <v-card v-if="sysData" class="mb-4 pa-0">
        <v-card-title class="d-flex align-center flex-wrap gap-2">
          <span>System Overview</span>
          <v-spacer />
          <v-chip v-if="sysData.header" size="small" class="mr-2">Load: {{ sysData.header.load1.toFixed(2) }} / {{ sysData.header.load5.toFixed(2) }} / {{ sysData.header.load15.toFixed(2) }}</v-chip>
          <v-chip v-if="sysData.header" size="small">Uptime: {{ sysData.header.uptime }}</v-chip>
        </v-card-title>
        <v-card-text class="pa-4">
          <!-- Tasks -->
          <div v-if="sysData.tasks" class="text-caption text-medium-emphasis mb-3">
            Tasks:
            <strong>{{ sysData.tasks.total }}</strong>
            total,
            <strong>{{ sysData.tasks.running }}</strong>
            running,
            <strong>{{ sysData.tasks.sleeping }}</strong>
            sleeping
          </div>

          <!-- CPU Bars -->
          <div v-if="sysData.cpus.length" class="mb-4">
            <div class="text-caption text-medium-emphasis mb-2"><strong>CPU</strong></div>
            <v-row dense>
              <v-col v-for="cpu in sysData.cpus" :key="cpu.num" cols="12" md="6" lg="4">
                <div style="display: flex; align-items: center; gap: 6px" class="mb-1">
                  <span class="text-caption" style="width: 52px; flex-shrink: 0">
                    {{ cpu.num >= 0 ? `CPU${cpu.num}` : 'CPU' }}
                  </span>
                  <v-progress-linear :model-value="cpu.used" height="14" :color="cpu.used >= 90 ? 'red' : cpu.used >= 70 ? 'orange' : 'green'" style="border-radius: 6px; overflow: hidden; flex: 1">
                    <template #default>
                      <span>
                        <small>{{ cpu.used.toFixed(1) }}%</small>
                      </span>
                    </template>
                  </v-progress-linear>
                </div>
              </v-col>
            </v-row>
          </div>

          <!-- Memory Bar -->
          <div v-if="sysData.mem" class="mb-2">
            <div class="d-flex align-center mb-1">
              <span class="text-caption" style="width: 52px; flex-shrink: 0"><strong>Mem</strong></span>
              <v-progress-linear :model-value="memPercent" height="16" :color="memPercent >= 90 ? 'red' : memPercent >= 75 ? 'orange' : 'green'" style="border-radius: 7px; overflow: hidden; flex: 1">
                <template #default>
                  <span>
                    <small>{{ sysData.mem.used.toFixed(0) }} / {{ sysData.mem.total.toFixed(0) }} MiB</small>
                  </span>
                </template>
              </v-progress-linear>
            </div>
          </div>

          <!-- Swap Bar -->
          <div v-if="sysData.swap && sysData.swap.total > 0">
            <div class="d-flex align-center">
              <span class="text-caption" style="width: 52px; flex-shrink: 0"><strong>Swp</strong></span>
              <v-progress-linear
                :model-value="swapPercent"
                height="16"
                :color="swapPercent >= 90 ? 'red' : swapPercent >= 50 ? 'orange' : 'cyan'"
                style="border-radius: 7px; overflow: hidden; flex: 1"
              >
                <template #default>
                  <span>
                    <small>{{ sysData.swap.used.toFixed(0) }} / {{ sysData.swap.total.toFixed(0) }} MiB</small>
                  </span>
                </template>
              </v-progress-linear>
            </div>
          </div>
        </v-card-text>
      </v-card>

      <!-- No data yet -->
      <v-card v-else class="mb-4 pa-0">
        <v-card-text class="pa-4 text-grey text-center">Fetching system data...</v-card-text>
      </v-card>

      <!-- Process List -->
      <v-card v-if="sysData?.processes?.length" class="pa-0">
        <v-card-title>Processes</v-card-title>
        <v-card-text class="pa-0">
          <v-table density="compact" fixed-header height="420px">
            <thead>
              <tr>
                <th v-for="col in columns" :key="col.field" :style="col.sortable ? 'cursor: pointer; user-select: none' : ''" @click="col.sortable ? setSortField(col.field) : null">
                  {{ col.label }}
                  <v-icon v-if="sortField === col.field" size="x-small">mdi-arrow-down</v-icon>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="proc in sortedProcesses" :key="proc.pid">
                <td>{{ proc.pid }}</td>
                <td>{{ proc.user }}</td>
                <td>
                  <span :style="{ color: proc.cpu > 50 ? '#f44336' : proc.cpu > 20 ? '#ff9800' : undefined }">{{ proc.cpu.toFixed(1) }}%</span>
                </td>
                <td>
                  <span :style="{ color: proc.mem > 50 ? '#f44336' : proc.mem > 20 ? '#ff9800' : undefined }">{{ proc.mem.toFixed(1) }}%</span>
                </td>
                <td>{{ proc.res }}</td>
                <td>{{ proc.s }}</td>
                <td class="text-truncate" style="max-width: 220px">{{ proc.command }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card-text>
      </v-card>
    </div>

    <!-- Settings Dialog -->
    <v-dialog v-model="settingsDialog.value" max-width="500">
      <v-card class="pa-0">
        <v-card-title>Settings</v-card-title>
        <v-card-text>
          <v-form>
            <v-text-field v-model.number="settingsDialog.interval" label="Update interval (seconds)" type="number" min="1" @blur="validateInterval" />
            <v-text-field v-model.number="settingsDialog.maxProcesses" label="Max processes shown" type="number" min="5" max="500" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn color="onPrimary" @click="settingsDialog.value = false">Cancel</v-btn>
          <v-btn color="onPrimary" @click="saveSettings" :loading="settingsDialog.saving">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-fab color="primary" style="position: fixed; bottom: 32px; right: 32px; z-index: 1000" size="large" icon @click="openSettingsDialog">
      <v-icon>mdi-cog</v-icon>
    </v-fab>
  </div>
</template>

<script setup>
import { ref, computed, reactive, onMounted, onUnmounted } from 'vue';

const loading = ref(true);
const settings = ref({ interval: 2, maxProcesses: 50 });
const sysData = ref(null);
const sortField = ref('cpu');
let pollInterval = null;

const settingsDialog = reactive({
  value: false,
  interval: 2,
  maxProcesses: 50,
  saving: false,
});

const columns = [
  { field: 'pid', label: 'PID', sortable: true },
  { field: 'user', label: 'User', sortable: false },
  { field: 'cpu', label: 'CPU%', sortable: true },
  { field: 'mem', label: 'MEM%', sortable: true },
  { field: 'res', label: 'RES', sortable: false },
  { field: 's', label: 'S', sortable: false },
  { field: 'command', label: 'Command', sortable: false },
];

const getAuthHeaders = () => ({
  Authorization: 'Bearer ' + localStorage.getItem('authToken'),
});

const validateInterval = () => {
  if (settingsDialog.interval < 1) settingsDialog.interval = 1;
};

const memPercent = computed(() => {
  if (!sysData.value?.mem || !sysData.value.mem.total) return 0;
  return (sysData.value.mem.used / sysData.value.mem.total) * 100;
});

const swapPercent = computed(() => {
  if (!sysData.value?.swap || !sysData.value.swap.total) return 0;
  return (sysData.value.swap.used / sysData.value.swap.total) * 100;
});

const sortedProcesses = computed(() => {
  if (!sysData.value?.processes) return [];
  const procs = [...sysData.value.processes];
  procs.sort((a, b) => {
    const va = typeof a[sortField.value] === 'number' ? a[sortField.value] : 0;
    const vb = typeof b[sortField.value] === 'number' ? b[sortField.value] : 0;
    return vb - va;
  });
  return procs.slice(0, settings.value.maxProcesses);
});

const setSortField = (field) => {
  sortField.value = field;
};



const fetchSettings = async () => {
  try {
    const res = await fetch('/api/v1/mos/plugins/settings/mos-htop', {
      headers: getAuthHeaders(),
    });
    if (res.ok) {
      const data = await res.json();
      settings.value = {
        interval: data.interval || 2,
        maxProcesses: data.maxProcesses || 50,
      };
    }
  } catch (e) {
    console.error('Failed to fetch settings:', e);
  }
};

const fetchSystemData = async () => {
  try {
    const res = await fetch('/api/v1/mos/plugins/query', {
      method: 'POST',
      headers: { ...getAuthHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        command: 'mos-htop-query',
        args: [],
        timeout: 10,
        parse_json: true,
      }),
    });
    if (res.ok) {
      const data = await res.json();
      sysData.value = data.output;
    }
  } catch (e) {
    console.error('Failed to fetch system data:', e);
  }
};

const startPolling = () => {
  stopPolling();
  const interval = Math.max(1, settings.value.interval) * 1000;
  pollInterval = setInterval(fetchSystemData, interval);
};

const stopPolling = () => {
  if (pollInterval) {
    clearInterval(pollInterval);
    pollInterval = null;
  }
};

const openSettingsDialog = () => {
  settingsDialog.interval = settings.value.interval;
  settingsDialog.maxProcesses = settings.value.maxProcesses;
  settingsDialog.saving = false;
  settingsDialog.value = true;
};

const saveSettings = async () => {
  settingsDialog.saving = true;
  validateInterval();
  try {
    const res = await fetch('/api/v1/mos/plugins/settings/mos-htop', {
      method: 'POST',
      headers: { ...getAuthHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        interval: settingsDialog.interval,
        maxProcesses: settingsDialog.maxProcesses,
      }),
    });
    if (res.ok) {
      settings.value = {
        interval: settingsDialog.interval,
        maxProcesses: settingsDialog.maxProcesses,
      };
      settingsDialog.value = false;
      startPolling();
    }
  } catch (e) {
    console.error('Failed to save settings:', e);
  } finally {
    settingsDialog.saving = false;
  }
};

onMounted(async () => {
  try {
    await fetchSettings();
    await fetchSystemData();
  } catch (e) {
    console.error('Failed to initialize:', e);
  } finally {
    loading.value = false;
  }
  startPolling();
});

onUnmounted(() => {
  stopPolling();
});
</script>
