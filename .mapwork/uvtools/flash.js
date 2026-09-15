// js/flash.js
// UV-K5 Web Flasher core logic (Web Serial + protocol)
// Adds: 
// - Auto-load of firmware from URL param ?firmwareURL=... (or ?fw=...)
// - Requires i18n.js to be loaded first (window.i18nReady).
// - Defines window.updateUI() to (re)apply translations to the DOM.
// - Shows progress bar during flashing, hides it after successful completion.
// - Percentage text is centered via #progressLabel overlay.
// - Dump and restore

'use strict';

// ========== CONSTANTS ==========
const BAUDRATE = 38400;

// Message types
const MSG_NOTIFY_DEV_INFO = 0x0518;
const MSG_NOTIFY_BL_VER = 0x0530;
const MSG_PROG_FW = 0x0519;
const MSG_PROG_FW_RESP = 0x051A;
const MSG_DEV_INFO_REQ = 0x0514;
const MSG_DEV_INFO_RESP = 0x0515;
const MSG_READ_EEPROM = 0x051B;
const MSG_READ_EEPROM_RESP = 0x051C;
const MSG_WRITE_EEPROM = 0x051D;
const MSG_WRITE_EEPROM_RESP = 0x051E;
const MSG_REBOOT = 0x05DD;

const OBFUS_TBL = new Uint8Array([
  0x16, 0x6c, 0x14, 0xe6, 0x2e, 0x91, 0x0d, 0x40,
  0x21, 0x35, 0xd5, 0x40, 0x13, 0x03, 0xe9, 0x80
]);

const LEGACY_FW_XOR_TBL = new Uint8Array([
  0x47, 0x22, 0xc0, 0x52, 0x5d, 0x57, 0x48, 0x94, 0xb1, 0x60, 0x60, 0xdb, 0x6f, 0xe3, 0x4c, 0x7c,
  0xd8, 0x4a, 0xd6, 0x8b, 0x30, 0xec, 0x25, 0xe0, 0x4c, 0xd9, 0x00, 0x7f, 0xbf, 0xe3, 0x54, 0x05,
  0xe9, 0x3a, 0x97, 0x6b, 0xb0, 0x6e, 0x0c, 0xfb, 0xb1, 0x1a, 0xe2, 0xc9, 0xc1, 0x56, 0x47, 0xe9,
  0xba, 0xf1, 0x42, 0xb6, 0x67, 0x5f, 0x0f, 0x96, 0xf7, 0xc9, 0x3c, 0x84, 0x1b, 0x26, 0xe1, 0x4e,
  0x3b, 0x6f, 0x66, 0xe6, 0xa0, 0x6a, 0xb0, 0xbf, 0xc6, 0xa5, 0x70, 0x3a, 0xba, 0x18, 0x9e, 0x27,
  0x1a, 0x53, 0x5b, 0x71, 0xb1, 0x94, 0x1e, 0x18, 0xf2, 0xd6, 0x81, 0x02, 0x22, 0xfd, 0x5a, 0x28,
  0x91, 0xdb, 0xba, 0x5d, 0x64, 0xc6, 0xfe, 0x86, 0x83, 0x9c, 0x50, 0x1c, 0x73, 0x03, 0x11, 0xd6,
  0xaf, 0x30, 0xf4, 0x2c, 0x77, 0xb2, 0x7d, 0xbb, 0x3f, 0x29, 0x28, 0x57, 0x22, 0xd6, 0x92, 0x8b
]);

// Calibration memory layout
const CALIB_SIZE = 512; // bytes
const CHUNK_SIZE = 64;
let CALIB_OFFSET = 0x1E00; // Default for firmware < v5.0.0
const SERIAL_RESPONSE_TIMEOUT_MS = 30000;
const DEVICE_INFO_TIMEOUT_MS = 30000;
const EEPROM_READ_MAX_RETRIES = 3;
const EEPROM_CHUNK_FALLBACKS = [64, 32, 16];

// ========== STATE ==========
let port = null;
let reader = null;
let writer = null;
let firmwareData = null;
let calibData = null;
let isFlashing = false;
let isDumping = false;
let isRestoring = false;
let readBuffer = [];
let isReading = false;
let parsedMessageQueue = [];
let messageWaiters = [];

// ========== UI ELEMENTS ==========
const flashBtn = document.getElementById('flashBtn');
const dumpBtn = document.getElementById('dumpBtn');
const restoreBtn = document.getElementById('restoreBtn');
const blVersionInput = document.getElementById('blVersion');
const firmwareFileInput = document.getElementById('firmwareFile');
const calibFileInput = document.getElementById('calibFile');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const labelRadioProfileEl = document.getElementById('labelRadioProfile');
const radioProfileSelect = document.getElementById('radioProfile');
const profileHelpEl = document.getElementById('profileHelp');
const engineBadgeEl = document.getElementById('engineBadge');
const firmwareFileSection = document.getElementById('firmwareFileSection');
const labelBlVersionEl = document.getElementById('labelBlVersion');
const labelFwFileEl = document.getElementById('labelFirmwareFile');
const labelCalibFileEl = document.getElementById('labelCalibFile');
const logDiv = document.getElementById('log');
const infoBoxEl = document.getElementById('infoBox');
const progressContainer = document.getElementById('progressContainer');
const progressFill = document.getElementById('progressFill');
const progressLabel = document.getElementById('progressLabel');
const logToggle = document.getElementById('logToggle');
const languageSelect = document.getElementById('languageSelect');
const dumpDownload = document.getElementById('dumpDownload');
const dumpLink = document.getElementById('dumpLink');
const baselineDev = document.getElementById("baseline-developed");

// File input labels
const fileLabel = document.getElementById('fileLabel');
const fileName = document.getElementById('fileName');
const fileButton = document.getElementById('fileButton');
const calibFileLabel = document.getElementById('calibFileLabel');
const calibFileName = document.getElementById('calibFileName');
const calibFileButton = document.getElementById('calibFileButton');

const PROFILE_DEFAULT = null;
const LEGACY_VERSION_INFO_OFFSET = 0x2000;
const LEGACY_VERSION_INFO_LENGTH = 16;
const LEGACY_MAX_FIRMWARE_SIZE = 0xefff;
const PROFILE_CONFIG = {
  'k5k6-v1': { engine: 'legacy', helpKey: 'profileHelpLegacy' },
  'k5k6-v2': { engine: 'legacy', helpKey: 'profileHelpLegacy' },
  'k1k5-v3': { engine: 'native', helpKey: 'profileHelpV3' }
};

// ========== VERSION COMPARISON ==========
function isBootloaderCompatible(version, minVersion) {
  // Parse version strings (e.g., "7.02.02")
  const parseVersion = (v) => {
    const parts = v.split('.').map(p => parseInt(p, 10) || 0);
    while (parts.length < 3) parts.push(0);
    return parts;
  };
  
  const current = parseVersion(version);
  const required = parseVersion(minVersion);
  
  // Compare major.minor.patch
  for (let i = 0; i < 3; i++) {
    if (current[i] > required[i]) return true;
    if (current[i] < required[i]) return false;
  }
  
  return true; // Equal versions are compatible
}

// ========== i18n HELPER ==========
function t(key, ...args) {
  return window.i18n && window.i18n.t ? window.i18n.t(key, ...args) : key;
}

function getSelectedProfileId() {
  const profileId = radioProfileSelect?.value || '';
  return PROFILE_CONFIG[profileId] ? profileId : PROFILE_DEFAULT;
}

