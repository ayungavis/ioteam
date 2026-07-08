#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#include "cJSON.h"
#include "esp_check.h"
#include "esp_crt_bundle.h"
#include "esp_event.h"
#include "esp_http_client.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_netif.h"
#include "esp_sntp.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "nimble/ble.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "os/os_mbuf.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"
#include "store/config/ble_store_config.h"
#include "driver/gpio.h"
#include "esp_nimble_hci.h"

#define LED_PIN GPIO_NUM_4
#define REED_PIN GPIO_NUM_17

#define DEVICE_ID_LENGTH 37
#define TOKEN_LENGTH 256
#define DEVICE_NAME_LENGTH 64
#define WIFI_SSID_LENGTH 33
#define WIFI_PASSWORD_LENGTH 65
#define BACKEND_MODE_LENGTH 16
#define BACKEND_URL_LENGTH 160
#define BACKEND_DEVICE_ID_LENGTH 37
#define DEVICE_TOKEN_LENGTH 256
#define ERROR_LENGTH 128
#define JSON_BUFFER_LENGTH 1024
#define COMMAND_BUFFER_LENGTH 160
#define EVENT_QUEUE_LENGTH 16
#define REED_TASK_STACK_SIZE 4096
#define UPLOAD_TASK_STACK_SIZE 8192
#define CONSOLE_TASK_STACK_SIZE 4096
#define REED_DEBOUNCE_US 500000

#define WIFI_CONNECTED_BIT BIT0

static const char *TAG = "doselatch";
static const char *TAG_BLE = "doselatch_ble";
static const char *TAG_WIFI = "doselatch_wifi";
static const char *TAG_QUEUE = "doselatch_queue";
static const char *TAG_STORAGE = "doselatch_storage";

static const ble_uuid128_t kServiceUuid = BLE_UUID128_INIT(
    0x01, 0x00, 0xA0, 0xE5, 0x41, 0x5B, 0x22, 0x9E,
    0x0D, 0x4F, 0xA5, 0x71, 0x01, 0x00, 0xDE, 0xC0
);
static const ble_uuid128_t kDeviceInfoUuid = BLE_UUID128_INIT(
    0x02, 0x00, 0xA0, 0xE5, 0x41, 0x5B, 0x22, 0x9E,
    0x0D, 0x4F, 0xA5, 0x71, 0x01, 0x00, 0xDE, 0xC0
);
static const ble_uuid128_t kPairCommandUuid = BLE_UUID128_INIT(
    0x03, 0x00, 0xA0, 0xE5, 0x41, 0x5B, 0x22, 0x9E,
    0x0D, 0x4F, 0xA5, 0x71, 0x01, 0x00, 0xDE, 0xC0
);
static const ble_uuid128_t kDeviceEventUuid = BLE_UUID128_INIT(
    0x04, 0x00, 0xA0, 0xE5, 0x41, 0x5B, 0x22, 0x9E,
    0x0D, 0x4F, 0xA5, 0x71, 0x01, 0x00, 0xDE, 0xC0
);

typedef enum {
    PROVISIONING_STATE_UNPAIRED = 0,
    PROVISIONING_STATE_PROVISIONING,
    PROVISIONING_STATE_PROVISIONED,
    PROVISIONING_STATE_FAILED,
} provisioning_state_t;

typedef enum {
    WIFI_STATE_DISCONNECTED = 0,
    WIFI_STATE_CONNECTING,
    WIFI_STATE_CONNECTED,
} wifi_state_t;

typedef struct {
    char device_id[DEVICE_ID_LENGTH];
    bool paired;
    char device_name[DEVICE_NAME_LENGTH];
    char pairing_token[TOKEN_LENGTH];
    char wifi_ssid[WIFI_SSID_LENGTH];
    char wifi_password[WIFI_PASSWORD_LENGTH];
    char backend_mode[BACKEND_MODE_LENGTH];
    char backend_base_url[BACKEND_URL_LENGTH];
    char backend_device_id[BACKEND_DEVICE_ID_LENGTH];
    char device_token[DEVICE_TOKEN_LENGTH];
} device_config_t;

typedef struct {
    bool is_open;
    int64_t timestamp_ms;
} device_event_t;

typedef struct {
    char pairing_token[TOKEN_LENGTH];
    char device_name[DEVICE_NAME_LENGTH];
    char wifi_ssid[WIFI_SSID_LENGTH];
    char wifi_password[WIFI_PASSWORD_LENGTH];
    char backend_mode[BACKEND_MODE_LENGTH];
    char backend_base_url[BACKEND_URL_LENGTH];
} pair_command_t;

static device_config_t s_config = {0};
static provisioning_state_t s_provisioning_state = PROVISIONING_STATE_UNPAIRED;
static wifi_state_t s_wifi_state = WIFI_STATE_DISCONNECTED;
static bool s_current_is_open = true;
static char s_last_error[ERROR_LENGTH] = {0};

static SemaphoreHandle_t s_state_mutex;
static QueueHandle_t s_event_queue;
static EventGroupHandle_t s_wifi_events;
static TaskHandle_t s_reed_task_handle;
static esp_timer_handle_t s_reed_timer;
static bool s_sntp_started = false;
static bool s_backend_registration_blocked = false;

static uint8_t s_ble_addr_type;
static uint16_t s_ble_connection_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t s_device_info_handle;
static uint16_t s_device_event_handle;
static char s_pair_command_json_buffer[JSON_BUFFER_LENGTH];

static int ble_gap_event_handler(struct ble_gap_event *event, void *arg);
static void start_advertising(void);
static void notify_device_info(void);
extern void ble_store_config_init(void);

static void safe_copy(char *destination, size_t destination_size, const char *source) {
    if (destination_size == 0) {
        return;
    }

    if (source == NULL) {
        destination[0] = '\0';
        return;
    }

    strlcpy(destination, source, destination_size);
}

static const char *reed_state_label(bool is_open) {
    return is_open ? "open" : "close";
}

static const char *wifi_state_label(wifi_state_t state) {
    switch (state) {
        case WIFI_STATE_CONNECTING:
            return "connecting";
        case WIFI_STATE_CONNECTED:
            return "connected";
        case WIFI_STATE_DISCONNECTED:
        default:
            return "disconnected";
    }
}

