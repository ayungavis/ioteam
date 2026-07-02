#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#include "cJSON.h"
#include "esp_check.h"
#include "esp_event.h"
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
#define TOKEN_LENGTH 96
#define FAMILY_ID_LENGTH 96
#define WIFI_SSID_LENGTH 33
#define WIFI_PASSWORD_LENGTH 65
#define BACKEND_MODE_LENGTH 16
#define BACKEND_URL_LENGTH 160
#define ERROR_LENGTH 128
#define JSON_BUFFER_LENGTH 384
#define COMMAND_BUFFER_LENGTH 160
#define EVENT_QUEUE_LENGTH 16
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
    char pairing_token[TOKEN_LENGTH];
    char family_id[FAMILY_ID_LENGTH];
    char wifi_ssid[WIFI_SSID_LENGTH];
    char wifi_password[WIFI_PASSWORD_LENGTH];
    char backend_mode[BACKEND_MODE_LENGTH];
    char backend_base_url[BACKEND_URL_LENGTH];
} device_config_t;

typedef struct {
    bool is_open;
    int64_t timestamp_ms;
} device_event_t;

typedef struct {
    char pairing_token[TOKEN_LENGTH];
    char family_id[FAMILY_ID_LENGTH];
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

static uint8_t s_ble_addr_type;
static uint16_t s_ble_connection_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t s_device_info_handle;
static uint16_t s_device_event_handle;

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

static int64_t current_timestamp_ms(void) {
    struct timeval now = {0};
    gettimeofday(&now, NULL);

    if (now.tv_sec > 1735689600) {
        return ((int64_t) now.tv_sec * 1000) + (now.tv_usec / 1000);
    }

    return esp_timer_get_time() / 1000;
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
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "pair_token", s_config.pairing_token), finish, TAG_STORAGE, "Failed to save pair token");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "family_id", s_config.family_id), finish, TAG_STORAGE, "Failed to save family id");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "wifi_ssid", s_config.wifi_ssid), finish, TAG_STORAGE, "Failed to save wifi ssid");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "wifi_pass", s_config.wifi_password), finish, TAG_STORAGE, "Failed to save wifi password");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "backend_mode", s_config.backend_mode), finish, TAG_STORAGE, "Failed to save backend mode");
    ESP_GOTO_ON_ERROR(nvs_set_str(handle, "backend_url", s_config.backend_base_url), finish, TAG_STORAGE, "Failed to save backend url");
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
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "pair_token", s_config.pairing_token, sizeof(s_config.pairing_token)), finish, TAG_STORAGE, "Failed to load pair token");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "family_id", s_config.family_id, sizeof(s_config.family_id)), finish, TAG_STORAGE, "Failed to load family id");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "wifi_ssid", s_config.wifi_ssid, sizeof(s_config.wifi_ssid)), finish, TAG_STORAGE, "Failed to load wifi ssid");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "wifi_pass", s_config.wifi_password, sizeof(s_config.wifi_password)), finish, TAG_STORAGE, "Failed to load wifi password");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "backend_mode", s_config.backend_mode, sizeof(s_config.backend_mode)), finish, TAG_STORAGE, "Failed to load backend mode");
    ESP_GOTO_ON_ERROR(storage_load_string(handle, "backend_url", s_config.backend_base_url, sizeof(s_config.backend_base_url)), finish, TAG_STORAGE, "Failed to load backend url");

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
    ESP_LOGI(TAG_WIFI, "Connecting to Wi-Fi SSID=%s", s_config.wifi_ssid);
}

static void wifi_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data) {
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        if (s_config.wifi_ssid[0] != '\0') {
            restart_wifi_connection();
        }
        return;
    }

    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        xEventGroupClearBits(s_wifi_events, WIFI_CONNECTED_BIT);
        s_wifi_state = WIFI_STATE_DISCONNECTED;
        set_last_error("Wi-Fi disconnected");
        notify_device_info();
        ESP_LOGW(TAG_WIFI, "Wi-Fi disconnected, retrying");

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
        "{\"deviceId\":\"%s\",\"firmwareVersion\":\"0.2.0\",\"paired\":%s,"
        "\"reedState\":\"%s\",\"wifiState\":\"%s\",\"provisioningState\":\"%s\","
        "\"lastError\":\"%s\"}",
        s_config.device_id,
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

    safe_copy(destination, destination_size, item->valuestring);
    return ESP_OK;
}