function getSelectedProfile() {
  const profileId = getSelectedProfileId();
  if (!profileId) return null;
  return { id: profileId, ...PROFILE_CONFIG[profileId] };
}

function applyProfileFromQuery() {
  if (!radioProfileSelect) return;
  const profile = new URLSearchParams(window.location.search).get('profile');
  if (profile && PROFILE_CONFIG[profile]) {
    radioProfileSelect.value = profile;
  }
}

function setSelectedProfile(profileId) {
  if (!radioProfileSelect || !PROFILE_CONFIG[profileId]) return;
  radioProfileSelect.value = profileId;
  applyRadioProfileUI();
  updateInfoBox();
}

function xorLegacyFirmware(data) {
  const out = new Uint8Array(data.length);
  for (let i = 0; i < data.length; i++) {
    out[i] = data[i] ^ LEGACY_FW_XOR_TBL[i % LEGACY_FW_XOR_TBL.length];
  }
  return out;
}

function detectProfileFromFirmware(data) {
  // Legacy packed firmware has a CRC16 trailer over encoded content and version bytes at 0x2000 after XOR decode.
  if (data.length > 0x2012) {
    const body = data.subarray(0, data.length - 2);
    const expectedCrc = data[data.length - 2] | (data[data.length - 1] << 8);
    const computedCrc = calcCRC(body, 0, body.length);

    if (computedCrc === expectedCrc) {
      const decoded = xorLegacyFirmware(body);
      const versionByte = decoded[0x2000];
      if (versionByte === 0x32) return { profileId: 'k5k6-v1', mode: 'legacy' }; // '2'
      if (versionByte === 0x33 || versionByte === 0x34 || versionByte === 0x2a) return { profileId: 'k5k6-v2', mode: 'legacy' }; // '3', '4', '*'
      return { profileId: 'k5k6-v2', mode: 'legacy' };
    }
  }

  return { profileId: 'k1k5-v3', mode: 'native' };
}

function autoSelectProfileFromFirmware(data) {
  const detected = detectProfileFromFirmware(data);
  setSelectedProfile(detected.profileId);
  if (detected.mode === 'legacy') {
    log(t('autoDetectLegacy', t(detected.profileId === 'k5k6-v1' ? 'profileK5K6V1' : 'profileK5K6V2')), 'info');
  } else {
    log(t('autoDetectNative', t('profileK1K5V3')), 'info');
  }
}

function applyRadioProfileUI() {
  const profile = getSelectedProfile();
  const isLegacy = profile?.engine === 'legacy';
  const hasProfile = Boolean(profile);

  if (profileHelpEl) profileHelpEl.textContent = hasProfile ? t(profile.helpKey) : t('profileHelpAuto');
  if (engineBadgeEl) {
    engineBadgeEl.hidden = !hasProfile;
    if (hasProfile) {
      const badgeText = isLegacy ? t('engineBadgeLegacy') : t('engineBadgeNative');
      const badgeTooltip = isLegacy ? t('engineBadgeLegacyTooltip') : t('engineBadgeNativeTooltip');
      engineBadgeEl.textContent = badgeText;
      engineBadgeEl.title = badgeTooltip;
      engineBadgeEl.setAttribute('aria-label', `${badgeText}. ${badgeTooltip}`);
      engineBadgeEl.classList.toggle('engine-legacy', isLegacy);
      engineBadgeEl.classList.toggle('engine-modern', !isLegacy);
    }
  }
  if (firmwareFileInput) firmwareFileInput.disabled = false;
  if (firmwareFileSection) firmwareFileSection.classList.remove('is-disabled');
  if (dumpBtn) dumpBtn.disabled = isDumping;

  updateRestoreButton();
  updateFlashButton();
}

// ========== UI UPDATE ==========
window.updateUI = function updateUI() {
  if (titleEl) titleEl.textContent = t('title');
  if (subtitleEl) subtitleEl.textContent = t('subtitle');
  if (labelRadioProfileEl) labelRadioProfileEl.textContent = t('labelRadioProfile');
  if (labelBlVersionEl) labelBlVersionEl.textContent = t('labelBlVersion');
  if (labelFwFileEl) labelFwFileEl.textContent = t('labelFirmwareFile');
  if (labelCalibFileEl) labelCalibFileEl.textContent = t('labelCalibFile');
  if (baselineDev) baselineDev.textContent = t('baselineDeveloped');

  if (radioProfileSelect) {
    const optionBlank = radioProfileSelect.querySelector('option[value=""]');
    const optionV1 = radioProfileSelect.querySelector('option[value="k5k6-v1"]');
    const optionV2 = radioProfileSelect.querySelector('option[value="k5k6-v2"]');
    const optionV3 = radioProfileSelect.querySelector('option[value="k1k5-v3"]');
    if (optionBlank) optionBlank.textContent = t('profilePlaceholder');
    if (optionV1) optionV1.textContent = t('profileK5K6V1');
    if (optionV2) optionV2.textContent = t('profileK5K6V2');
    if (optionV3) optionV3.textContent = t('profileK1K5V3');
  }

  // Update info box based on active tab
  updateInfoBox();
  
  if (flashBtn) flashBtn.textContent = t('flashBtn');
  if (dumpBtn) dumpBtn.textContent = t('dumpBtn');
  if (restoreBtn) restoreBtn.textContent = t('restoreBtn');
  if (fileButton) fileButton.textContent = t('fileChoose');
  if (calibFileButton) calibFileButton.textContent = t('fileChoose');

  // Tabs
  const tabFlash = document.getElementById('tabFlash');
  const tabDump = document.getElementById('tabDump');
  const tabRestore = document.getElementById('tabRestore');
  if (tabFlash) tabFlash.textContent = t('tabFlash');
  if (tabDump) tabDump.textContent = t('tabDump');
  if (tabRestore) tabRestore.textContent = t('tabRestore');

  // Description
  const dumpDesc = document.getElementById('dumpDescription');
  const downloadText = document.getElementById('downloadText');
  if (dumpDesc) dumpDesc.textContent = t('dumpDescription');
  if (downloadText) downloadText.textContent = t('downloadText');
  if (dumpBtn) dumpBtn.textContent = t('dumpBtn');
  if (dumpFullBtn) dumpFullBtn.textContent = t('dumpFullBtn');
  const downloadFullTextEl = document.getElementById('downloadFullText');
  if (downloadFullTextEl) downloadFullTextEl.textContent = t('downloadFullText');

  // Log toggle
  if (logToggle) {
    const visible = logDiv && logDiv.classList.contains('visible');
    logToggle.textContent = visible ? t('logHide') : t('logShow');
    logToggle.setAttribute('aria-expanded', visible ? 'true' : 'false');
  }

  // File names
  if (fileName && !firmwareData) {
    fileName.textContent = t('fileNoFile');
    fileName.classList.remove('has-file');
    if (fileLabel) fileLabel.classList.remove('has-file');
  }

  if (calibFileName && !calibData) {
    calibFileName.textContent = t('fileNoFile');
    calibFileName.classList.remove('has-file');
    if (calibFileLabel) calibFileLabel.classList.remove('has-file');
  }

  if (languageSelect && window.i18n && window.i18n.lang) {
    languageSelect.value = window.i18n.lang;
  }

  applyRadioProfileUI();
};