static const char *provisioning_state_label(provisioning_state_t state) {
    switch (state) {
        case PROVISIONING_STATE_PROVISIONING:
            return "provisioning";
        case PROVISIONING_STATE_PROVISIONED:
            return "provisioned";
        case PROVISIONING_STATE_FAILED:
            return "failed";
        case PROVISIONING_STATE_UNPAIRED:
        default:
            return "unpaired";
    }
}

static void log_state_snapshot(const char *stage) {
    char device_id[DEVICE_ID_LENGTH] = {0};
    char device_name[DEVICE_NAME_LENGTH] = {0};
    char wifi_ssid[WIFI_SSID_LENGTH] = {0};
    char backend_mode[BACKEND_MODE_LENGTH] = {0};
    char backend_base_url[BACKEND_URL_LENGTH] = {0};
    char backend_device_id[BACKEND_DEVICE_ID_LENGTH] = {0};
    char last_error[ERROR_LENGTH] = {0};
    bool paired = false;
    provisioning_state_t provisioning_state = PROVISIONING_STATE_UNPAIRED;
    wifi_state_t wifi_state = WIFI_STATE_DISCONNECTED;

    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    safe_copy(device_id, sizeof(device_id), s_config.device_id);
    safe_copy(device_name, sizeof(device_name), s_config.device_name);
    safe_copy(wifi_ssid, sizeof(wifi_ssid), s_config.wifi_ssid);
    safe_copy(backend_mode, sizeof(backend_mode), s_config.backend_mode);
    safe_copy(backend_base_url, sizeof(backend_base_url), s_config.backend_base_url);
    safe_copy(backend_device_id, sizeof(backend_device_id), s_config.backend_device_id);
    safe_copy(last_error, sizeof(last_error), s_last_error);
    paired = s_config.paired;
    provisioning_state = s_provisioning_state;
    wifi_state = s_wifi_state;
    xSemaphoreGive(s_state_mutex);

    ESP_LOGI(
        TAG,
        "%s deviceId=%s name=%s paired=%s provisioning=%s wifi=%s ssid=%s backendMode=%s backendUrlSet=%s backendDeviceIdSet=%s lastError=%s",
        stage,
        device_id,
        device_name,
        paired ? "true" : "false",
        provisioning_state_label(provisioning_state),
        wifi_state_label(wifi_state),
        wifi_ssid,
        backend_mode,
        backend_base_url[0] != '\0' ? "true" : "false",
        backend_device_id[0] != '\0' ? "true" : "false",
        last_error
    );
}

static int64_t current_timestamp_ms(void) {
    struct timeval now = {0};
    gettimeofday(&now, NULL);

    if (now.tv_sec > 1735689600) {
        return ((int64_t) now.tv_sec * 1000) + (now.tv_usec / 1000);
    }

    return esp_timer_get_time() / 1000;
}

static bool has_real_time(void) {
    struct timeval now = {0};
    gettimeofday(&now, NULL);
    return now.tv_sec > 1735689600;
}

static int64_t absolute_event_timestamp_ms(int64_t recorded_timestamp_ms) {
    if (recorded_timestamp_ms > 1735689600000LL) {
        return recorded_timestamp_ms;
    }

    if (!has_real_time()) {
        return 0;
    }

    int64_t now_epoch_ms = current_timestamp_ms();
    int64_t now_uptime_ms = esp_timer_get_time() / 1000;
    int64_t age_ms = now_uptime_ms - recorded_timestamp_ms;
    if (age_ms < 0) {
        age_ms = 0;
    }

    return now_epoch_ms - age_ms;
}

static esp_err_t format_timestamp_iso8601(int64_t timestamp_ms, char *buffer, size_t buffer_size) {
    if (timestamp_ms <= 0) {
        return ESP_ERR_INVALID_STATE;
    }

    time_t seconds = (time_t) (timestamp_ms / 1000);
    int milliseconds = (int) (timestamp_ms % 1000);
    struct tm time_info = {0};
    if (gmtime_r(&seconds, &time_info) == NULL) {
        return ESP_FAIL;
    }

    size_t written = strftime(buffer, buffer_size, "%Y-%m-%dT%H:%M:%S", &time_info);
    if (written == 0 || written + 6 >= buffer_size) {
        return ESP_ERR_INVALID_SIZE;
    }

    snprintf(buffer + written, buffer_size - written, ".%03dZ", milliseconds);
    return ESP_OK;
}

static esp_err_t build_url(char *destination, size_t destination_size, const char *base_url, const char *path) {
    if (base_url == NULL || path == NULL || destination_size == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    const char *separator = base_url[strlen(base_url) - 1] == '/' ? "" : "/";
    int written = snprintf(destination, destination_size, "%s%s%s", base_url, separator, path);
    if (written < 0 || (size_t) written >= destination_size) {
        return ESP_ERR_INVALID_SIZE;
    }

    return ESP_OK;
}

static void set_last_error(const char *message) {
    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    safe_copy(s_last_error, sizeof(s_last_error), message);
    xSemaphoreGive(s_state_mutex);
}

static void clear_last_error(void) {
    set_last_error("");
}

static void update_led(bool is_open) {
    gpio_set_level(LED_PIN, is_open ? 0 : 1);
}

static bool read_reed_state(void) {
    return gpio_get_level(REED_PIN) == 1;
}

static void create_device_id(char *buffer, size_t buffer_size) {
    uint8_t mac[6] = {0};
    ESP_ERROR_CHECK(esp_read_mac(mac, ESP_MAC_WIFI_STA));
    snprintf(
        buffer,
        buffer_size,
        "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
        0,
        0,
        mac[0],
        mac[1],
        mac[2],
        mac[3],
        mac[4],
        mac[5],
        mac[0],
        mac[1],
        mac[2],
        mac[3],
        mac[4],
        mac[5],
        mac[0],
        mac[1]
    );
}

static esp_err_t storage_load_string(nvs_handle_t handle, const char *key, char *buffer, size_t buffer_size) {
    size_t required_size = buffer_size;
    esp_err_t error = nvs_get_str(handle, key, buffer, &required_size);

    if (error == ESP_ERR_NVS_NOT_FOUND) {
        buffer[0] = '\0';
        return ESP_OK;
    }

    return error;
}

static esp_err_t storage_save_config(void) {
    nvs_handle_t handle;
    esp_err_t ret = nvs_open("doselatch", NVS_READWRITE, &handle);
    ESP_RETURN_ON_ERROR(ret, TAG_STORAGE, "Failed to open NVS");

    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "device_id", s_config.device_id), finish, TAG_STORAGE, "Failed to save device_id");
    ESP_GOTO_ON_ERROR(nvs_set_u8(handle, "paired", s_config.paired ? 1 : 0), finish, TAG_STORAGE, "Failed to save paired");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "device_name", s_config.device_name), finish, TAG_STORAGE, "Failed to save device name");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "pair_token", s_config.pairing_token), finish, TAG_STORAGE, "Failed to save pair token");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "wifi_ssid", s_config.wifi_ssid), finish, TAG_STORAGE, "Failed to save wifi ssid");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "wifi_pass", s_config.wifi_password), finish, TAG_STORAGE, "Failed to save wifi password");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "backend_mode", s_config.backend_mode), finish, TAG_STORAGE, "Failed to save backend mode");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "backend_url", s_config.backend_base_url), finish, TAG_STORAGE, "Failed to save backend url");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "backend_id", s_config.backend_device_id), finish, TAG_STORAGE, "Failed to save backend device id");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "device_token", s_config.device_token), finish, TAG_STORAGE, "Failed to save device token");
    ESP_GOTO_ON_ERROR(nvs_commit(handle), finish, TAG_STORAGE, "Failed to commit NVS");

