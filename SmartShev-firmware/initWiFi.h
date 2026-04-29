#ifndef MAIN_SRC_WIFI_INITWIFI_H_
#define MAIN_SRC_WIFI_INITWIFI_H_

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_event.h"
#include "esp_wifi.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"

#include "esp_mac.h"

#include "lwip/err.h"
#include "lwip/sys.h"

#include "esp_http_client.h"
#include "esp_https_ota.h"
#include "esp_system.h"
#include "MyStruct.h"


void wifi_init_sta(struct _DataToSend *DataToSend, struct _DataWiFiServer *DataWiFiServer, struct _SistemFlags *SistemFlags, struct _PositionGUI * NumberGUI);

esp_err_t _http_event_handler_get(esp_http_client_event_t *evt);
esp_err_t _http_event_handler(esp_http_client_event_t *evt);

void TestConnectToServer(struct _DataWiFiServer * DataWiFiServer);

void WiFiStop(void);
void WiFiStart(void);
void WiFiDeinit(void);

void GetMACAddr(char tmpMac[13]);

#endif /* MAIN_SRC_WIFI_INITWIFI_H_ */