// Update info box based on active tab
function updateInfoBox() {
  if (!infoBoxEl) return;
  
  const activeTab = document.querySelector('.tab.active');
  const tabName = activeTab ? activeTab.dataset.tab : 'flash';
  const profile = getSelectedProfile();
  
  if (tabName === 'flash') {
    infoBoxEl.innerHTML = profile?.engine === 'legacy' ? t('infoBoxLegacy') : t('infoBox');
  } else {
    infoBoxEl.innerHTML = t('infoBoxDump');
  }
}

// Re-apply UI when i18n signals readiness
window.addEventListener('i18n:ready', () => {
  if (window.updateUI) window.updateUI();
});

// Initial i18n sync
(async () => {
  if (window.i18nReady) await window.i18nReady;
  applyProfileFromQuery();
  if (window.updateUI) window.updateUI();
  await maybeLoadFirmwareFromQuery();
})();

if (radioProfileSelect) {
  radioProfileSelect.addEventListener('change', () => {
    applyRadioProfileUI();
    updateInfoBox();
  });
}

// ========== TABS ==========
document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(t => {
      t.classList.remove('active');
      t.setAttribute('aria-selected', 'false');
    });
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    
    tab.classList.add('active');
    tab.setAttribute('aria-selected', 'true');
    document.getElementById(tab.dataset.tab + '-content').classList.add('active');
    
    // Update info box when tab changes
    updateInfoBox();
  });
});

// ========== LOG VISIBILITY ==========
if (logToggle) {
  logToggle.addEventListener('click', () => {
    if (!logDiv) return;
    logDiv.classList.toggle('visible');
    logToggle.textContent = logDiv.classList.contains('visible') ? t('logHide') : t('logShow');
    logToggle.setAttribute('aria-expanded', logDiv.classList.contains('visible') ? 'true' : 'false');
  });
}

// ========== FIRMWARE FILE INPUT ==========
if (firmwareFileInput) {
  firmwareFileInput.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const fr = new FileReader();
    fr.onload = (ev) => setFirmwareBuffer(ev.target.result, file.name);
    fr.readAsArrayBuffer(file);
  });
}

function setFirmwareBuffer(buf, name = 'firmware.bin') {
  firmwareData = new Uint8Array(buf);
  autoSelectProfileFromFirmware(firmwareData);
  if (fileName) {
    fileName.textContent = name;
    fileName.classList.add('has-file');
  }
  if (fileLabel) fileLabel.classList.add('has-file');
  log(t('firmwareLoaded', name, firmwareData.length), 'success');
  updateFlashButton();
}

function clearFirmwareSelection() {
  firmwareData = null;

  if (firmwareFileInput) firmwareFileInput.value = '';

  if (fileName) {
    fileName.textContent = t('fileNoFile');
    fileName.classList.remove('has-file');
  }

  if (fileLabel) fileLabel.classList.remove('has-file');

  updateFlashButton();
}

function resetRadioProfileSelection() {
  if (!radioProfileSelect) return;
  radioProfileSelect.value = '';
  applyRadioProfileUI();
  updateInfoBox();
}

// ---------- Auto-load firmware from URL ----------

async function loadFirmwareFromURL(url) {
  try {
    log(t('loadingFromUrl', url), 'info');

    const urlObj = new URL(url);

    // Only HTTPS
    if (urlObj.protocol !== 'https:') {
      throw new Error(t('urlHttpNotHttps'));
    }

    // GitHub convenience: github.com/.../raw/... → raw.githubusercontent.com/...
    if (urlObj.hostname === 'github.com' && urlObj.pathname.includes('/raw/')) {
      const parts = urlObj.pathname.split('/').filter(Boolean);
      const i = parts.indexOf('raw');
      if (i > 1 && i < parts.length - 1) {
        const user = parts[0];
        const repo = parts[1];
        const branch = parts[i + 1];
        const rest = parts.slice(i + 2).join('/');
        urlObj.hostname = 'raw.githubusercontent.com';
        urlObj.pathname = `/${user}/${repo}/${branch}/${rest}`;
      }
    }

    const res = await fetch(urlObj.toString(), { cache: 'no-cache', mode: 'cors' });
    if (!res.ok) {
      throw new Error(`${t('urlFetchError')} HTTP ${res.status}`);
    }

    const buf = await res.arrayBuffer();
    const fname = (urlObj.pathname.split('/').pop() || 'firmware.bin').split('?')[0];

    setFirmwareBuffer(buf, fname);

    // Clean URL so refresh does not re-trigger auto-load
    const clean = new URL(window.location.href);
    clean.searchParams.delete('firmwareURL');
    clean.searchParams.delete('fw');
    window.history.replaceState({}, '', clean.toString());
  } catch (err) {
    log(`${t('urlFetchError')} ${err?.message ?? String(err)}`, 'error');
  }
}

async function maybeLoadFirmwareFromQuery() {
  try {
    const params = new URLSearchParams(window.location.search);
    const param = params.get('firmwareURL') || params.get('fw');
    if (!param) return;
    await loadFirmwareFromURL(decodeURIComponent(param));
  } catch (e) {
    log(t('urlInvalid'), 'error');
  }
}

function updateFlashButton() {
  if (!flashBtn) return;
  const profile = getSelectedProfile();
  flashBtn.textContent = t('flashBtn');
  flashBtn.disabled = isFlashing || !profile || !firmwareData;
}

// ========== CALIBRATION FILE INPUT ==========
if (calibFileInput) {
  calibFileInput.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const fr = new FileReader();
    fr.onload = (ev) => {
      const buf = new Uint8Array(ev.target.result);
      if (buf.length !== CALIB_SIZE) {
        log(t('calibInvalidSize', buf.length), 'error');
        return;
      }
      calibData = buf;
      if (calibFileName) {
        calibFileName.textContent = file.name;
        calibFileName.classList.add('has-file');
      }
      if (calibFileLabel) calibFileLabel.classList.add('has-file');
      log(t('calibLoaded', file.name, calibData.length), 'success');
      updateRestoreButton();
    };
    fr.readAsArrayBuffer(file);
  });
}

function updateRestoreButton() {
  if (!restoreBtn) return;
  restoreBtn.disabled = !calibData || isRestoring;
}

// ========== SERIAL CONNECTION ==========
async function connect() {
  try {
    log(t('requestingPort'), 'info');
    port = await navigator.serial.requestPort();
    log(t('openingPort'), 'info');
    await port.open({ baudRate: BAUDRATE });

    log(t('gettingReader'), 'info');
    reader = port.readable.getReader();
    log(t('gettingWriter'), 'info');
    writer = port.writable.getWriter();

    log(t('startingRead'), 'info');
    startReading();

    log(t('waiting500ms'), 'info');
    await sleep(500);

    log(t('connected'), 'success');
  } catch (e) {
    log(t('connectionError', e?.message ?? String(e)), 'error');
    throw e;
  }
}

async function disconnect() {
  failPendingMessageWaiters(new Error('Serial disconnected'));
  isReading = false;
  if (reader) {
    try { await reader.cancel(); } catch (e) { /* no-op */ }
    try { reader.releaseLock(); } catch (e) { /* no-op */ }
    reader = null;
  }
  if (writer) {
    try { await writer.close(); } catch (e) { /* no-op */ }
    writer = null;
  }
  if (port) {
    try { await port.close(); } catch (e) { /* no-op */ }
    port = null;
  }
  log(t('disconnected'), 'info');
}