finish:
    nvs_close(handle);
    return ret;
}

static esp_err_t storage_load_config(void) {
    nvs_handle_t handle;
    esp_err_t ret = nvs_open("doselatch", NVS_READWRITE, &handle);
    ESP_RETURN_ON_ERROR(ret, TAG_STORAGE, "Failed to open NVS");

    memset(&s_config, 0, sizeof(s_config));
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "device_id", s_config.device_id, sizeof(s_config.device_id)), finish, TAG_STORAGE, "Failed to load device_id");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "device_name", s_config.device_name, sizeof(s_config.device_name)), finish, TAG_STORAGE, "Failed to load device name");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "pair_token", s_config.pairing_token, sizeof(s_config.pairing_token)), finish, TAG_STORAGE, "Failed to load pair token");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "wifi_ssid", s_config.wifi_ssid, sizeof(s_config.wifi_ssid)), finish, TAG_STORAGE, "Failed to load wifi ssid");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "wifi_pass", s_config.wifi_password, sizeof(s_config.wifi_password)), finish, TAG_STORAGE, "Failed to load wifi password");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "backend_mode", s_config.backend_mode, sizeof(s_config.backend_mode)), finish, TAG_STORAGE, "Failed to load backend mode");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "backend_url", s_config.backend_base_url, sizeof(s_config.backend_base_url)), finish, TAG_STORAGE, "Failed to load backend url");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "backend_id", s_config.backend_device_id, sizeof(s_config.backend_device_id)), finish, TAG_STORAGE, "Failed to load backend device id");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "device_token", s_config.device_token, sizeof(s_config.device_token)), finish, TAG_STORAGE, "Failed to load device token");

    uint8_t paired = 0;
    ret = nvs_get_u8(handle, "paired", &paired);
    if (ret == ESP_ERR_NVS_NOT_FOUND) {
        ret = ESP_OK;
        paired = 0;
    }
    ESP_GOTO_ON_ERROR(ret, finish, TAG_STORAGE, "Failed to load paired");
    s_config.paired = paired == 1;

    if (s_config.device_id[0] == '\0') {
        create_device_id(s_config.device_id, sizeof(s_config.device_id));
        ret = storage_save_config();
        if (ret != ESP_OK) {
            goto finish;
        }
    }

finish:
    nvs_close(handle);
    return ret;
}

static esp_err_t storage_factory_reset(void) {
    nvs_handle_t handle;
    esp_err_t ret = nvs_open("doselatch", NVS_READWRITE, &handle);
    ESP_RETURN_ON_ERROR(ret, TAG_STORAGE, "Failed to open NVS for reset");
    ESP_GOTO_ON_ERROR(nvs_erase_all(handle), finish, TAG_STORAGE, "Failed to erase NVS");
    ESP_GOTO_ON_ERROR(nvs_commit(handle), finish, TAG_STORAGE, "Failed to commit reset");

finish:
    nvs_close(handle);
    return ret;
}

static void start_sntp_if_needed(void) {
    if (s_sntp_started) {
        return;
    }

    esp_sntp_setoperatingmode(SNTP_OPMODE_POLL);
    esp_sntp_setservername(0, "pool.ntp.org");
    esp_sntp_init();
    s_sntp_started = true;
    ESP_LOGI(TAG_WIFI, "SNTP started");
}

static void restart_wifi_connection(void) {
    if (s_config.wifi_ssid[0] == '\0') {
        ESP_LOGW(TAG_WIFI, "Wi-Fi reconnect skipped: SSID is empty");
        return;
    }

    wifi_config_t wifi_config = {0};
    safe_copy((char *) wifi_config.sta.ssid, sizeof(wifi_config.sta.ssid), s_config.wifi_ssid);
    safe_copy((char *) wifi_config.sta.password, sizeof(wifi_config.sta.password), s_config.wifi_password);
    wifi_config.sta.threshold.authmode = s_config.wifi_password[0] == '\0' ? WIFI_AUTH_OPEN : WIFI_AUTH_WPA2_PSK;
    wifi_config.sta.pmf_cfg.capable = true;
    wifi_config.sta.pmf_cfg.required = false;

    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    xEventGroupClearBits(s_wifi_events, WIFI_CONNECTED_BIT);
    s_wifi_state = WIFI_STATE_CONNECTING;
    clear_last_error();
    ESP_ERROR_CHECK(esp_wifi_connect());
    ESP_LOGI(TAG_WIFI, "Wi-Fi reconnect requested ssid=%s", s_config.wifi_ssid);
}

