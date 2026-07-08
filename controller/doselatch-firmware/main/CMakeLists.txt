idf_component_register(
    SRCS "app_main.c"
    INCLUDE_DIRS "."
    REQUIRES bt esp_driver_gpio esp_event esp_http_client esp_netif esp_timer esp_wifi json lwip mbedtls nvs_flash
)