function startReading() {
  if (!reader || isReading) return;
  isReading = true;
  readLoop().catch(e => {
    if (isReading) log(t('loopError', e?.message ?? String(e)), 'error');
  });
}

async function readLoop() {
  log(t('startReading'), 'info');
  try {
    while (isReading && reader) {
      const { value, done } = await reader.read();
      if (done) {
        log(t('streamClosed'), 'info');
        break;
      }
      if (value?.length) {
        readBuffer.push(...value);
        processReadBuffer();
        log(t('rxData', value.length, readBuffer.length), 'info');
      }
    }
  } catch (e) {
    if (isReading) log(t('readError', e?.message ?? String(e)), 'error');
  }
  log(t('readComplete'), 'info');
}

// ========== PROTOCOL HELPERS ==========
function createMessage(msgType, dataLen) {
  const msg = new Uint8Array(4 + dataLen);
  const view = new DataView(msg.buffer);
  view.setUint16(0, msgType, true);
  view.setUint16(2, dataLen, true);
  return msg;
}

async function sendMessage(msg) {
  const packet = makePacket(msg);
  await writer.write(packet);
}

function makePacket(msg) {
  let msgLen = msg.length;
  if (msgLen % 2 !== 0) msgLen++;
  const buf = new Uint8Array(8 + msgLen);
  const view = new DataView(buf.buffer);

  view.setUint16(0, 0xCDAB, true);
  view.setUint16(2, msgLen, true);
  view.setUint16(6 + msgLen, 0xBADC, true);

  for (let i = 0; i < msg.length; i++) buf[4 + i] = msg[i];

  const crc = calcCRC(buf, 4, msgLen);
  view.setUint16(4 + msgLen, crc, true);

  obfuscate(buf, 4, 2 + msgLen);
  return buf;
}

function fetchMessage(buf) {
  if (buf.length < 8) return null;

  let packBegin = -1;
  for (let i = 0; i < buf.length - 1; i++) {
    if (buf[i] === 0xab && buf[i + 1] === 0xcd) {
      packBegin = i;
      break;
    }
  }
  if (packBegin === -1) {
    if (buf.length > 0 && buf[buf.length - 1] === 0xab) buf.splice(0, buf.length - 1);
    else buf.length = 0;
    return null;
  }
  if (buf.length - packBegin < 8) return null;

  const msgLen = (buf[packBegin + 3] << 8) | buf[packBegin + 2];
  const packEnd = packBegin + 6 + msgLen;
  if (buf.length < packEnd + 2) return null;

  if (buf[packEnd] !== 0xdc || buf[packEnd + 1] !== 0xba) {
    buf.splice(0, packBegin + 2);
    return null;
  }

  const msgBuf = new Uint8Array(msgLen + 2);
  for (let i = 0; i < msgLen + 2; i++) msgBuf[i] = buf[packBegin + 4 + i];
  obfuscate(msgBuf, 0, msgLen + 2);

  const view = new DataView(msgBuf.buffer);
  const msgType = view.getUint16(0, true);
  const data = msgBuf.slice(4);

  buf.splice(0, packEnd + 2);
  return { msgType, data, rawData: msgBuf };
}

function processReadBuffer() {
  let msg = fetchMessage(readBuffer);
  while (msg) {
    enqueueParsedMessage(msg);
    msg = fetchMessage(readBuffer);
  }
}

function enqueueParsedMessage(msg) {
  for (let i = 0; i < messageWaiters.length; i++) {
    const waiter = messageWaiters[i];
    if (waiter.predicate(msg)) {
      messageWaiters.splice(i, 1);
      if (waiter.timeoutId) clearTimeout(waiter.timeoutId);
      waiter.resolve(msg);
      return;
    }
  }
  parsedMessageQueue.push(msg);
}

function waitForMessage(predicate = () => true, timeoutMs = 3000) {
  for (let i = 0; i < parsedMessageQueue.length; i++) {
    const msg = parsedMessageQueue[i];
    if (predicate(msg)) {
      parsedMessageQueue.splice(i, 1);
      return Promise.resolve(msg);
    }
  }

  return new Promise((resolve, reject) => {
    const waiter = {
      predicate,
      resolve,
      reject,
      timeoutId: null
    };

    if (timeoutMs > 0) {
      waiter.timeoutId = setTimeout(() => {
        const idx = messageWaiters.indexOf(waiter);
        if (idx >= 0) messageWaiters.splice(idx, 1);
        reject(new Error('Timed out waiting for serial response'));
      }, timeoutMs);
    }

    messageWaiters.push(waiter);
  });
}

function failPendingMessageWaiters(error) {
  if (messageWaiters.length === 0) return;
  for (const waiter of messageWaiters) {
    if (waiter.timeoutId) clearTimeout(waiter.timeoutId);
    waiter.reject(error);
  }
  messageWaiters = [];
}

function resetMessageState() {
  readBuffer = [];
  parsedMessageQueue = [];
  failPendingMessageWaiters(new Error('Message state reset'));
}

function obfuscate(buf, off, size) {
  for (let i = 0; i < size; i++) buf[off + i] ^= OBFUS_TBL[i % OBFUS_TBL.length];
}

function calcCRC(buf, off, size) {
  let CRC = 0;
  for (let i = 0; i < size; i++) {
    const b = buf[off + i] & 0xff;
    CRC ^= b << 8;
    for (let j = 0; j < 8; j++) {
      if (CRC & 0x8000) CRC = ((CRC << 1) ^ 0x1021) & 0xffff;
      else CRC = (CRC << 1) & 0xffff;
    }
  }
  return CRC;
}

function arrayToHex(arr) {
  return Array.from(arr).map(b => b.toString(16).padStart(2, '0')).join(' ');
}

function unpackLegacyFirmware(encodedFirmware) {
  if (encodedFirmware.length <= LEGACY_VERSION_INFO_OFFSET + LEGACY_VERSION_INFO_LENGTH + 2) {
    throw new Error(t('legacyFirmwareInvalid'));
  }

  const body = encodedFirmware.subarray(0, encodedFirmware.length - 2);
  const expectedCrc = encodedFirmware[encodedFirmware.length - 2] | (encodedFirmware[encodedFirmware.length - 1] << 8);
  const computedCrc = calcCRC(body, 0, body.length);

  if (computedCrc !== expectedCrc) {
    throw new Error(t('legacyFirmwareInvalid'));
  }

  const decodedFirmware = xorLegacyFirmware(body);
  const versionInfo = decodedFirmware.slice(LEGACY_VERSION_INFO_OFFSET, LEGACY_VERSION_INFO_OFFSET + LEGACY_VERSION_INFO_LENGTH);
  const unpackedFirmware = new Uint8Array(decodedFirmware.length - LEGACY_VERSION_INFO_LENGTH);

  unpackedFirmware.set(decodedFirmware.subarray(0, LEGACY_VERSION_INFO_OFFSET));
  unpackedFirmware.set(decodedFirmware.subarray(LEGACY_VERSION_INFO_OFFSET + LEGACY_VERSION_INFO_LENGTH), LEGACY_VERSION_INFO_OFFSET);

  return { versionInfo, unpackedFirmware };
}