static void wifi_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data) {
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        if (s_config.wifi_ssid[0] != '\0') {
            restart_wifi_connection();
        }
        return;
    }

    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        const wifi_event_sta_disconnected_t *disconnected = event_data;
        char error_message[ERROR_LENGTH] = {0};
        xEventGroupClearBits(s_wifi_events, WIFI_CONNECTED_BIT);
        s_wifi_state = WIFI_STATE_DISCONNECTED;
        snprintf(
            error_message,
            sizeof(error_message),
            "Wi-Fi disconnected (reason=%d)",
            disconnected != NULL ? disconnected->reason : -1
        );
        set_last_error(error_message);
        notify_device_info();
        ESP_LOGW(
            TAG_WIFI,
            "Wi-Fi disconnected ssid=%s reason=%d, retrying",
            s_config.wifi_ssid,
            disconnected != NULL ? disconnected->reason : -1
        );

        if (s_config.wifi_ssid[0] != '\0') {
            esp_wifi_connect();
        }
        return;
    }

    if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        s_wifi_state = WIFI_STATE_CONNECTED;
        s_provisioning_state = PROVISIONING_STATE_PROVISIONED;
        xEventGroupSetBits(s_wifi_events, WIFI_CONNECTED_BIT);
        clear_last_error();
        notify_device_info();
        start_sntp_if_needed();
        ESP_LOGI(TAG_WIFI, "Wi-Fi connected and IP ready");
    }
}

static void wifi_init(void) {
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t config = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&config));
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
}

static void build_device_info_json(char *buffer, size_t buffer_size) {
    char last_error[ERROR_LENGTH] = {0};
    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    safe_copy(last_error, sizeof(last_error), s_last_error);
    snprintf(
        buffer,
        buffer_size,
        "{\"deviceId\":\"%s\",\"deviceName\":\"%s\",\"firmwareVersion\":\"0.2.0\",\"paired\":%s,"
        "\"reedState\":\"%s\",\"wifiState\":\"%s\",\"provisioningState\":\"%s\","
        "\"lastError\":\"%s\"}",
        s_config.device_id,
        s_config.device_name,
        s_config.paired ? "true" : "false",
        reed_state_label(s_current_is_open),
        wifi_state_label(s_wifi_state),
        provisioning_state_label(s_provisioning_state),
        last_error
    );
    xSemaphoreGive(s_state_mutex);
}

static void notify_ble_characteristic(uint16_t value_handle, const char *json_payload) {
    if (s_ble_connection_handle == BLE_HS_CONN_HANDLE_NONE) {
        return;
    }

    struct os_mbuf *buffer = ble_hs_mbuf_from_flat(json_payload, strlen(json_payload));
    if (buffer == NULL) {
        ESP_LOGW(TAG_BLE, "Failed to allocate BLE notification buffer");
        return;
    }

    int result = ble_gatts_notify_custom(s_ble_connection_handle, value_handle, buffer);
    if (result != 0) {
        ESP_LOGW(TAG_BLE, "BLE notify failed rc=%d", result);
    }
}

static void notify_device_info(void) {
    char payload[JSON_BUFFER_LENGTH] = {0};
    build_device_info_json(payload, sizeof(payload));
    ESP_LOGD(TAG_BLE, "Notify device info payload=%s", payload);
    notify_ble_characteristic(s_device_info_handle, payload);
}

static void enqueue_device_event(device_event_t event) {
    if (xQueueSend(s_event_queue, &event, 0) == pdPASS) {
        return;
    }

    device_event_t dropped_event = {0};
    if (xQueueReceive(s_event_queue, &dropped_event, 0) == pdPASS) {
        ESP_LOGW(TAG_QUEUE, "Event queue full, dropped oldest event");
        xQueueSend(s_event_queue, &event, 0);
    }
}

static void publish_reed_event(bool is_open) {
    char payload[JSON_BUFFER_LENGTH] = {0};
    device_event_t event = {
        .is_open = is_open,
        .timestamp_ms = current_timestamp_ms(),
    };

    snprintf(
        payload,
        sizeof(payload),
        "{\"deviceId\":\"%s\",\"eventType\":\"%s\",\"timestamp\":\"%lld\","
        "\"firmwareVersion\":\"0.2.0\"}",
        s_config.device_id,
        reed_state_label(is_open),
        (long long) event.timestamp_ms
    );

    notify_ble_characteristic(s_device_event_handle, payload);
    enqueue_device_event(event);
    ESP_LOGI(TAG, "Published event: %s", payload);
}

static esp_err_t copy_json_string(cJSON *object, const char *key, char *destination, size_t destination_size, bool required) {
    cJSON *item = cJSON_GetObjectItemCaseSensitive(object, key);

    if (item == NULL || !cJSON_IsString(item) || item->valuestring == NULL) {
        return required ? ESP_ERR_INVALID_ARG : ESP_OK;
    }

    if (strlen(item->valuestring) >= destination_size) {
        return ESP_ERR_INVALID_SIZE;
    }

    safe_copy(destination, destination_size, item->valuestring);
    return ESP_OK;
}

