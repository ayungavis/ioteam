#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <Preferences.h>
#include <esp_system.h>

#define LED_PIN 4
#define REED_PIN 17

static const char *SERVICE_UUID = "C0DE0001-71A5-4F0D-9E22-5B41E5A00001";
static const char *DEVICE_INFO_UUID = "C0DE0001-71A5-4F0D-9E22-5B41E5A00002";
static const char *PAIR_COMMAND_UUID = "C0DE0001-71A5-4F0D-9E22-5B41E5A00003";
static const char *DEVICE_EVENT_UUID = "C0DE0001-71A5-4F0D-9E22-5B41E5A00004";

static const unsigned long DEBOUNCE_MS = 500;
static const char *FIRMWARE_VERSION = "0.1.0";

Preferences preferences;
BLEServer *serverRef = nullptr;
BLECharacteristic *deviceInfoCharacteristic = nullptr;
BLECharacteristic *deviceEventCharacteristic = nullptr;

String deviceId;
bool isPaired = false;
bool currentIsOpen = true;
unsigned long lastTransitionAt = 0;

String createDeviceId() {
  uint64_t chipId = ESP.getEfuseMac();
  char buffer[37];
  snprintf(
      buffer,
      sizeof(buffer),
      "%08X-%04X-%04X-%04X-%012llX",
      (uint32_t)(chipId >> 32),
      (uint16_t)((chipId >> 16) & 0xFFFF),
      (uint16_t)(chipId & 0xFFFF),
      0xD051,
      chipId);
  return String(buffer);
}

const char *eventTypeLabel(bool isOpen) {
  return isOpen ? "open" : "close";
}

void updateLed(bool isOpen) {
  digitalWrite(LED_PIN, isOpen ? LOW : HIGH);
}

String deviceInfoPayload() {
  String payload = "{";
  payload += "\"deviceId\":\"" + deviceId + "\",";
  payload += "\"firmwareVersion\":\"" + String(FIRMWARE_VERSION) + "\",";
  payload += "\"paired\":" + String(isPaired ? "true" : "false") + ",";
  payload += "\"reedState\":\"" + String(eventTypeLabel(currentIsOpen)) + "\"";
  payload += "}";
  return payload;
}

void publishDeviceInfo() {
  String payload = deviceInfoPayload();
  deviceInfoCharacteristic->setValue(payload.c_str());
}

void notifyEvent(bool isOpen) {
  String payload = "{";
  payload += "\"deviceId\":\"" + deviceId + "\",";
  payload += "\"eventType\":\"" + String(eventTypeLabel(isOpen)) + "\",";
  payload += "\"timestamp\":\"" + String(millis()) + "\",";
  payload += "\"firmwareVersion\":\"" + String(FIRMWARE_VERSION) + "\"";
  payload += "}";

  deviceEventCharacteristic->setValue(payload.c_str());
  deviceEventCharacteristic->notify();
  Serial.printf("Published event: %s\n", payload.c_str());
}

void loadProvisioningState() {
  preferences.begin("doselatch", false);
  deviceId = preferences.getString("device_id", "");
  if (deviceId.isEmpty()) {
    deviceId = createDeviceId();
    preferences.putString("device_id", deviceId);
  }
  isPaired = preferences.getBool("paired", false);
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    Serial.println("BLE client connected");
  }

  void onDisconnect(BLEServer *server) override {
    Serial.println("BLE client disconnected");
    BLEDevice::startAdvertising();
  }
};

class PairCommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    String value = characteristic->getValue();
    if (value.length() == 0) {
      return;
    }

    Serial.printf("Received pair command: %s\n", value.c_str());
    isPaired = true;
    preferences.putBool("paired", true);
    publishDeviceInfo();
  }
};

void setupBle() {
  BLEDevice::init(isPaired ? "DoseLatch" : "DoseLatch Setup");
  Serial.printf("BLE device name: %s\n", isPaired ? "DoseLatch" : "DoseLatch Setup");
  serverRef = BLEDevice::createServer();
  serverRef->setCallbacks(new ServerCallbacks());

  BLEService *service = serverRef->createService(SERVICE_UUID);

  deviceInfoCharacteristic = service->createCharacteristic(
      DEVICE_INFO_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  deviceInfoCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic *pairCommandCharacteristic = service->createCharacteristic(
      PAIR_COMMAND_UUID,
      BLECharacteristic::PROPERTY_WRITE);
  pairCommandCharacteristic->setCallbacks(new PairCommandCallbacks());

  deviceEventCharacteristic = service->createCharacteristic(
      DEVICE_EVENT_UUID,
      BLECharacteristic::PROPERTY_NOTIFY);
  deviceEventCharacteristic->addDescriptor(new BLE2902());

  publishDeviceInfo();
  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.printf("BLE advertising started. paired=%s service=%s\n", isPaired ? "true" : "false", SERVICE_UUID);
}

bool readReedState() {
  return digitalRead(REED_PIN) == HIGH;
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(LED_PIN, OUTPUT);
  pinMode(REED_PIN, INPUT_PULLUP);

  loadProvisioningState();
  Serial.printf("DoseLatch booted. deviceId=%s paired=%s\n", deviceId.c_str(), isPaired ? "true" : "false");

  currentIsOpen = readReedState();
  updateLed(currentIsOpen);
  setupBle();
}

void loop() {
  bool isOpen = readReedState();

  if (isOpen != currentIsOpen && millis() - lastTransitionAt >= DEBOUNCE_MS) {
    currentIsOpen = isOpen;
    lastTransitionAt = millis();

    updateLed(currentIsOpen);
    publishDeviceInfo();
    notifyEvent(currentIsOpen);
  }

  delay(50);
}