function legacyPacketize(data) {
  const payload = new Uint8Array(data.length + 2);
  payload.set(data, 0);
  const crc = calcCRC(data, 0, data.length);
  payload[data.length] = crc & 0xff;
  payload[data.length + 1] = (crc >> 8) & 0xff;
  obfuscate(payload, 0, payload.length);

  const packet = new Uint8Array(payload.length + 6);
  packet[0] = 0xab;
  packet[1] = 0xcd;
  packet[2] = data.length & 0xff;
  packet[3] = (data.length >> 8) & 0xff;
  packet.set(payload, 4);
  packet[packet.length - 2] = 0xdc;
  packet[packet.length - 1] = 0xba;
  return packet;
}

function legacyUnpacketize(packet) {
  const payloadLength = packet[2] | (packet[3] << 8);
  const payload = packet.slice(4, 4 + payloadLength + 2);
  obfuscate(payload, 0, payload.length);
  return payload.slice(0, payloadLength);
}

async function connectLegacyPort() {
  log(t('requestingPort'), 'info');
  const legacyPort = await navigator.serial.requestPort();
  log(t('openingPort'), 'info');
  await legacyPort.open({ baudRate: BAUDRATE });
  log(t('connected'), 'success');
  return legacyPort;
}

async function disconnectLegacyPort(legacyPort) {
  if (!legacyPort) return;
  try {
    await legacyPort.close();
  } catch (e) { /* no-op */ }
  log(t('disconnected'), 'info');
}

async function legacySendPacket(legacyPort, data) {
  const writer = legacyPort.writable.getWriter();
  try {
    await writer.write(legacyPacketize(data));
  } finally {
    writer.releaseLock();
  }
}

async function legacyReadPacket(legacyPort, expectedType, timeoutMs = 1000) {
  const reader = legacyPort.readable.getReader();
  let buffer = new Uint8Array();
  let timeoutId = null;

  try {
    return await new Promise((resolve, reject) => {
      const finish = (callback, value) => {
        if (timeoutId) clearTimeout(timeoutId);
        callback(value);
      };

      const pump = () => {
        reader.read().then(({ value, done }) => {
          if (done) {
            finish(reject, new Error(t('legacyNoData')));
            return;
          }

          buffer = new Uint8Array([...buffer, ...value]);

          while (buffer.length > 0 && buffer[0] !== 0xab) {
            buffer = buffer.slice(1);
          }

          while (buffer.length >= 8 && buffer[0] === 0xab && buffer[1] === 0xcd) {
            const payloadLength = buffer[2] | (buffer[3] << 8);
            const totalLength = payloadLength + 8;
            if (buffer.length < totalLength) break;

            const packet = buffer.slice(0, totalLength);
            buffer = buffer.slice(totalLength);

            if (packet[totalLength - 2] !== 0xdc || packet[totalLength - 1] !== 0xba) {
              continue;
            }

            const data = legacyUnpacketize(packet);
            if (data[0] !== expectedType) {
              continue;
            }

            finish(resolve, data);
            return;
          }

          pump();
        }).catch(error => finish(reject, error));
      };

      timeoutId = setTimeout(() => {
        reader.cancel().catch(() => {});
        reject(new Error(t('legacyPacketTimeout')));
      }, timeoutMs);

      pump();
    });
  } finally {
    if (timeoutId) clearTimeout(timeoutId);
    reader.releaseLock();
  }
}

async function legacyInitFlash(legacyPort, versionInfo) {
  const payload = new Uint8Array([0x30, 0x05, versionInfo.length, 0x00, ...versionInfo]);
  await legacySendPacket(legacyPort, payload);
  return legacyReadPacket(legacyPort, 0x18, 2000);
}

function legacyVersionMatches(bootInfoPacket, versionInfo) {
  if (versionInfo[0] === 0x2a) return true;
  return bootInfoPacket[0x14] === versionInfo[0];
}

function legacyBuildFlashCommand(data, address, totalSize) {
  const block = new Uint8Array(0x100);
  block.set(data, 0);

  const finalAddress = (totalSize + 0xff) & ~0xff;
  if (finalAddress > 0xf000) throw new Error(t('legacyFirmwareTooLarge'));

  return new Uint8Array([
    0x19, 0x05, 0x0c, 0x01, 0x8a, 0x8d, 0x9f, 0x1d,
    (address >> 8) & 0xff, address & 0xff,
    (finalAddress >> 8) & 0xff, 0x00,
    0x01, 0x00, 0x00, 0x00,
    ...block
  ]);
}

async function flashLegacyFirmware(legacyPort, unpackedFirmware) {
  if (unpackedFirmware.length > LEGACY_MAX_FIRMWARE_SIZE) {
    throw new Error(t('legacyFirmwareTooLarge'));
  }

  for (let offset = 0; offset < unpackedFirmware.length; offset += 0x100) {
    const chunk = unpackedFirmware.slice(offset, offset + 0x100);
    await legacySendPacket(legacyPort, legacyBuildFlashCommand(chunk, offset, unpackedFirmware.length));
    await legacyReadPacket(legacyPort, 0x1a, 2000);
    const percent = ((offset + chunk.length) / unpackedFirmware.length) * 100;
    updateProgress(Math.round(percent));
    log(t('legacyFlashingProgress', percent.toFixed(1)), 'info');
  }
}

async function flashLegacyFirmwareFlow() {
  if (!firmwareData) return;

  isFlashing = true;
  updateFlashButton();
  if (progressContainer) progressContainer.style.display = 'block';
  updateProgress(0);

  let legacyPort = null;

  try {
    const { versionInfo, unpackedFirmware } = unpackLegacyFirmware(firmwareData);
    legacyPort = await connectLegacyPort();

    const readyPacket = await legacyReadPacket(legacyPort, 0x18, 1500);
    if (readyPacket[0] !== 0x18) {
      throw new Error(t('legacyWrongPacket'));
    }
    log(t('legacyRadioReady'), 'info');

    const initResponse = await legacyInitFlash(legacyPort, versionInfo);
    const versionEnd = versionInfo.indexOf(0) === -1 ? versionInfo.length : versionInfo.indexOf(0);
    const versionText = new TextDecoder().decode(versionInfo.subarray(0, versionEnd));
    log(t('legacyVersionDetected', versionText), 'info');

    if (!legacyVersionMatches(initResponse, versionInfo)) {
      throw new Error(t('legacyVersionCheckFailed'));
    }
    log(t('legacyVersionCheckPassed'), 'success');

    await flashLegacyFirmware(legacyPort, unpackedFirmware);
    log(t('legacyFlashSuccess'), 'success');
    clearFirmwareSelection();
    resetRadioProfileSelection();
  } finally {
    if (progressContainer) progressContainer.style.display = 'none';
    isFlashing = false;
    updateFlashButton();
    await disconnectLegacyPort(legacyPort);
  }
}

// ========== FLASH FIRMWARE (from original flash.js) ==========
flashBtn.addEventListener('click', async () => {
  const profile = getSelectedProfile();
  if (!profile) return;
  if (profile.engine === 'legacy') {
    try {
      await flashLegacyFirmwareFlow();
    } catch (e) {
      log(t('flashError', e?.message ?? String(e)), 'error');
    }
    return;
  }
  if (!firmwareData || isFlashing) return;
  try {
    if (!port) await connect();
    await flashFirmware();
  } catch (e) {
    log(t('flashError', e?.message ?? String(e)), 'error');
    isFlashing = false;
    updateFlashButton();
  } finally {
    if (port) await disconnect();
  }
});