static esp_err_t apply_pair_command(const pair_command_t *command) {
    if (command->wifi_ssid[0] == '\0' || command->pairing_token[0] == '\0' || command->device_name[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    safe_copy(s_config.device_name, sizeof(s_config.device_name), command->device_name);
    safe_copy(s_config.pairing_token, sizeof(s_config.pairing_token), command->pairing_token);
    safe_copy(s_config.wifi_ssid, sizeof(s_config.wifi_ssid), command->wifi_ssid);
    safe_copy(s_config.wifi_password, sizeof(s_config.wifi_password), command->wifi_password);
    safe_copy(s_config.backend_mode, sizeof(s_config.backend_mode), command->backend_mode);
    safe_copy(s_config.backend_base_url, sizeof(s_config.backend_base_url), command->backend_base_url);
    s_config.paired = false;
    s_backend_registration_blocked = false;
    s_config.backend_device_id[0] = '\0';
    s_config.device_token[0] = '\0';
    s_provisioning_state = PROVISIONING_STATE_PROVISIONING;
    xSemaphoreGive(s_state_mutex);

    clear_last_error();
    ESP_RETURN_ON_ERROR(storage_save_config(), TAG_STORAGE, "Failed to persist pair command");

    ble_svc_gap_device_name_set("DoseLatch");
    log_state_snapshot("Pair command applied");
    restart_wifi_connection();
    notify_device_info();
    return ESP_OK;
}

static int device_info_access(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *context, void *arg) {
    if (context->op != BLE_GATT_ACCESS_OP_READ_CHR || attr_handle != s_device_info_handle) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    char payload[JSON_BUFFER_LENGTH] = {0};
    build_device_info_json(payload, sizeof(payload));
    int result = os_mbuf_append(context->om, payload, strlen(payload));
    return result == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
}

static int device_event_access(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *context, void *arg) {
    return BLE_ATT_ERR_READ_NOT_PERMITTED;
}

static int pair_command_access(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *context, void *arg) {
    if (context->op != BLE_GATT_ACCESS_OP_WRITE_CHR) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    uint16_t payload_length = OS_MBUF_PKTLEN(context->om);
    if (payload_length >= JSON_BUFFER_LENGTH) {
        ESP_LOGW(
            TAG_BLE,
            "Pair command rejected: payload too large bytes=%u limit=%u",
            payload_length,
            JSON_BUFFER_LENGTH - 1
        );
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    memset(s_pair_command_json_buffer, 0, sizeof(s_pair_command_json_buffer));
    int result = os_mbuf_copydata(context->om, 0, payload_length, s_pair_command_json_buffer);
    if (result != 0) {
        ESP_LOGW(TAG_BLE, "Pair command copy failed rc=%d bytes=%u", result, payload_length);
        return BLE_ATT_ERR_UNLIKELY;
    }

    cJSON *root = cJSON_Parse(s_pair_command_json_buffer);
    if (root == NULL) {
        ESP_LOGW(
            TAG_BLE,
            "Pair command rejected: invalid JSON bytes=%u firstSegmentBytes=%u",
            payload_length,
            context->om->om_len
        );
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    pair_command_t command = {0};
    esp_err_t error = copy_json_string(root, "pairingToken", command.pairing_token, sizeof(command.pairing_token), true);
    if (error == ESP_OK) {
        error = copy_json_string(root, "deviceName", command.device_name, sizeof(command.device_name), true);
    }
    if (error == ESP_OK) {
        error = copy_json_string(root, "wifiSSID", command.wifi_ssid, sizeof(command.wifi_ssid), true);
    }
    if (error == ESP_OK) {
        error = copy_json_string(root, "wifiPassword", command.wifi_password, sizeof(command.wifi_password), false);
    }
    if (error == ESP_OK) {
        error = copy_json_string(root, "backendMode", command.backend_mode, sizeof(command.backend_mode), false);
    }
    if (error == ESP_OK) {
        error = copy_json_string(root, "backendBaseURL", command.backend_base_url, sizeof(command.backend_base_url), false);
    }
    if (command.backend_mode[0] == '\0') {
        safe_copy(command.backend_mode, sizeof(command.backend_mode), "mock");
    }

    cJSON_Delete(root);

    if (error != ESP_OK) {
        set_last_error("Invalid provisioning payload");
        s_provisioning_state = PROVISIONING_STATE_FAILED;
        ESP_LOGW(TAG_BLE, "Pair command rejected: invalid provisioning payload bytes=%u", payload_length);
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    ESP_LOGI(
        TAG_BLE,
        "Pair command received bytes=%u deviceName=%s ssid=%s backendMode=%s backendBaseURLSet=%s passwordSet=%s",
        payload_length,
        command.device_name,
        command.wifi_ssid,
        command.backend_mode,
        command.backend_base_url[0] != '\0' ? "true" : "false",
        command.wifi_password[0] != '\0' ? "true" : "false"
    );
    error = apply_pair_command(&command);
    if (error != ESP_OK) {
        set_last_error("Provisioning apply failed");
        s_provisioning_state = PROVISIONING_STATE_FAILED;
        ESP_LOGW(TAG_BLE, "Pair command apply failed err=0x%x", error);
        return BLE_ATT_ERR_UNLIKELY;
    }

    ESP_LOGI(TAG_BLE, "Pair command accepted for device=%s ssid=%s", command.device_name, command.wifi_ssid);
    return 0;
}

static const struct ble_gatt_svc_def gatt_services[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &kServiceUuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &kDeviceInfoUuid.u,
                .access_cb = device_info_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
                .val_handle = &s_device_info_handle,
            },
            {
                .uuid = &kPairCommandUuid.u,
                .access_cb = pair_command_access,
                .flags = BLE_GATT_CHR_F_WRITE,
            },
            {
                .uuid = &kDeviceEventUuid.u,
                .access_cb = device_event_access,
                .flags = BLE_GATT_CHR_F_NOTIFY,
                .val_handle = &s_device_event_handle,
            },
            {0},
        },
    },
    {0},
};

static void start_advertising(void) {
    struct ble_hs_adv_fields fields = {0};
    struct ble_hs_adv_fields response_fields = {0};
    struct ble_gap_adv_params parameters = {0};
    const char *name = s_config.paired ? "DoseLatch" : "DoseLatch Setup";

    ble_svc_gap_device_name_set(name);

    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.uuids128 = (ble_uuid128_t *) &kServiceUuid;
    fields.num_uuids128 = 1;
    fields.uuids128_is_complete = 1;

    ble_gap_adv_stop();
    int result = ble_gap_adv_set_fields(&fields);
    if (result != 0) {
        ESP_LOGE(TAG_BLE, "Failed to set advertising fields rc=%d", result);
        return;
    }

    response_fields.name = (const uint8_t *) name;
    response_fields.name_len = strlen(name);
    response_fields.name_is_complete = 1;
    result = ble_gap_adv_rsp_set_fields(&response_fields);
    if (result != 0) {
        ESP_LOGE(TAG_BLE, "Failed to set scan response fields rc=%d", result);
        return;
    }

    parameters.conn_mode = BLE_GAP_CONN_MODE_UND;
    parameters.disc_mode = BLE_GAP_DISC_MODE_GEN;

    result = ble_gap_adv_start(s_ble_addr_type, NULL, BLE_HS_FOREVER, &parameters, ble_gap_event_handler, NULL);
    if (result != 0) {
        ESP_LOGE(TAG_BLE, "Failed to start advertising rc=%d", result);
        return;
    }

    ESP_LOGI(TAG_BLE, "Advertising as %s", name);
}

static int ble_gap_event_handler(struct ble_gap_event *event, void *arg) {
    switch (event->type) {
        case BLE_GAP_EVENT_CONNECT:
            if (event->connect.status == 0) {
                s_ble_connection_handle = event->connect.conn_handle;
                ESP_LOGI(TAG_BLE, "BLE client connected");
                log_state_snapshot("BLE connected");
            } else {
                ESP_LOGW(TAG_BLE, "BLE connect failed status=%d", event->connect.status);
                start_advertising();
            }
            return 0;
        case BLE_GAP_EVENT_DISCONNECT:
            s_ble_connection_handle = BLE_HS_CONN_HANDLE_NONE;
            ESP_LOGI(TAG_BLE, "BLE client disconnected");
            log_state_snapshot("BLE disconnected");
            start_advertising();
            return 0;
        case BLE_GAP_EVENT_SUBSCRIBE:
            ESP_LOGI(TAG_BLE, "BLE subscribe attr=%d cur_notify=%d", event->subscribe.attr_handle, event->subscribe.cur_notify);
            return 0;
        default:
            return 0;
    }
}

static void ble_on_reset(int reason) {
    ESP_LOGW(TAG_BLE, "BLE reset reason=%d", reason);
}

static void ble_on_sync(void) {
    int result = ble_hs_id_infer_auto(0, &s_ble_addr_type);
    if (result != 0) {
        ESP_LOGE(TAG_BLE, "BLE address infer failed rc=%d", result);
        return;
    }

    start_advertising();
}

static void ble_host_task(void *parameter) {
    nimble_port_run();
    nimble_port_freertos_deinit();
}

static void ble_init(void) {
    ESP_ERROR_CHECK(nimble_port_init());

    ble_hs_cfg.reset_cb = ble_on_reset;
    ble_hs_cfg.sync_cb = ble_on_sync;
    ble_hs_cfg.store_status_cb = ble_store_util_status_rr;

    ble_svc_gap_init();
    ble_svc_gatt_init();
    ble_store_config_init();

    int result = ble_gatts_count_cfg(gatt_services);
    if (result != 0) {
        ESP_LOGE(TAG_BLE, "ble_gatts_count_cfg failed rc=%d", result);
        ESP_ERROR_CHECK(ESP_FAIL);
    }

    result = ble_gatts_add_svcs(gatt_services);
    if (result != 0) {
        ESP_LOGE(TAG_BLE, "ble_gatts_add_svcs failed rc=%d", result);
        ESP_ERROR_CHECK(ESP_FAIL);
    }

    nimble_port_freertos_init(ble_host_task);
}

static void IRAM_ATTR reed_gpio_isr(void *argument) {
    if (s_reed_task_handle == NULL) {
        return;
    }

    BaseType_t should_yield = pdFALSE;
    vTaskNotifyGiveFromISR(s_reed_task_handle, &should_yield);
    if (should_yield == pdTRUE) {
        portYIELD_FROM_ISR();
    }
}

static void reed_debounce_timer_callback(void *argument) {
    bool is_open = read_reed_state();

    if (is_open == s_current_is_open) {
        return;
    }

    s_current_is_open = is_open;
    update_led(is_open);
    notify_device_info();
    publish_reed_event(is_open);
}

static void reed_task(void *argument) {
    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        esp_timer_stop(s_reed_timer);
        esp_timer_start_once(s_reed_timer, REED_DEBOUNCE_US);
    }
}

typedef struct {
    char *buffer;
    size_t buffer_size;
    int bytes_written;
    bool truncated;
} http_response_capture_t;

static esp_err_t http_event_handler(esp_http_client_event_t *event) {
    if (event->event_id != HTTP_EVENT_ON_DATA || event->user_data == NULL) {
        return ESP_OK;
    }

    http_response_capture_t *capture = event->user_data;
    if (capture->buffer == NULL || capture->buffer_size == 0 || event->data == NULL || event->data_len <= 0) {
        return ESP_OK;
    }

    size_t remaining = capture->buffer_size - (size_t) capture->bytes_written - 1;
    if (remaining == 0) {
        capture->truncated = true;
        return ESP_OK;
    }

    size_t copy_length = (size_t) event->data_len;
    if (copy_length > remaining) {
        copy_length = remaining;
        capture->truncated = true;
    }

    memcpy(capture->buffer + capture->bytes_written, event->data, copy_length);
    capture->bytes_written += (int) copy_length;
    capture->buffer[capture->bytes_written] = '\0';
    return ESP_OK;
}

static esp_err_t http_post_json(
    const char *url,
    const char *bearer_token,
    const char *payload,
    char *response_buffer,
    size_t response_buffer_size,
    int *status_code_out
) {
    if (status_code_out != NULL) {
        *status_code_out = -1;
    }

    ESP_LOGI(
        TAG_QUEUE,
        "HTTP POST url=%s payloadBytes=%u bearerTokenSet=%s",
        url,
        (unsigned int) strlen(payload),
        bearer_token != NULL && bearer_token[0] != '\0' ? "true" : "false"
    );
    http_response_capture_t response_capture = {
        .buffer = response_buffer,
        .buffer_size = response_buffer_size,
        .bytes_written = 0,
        .truncated = false,
    };
    if (response_buffer != NULL && response_buffer_size > 0) {
        memset(response_buffer, 0, response_buffer_size);
    }

    esp_http_client_config_t config = {
        .url = url,
        .method = HTTP_METHOD_POST,
        .timeout_ms = 15000,
        .crt_bundle_attach = esp_crt_bundle_attach,
        .event_handler = http_event_handler,
        .user_data = &response_capture,
    };

    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        return ESP_FAIL;
    }

    esp_http_client_set_header(client, "Content-Type", "application/json");
    esp_http_client_set_header(client, "Accept", "application/json");
    if (bearer_token != NULL && bearer_token[0] != '\0') {
        char auth_header[DEVICE_TOKEN_LENGTH + 16] = {0};
        snprintf(auth_header, sizeof(auth_header), "Bearer %s", bearer_token);
        esp_http_client_set_header(client, "Authorization", auth_header);
    }
    esp_http_client_set_post_field(client, payload, strlen(payload));

    esp_err_t error = esp_http_client_perform(client);
    if (error != ESP_OK) {
        int status_code = esp_http_client_get_status_code(client);
        if (status_code_out != NULL) {
            *status_code_out = status_code;
        }
        ESP_LOGW(TAG_QUEUE, "HTTP request failed err=0x%x status=%d url=%s", error, status_code, url);
        esp_http_client_cleanup(client);
        return error;
    }

    int status_code = esp_http_client_get_status_code(client);
    if (status_code_out != NULL) {
        *status_code_out = status_code;
    }
    int content_length = esp_http_client_get_content_length(client);

    esp_http_client_cleanup(client);
    if (status_code < 200 || status_code >= 300) {
        ESP_LOGW(
            TAG_QUEUE,
            "HTTP request failed status=%d contentLength=%d responseBytes=%d truncated=%s body=%s",
            status_code,
            content_length,
            response_capture.bytes_written,
            response_capture.truncated ? "true" : "false",
            response_buffer != NULL ? response_buffer : ""
        );
        return ESP_FAIL;
    }

    ESP_LOGI(
        TAG_QUEUE,
        "HTTP response status=%d contentLength=%d responseBytes=%d truncated=%s body=%s",
        status_code,
        content_length,
        response_capture.bytes_written,
        response_capture.truncated ? "true" : "false",
        response_buffer != NULL ? response_buffer : ""
    );
    if (response_capture.truncated) {
        return ESP_ERR_INVALID_SIZE;
    }

    return ESP_OK;
}