static esp_err_t apply_pair_command(const pair_command_t *command) {
    if (command->wifi_ssid[0] == '\0' || command->pairing_token[0] == '\0' || command->family_id[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    safe_copy(s_config.pairing_token, sizeof(s_config.pairing_token), command->pairing_token);
    safe_copy(s_config.family_id, sizeof(s_config.family_id), command->family_id);
    safe_copy(s_config.wifi_ssid, sizeof(s_config.wifi_ssid), command->wifi_ssid);
    safe_copy(s_config.wifi_password, sizeof(s_config.wifi_password), command->wifi_password);
    safe_copy(s_config.backend_mode, sizeof(s_config.backend_mode), command->backend_mode);
    safe_copy(s_config.backend_base_url, sizeof(s_config.backend_base_url), command->backend_base_url);
    s_config.paired = true;
    s_provisioning_state = PROVISIONING_STATE_PROVISIONING;
    xSemaphoreGive(s_state_mutex);

    clear_last_error();
    ESP_RETURN_ON_ERROR(storage_save_config(), TAG_STORAGE, "Failed to persist pair command");

    ble_svc_gap_device_name_set("DoseLatch");
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

    if (context->om->om_len >= JSON_BUFFER_LENGTH) {
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    char json_buffer[JSON_BUFFER_LENGTH] = {0};
    int result = os_mbuf_copydata(context->om, 0, context->om->om_len, json_buffer);
    if (result != 0) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    cJSON *root = cJSON_Parse(json_buffer);
    if (root == NULL) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    pair_command_t command = {0};
    esp_err_t error = copy_json_string(root, "pairingToken", command.pairing_token, sizeof(command.pairing_token), true);
    if (error == ESP_OK) {
        error = copy_json_string(root, "familyId", command.family_id, sizeof(command.family_id), true);
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
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    error = apply_pair_command(&command);
    if (error != ESP_OK) {
        set_last_error("Provisioning apply failed");
        s_provisioning_state = PROVISIONING_STATE_FAILED;
        return BLE_ATT_ERR_UNLIKELY;
    }

    ESP_LOGI(TAG_BLE, "Pair command accepted for family=%s ssid=%s", command.family_id, command.wifi_ssid);
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
            } else {
                ESP_LOGW(TAG_BLE, "BLE connect failed status=%d", event->connect.status);
                start_advertising();
            }
            return 0;
        case BLE_GAP_EVENT_DISCONNECT:
            s_ble_connection_handle = BLE_HS_CONN_HANDLE_NONE;
            ESP_LOGI(TAG_BLE, "BLE client disconnected");
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

static void upload_task(void *argument) {
    device_event_t event = {0};

    for (;;) {
        EventBits_t bits = xEventGroupGetBits(s_wifi_events);
        if ((bits & WIFI_CONNECTED_BIT) == 0) {
            vTaskDelay(pdMS_TO_TICKS(500));
            continue;
        }

        if (xQueueReceive(s_event_queue, &event, pdMS_TO_TICKS(1000)) != pdPASS) {
            continue;
        }

        char payload[JSON_BUFFER_LENGTH] = {0};
        snprintf(
            payload,
            sizeof(payload),
            "{\"deviceId\":\"%s\",\"eventType\":\"%s\",\"timestamp\":\"%lld\","
            "\"firmwareVersion\":\"0.2.0\"}",
            s_config.device_id,
            reed_state_label(event.is_open),
            (long long) event.timestamp_ms
        );

        if (strcmp(s_config.backend_mode, "http") == 0 && s_config.backend_base_url[0] != '\0') {
            // ponytail: keep the uploader interface stable now; swap this log-only branch for esp_http_client when the backend contract exists.
            ESP_LOGW(TAG_QUEUE, "HTTP backend not implemented yet, payload=%s url=%s", payload, s_config.backend_base_url);
            continue;
        }

        ESP_LOGI(TAG_QUEUE, "Mock backend accepted payload=%s", payload);
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

    xTaskCreate(reed_task, "reed_task", 4096, NULL, 10, &s_reed_task_handle);
    reed_init();
    wifi_init();
    ble_init();

    xTaskCreate(upload_task, "upload_task", 4096, NULL, 8, NULL);
    xTaskCreate(console_task, "console_task", 4096, NULL, 5, NULL);
}