async function flashFirmware() {
  isFlashing = true;
  updateFlashButton();

  if (progressContainer) progressContainer.style.display = 'block';
  updateProgress(0);

  resetMessageState();
  log(t('bufferEmpty'), 'info');
  await sleep(1000);
  processReadBuffer();
  log(t('bufferContains', readBuffer.length), 'info');

  try {
    log(t('establishing'), 'info');
    const devInfo = await waitForDeviceInfo();
    log(t('uidLabel', arrayToHex(devInfo.uid)), 'info');
    log(t('blVersionLabel', devInfo.blVersion), 'info');

    // Check bootloader version compatibility
    const minVersion = '7.00.07';
    if (!isBootloaderCompatible(devInfo.blVersion, minVersion)) {
      log('==============================================', 'error');
      log('❌ INCOMPATIBLE BOOTLOADER VERSION', 'error');
      log(`   Detected: ${devInfo.blVersion}`, 'error');
      log(`   Required: ${minVersion} or higher`, 'error');
      log('', 'error');
      log('This radio does not seem compatible with this firmware.', 'error');
      log('Please open an issue on GitHub:', 'error');
      log('https://github.com/armel/uv-k1-k5v3-firmware-custom', 'error');
      log('Please, include your bootloader version in the issue:', 'error');
      log(`   Bootloader: ${devInfo.blVersion}`, 'error');
      log('==============================================', 'error');
      throw new Error('Bootloader version too old');
    }

    const expectedBl = blVersionInput?.value?.trim?.() ?? '';
    if (expectedBl !== '*' && expectedBl !== '?' && expectedBl !== '' && devInfo.blVersion !== expectedBl) {
      log(t('blWarning', expectedBl, devInfo.blVersion), 'error');
    }
    log(t('deviceDetected'), 'success');

    log(t('handshake'), 'info');
    await performHandshake(devInfo.blVersion);
    log(t('handshakeComplete'), 'success');

    await programFirmware();

    updateProgress(100);
    log(t('programmingComplete'), 'success');
    clearFirmwareSelection();
    resetRadioProfileSelection();

    setTimeout(() => {
      if (progressContainer) progressContainer.style.display = 'none';
      updateProgress(0);
    }, 800);
  } finally {
    isFlashing = false;
    updateFlashButton();
  }
}

async function waitForDeviceInfo() {
  let lastTimestamp = 0;
  let acc = 0;
  log(t('waiting'), 'info');

  const deadline = Date.now() + DEVICE_INFO_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const remaining = Math.max(1, deadline - Date.now());
    const msg = await waitForMessage(() => true, remaining);

    log(t('messageReceived', msg.msgType.toString(16).padStart(4, '0')), 'info');

    if (msg.msgType !== MSG_NOTIFY_DEV_INFO) continue;

    const now = Date.now();
    const dt = now - lastTimestamp;
    log(t('interval', dt, acc), 'info');
    lastTimestamp = now;

    // Do not enforce strict interval bounds because background tabs can delay JS scheduling.
    acc++;
    log(t('validMessage', acc), 'success');
    if (acc >= 1) {
      const uid = msg.data.slice(0, 16);
      let blVersionEnd = -1;
      for (let i = 16; i < 32; i++) {
        if (msg.data[i] === 0) {
          blVersionEnd = i;
          break;
        }
      }
      if (blVersionEnd === -1) blVersionEnd = 32;
      const blVersion = new TextDecoder().decode(msg.data.slice(16, blVersionEnd));
      return { uid, blVersion };
    }
  }
  throw new Error(t('timeoutNoDevice'));
}

async function performHandshake(blVersion) {
  let acc = 0;

  while (acc < 3) {
    await waitForMessage(m => m.msgType === MSG_NOTIFY_DEV_INFO, SERIAL_RESPONSE_TIMEOUT_MS);
    if (acc === 0) log(t('sendingBlVersion'), 'info');

    const blMsg = createMessage(MSG_NOTIFY_BL_VER, 4);
    const blBytes = new TextEncoder().encode(blVersion.substring(0, 4));
    for (let i = 0; i < Math.min(blBytes.length, 4); i++) blMsg[4 + i] = blBytes[i];
    await sendMessage(blMsg);
    acc++;
  }

  log(t('waitingStop'), 'info');
  await sleep(200);

  processReadBuffer();
  while (parsedMessageQueue.length > 0) {
    const msg = parsedMessageQueue.shift();
    if (msg.msgType === MSG_NOTIFY_DEV_INFO) log(t('devInfoIgnored'), 'info');
    else log(t('messageReceived', msg.msgType.toString(16)), 'info');
  }
  log(t('bufferCleaned', 0), 'info');
}

async function programFirmware() {
  const pageCount = Math.ceil(firmwareData.length / 256);
  const timestamp = Date.now() & 0xffffffff;
  log(t('programming', pageCount), 'info');

  let pageIndex = 0, retryCount = 0;
  const MAX_RETRIES = 3;

  while (pageIndex < pageCount) {
    updateProgress((pageIndex / pageCount) * 100);

    const msg = createMessage(MSG_PROG_FW, 268);
    const view = new DataView(msg.buffer);
    view.setUint32(4, timestamp, true);
    view.setUint16(8, pageIndex, true);
    view.setUint16(10, pageCount, true);

    const offset = pageIndex * 256;
    const len = Math.min(256, firmwareData.length - offset);
    for (let i = 0; i < len; i++) msg[16 + i] = firmwareData[offset + i];

    await sendMessage(msg);

    let gotResponse = false;
    const deadline = Date.now() + SERIAL_RESPONSE_TIMEOUT_MS;
    while (Date.now() < deadline && !gotResponse) {
      const remaining = Math.max(1, deadline - Date.now());
      const resp = await waitForMessage(() => true, remaining);
      if (resp.msgType === MSG_NOTIFY_DEV_INFO) continue;
      if (resp.msgType !== MSG_PROG_FW_RESP) continue;

      const dv = new DataView(resp.data.buffer);
      const respPageIndex = dv.getUint16(4, true);
      const err = dv.getUint16(6, true);

      if (respPageIndex !== pageIndex) {
        log(t('pageWrongResponse', pageIndex + 1, pageCount, respPageIndex), 'error');
        continue;
      }
      if (err !== 0) {
        log(t('pageError', pageIndex + 1, pageCount, err), 'error');
        retryCount++;
        if (retryCount > MAX_RETRIES) throw new Error(t('tooManyErrors', pageIndex));
        break;
      }

      gotResponse = true;
      retryCount = 0;
      if ((pageIndex + 1) % 10 === 0 || pageIndex === pageCount - 1)
        log(t('pageOk', pageIndex + 1, pageCount), 'success');
    }

    if (gotResponse) {
      pageIndex++;
    } else {
      log(t('pageTimeout', pageIndex + 1, pageCount), 'error');
      retryCount++;
      if (retryCount > MAX_RETRIES) throw new Error(t('tooManyTimeouts', pageIndex));
    }
  }
}

// ========== EEPROM READ HELPER ==========
const EEPROM_FULL_SIZE = 0x10000; // 64 KB

function isLikelyEmptyCalibrationDump(data) {
  if (!data || data.length === 0) return true;

  let zeroCount = 0;
  let ffCount = 0;
  for (let i = 0; i < data.length; i++) {
    if (data[i] === 0x00) zeroCount++;
    if (data[i] === 0xFF) ffCount++;
  }

  const maxCount = Math.max(zeroCount, ffCount);
  const ratio = maxCount / data.length;
  return ratio >= 0.98;
}

