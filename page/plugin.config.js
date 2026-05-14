const localizedTexts = {
  de: {
    displayName: 'WiFi Treiber fuer MOS',
    description: 'Installiert WiFi-Firmware und Treiber im MOS-Container',
    commandDescription: 'Installiere WiFi-Treiber und Firmware',
  },
  en: {
    displayName: 'WiFi Drivers for MOS',
    description: 'Installs WiFi firmware and drivers in the MOS container',
    commandDescription: 'Install WiFi drivers and firmware',
  },
};

const fallbackLocale = 'de';
const supportedLocales = ['de', 'en'];

const resolveLocale = () => {
  const envLocale = (
    process.env.MOS_PLUGIN_LOCALE ||
    process.env.LC_ALL ||
    process.env.LC_MESSAGES ||
    process.env.LANG ||
    fallbackLocale
  ).toLowerCase();

  const baseLocale = envLocale.split(/[._-]/)[0];
  return supportedLocales.includes(baseLocale) ? baseLocale : fallbackLocale;
};

const locale = resolveLocale();
const texts = localizedTexts[locale] || localizedTexts[fallbackLocale];

export default {
  name: 'mos-wifi',
  displayName: texts.displayName,
  description: texts.description,
  version: '0.0.1',
  icon: 'https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-wifi.png',
  category: ['Driver'],
  architecture: ['amd64'],
  driver: true,
  author: 's3ppo',
  homepage: 'https://github.com/s3ppo/mos_wifi',
  repository: 'https://github.com/s3ppo/mos_wifi',
  support: 'https://github.com/s3ppo/mos_wifi/issues',
  commands: [
    {
      name: 'mos-wifi-driver-install',
      executable: '/usr/bin/plugins/mos-wifi-driver-install',
      description: texts.commandDescription,
    },
  ],
};