static esp_err_t register_device_with_backend(void) {
    if (strcmp(s_config.backend_mode, "http") != 0 || s_config.backend_base_url[0] == '\0') {
        s_config.paired = true;
        s_provisioning_state = PROVISIONING_STATE_PROVISIONED;
        log_state_snapshot("Backend registration skipped");
        return storage_save_config();
    }

    char url[BACKEND_URL_LENGTH + 32] = {0};
    ESP_RETURN_ON_ERROR(build_url(url, sizeof(url), s_config.backend_base_url, "devices/register"), TAG_QUEUE, "Failed to build register url");

    char payload[JSON_BUFFER_LENGTH] = {0};
    snprintf(
        payload,
        sizeof(payload),
        "{\"pairingToken\":\"%s\",\"hardwareId\":\"%s\",\"name\":\"%s\","
        "\"firmwareVersion\":\"0.2.0\",\"connectionType\":\"bluetooth\"}",
        s_config.pairing_token,
        s_config.device_id,
        s_config.device_name
    );
    ESP_LOGI(TAG_QUEUE, "Backend register request payload=%s", payload);

    char response_buffer[JSON_BUFFER_LENGTH] = {0};
    int status_code = -1;
    esp_err_t error = http_post_json(url, NULL, payload, response_buffer, sizeof(response_buffer), &status_code);
    if (status_code == 401) {
        set_last_error("Backend registration unauthorized; re-pair device");
        s_provisioning_state = PROVISIONING_STATE_FAILED;
        s_backend_registration_blocked = true;
        ESP_LOGW(TAG_QUEUE, "Backend registration unauthorized status=%d; re-pair device", status_code);
        return ESP_ERR_INVALID_STATE;
    }
    ESP_RETURN_ON_ERROR(error, TAG_QUEUE, "Failed to register device");

    ESP_LOGI(TAG_QUEUE, "Backend register response payload=%s", response_buffer);
    cJSON *root = cJSON_Parse(response_buffer);
    if (root == NULL) {
        return ESP_FAIL;
    }

    cJSON *data = cJSON_GetObjectItemCaseSensitive(root, "data");
    cJSON *device = data != NULL ? cJSON_GetObjectItemCaseSensitive(data, "device") : NULL;
    error = copy_json_string(device, "id", s_config.backend_device_id, sizeof(s_config.backend_device_id), true);
    if (error == ESP_OK && data != NULL) {
        error = copy_json_string(data, "deviceToken", s_config.device_token, sizeof(s_config.device_token), true);
    }
    cJSON_Delete(root);
    if (error != ESP_OK) {
        return error;
    }

    s_config.paired = true;
    s_provisioning_state = PROVISIONING_STATE_PROVISIONED;
    clear_last_error();
    ESP_RETURN_ON_ERROR(storage_save_config(), TAG_STORAGE, "Failed to persist device registration");
    notify_device_info();
    log_state_snapshot("Backend registration completed");
    start_advertising();
    return ESP_OK;
}