function analyzeDumpData(data) {
  const histogram = new Uint32Array(256);
  for (let i = 0; i < data.length; i++) histogram[data[i]]++;

  let uniqueBytes = 0;
  let dominantByte = 0;
  let dominantCount = 0;
  for (let i = 0; i < histogram.length; i++) {
    const count = histogram[i];
    if (count > 0) uniqueBytes++;
    if (count > dominantCount) {
      dominantCount = count;
      dominantByte = i;
    }
  }

  return {
    size: data.length,
    uniqueBytes,
    dominantByte,
    dominantCount,
    dominantRatio: data.length > 0 ? dominantCount / data.length : 1
  };
}

function logDumpStats(label, data) {
  const stats = analyzeDumpData(data);
  log(
    `${label} stats: size=${stats.size} bytes, unique=${stats.uniqueBytes}, dominant=0x${stats.dominantByte
      .toString(16)
      .toUpperCase()
      .padStart(2, '0')} (${(stats.dominantRatio * 100).toFixed(1)}%)`,
    'info'
  );

  if (stats.dominantRatio >= 0.98) {
    log(
      `${label} appears suspiciously uniform (mostly 0x${stats.dominantByte
        .toString(16)
        .toUpperCase()
        .padStart(2, '0')}). Verify radio mode and connection quality.`,
      'error'
    );
  }
}

function getAlternateCalibOffset(offset) {
  return offset === 0xB000 ? 0x1E00 : 0xB000;
}

async function readEepromChunk(devInfo, offset, chunkSize) {
  const msg = createMessage(MSG_READ_EEPROM, 8);
  const view = new DataView(msg.buffer);
  view.setUint16(4, offset, true);
  view.setUint16(6, chunkSize, true);
  view.setUint32(8, devInfo.timestamp, true);
  await sendMessage(msg);

  const deadline = Date.now() + SERIAL_RESPONSE_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const remaining = Math.max(1, deadline - Date.now());
    const resp = await waitForMessage(m => m.msgType === MSG_READ_EEPROM_RESP, remaining);
    if (!resp?.data || resp.data.length < 4) continue;

    const dv = new DataView(resp.data.buffer, resp.data.byteOffset, resp.data.byteLength);
    const respOffset = dv.getUint16(0, true);
    const respSize = resp.data[2];

    if (respOffset !== offset || respSize !== chunkSize) continue;
    if (resp.data.length < 4 + respSize) {
      throw new Error(`Invalid EEPROM response length at 0x${offset.toString(16)}`);
    }

    return resp.data.slice(4, 4 + respSize);
  }

  throw new Error(t('eepromError', offset.toString(16)));
}

async function readEepromChunkWithRetry(devInfo, offset, requestedSize) {
  const candidates = EEPROM_CHUNK_FALLBACKS.filter(size => size <= requestedSize);
  for (const candidateSize of candidates) {
    for (let attempt = 1; attempt <= EEPROM_READ_MAX_RETRIES; attempt++) {
      try {
        const data = await readEepromChunk(devInfo, offset, candidateSize);
        if (candidateSize !== requestedSize) {
          log(`EEPROM read fallback chunk ${candidateSize} bytes at 0x${offset.toString(16).toUpperCase()}`, 'info');
        }
        return data;
      } catch (e) {
        if (attempt === EEPROM_READ_MAX_RETRIES) {
          log(`EEPROM read retry exhausted (size=${candidateSize}) at 0x${offset.toString(16).toUpperCase()}`, 'error');
        }
      }
    }
  }

  throw new Error(t('eepromError', offset.toString(16)));
}

async function readEepromRegion(devInfo, startOffset, size, onProgress) {
  const data = new Uint8Array(size);
  let bytesRead = 0;
  let offset = startOffset;

  while (bytesRead < size) {
    if (onProgress) onProgress(Math.round((bytesRead / size) * 100));
    const remaining = size - bytesRead;
    const requestSize = Math.min(CHUNK_SIZE, remaining);
    const chunk = await readEepromChunkWithRetry(devInfo, offset, requestSize);

    data.set(chunk, bytesRead);
    bytesRead += chunk.length;
    offset += chunk.length;
  }

  return data;
}

// ========== DUMP CALIBRATION ==========
const dumpFullBtn = document.getElementById('dumpFullBtn');
const dumpFullDownload = document.getElementById('dumpFullDownload');
const dumpFullLink = document.getElementById('dumpFullLink');

dumpBtn.addEventListener('click', async () => {
  if (isDumping) return;
  isDumping = true;
  dumpBtn.disabled = true;
  if (dumpFullBtn) dumpFullBtn.disabled = true;
  progressContainer.style.display = 'block';
  updateProgress(0);
  dumpDownload.style.display = 'none';

  try {
    if (!port) await connect();
    resetMessageState();
    await sleep(1000);
    processReadBuffer();


    const devInfo = await requestDeviceInfo();
    log(t('dumpingData'), 'info');

    log(t('readingEeprom', CALIB_OFFSET.toString(16).toUpperCase()), 'info');
    let dumpedData = await readEepromRegion(devInfo, CALIB_OFFSET, CALIB_SIZE, pct => updateProgress(pct));

    if (isLikelyEmptyCalibrationDump(dumpedData)) {
      const alternateOffset = getAlternateCalibOffset(CALIB_OFFSET);
      log(`Calibration dump looks empty at 0x${CALIB_OFFSET.toString(16).toUpperCase()}, trying 0x${alternateOffset.toString(16).toUpperCase()}...`, 'info');
      const fallbackData = await readEepromRegion(devInfo, alternateOffset, CALIB_SIZE, pct => updateProgress(pct));
      if (!isLikelyEmptyCalibrationDump(fallbackData)) {
        dumpedData = fallbackData;
        CALIB_OFFSET = alternateOffset;
        log(`Using calibration offset 0x${alternateOffset.toString(16).toUpperCase()} based on content check.`, 'success');
      } else {
        log('Calibration dump still appears mostly empty after fallback offset probe.', 'error');
      }
    }

    logDumpStats('Calibration dump', dumpedData);

    updateProgress(100);
    log(t('dumpComplete'), 'success');

    const blob = new Blob([dumpedData], { type: 'application/octet-stream' });
    const url = URL.createObjectURL(blob);
    dumpLink.href = url;
    dumpLink.download = 'calibration.dat';
    dumpDownload.style.display = 'block';
    log(t('dumpSaved'), 'success');

    setTimeout(() => {
      if (progressContainer) progressContainer.style.display = 'none';
      updateProgress(0);
    }, 800);
  } catch (e) {
    log(t('error', e?.message ?? String(e)), 'error');
  } finally {
    isDumping = false;
    dumpBtn.disabled = false;
    if (dumpFullBtn) dumpFullBtn.disabled = false;
    if (port) await disconnect();
  }
});

