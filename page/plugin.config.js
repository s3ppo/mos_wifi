const translations = {
  en: {
    displayName: 'WiFi Drivers for MOS',
    description: 'WiFi driver and firmware management',
    commands: {
      install: 'Install WiFi drivers and firmware',
    },
  },
  de: {
    displayName: 'WiFi-Treiber fuer MOS',
    description: 'Verwaltung von WiFi-Treibern und Firmware',
    commands: {
      install: 'WiFi-Treiber und Firmware installieren',
    },
  },
};

export default {
  name: 'mos-wifi',
  displayName: translations.en.displayName,
  description: translations.en.description,
  version: '0.0.1',
  icon: 'https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-wifi.png',
  category: ['Driver'],
  architecture: ['amd64'],
  driver: true,
  author: 's3ppo',
  homepage: 'https://github.com/s3ppo/mos_wifi',
  repository: 'https://github.com/s3ppo/mos_wifi',
  support: 'https://github.com/s3ppo/mos_wifi/issues',
  translations,
  commands: [
    {
      name: 'mos-wifi-driver-install',
      executable: '/usr/bin/plugins/mos-wifi-driver-install',
      description: translations.en.commands.install,
    },
  ],
};