static esp_err_t upload_event_to_backend(const device_event_t *event) {
    if (s_config.backend_device_id[0] == '\0' || s_config.device_token[0] == '\0') {
        return ESP_ERR_INVALID_STATE;
    }

    int64_t absolute_timestamp_ms = absolute_event_timestamp_ms(event->timestamp_ms);
    char timestamp_buffer[40] = {0};
    ESP_RETURN_ON_ERROR(format_timestamp_iso8601(absolute_timestamp_ms, timestamp_buffer, sizeof(timestamp_buffer)), TAG_QUEUE, "Failed to format event timestamp");

    char url[BACKEND_URL_LENGTH + 64] = {0};
    char path[80] = {0};
    snprintf(path, sizeof(path), "devices/%s/events", s_config.backend_device_id);
    ESP_RETURN_ON_ERROR(build_url(url, sizeof(url), s_config.backend_base_url, path), TAG_QUEUE, "Failed to build event url");

    char payload[JSON_BUFFER_LENGTH] = {0};
    snprintf(
        payload,
        sizeof(payload),
        "{\"eventType\":\"%s\",\"deviceTimestamp\":\"%s\",\"firmwareVersion\":\"0.2.0\","
        "\"raw_payload\":\"{\\\"deviceId\\\":\\\"%s\\\",\\\"eventType\\\":\\\"%s\\\",\\\"timestamp\\\":\\\"%s\\\"}\"}",
        reed_state_label(event->is_open),
        timestamp_buffer,
        s_config.device_id,
        reed_state_label(event->is_open),
        timestamp_buffer
    );

    char response_buffer[JSON_BUFFER_LENGTH] = {0};
    return http_post_json(url, s_config.device_token, payload, response_buffer, sizeof(response_buffer), NULL);
}