// ========== DUMP FULL EEPROM ==========
if (dumpFullBtn) {
  dumpFullBtn.addEventListener('click', async () => {
    if (isDumping) return;
    isDumping = true;
    dumpBtn.disabled = true;
    dumpFullBtn.disabled = true;
    progressContainer.style.display = 'block';
    updateProgress(0);
    if (dumpFullDownload) dumpFullDownload.style.display = 'none';

    try {
      if (!port) await connect();
      resetMessageState();
      await sleep(1000);
      processReadBuffer();

      const devInfo = await requestDeviceInfo();
      log(t('dumpFullStarted'), 'info');

      const fullData = await readEepromRegion(devInfo, 0, EEPROM_FULL_SIZE, pct => updateProgress(pct));
      logDumpStats('Full EEPROM dump', fullData);

      updateProgress(100);
      log(t('dumpFullComplete'), 'success');

      const blob = new Blob([fullData], { type: 'application/octet-stream' });
      const url = URL.createObjectURL(blob);
      dumpFullLink.href = url;
      dumpFullLink.download = 'eeprom_full.bin';
      dumpFullDownload.style.display = 'block';
      log(t('dumpFullSaved'), 'success');

      setTimeout(() => {
        if (progressContainer) progressContainer.style.display = 'none';
        updateProgress(0);
      }, 800);
    } catch (e) {
      log(t('error', e?.message ?? String(e)), 'error');
    } finally {
      isDumping = false;
      dumpBtn.disabled = false;
      dumpFullBtn.disabled = false;
      if (port) await disconnect();
    }
  });
}

// ========== RESTORE CALIBRATION ==========
restoreBtn.addEventListener('click', async () => {
  if (!calibData || isRestoring) return;
  isRestoring = true;
  restoreBtn.disabled = true;
  progressContainer.style.display = 'block';
  updateProgress(0);

  try {
    if (!port) await connect();
    resetMessageState();
    await sleep(1000);
    processReadBuffer();

    const devInfo = await requestDeviceInfo();
    log(t('restoringData'), 'info');

    let offset = CALIB_OFFSET;

    for (let i = 0; i < CALIB_SIZE; i += CHUNK_SIZE) {
      const pct = Math.round((i / CALIB_SIZE) * 100);
      updateProgress(pct);

      const msg = createMessage(MSG_WRITE_EEPROM, 24);
      const view = new DataView(msg.buffer);
      view.setUint16(4, offset, true);
      view.setUint16(6, CHUNK_SIZE, true);
      msg[7] = 1;
      view.setUint32(8, devInfo.timestamp, true);
      
      for (let j = 0; j < CHUNK_SIZE; j++) {
        msg[12 + j] = calibData[i + j];
      }
      
      await sendMessage(msg);

      let gotResponse = false;
      const deadline = Date.now() + SERIAL_RESPONSE_TIMEOUT_MS;
      while (Date.now() < deadline && !gotResponse) {
        const remaining = Math.max(1, deadline - Date.now());
        const resp = await waitForMessage(m => m.msgType === MSG_WRITE_EEPROM_RESP, remaining);
        const dv = new DataView(resp.data.buffer);
        const respOffset = dv.getUint16(0, true);

        if (respOffset === offset) {
          gotResponse = true;
          offset += CHUNK_SIZE;
        }
      }

      if (!gotResponse) {
        throw new Error(t('eepromError', offset.toString(16)));
      }
    }

    updateProgress(100);
    log(t('restoreComplete'), 'success');

    log(t('rebooting'), 'info');
    const rebootMsg = createMessage(MSG_REBOOT, 0);
    await sendMessage(rebootMsg);
    await sleep(500);
    log(t('rebootComplete'), 'success');

    setTimeout(() => {
      if (progressContainer) progressContainer.style.display = 'none';
      updateProgress(0);
    }, 800);
  } catch (e) {
    log(t('error', e?.message ?? String(e)), 'error');
  } finally {
    isRestoring = false;
    updateRestoreButton();
    if (port) await disconnect();
  }
});

// ========== REQUEST DEVICE INFO (for dump/restore) ==========
async function requestDeviceInfo() {
  log(t('establishing'), 'info');
  
  const ts = Date.now() & 0xffffffff;
  const msg = createMessage(MSG_DEV_INFO_REQ, 4);
  new DataView(msg.buffer).setUint32(4, ts, true);
  await sendMessage(msg);

  const deadline = Date.now() + DEVICE_INFO_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const remaining = Math.max(1, deadline - Date.now());
    const resp = await waitForMessage(() => true, remaining);

    log(t('messageReceived', resp.msgType.toString(16).padStart(4, '0')), 'info');

    if (resp.msgType !== MSG_DEV_INFO_RESP) continue;

    // Log raw device info data
    logDeviceInfo(resp.data);
    log(t('deviceDetected'), 'success');
    return { timestamp: ts };
  }
  throw new Error(t('timeoutNoDevice'));
}

// Helper to display device info response
function logDeviceInfo(data) {
  // Extract ASCII string from device info
  let deviceInfoStr = '';
  for (let i = 0; i < data.length; i++) {
    const c = data[i];
    if (c === 0x00 || c === 0xFF) break; // Stop at null or padding
    if (c >= 32 && c < 127) {
      deviceInfoStr += String.fromCharCode(c);
    }
  }
  
  if (deviceInfoStr) {
    log(`Device: ${deviceInfoStr}`, 'success');
    
    // Extract version from string (e.g., "F4HWN v4.3.3" -> "4.3.3")
    const versionMatch = deviceInfoStr.match(/(?:^|\s)v?(\d+)\.(\d+)\.(\d+)/i);
    if (versionMatch) {
      const major = Number(versionMatch[1]);
      const minor = Number(versionMatch[2]);
      const patch = Number(versionMatch[3]);
      const version = `${major}.${minor}.${patch}`;
      
      // Set CALIB_OFFSET based on version
      if (major >= 5) {
        CALIB_OFFSET = 0xB000;
        log(`Firmware v${version} detected: CALIB_OFFSET = 0xB000`, 'info');
      } else {
        CALIB_OFFSET = 0x1E00;
        log(`Firmware v${version} detected: CALIB_OFFSET = 0x1E00`, 'info');
      }
    } else {
      log('Could not parse firmware version from device info, keeping current calibration offset.', 'info');
    }
  } else {
    // Fallback to hex dump if no ASCII found
    let hexStr = 'Device Info (hex): ';
    for (let i = 0; i < Math.min(data.length, 40); i++) {
      hexStr += data[i].toString(16).padStart(2, '0').toUpperCase() + ' ';
    }
    log(hexStr, 'info');
  }
}

// ========== UI HELPERS ==========
function log(message, type = '') {
  const entry = document.createElement('div');
  entry.className = `log-entry ${type}`;
  entry.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
  if (logDiv) {
    logDiv.appendChild(entry);
    logDiv.scrollTop = logDiv.scrollHeight;
  } else {
    console.log(message);
  }
}

function updateProgress(percent) {
  const rounded = Math.round(percent);
  if (progressFill) progressFill.style.width = `${rounded}%`;
  if (progressLabel) progressLabel.textContent = `${rounded}%`;
  const bar = document.querySelector('.progress-bar');
  if (bar) bar.setAttribute('aria-valuenow', String(rounded));
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// ========== CAPABILITY CHECK ==========
if (!('serial' in navigator)) {
  log(t('webSerialNotSupported'), 'error');
  if (flashBtn) flashBtn.disabled = true;
  if (dumpBtn) dumpBtn.disabled = true;
  if (restoreBtn) restoreBtn.disabled = true;
}

// ========== AUTO TAB SELECT VIA ?mode=flash|dump|restore ==========

(function () {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get("mode") || "flash";

  const modeMap = {
    flash: "tabFlash",
    dump: "tabDump",
    restore: "tabRestore"
  };

  const tabId = modeMap[mode];
  if (tabId) {
    const el = document.getElementById(tabId);
    if (el) el.click();
  }
})();

// ========== Version ==========