static void upload_task(void *argument) {
    device_event_t event = {0};

    for (;;) {
        EventBits_t bits = xEventGroupGetBits(s_wifi_events);
        if ((bits & WIFI_CONNECTED_BIT) == 0) {
            vTaskDelay(pdMS_TO_TICKS(500));
            continue;
        }

        if (!s_config.paired || s_config.backend_device_id[0] == '\0' || s_config.device_token[0] == '\0') {
            if (s_backend_registration_blocked) {
                vTaskDelay(pdMS_TO_TICKS(5000));
                continue;
            }

            ESP_LOGD(
                TAG_QUEUE,
                "Upload loop waiting for registration paired=%s backendDeviceIdSet=%s tokenSet=%s stackFreeWords=%u",
                s_config.paired ? "true" : "false",
                s_config.backend_device_id[0] != '\0' ? "true" : "false",
                s_config.device_token[0] != '\0' ? "true" : "false",
                (unsigned int) uxTaskGetStackHighWaterMark(NULL)
            );
            esp_err_t registration_error = register_device_with_backend();
            if (registration_error != ESP_OK) {
                if (registration_error != ESP_ERR_INVALID_STATE) {
                    set_last_error("Backend registration failed");
                }
                s_provisioning_state = PROVISIONING_STATE_FAILED;
                notify_device_info();
                ESP_LOGW(TAG_QUEUE, "Backend registration failed err=0x%x", registration_error);
                vTaskDelay(pdMS_TO_TICKS(2000));
                continue;
            }
        }

        if (!has_real_time()) {
            vTaskDelay(pdMS_TO_TICKS(500));
            continue;
        }

        if (xQueueReceive(s_event_queue, &event, pdMS_TO_TICKS(1000)) != pdPASS) {
            continue;
        }

        if (strcmp(s_config.backend_mode, "http") == 0 && s_config.backend_base_url[0] != '\0') {
            esp_err_t upload_error = upload_event_to_backend(&event);
            if (upload_error != ESP_OK) {
                enqueue_device_event(event);
                ESP_LOGW(TAG_QUEUE, "Event upload failed err=0x%x", upload_error);
                vTaskDelay(pdMS_TO_TICKS(2000));
                continue;
            }
        } else {
            ESP_LOGI(TAG_QUEUE, "Mock backend accepted event=%s", reed_state_label(event.is_open));
        }
    }
}

static void print_status(void) {
    char info[JSON_BUFFER_LENGTH] = {0};
    build_device_info_json(info, sizeof(info));
    printf("%s\n", info);
    printf("queueDepth=%lu\n", (unsigned long) uxQueueMessagesWaiting(s_event_queue));
}

static void process_console_command(char *line) {
    char *command = strtok(line, " \r\n");
    if (command == NULL) {
        return;
    }

    if (strcmp(command, "help") == 0) {
        printf("Commands: help, status, factory-reset, wifi-reconnect, queue-dump, log-level <E|W|I|D|V>\n");
        return;
    }

    if (strcmp(command, "status") == 0) {
        print_status();
        return;
    }

    if (strcmp(command, "factory-reset") == 0) {
        printf("Factory reset requested. Rebooting...\n");
        if (storage_factory_reset() == ESP_OK) {
            esp_restart();
        }
        printf("Factory reset failed.\n");
        return;
    }

    if (strcmp(command, "wifi-reconnect") == 0) {
        restart_wifi_connection();
        printf("Wi-Fi reconnect requested.\n");
        return;
    }

    if (strcmp(command, "queue-dump") == 0) {
        printf("queueDepth=%lu\n", (unsigned long) uxQueueMessagesWaiting(s_event_queue));
        return;
    }

    if (strcmp(command, "log-level") == 0) {
        char *level = strtok(NULL, " \r\n");
        if (level == NULL) {
            printf("Usage: log-level <E|W|I|D|V>\n");
            return;
        }

        esp_log_level_t log_level = ESP_LOG_INFO;
        switch (level[0]) {
            case 'E':
                log_level = ESP_LOG_ERROR;
                break;
            case 'W':
                log_level = ESP_LOG_WARN;
                break;
            case 'I':
                log_level = ESP_LOG_INFO;
                break;
            case 'D':
                log_level = ESP_LOG_DEBUG;
                break;
            case 'V':
                log_level = ESP_LOG_VERBOSE;
                break;
            default:
                printf("Unknown level.\n");
                return;
        }

        esp_log_level_set("*", log_level);
        printf("Log level updated.\n");
        return;
    }

    printf("Unknown command. Type help.\n");
}

static void console_task(void *argument) {
    char line[COMMAND_BUFFER_LENGTH] = {0};

    printf("DoseLatch console ready. Type help.\n");
    while (fgets(line, sizeof(line), stdin) != NULL) {
        process_console_command(line);
        memset(line, 0, sizeof(line));
    }

    vTaskDelete(NULL);
}

static void reed_init(void) {
    gpio_config_t led_config = {
        .pin_bit_mask = 1ULL << LED_PIN,
        .mode = GPIO_MODE_OUTPUT,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ESP_ERROR_CHECK(gpio_config(&led_config));

    gpio_config_t reed_config = {
        .pin_bit_mask = 1ULL << REED_PIN,
        .mode = GPIO_MODE_INPUT,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .intr_type = GPIO_INTR_ANYEDGE,
    };
    ESP_ERROR_CHECK(gpio_config(&reed_config));

    s_current_is_open = read_reed_state();
    update_led(s_current_is_open);

    const esp_timer_create_args_t timer_args = {
        .callback = reed_debounce_timer_callback,
        .name = "reed_debounce",
    };
    ESP_ERROR_CHECK(esp_timer_create(&timer_args, &s_reed_timer));

    ESP_ERROR_CHECK(gpio_install_isr_service(0));
    ESP_ERROR_CHECK(gpio_isr_handler_add(REED_PIN, reed_gpio_isr, NULL));
}

void app_main(void) {
    esp_err_t error = nvs_flash_init();
    if (error == ESP_ERR_NVS_NO_FREE_PAGES || error == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        error = nvs_flash_init();
    }
    ESP_ERROR_CHECK(error);

    s_state_mutex = xSemaphoreCreateMutex();
    s_event_queue = xQueueCreate(EVENT_QUEUE_LENGTH, sizeof(device_event_t));
    s_wifi_events = xEventGroupCreate();

    ESP_ERROR_CHECK(storage_load_config());
    s_provisioning_state = s_config.paired ? PROVISIONING_STATE_PROVISIONED : PROVISIONING_STATE_UNPAIRED;
    if (s_config.backend_mode[0] == '\0') {
        safe_copy(s_config.backend_mode, sizeof(s_config.backend_mode), "mock");
    }

    ESP_LOGI(TAG, "DoseLatch booted. deviceId=%s paired=%s", s_config.device_id, s_config.paired ? "true" : "false");
    log_state_snapshot("Boot state");

    xTaskCreate(reed_task, "reed_task", REED_TASK_STACK_SIZE, NULL, 10, &s_reed_task_handle);
    reed_init();
    wifi_init();
    ble_init();

    xTaskCreate(upload_task, "upload_task", UPLOAD_TASK_STACK_SIZE, NULL, 8, NULL);
    xTaskCreate(console_task, "console_task", CONSOLE_TASK_STACK_SIZE, NULL, 5, NULL);
}
